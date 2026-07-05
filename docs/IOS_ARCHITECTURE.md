# iOS + унификация ядра: архитектурное решение

Статус: **принято** (архитектурная развилка). Исполнение требует macOS + Xcode +
платного Apple Developer аккаунта — в CI/песочнице не собирается.

## Проблема

- **iOS не работает вообще.** Плагин `flutter_v2ray` на iOS — заглушка (~19 строк,
  возвращает только версию ОС). Нет `NEPacketTunnelProvider` → нет туннеля.
  Половина рынка (и менее технические, платящие пользователи) недоступна.
- **Протокольный гэп.** `xray-core` (что оборачивает flutter_v2ray) НЕ умеет
  Hysteria2 / TUIC / ShadowTLS — мы их честно отключили (`BypassMode.isAvailable`).

## Решение: единое ядро **sing-box** для Android + iOS

Не тащим xray на iOS (почти никто так не делает). Переезжаем на **sing-box** как
на единственное VPN-ядро на обеих платформах.

Почему sing-box:
- **Официальная iOS-поддержка** (`libbox`, собирается gomobile → `.xcframework`).
  На нём стоят sing-box iOS, Karing, Hiddify — проверенный путь.
- **Одно ядро на Android + iOS** → одинаковое поведение, один формат конфига,
  одна кодовая база логики обхода. Сейчас Android = xray, iOS = ничего.
- **Умеет то, чего не умеет xray**: Hysteria2, TUIC, ShadowTLS — плюс VLESS +
  Reality + Vision, gRPC, WebSocket, HTTPUpgrade, mux. То есть переезд ЗАОДНО
  честно возвращает отключённые протоколы.
- Конфиг — JSON (формат sing-box), генерируется в Dart (единый источник правды).

Цена: это своп ядра и на **Android** тоже (замена flutter_v2ray). Это осознанно:
альтернатива «xray на Android + sing-box на iOS» = два ядра, два формата,
расходящееся поведение — не «идеально».

## Целевая архитектура

```
Dart (общий)
 ├─ VpnEngine (интерфейс: start/stop/status)        ← абстракция ядра
 ├─ SingBoxConfigBuilder → sing-box JSON            ← единый билдер конфига
 └─ MethodChannel('vly_vpn/core')                   ← мост в натив
     ├─ Android: SingBoxService (libbox .aar) + VpnService (foreground)
     └─ iOS: PacketTunnelProvider (NetworkExtension) + libbox .xcframework
              ├─ App Group (общий контейнер: app → extension передаёт конфиг)
              └─ Entitlements: packet-tunnel-provider + App Groups
```

Ключ: **и Android, и iOS потребляют один и тот же sing-box JSON**, собранный в
Dart. Логика обхода (AiBypassAgent, каскад, мутации, бандит) не меняется — меняется
только целевой формат в билдере конфига и транспорт запуска.

## План миграции (фазами, каждая — отдельный PR)

1. **Dart-абстракция (безопасно, тестируемо).** Ввести `VpnEngine`; текущий
   flutter_v2ray спрятать за ним без смены поведения. Это подготавливает своп и
   не ломает Android.
2. **SingBoxConfigBuilder (Dart, тестируемо).** Генерация sing-box `outbounds`/
   `route`/`inbounds` из `VpnConfig` + `BypassStrategy`. Юнит-тесты формата — как
   уже есть для xray-конфигов (`bypass_logic_test.dart`).
3. **Android: интеграция libbox.** Собрать sing-box gomobile `.aar`, реализовать
   `SingBoxEngine` через канал `vly_vpn/core`; гонять параллельно со старым ядром
   за feature-flag; проверить паритет; затем cut-over и удалить flutter_v2ray.
4. **iOS: NetworkExtension.** Создать target в Xcode, реализовать
   `PacketTunnelProvider` с libbox, передачу конфига через App Group, entitlements.
   Тест на устройстве через TestFlight.
5. **Вернуть протоколы.** Флипнуть `BypassMode.isAvailable` → Hysteria2/TUIC/
   ShadowTLS снова в пикере и каскаде (теперь реально рабочие); вернуть их в
   `_buildCascade`.

## Готовые сниппеты (вставить при исполнении в Xcode)

### iOS entitlements (Runner + расширение)
```xml
<key>com.apple.developer.networking.networkextension</key>
<array><string>packet-tunnel-provider</string></array>
<key>com.apple.security.application-groups</key>
<array><string>group.app.vlyvpn</string></array>
```

### iOS `PacketTunnelProvider.swift` (скелет)
```swift
import NetworkExtension
import Libbox   // из собранного libbox.xcframework

class PacketTunnelProvider: NEPacketTunnelProvider {
  private var boxService: LibboxBoxService?

  override func startTunnel(options: [String : NSObject]?,
                            completionHandler: @escaping (Error?) -> Void) {
    // Конфиг кладёт app в App Group; читаем и запускаем sing-box.
    guard let cfg = SharedConfig.read(group: "group.app.vlyvpn") else {
      completionHandler(NSError(domain: "vly", code: 1)); return
    }
    do {
      let box = try LibboxNewService(cfg, PlatformInterface(self))
      try box.start()
      self.boxService = box
      completionHandler(nil)
    } catch { completionHandler(error) }
  }

  override func stopTunnel(with reason: NEProviderStopReason,
                           completionHandler: @escaping () -> Void) {
    try? boxService?.close(); boxService = nil; completionHandler()
  }
}
```

### Dart-мост (интерфейс, платформо-независимый)
```dart
abstract class VpnEngine {
  Future<void> start(String singBoxJson);
  Future<void> stop();
  Stream<String> get status; // 'connecting'|'connected'|'error'|'disconnected'
}
// Реализация через const MethodChannel('vly_vpn/core').
```

## Требования и риски

- **Apple Developer аккаунт** (платный) — entitlement NetworkExtension выдаётся
  только с ним; provisioning profile с capability Packet Tunnel.
- **Сборка libbox** через gomobile из исходников sing-box (Go toolchain) → `.aar`
  (Android) и `.xcframework` (iOS). Нетривиально, но документировано в sing-box.
- **Паритет поведения** с текущим xray-флоу — проверять фаза 3 за флагом.
- **Размер приложения**: libbox добавляет ~10–20 МБ на платформу.
- **Reality** в sing-box поддерживается (inbound/outbound) — регресса нет.
- **Play Protect / App Store review**: VPN-приложения требуют декларации
  (Android: Core Functionality → VPN; iOS: обоснование NetworkExtension).

## Оценка объёма (для человека с Mac + Apple аккаунтом)

- Фазы 1–2 (Dart абстракция + sing-box config builder + тесты): ~1 неделя.
- Фаза 3 (Android libbox, паритет, cut-over): ~1–2 недели.
- Фаза 4 (iOS NetworkExtension, gomobile, provisioning, device-тест): ~2–4 недели.

## Что НЕ сделано здесь и почему

Нативная часть (Swift, project.pbxproj target, gomobile-сборка libbox,
entitlements в Xcode) в этом окружении не выполнялась: нет macOS/Xcode-тулчейна,
а ручная правка `project.pbxproj` для добавления NetworkExtension-таргета
ломает Xcode-проект. Этот документ — принятое решение + готовый план и сниппеты,
чтобы исполнение на Mac было механическим.
