// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

// ─── CONSTANTS ───────────────────────────────────────────────────────────────

const String kControlPlaneUrl   = 'https://api.vlyvpn.app';

// ── Certificate Pinning ───────────────────────────────────────────────────────
// Отпечатки сертификата нашего сервера api.vlyvpn.app. Enforcement включается
// в PinnedHttpClient АВТОМАТИЧЕСКИ, как только здесь появятся реальные значения
// (не PLACEHOLDER). Пока placeholders — работает обычная CA-проверка.
// Формат: base64(sha256(DER всего сертификата)).
// Получить значение можно двумя путями:
//   1) PinnedHttpClient.fetchFingerprint('https://api.vlyvpn.app') — вернёт
//      готовую строку для вставки сюда;
//   2) openssl s_client -connect api.vlyvpn.app:443 </dev/null 2>/dev/null |
//        openssl x509 -outform DER | openssl dgst -sha256 -binary | base64
// Пиньте ДВА значения (текущий + резервный/следующий сертификат), чтобы ротация
// сертификата не оборвала клиентов.
const kPinnedSha256 = [
  'PLACEHOLDER_REPLACE_WITH_REAL_SHA256_OF_YOUR_CERT==',  // Primary cert
  'PLACEHOLDER_REPLACE_WITH_REAL_SHA256_OF_BACKUP_CERT==', // Backup / next cert
];

// Домены для которых применяется cert pinning (только наши серверы)
// Cloudflare, Google, antifilter.download — без pinning (у них своя цепочка)
const kPinnedDomains = ['api.vlyvpn.app', 'vlyvpn.app'];

const String kBypassRulesUrl    = '$kControlPlaneUrl/bypass_rules.json';
const String kTelemetryUrl      = '$kControlPlaneUrl/telemetry';
const String kNodesUrl          = '$kControlPlaneUrl/nodes.json';
// Серверные mutation-программы для AI-каскада (обновляются без пересборки app).
const String kAiMutationsUrl    = '$kControlPlaneUrl/ai_mutations.json';
// Проверка обновлений (sideload APK: пользователь должен обновляться сам, иначе
// застрянет на старых версиях протоколов пока сеть эволюционирует).
const String kUpdateUrl         = '$kControlPlaneUrl/version.json';
// Версия схемы mutation-программы, которую УМЕЕТ интерпретировать этот клиент.
// Программа с min_client > этого значения отвергается (клиент слишком старый).
const int    kAiCascadeSchema   = 1;

// ── Stealth Engine 2.0 — Dead Drop зеркала ──────────────────────────────────
// Если основной API недоступен — берём ноды из этих источников
// Порядок: сначала Яндекс/VK (белый список провайдер) → потом GitHub → DNS TXT
const List<String> kDeadDropMirrors = [
  // ── Tier 0: Яндекс — всегда белый список провайдер (AS13238) ───────────────────
  // storage.yandexcloud.net: S3-совместимое Object Storage, Яндекс CDN
  // Не блокируется т.к. используется тысячами российских сайтов
  'https://storage.yandexcloud.net/vlyvpn-nodes/nodes.json',
  // Яндекс Диск public link (через get.disk.yandex.net — белый список)
  'https://getfile.dokpub.com/yandex/get/https://disk.yandex.ru/d/vlyvpn-nodes',

  // ── Tier 1: VK — крупнейшая российская соцсеть (AS47541) ─────────────────
  // userapi.com / vk.com CDN — блокировка означает падение ВКонтакте
  'https://vk.com/doc-vlyvpn_nodes',             // VK Documents (публичный)
  'https://sun6-21.userapi.com/vlyvpn/nodes.json', // VK CDN edge

  // ── Tier 2: GitHub (международный, может быть заблокирован) ──────────────
  'https://raw.githubusercontent.com/vlyvpn/nodes/main/nodes.json',
  'https://gist.githubusercontent.com/vlyvpn/nodes/raw/nodes.json',

  // ── Tier 3: jsDelivr CDN — зеркало GitHub через CDN ─────────────────────
  // jsDelivr использует Cloudflare + Fastly — сложнее заблокировать
  'https://cdn.jsdelivr.net/gh/vlyvpn/nodes@main/nodes.json',

  // DNS TXT: dig TXT nodes.vlyvpn.app — содержит base64 списка нод
];
const String kDeadDropDnsTxt = 'nodes.vlyvpn.app';

// ── Browser identity — ЕДИНЫЙ источник правды ────────────────────────────────
// Обновлено 28.06.2026. Раньше версии Chrome (134/135/136/137) и User-Agent
// были захардкожены и разбросаны по 5 файлам (networking/stealth/camouflage/
// netcond_2026). Они рассинхронизировались между собой и с uTLS fingerprint.
// Рассинхрон UA ↔ TLS fingerprint = готовый признак для ML-классификатора DPI
// (слой 4 — поведенческий анализ). При обновлении браузеров правим ТОЛЬКО здесь.
const String kChromeMajor    = '138';
const String kChromeFull     = '138.0.7204.97';
const String kEdgeFull       = '138.0.3351.65';
const String kIosUaVersion   = '18_5';   // подчёркивания — формат внутри UA
const String kSafariVersion  = '18.5';
const String kFirefoxVersion = '140.0';

// Канонический пул реалистичных User-Agent (доли рынка РФ, июнь 2026):
// Android Chrome ~45% · iOS Safari ~30% · Windows Chrome/Edge ~20% · прочее ~5%.
// Используется и для warm-up запросов, и для HTTP-камуфляжа outbound'ов.
const List<String> kModernUserAgents = [
  // Android Chrome — самый частый клиент в РФ
  'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 15; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; 23049PCD8G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
  // iOS Safari
  'Mozilla/5.0 (iPhone; CPU iPhone OS $kIosUaVersion like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$kSafariVersion Mobile/15E148 Safari/604.1',
  // Windows Chrome
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Safari/537.36',
  // Windows Edge
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Safari/537.36 Edg/$kEdgeFull',
];

// Случайный реалистичный User-Agent из канонического пула.
final Random _kUaRng = Random();
String randomUserAgent() => kModernUserAgents[_kUaRng.nextInt(kModernUserAgents.length)];

// ── Post-Quantum fingerprint (дыра обнаружена 28.06.2026) ────────────────────
// ~57% Chrome ClientHello несут key share X25519MLKEM768 (+1088 байт). Его
// ОТСУТСТВИЕ при UA=Chrome — прямой fingerprint-mismatch, срабатывает ДО HTTP:
// DPI/CDN сверяют наличие PQ-keyshare с User-Agent. Старый uTLS 'chrome' без
// PQ-keyshare выдаёт VPN. Реальный PQ-handshake делает НАТИВНЫЙ xray-core —
// из Dart мы это не контролируем, поэтому требование к движку, не к клиенту:
//   • нужен свежий xray-core (PQ-fingerprint: mlkem768 / mldsa65 в Reality);
//   • Reality-сервер должен иметь PQ-ключи (xray x25519 --pq / mldsa65).
// Здесь — флаг и заметка, чтобы UI/диагностика показывали статус требования.
const bool   kRequiresPqFingerprint = true;
const String kPqKeyShare            = 'X25519MLKEM768';

// Reality SNI пул — высокоавторитетные домены (в белом списке провайдер)
// SNI-пул актуализирован 28.03.2026
// Источник: анализ CIDR белых списков DPI + net4people/bbs #490 + XTLS/Xray-examples
// Критерии: (1) IP в CIDR-whitelist провайдер, (2) TLS1.3 + поддержка REALITY, (3) не блокируется в РФ
// ВАЖНО: dest и serverName должны совпадать — XTLS-Vision требует реального TLS с этого сервера
const List<String> kRealitySniPool = [
  // ── Tier 0: ЯНДЕКС — 100% белый список провайдер (AS13238, 77.88.0.0/18) ──────
  // Самый надёжный выбор для России — Яндекс никогда не блокируется
  'www.yandex.ru',               // Яндекс главная — иконический российский домен
  'mail.yandex.ru',              // Яндекс Почта — корпоративный whitelist
  'yastatic.net',                // Яндекс Static CDN — используется тысячами сайтов
  'storage.yandexcloud.net',     // Яндекс Object Storage S3 — корпоративный трафик
  'api.browser.yandex.com',      // Яндекс Браузер API — высокий трафик

  // ── Tier 1: VK / MAIL.RU GROUP (AS47541, 87.240.128.0/18) ───────────────
  // Блокировка VK = социальный коллапс → DPI никогда не тронет
  'vk.com',                      // ВКонтакте — крупнейшая соцсеть РФ
  'userapi.com',                 // VK CDN — медиа контент всех пользователей
  'mail.ru',                     // Mail.ru — почта, белый список
  'ok.ru',                       // Одноклассники — белый список

  // ── Tier 2: MICROSOFT — крупнейший CIDR whitelist (20.112.0.0/13) ────────
  'www.microsoft.com',           // Рекомендован XTLS-examples для России/Ирана
  'login.microsoft.com',         // Microsoft Login — высокий корпоративный трафик
  'login.microsoftonline.com',   // Azure AD OAuth — в белом списке провайдер
  'update.microsoft.com',        // Windows Update — критически важен для провайдер
  'office.com',                  // Microsoft Office Online
  'teams.microsoft.com',         // Microsoft Teams — корпоративный, всегда whitelist

  // ── Tier 3: APPLE — iCloud всегда доступен (17.0.0.0/8) ──────────────────
  'www.apple.com',               // Рекомендован XTLS/Xray-examples как dest
  'gateway.icloud.com',          // iCloud Gateway — Private Relay IP
  'mask.icloud.com',             // iCloud Private Relay — надёжный SNI
  'swscan.apple.com',            // Apple Software Updates — corporate whitelist

  // ── Tier 4: GOOGLE — максимальный трафик (142.250.0.0/15) ────────────────
  'dl.google.com',               // Google Download CDN
  'www.gstatic.com',             // Google Static — connectivitycheck хост
  'accounts.google.com',         // Google Auth
  'play.googleapis.com',         // Google Play

  // ── Tier 5: CLOUDFLARE — крупнейший CDN (104.16.0.0/13) ─────────────────
  'www.cloudflare.com',          // Cloudflare главная
  'speed.cloudflare.com',        // Cloudflare Speed Test — в whitelist

  // ── Tier 6: AMAZON AWS — глобальный CDN (205.251.0.0/17) ─────────────────
  'www.amazon.com',              // Рекомендован XTLS/Xray-examples
  'd1.awsstatic.com',            // AWS Static CDN

  // ── Tier 7: MOZILLA — Firefox в корпоративных whitelist ──────────────────
  'addons.mozilla.org',          // Firefox Addons
  'aus5.mozilla.org',            // Firefox Auto-Update
];

// CDN Workers URL для финального fallback
// Трафик идёт через Cloudflare CDN — блокировка означает блокировку половины интернета
const List<String> kCdnFallbackUrls = [
  'https://vly-vpn.workers.dev',  // Cloudflare Workers
  'https://vly-cdn.pages.dev',    // Cloudflare Pages
];

// ── Hysteria2 настройки по умолчанию ────────────────────────────────────────
// Hysteria2 использует QUIC (UDP) — DPI плохо фильтрует UDP трафик
// Salamander: XOR обфускация QUIC пакетов — скрывает Hysteria fingerprint
// Порт 443 — выглядит как QUIC/HTTP3 (Chrome, YouTube используют QUIC)
const kHysteria2Defaults = {
  'obfs':           'salamander',  // обфускация протокола
  'obfsPassword':   '',            // заполняется из конфига ноды
  'sni':            '',            // заполняется из SNI пула
  'insecure':       false,         // не использовать без крайней нужды
  'fastOpen':       true,          // TFO — ускоряет переподключения
  'lazy':           false,         // не ленивое — сразу устанавливаем туннель
  'bandwidth': {
    'up':   '50 mbps',
    'down': '200 mbps',
  },
};

// Warm-up домены — реальный HTTPS трафик перед VPN туннелем
// Warm-up домены обновлены март 2026:
// Используем те же URL что запрашивает Android при подключении к WiFi
// DPI не может заблокировать эти домены без отключения миллионов устройств
const List<String> kWarmupTargets = [
  // Google — самый надёжный, отвечает 204 за ~10ms
  'https://connectivitycheck.gstatic.com/generate_204',
  // Microsoft — Windows Update белый список
  'https://www.msftconnecttest.com/connecttest.txt',
  // Firefox — браузерный traffic
  'https://detectportal.firefox.com/success.txt',
  // Apple — iOS connectivity check
  'https://captive.apple.com/hotspot-detect.html',
  // Cloudflare — CDN trace
  'https://1.1.1.1/cdn-cgi/trace',
];
const String kSupportEmail      = 'support@vlyvpn.app';
const int    kLocalRulesVersion = 0;
const String kBackupMagic       = 'VLY_VPN_BACKUP_V1';

// ─── COLORS ──────────────────────────────────────────────────────────────────

// ── Версия приложения ────────────────────────────────────────────────────────
// ЕДИНСТВЕННЫЙ источник версии — pubspec.yaml (`version: X.Y.Z+build`). При
// старте AppInfo.load() читает реальные значения из собранного пакета через
// package_info_plus и кладёт в gAppVersion/gAppBuild. Константы ниже — только
// запасной вариант на случай, если плагин не успел/не смог загрузиться (тесты,
// холодный старт до init). Больше НЕ нужно править версию в двух местах.
const kAppVersion = '6.4.0';
const kAppBuild   = '20260628';

// Живые значения версии/билда (обновляются AppInfo.load() из pubspec).
String gAppVersion = kAppVersion;
int    gAppBuild   = int.tryParse(kAppBuild) ?? 0;

class AppInfo {
  // Читаем реальную версию собранного APK — display и update-check берут отсюда,
  // поэтому версия всегда совпадает с pubspec без ручной синхронизации.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) gAppVersion = info.version;
      final b = int.tryParse(info.buildNumber);
      if (b != null && b > 0) gAppBuild = b;
    } catch (_) {/* остаёмся на запасных константах */}
  }
}

// ── Responsive breakpoints ────────────────────────────────────────────────────
// phone < 600  |  tablet 600-840  |  desktop > 840
// Все функции — extension на BuildContext для удобного доступа
extension VlyLayout on BuildContext {
  double get screenW   => MediaQuery.of(this).size.width;
  double get screenH   => MediaQuery.of(this).size.height;
  bool   get isTablet  => screenW >= 600;
  bool   get isDesktop => screenW >= 840;
  bool   get isLandscape => screenW > screenH;

  // Максимальная ширина контентной колонки (центрируется на планшете)
  double get contentMaxW => isTablet ? 640.0 : double.infinity;

  // Отступы: на планшете горизонтальные увеличены
  EdgeInsets get pagePadding => isTablet
      ? EdgeInsets.symmetric(horizontal: ((screenW - 640) / 2).clamp(24.0, 120.0), vertical: 16)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 0);

  // Число колонок для грида нод
  int get nodeColumns => isDesktop ? 3 : (isTablet && isLandscape ? 2 : 1);
}

// Нейтральный User-Agent для всех исходящих HTTP запросов (Dead Drop, DoH, warm-up).
// 'VlyVPN/5.6.0' мгновенно идентифицирует трафик системами провайдер/DPI.
// Версия привязана к единому источнику kChromeFull (обновл. 28.06.2026).
const kStealthUA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/$kChromeFull Mobile Safari/537.36';

// Пул UA для ротации — каждый запрос выглядит как другое устройство.
// Берём из единого канонического пула (см. kModernUserAgents выше).
const kStealthUAPool = kModernUserAgents;

// Акцентные цвета — управляются через VlySkin (динамические)
// Дефолтные значения — используются до инициализации скина
Color _accent     = const Color(0xFF00E5FF);
Color _accentBlue = const Color(0xFF4FC3F7);
const _accentPurple = Color(0xFFB39DDB);
const _accentGold   = Color(0xFFFFD740);

// ═══════════════════════════════════════════════════════════════
//  i18n
// ═══════════════════════════════════════════════════════════════