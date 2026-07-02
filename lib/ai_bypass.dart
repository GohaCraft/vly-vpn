// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  AI BYPASS ENGINE v6.0 — актуализировано 28.06.2026
//  Источники: ntc.rkn.quest, net4people, XTLS/Xray-core discussions, habr.
//
//  СТАТУС МЕТОДОВ (июнь 2026):
//  ✅ VLESS + Reality + xHTTP   — ЛУЧШИЙ. Reality detection stable-low.
//  ✅ VLESS + Reality + gRPC     — хорошо.
//  ✅ VLESS + Reality + RAW(tcp) + Vision — надёжно.
//  ⚠️ Hysteria2 (QUIC)          — ДЕГРАДИРУЕТ: ~40% детекта (КНР, май 2026),
//                                  QUIC-fingerprint отличим от Chrome.
//                                  НЕ совместим с Reality (нужен LE/selfsigned).
//  ❌ VLESS + WebSocket          — HTTP Upgrade детектируется давно и надёжно.
//  ❌ ShadowTLS                  — НЕ поддерживается xray-core (только sing-box).
//  ❌ OpenVPN / WireGuard plain  — детект на первом байте.
//
//  🔑 ВАЖНО (ограничение Reality): Reality работает ТОЛЬКО с транспортами
//     RAW(tcp) / xHTTP / gRPC. С WebSocket и Hysteria2 — несовместим.
//
//  🔑 ДЫРА FINGERPRINT (post-quantum): ~57% Chrome ClientHello несут key share
//     X25519MLKEM768 (+1088 байт). Его ОТСУТСТВИЕ при UA=Chrome — прямой
//     fingerprint-mismatch, срабатывает ДО первого байта HTTP. Нужен свежий
//     xray-core с PQ-fingerprint (mlkem768 / mldsa65 в Reality). См. constants.
//
//  ТСПУ работает в 4 слоя:
//  1. Сигнатурный (первые 16-32 байта) — убивает SS/OpenVPN/WG
//  2. JA3/JA4 + PQ key share            — убивает плохой/устаревший VLESS
//  3. IP/ASN несоответствие (SNI vs IP) — проверяет реальность
//  4. Поведенческий ML (энтропия, паттерны пакетов)
//
//  Белые списки (мобильный, июнь 2026): пропускают трафик ТОЛЬКО на whitelisted
//  IP (Яндекс/VK/Госуслуги/банки). Cloudflare НЕ в списке → CDN-фронтинг
//  работает лишь на Wi-Fi. Для мобильного нужен сервер на whitelisted-ASN.
//  SNI обязан быть из российского whitelist, иначе не проходит даже handshake.
// ═══════════════════════════════════════════════════════════════════════════

// ── Режим байпаса ──────────────────────────────────────────────────────────
enum BypassMode {
  auto,        // AUTO: умный каскад (рекомендуется)
  hysteria2,   // Принудительно Hysteria2/QUIC/UDP
  xhttp,       // VLESS + xHTTP (лучший TCP-метод 2026)
  realityVk,   // VLESS + Reality + VK/Yandex SNI (белые списки)
  grpc,        // VLESS + gRPC
  shadowtls,   // ShadowTLS v3 + Shadowsocks
  whitelist,   // Режим белых списков (domain fronting)
}

extension BypassModeInfo on BypassMode {
  String get label {
    switch (this) {
      case BypassMode.auto:       return 'AUTO (рекомендуется)';
      case BypassMode.hysteria2:  return 'Hysteria2 / QUIC';
      case BypassMode.xhttp:      return 'VLESS + xHTTP';
      case BypassMode.realityVk:  return 'VLESS + Reality (VK SNI)';
      case BypassMode.grpc:       return 'VLESS + gRPC';
      case BypassMode.shadowtls:  return 'ShadowTLS v3';
      case BypassMode.whitelist:  return 'Белые списки';
    }
  }
  String get description {
    switch (this) {
      case BypassMode.auto:      return 'Автоматически выбирает лучший метод. Пробует каскад из 10+ стратегий.';
      case BypassMode.hysteria2: return 'UDP протокол — ТСПУ плохо анализирует UDP. Лучший выбор при белых списках.';
      case BypassMode.xhttp:    return 'Новый транспорт Xray 2026. Выглядит как обычный HTTP upload — не детектируется.';
      case BypassMode.realityVk: return 'SNI из белого списка МТС. Трафик выглядит как обращение к VK/Яндекс.';
      case BypassMode.grpc:      return 'gRPC транспорт. Хуже xHTTP но стабильнее при нестабильном соединении.';
      case BypassMode.shadowtls: return 'TLS-туннель поверх реального TLS-сервера. Очень сложно детектировать.';
      case BypassMode.whitelist: return 'Domain fronting через CDN белого списка. Для жёстких белых списков.';
    }
  }
  String get emoji {
    switch (this) {
      case BypassMode.auto:      return '🤖';
      case BypassMode.hysteria2: return '⚡';
      case BypassMode.xhttp:     return '🌐';
      case BypassMode.realityVk: return '🛡';
      case BypassMode.grpc:      return '📡';
      case BypassMode.shadowtls: return '🔒';
      case BypassMode.whitelist: return '📋';
    }
  }
  String get status {
    switch (this) {
      case BypassMode.auto:      return '✅ Рекомендуется — июнь 2026';
      case BypassMode.hysteria2: return '⚠️ Деградирует — ~40% детекта (май 2026)';
      case BypassMode.xhttp:     return '✅ Лучший — Reality-совместим';
      case BypassMode.realityVk: return '✅ Лучший — Reality detection stable-low';
      case BypassMode.grpc:      return '✅ Актуально — Reality + gRPC';
      case BypassMode.shadowtls: return '❌ Не поддерживается xray-core → Reality';
      case BypassMode.whitelist: return '⚠️ Белые списки: нужен whitelisted-IP сервер';
    }
  }
  // Reality-методы (xHTTP/Reality) — приоритет: detection stable-low.
  // Hysteria2 убран из «рекомендуемых» — QUIC-fingerprint деградирует.
  bool get isRecommended => this == BypassMode.auto || this == BypassMode.xhttp || this == BypassMode.realityVk;
}

// ── Self-healing blacklist стратегий ───────────────────────────────────────
// КЛЮЧЕВАЯ защита от саморазрушения ИИ: провалившаяся стратегия НЕ убивается
// навсегда (иначе ИИ постепенно перебанит всё и обход умрёт). Вместо этого она
// уходит в cooldown с экспоненциальным backoff и АВТОМАТИЧЕСКИ возвращается в
// строй, когда cooldown истёк. Сеть/блокировки меняются — то, что не работало
// 10 минут назад, может заработать сейчас. markSuccess() мгновенно снимает бан.
class _BanEntry {
  final DateTime until;
  final int fails;
  const _BanEntry(this.until, this.fails);
  Map<String, dynamic> toJson() => {'u': until.millisecondsSinceEpoch, 'f': fails};
  static _BanEntry fromJson(Map j) => _BanEntry(
      DateTime.fromMillisecondsSinceEpoch((j['u'] as num).toInt()),
      (j['f'] as num).toInt());
}

class StrategyBlacklist {
  static final Map<String, _BanEntry> _banned = {};
  static bool _enabled = true;
  static const _baseCooldown = Duration(minutes: 8);
  static const _maxCooldown  = Duration(hours: 2);

  static bool isFailed(String type) {
    if (!_enabled) return false;
    final e = _banned[type];
    if (e == null) return false;
    if (DateTime.now().isAfter(e.until)) { _banned.remove(type); return false; } // cooldown истёк
    return true;
  }

  static void markFailed(String type) {
    if (!_enabled) return;
    final fails = (_banned[type]?.fails ?? 0) + 1;
    // Экспоненциальный backoff: 8м → 16м → 32м → 1ч4м → ... до потолка 2ч.
    var d = _baseCooldown * (1 << (fails - 1).clamp(0, 4));
    if (d > _maxCooldown) d = _maxCooldown;
    _banned[type] = _BanEntry(DateTime.now().add(d), fails);
  }

  // Стратегия сработала — снимаем бан немедленно (само-восстановление).
  static void markSuccess(String type) => _banned.remove(type);

  static void clear() => _banned.clear();

  // Активно забаненные (с непросроченным cooldown) — для диагностики/UI.
  static List<String> get allBlocked =>
      _banned.keys.where((t) => isFailed(t)).toList();

  static bool get isEnabled => _enabled;
  static void setEnabled(bool v) { _enabled = v; }

  // Сериализация для персиста между запусками (см. AiMemory).
  static Map<String, dynamic> toJson() =>
      _banned.map((k, v) => MapEntry(k, v.toJson()));
  static void restoreJson(Map<String, dynamic> j) {
    _banned.clear();
    j.forEach((k, v) { if (v is Map) _banned[k] = _BanEntry.fromJson(v); });
    _banned.removeWhere((_, v) => DateTime.now().isAfter(v.until)); // чистим просроченные
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AI MEMORY — долговременная память ИИ (сохраняется между запусками)
//
//  Раньше _lastWinnerType и StrategyBlacklist жили ТОЛЬКО в памяти → при каждом
//  перезапуске приложения ИИ учился с нуля. Теперь запоминаем:
//   • какая стратегия сработала на КАЖДОМ классе сети (mobile-whitelist /
//     mobile / wifi) — при возврате в такую сеть коннект сразу берёт победителя;
//   • состояние self-healing блеклиста (cooldown'ы стратегий).
//  Всё в SharedPreferences, запись дебаунсится.
// ═══════════════════════════════════════════════════════════════════════════
class AiMemory {
  static const _key = 'ai_memory_v1';
  static final Map<String, String> _winnerByNet = {};
  // Замеренная задержка успешной пробы: net -> strategyType -> ms (сглажено).
  // ИИ учится не «что работало», а «что работало БЫСТРЕЕ» в этой сети.
  static final Map<String, Map<String, int>> _latencyByNet = {};
  static Timer? _saveDebounce;

  // Класс сети — грубый «отпечаток» без спец-разрешений (SSID недоступен без
  // location). mobile+whitelist / mobile / wifi покрывают разные режимы обхода.
  static String netClass(bool mobile, bool whitelist) =>
      mobile ? (whitelist ? 'mobile_wl' : 'mobile') : 'wifi';

  static String? winnerFor(String net) => _winnerByNet[net];

  static void recordWinner(String net, String strategyType) {
    if (_winnerByNet[net] == strategyType) return;
    _winnerByNet[net] = strategyType;
    _scheduleSave();
  }

  // Запоминаем задержку успешной стратегии. EWMA (60% старое / 40% новое):
  // сглаживает джиттер сети, но следует за трендом деградации фронта.
  static void recordLatency(String net, String type, int ms) {
    if (ms < 0) return;
    final m = _latencyByNet.putIfAbsent(net, () => {});
    final prev = m[type];
    m[type] = prev == null ? ms : (prev * 0.6 + ms * 0.4).round();
    _scheduleSave();
  }

  static int? latencyFor(String net, String type) => _latencyByNet[net]?[type];

  // Типы стратегий этой сети, отсортированные по замеренной задержке
  // (самые быстрые — первыми). Пусто, если сеть ещё не изучена.
  static List<String> rankedTypes(String net) {
    final m = _latencyByNet[net];
    if (m == null || m.isEmpty) return const [];
    final e = m.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return e.map((x) => x.key).toList();
  }

  static void onBlacklistChanged() => _scheduleSave();

  static Map<String, String> get winners => Map.unmodifiable(_winnerByNet);

  static void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), save);
  }

  static Future<void> load() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final w = (j['winners'] as Map?)?.cast<String, dynamic>() ?? {};
      _winnerByNet
        ..clear()
        ..addEntries(w.entries.map((e) => MapEntry(e.key, e.value.toString())));
      final lat = (j['latency'] as Map?)?.cast<String, dynamic>() ?? {};
      _latencyByNet.clear();
      lat.forEach((net, m) {
        if (m is Map) {
          _latencyByNet[net] = m.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      });
      final bl = (j['blacklist'] as Map?)?.cast<String, dynamic>() ?? {};
      StrategyBlacklist.restoreJson(bl);
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({
        'winners':   _winnerByNet,
        'latency':   _latencyByNet,
        'blacklist': StrategyBlacklist.toJson(),
      }));
    } catch (_) {}
  }
}

// ── Детектор белых списков ──────────────────────────────────────────────────
class WhitelistBypassEngine {
  // Детект режима белого списка. Усилено 28.06.2026: вместо одиночной пробы
  // (1.1.1.1 — мог дать ложняк при флуктуации одного IP) пробуем НЕСКОЛЬКО
  // не-whitelisted зарубежных endpoint'ов параллельно. Whitelist = НИ ОДИН
  // зарубежный недоступен, НО российский whitelist-домен жив (иначе это просто
  // отсутствие сети, а не белый список).
  static const _foreignProbes = [
    ['1.1.1.1', 443], ['8.8.8.8', 443], ['9.9.9.9', 443], ['208.67.222.222', 443],
  ];
  static Future<bool> isWhitelistActive() async {
    int reachable = 0;
    await Future.wait(_foreignProbes.map((e) async {
      try {
        final s = await Socket.connect(e[0] as String, e[1] as int,
            timeout: const Duration(milliseconds: 1500));
        s.destroy();
        reachable++;
      } catch (_) {}
    }));
    if (reachable > 0) return false; // хоть один зарубежный доступен → не whitelist
    // Все зарубежные мертвы — отличаем whitelist от полного отсутствия сети.
    try {
      final addrs = await InternetAddress.lookup('vk.com')
          .timeout(const Duration(seconds: 2));
      return addrs.isNotEmpty;
    } catch (_) {
      return false; // сети нет вообще
    }
  }

  // Определить тип сети: мобильный или WiFi
  static Future<bool> isMobileNetwork() async {
    try {
      // Пробуем характерный для WiFi хост
      final s = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 1));
      s.destroy();
      return false; // Google DNS работает = WiFi или нет белых списков
    } catch (_) {
      return true; // Вероятно мобильный с белыми списками
    }
  }

  // Актуальные SNI для белого списка МТС апрель 2026
  // Важно: SNI должен быть физически близко к серверу!
  static const kMobileSniWhitelist = [
    // Tier 0: НИКОГДА не блокируются (МТС/Ростелеком)
    'vk.com', 'userapi.com', 'vkvideo.ru', 'vkontakte.ru',
    'yandex.ru', 'ya.ru', 'yandex.net',
    // Tier 1: Госсервисы
    'gosuslugi.ru', 'mos.ru', 'nalog.ru',
    // Tier 2: Банки
    'sber.ru', 'alfabank.ru', 'vtb.ru', 'gazprombank.ru', 'psbank.ru',
    'raiffeisen.ru', 'tinkoff.ru', 'mtsbank.ru',
    // Tier 3: Операторы
    'mts.ru', 'beeline.ru', 'megafon.ru',
    // Tier 4: Маркетплейсы
    'ozon.ru', 'wildberries.ru', 'avito.ru',
    // Tier 5: Медиа
    'rbc.ru', 'ria.ru', 'tass.ru', 'kommersant.ru',
    // Tier 6: Транспорт
    'rzd.ru', 'aeroflot.ru', '2gis.ru',
    // Tier 7: Прочее
    'mail.ru', 'ok.ru', 'rambler.ru',
  ];

  // SNI для WiFi (обычные блокировки, не белые списки)
  static const kWifiSniList = [
    // Крупные CDN которые пропускает ТСПУ
    'www.microsoft.com', 'login.microsoftonline.com', 'dl.google.com', 'update.googleapis.com',
    'gateway.icloud.com', 'itunes.apple.com', 'cdn.cloudflare.com',
    'ajax.googleapis.com', 'fonts.googleapis.com',
    // Российские домены физически близкие к EU-серверам
    'vk.com', 'yandex.ru', 'mail.ru',
  ];

  // ═══ ИЗМЕРЯЕМЫЙ АВТО-DISCOVERY ФРОНТОВ ════════════════════════════════════
  // Раньше getBestSni() возвращал СЛУЧАЙНЫЙ SNI (millisecond % len) — наугад,
  // без проверки, работает ли он сейчас. Это «как у всех». Здесь — измерение:
  // параллельно проверяем реальную доступность каждого whitelist-фронта в ТЕКУЩЕЙ
  // сети, ранжируем по задержке, кэшируем на TTL и переоткрываем заново когда
  // фронты прикрывают. Это фундамент адаптивного обхода белых списков.
  static final Map<String, int> frontLatencyMs = {};   // sni -> ms (-1 = мёртв)
  static List<String>           _rankedFronts  = [];
  static DateTime?              _lastDiscovery;
  static const _discoveryTtl = Duration(minutes: 4);    // фронты прикрывают быстро

  static bool   get isDiscoveryFresh => _lastDiscovery != null &&
      DateTime.now().difference(_lastDiscovery!) < _discoveryTtl;
  static List<String> get rankedFronts => List.unmodifiable(_rankedFronts);

  // Пробинг пула: реальный TLS-handshake к каждому фронту, замер задержки.
  // Возвращает живые фронты, отсортированные по скорости (быстрые — первыми).
  static Future<List<String>> discoverWorkingFronts({
    bool mobile = true, int max = 12, void Function(String)? log,
  }) async {
    final candidates = (mobile ? kMobileSniWhitelist : kWifiSniList)
        .toSet().take(max).toList();
    final probed = <MapEntry<String, int>>[];
    await Future.wait(candidates.map((sni) async {
      final sw = Stopwatch()..start();
      try {
        final s = await SecureSocket.connect(
          sni, 443,
          timeout: const Duration(milliseconds: 1800),
          onBadCertificate: (_) => true,    // важен сам handshake, не сертификат
        );
        sw.stop();
        await s.close();
        probed.add(MapEntry(sni, sw.elapsedMilliseconds));
      } catch (_) {
        probed.add(MapEntry(sni, -1));      // фронт недоступен/прикрыт в этой сети
      }
    }));
    frontLatencyMs
      ..clear()
      ..addEntries(probed);
    final working = probed.where((e) => e.value >= 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    _rankedFronts  = working.map((e) => e.key).toList();
    _lastDiscovery = DateTime.now();
    log?.call('🔎 Discovery: ${_rankedFronts.length}/${candidates.length} фронтов живы'
        '${_rankedFronts.isNotEmpty ? " · быстрейший: ${_rankedFronts.first} (${working.first.value}ms)" : ""}');
    return _rankedFronts;
  }

  // Фоновое переоткрытие — дёргается из stealth-background и при обрыве.
  static Future<void> autoRediscover({void Function(String)? log}) async {
    final mobile = await isMobileNetwork()
        .timeout(const Duration(seconds: 1), onTimeout: () => true);
    await discoverWorkingFronts(mobile: mobile, log: log)
        .timeout(const Duration(seconds: 4), onTimeout: () => _rankedFronts);
  }

  // Лучший ИЗМЕРЕННЫЙ фронт. Если кэш протух — пробуем discovery (с потолком по
  // времени, чтобы не тормозить коннект), иначе мгновенно отдаём из кэша/фолбэк.
  static Future<String> getBestSni() async {
    final isMobile = await isMobileNetwork()
        .timeout(const Duration(seconds: 1), onTimeout: () => true);
    if (!isDiscoveryFresh || _rankedFronts.isEmpty) {
      try {
        await discoverWorkingFronts(mobile: isMobile)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (_rankedFronts.isNotEmpty) return _rankedFronts.first;
    // Фолбэк: статический список, если discovery не успел/не дал результата
    final list = isMobile ? kMobileSniWhitelist : kWifiSniList;
    return list[DateTime.now().millisecondsSinceEpoch % list.length];
  }

  // Топ-N измеренных фронтов для ротации в каскаде (быстрые — приоритетнее).
  static List<String> topFronts(int n) {
    if (_rankedFronts.isNotEmpty) return _rankedFronts.take(n).toList();
    return kMobileSniWhitelist.take(n).toList();
  }

  // Эндпоинты для whitelist стратегии
  static const kWhitelistEndpoints = [
    {'host': 'vk.com',      'port': 443, 'sni': 'vk.com'},
    {'host': 'yandex.ru',   'port': 443, 'sni': 'yandex.ru'},
    {'host': 'mts.ru',      'port': 443, 'sni': 'mts.ru'},
    {'host': 'ozon.ru',     'port': 443, 'sni': 'ozon.ru'},
    {'host': 'sber.ru',     'port': 443, 'sni': 'sber.ru'},
  ];

  static String getEndpointByKey(String key) {
    switch (key) {
      case 'vk':      return kWhitelistEndpoints[0]['host'] as String;
      case 'yandex':  return kWhitelistEndpoints[1]['host'] as String;
      case 'mts':     return kWhitelistEndpoints[2]['host'] as String;
      default: return 'vk.com';
    }
  }
}

// ── TLS Fingerprint (Chrome — единая версия kChromeFull) ─────────────────────
class TlsFingerprint {
  // JA4 fingerprint Chrome (uTLS 'chrome' профиль xray-core).
  // Если ТСПУ видит этот fingerprint — считает трафик легитимным Chrome.
  // Имена констант исторические (kChrome134*), значение привязано к kChromeFull.
  static const kChrome134Fingerprint = 'chrome';

  // Chrome User-Agent для TLS Hello — версия из единого источника (28.06.2026)
  static const kChrome134UA =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/$kChromeFull Mobile Safari/537.36';

  // GREASE значения (случайные "мусорные" расширения Chrome)
  static List<int> getGreaseValues() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    final base = [0x0a0a, 0x1a1a, 0x2a2a, 0x3a3a, 0x4a4a,
                  0x5a5a, 0x6a6a, 0x7a7a, 0x8a8a, 0x9a9a,
                  0xaaaa, 0xbaba, 0xcaca, 0xdada, 0xeaea, 0xfafa];
    return [base[seed % base.length]];
  }
}

// ── TSPU Detector ──────────────────────────────────────────────────────────
class TspuBypassWindowDetector {
  // Определяет временные окна когда ТСПУ перегружен (меньше блокирует)
  // По наблюдениям: 03:00-06:00 МСК — минимальная нагрузка на ТСПУ
  static bool isLowLoadWindow() {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 3)).hour;
    return hour >= 3 && hour <= 6;
  }

  // Задержка между попытками чтобы не триггерить behavioral analysis
  static Duration getRetryDelay(int attempt) {
    // Случайная задержка 200-800мс — имитирует поведение браузера
    final base = 200 + (attempt * 150);
    final jitter = DateTime.now().millisecondsSinceEpoch % 300;
    return Duration(milliseconds: base + jitter);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ОСНОВНОЙ КЛАСС AI BYPASS AGENT
// ═══════════════════════════════════════════════════════════════════════════
class AiBypassAgent {
  final void Function(String) _log;
  BypassMode bypassMode = BypassMode.auto;
  bool _isRunning = false;
  int  currentStrategyId = 0;
  String currentStrategyName = '';

  AiBypassAgent(this._log);

  bool get isRunning => _isRunning;

  void stop() { _isRunning = false; }

  // Случайный CDN-подобный путь — ТСПУ думает что это обращение к CDN, не VPN
  static String _randomCdnPath() {
    final ts = DateTime.now();
    final paths = [
      '/cdn-cgi/trace',
      '/api/v${ts.second % 5 + 1}/stream',
      '/upload/chunk/${ts.millisecond}',
      '/static/media/bundle.${ts.minute.toRadixString(16)}.js',
      '/api/graphql/ws',
      '/live/hls/stream${ts.second % 4}.m3u8',
      '/push/notify/${ts.millisecond.toRadixString(16)}',
      '/ws/v2/connect',
    ];
    return paths[ts.millisecondsSinceEpoch % paths.length];
  }



  Future<VpnConfig?> findBypass(VpnConfig blocked) async {
    if (_isRunning) return null;
    _isRunning = true;
    try {
      return await _findInternal(blocked).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('⏱ E-2001: Таймаут 30с — байпас остановлен');
          return null;
        });
    } finally { _isRunning = false; }
  }

  Future<VpnConfig?> _findInternal(VpnConfig blocked) async {
    if (bypassMode != BypassMode.auto) {
      return _applyDirectMode(blocked, bypassMode);
    }
    return _runAutoMode(blocked);
  }

  // ── Прямой режим ─────────────────────────────────────────────────────────
  Future<VpnConfig?> _applyDirectMode(VpnConfig blocked, BypassMode mode) async {
    _log('🎯 Прямой режим: ${mode.label}');
    currentStrategyName = mode.label;

    switch (mode) {
      case BypassMode.hysteria2:
        return _patchHysteria2(blocked);
      case BypassMode.xhttp:
        return _patchXHttp(blocked);
      case BypassMode.realityVk:
        final sni = await WhitelistBypassEngine.getBestSni();
        return _patchReality(blocked, sni);
      case BypassMode.grpc:
        return _patchGrpc(blocked);
      case BypassMode.shadowtls:
        return _patchShadowTls(blocked);
      case BypassMode.whitelist:
        return _tryWhitelistStrategies(blocked);
      case BypassMode.auto:
        return _runAutoMode(blocked);
    }
  }

  // ── AUTO режим: умный каскад ──────────────────────────────────────────────
  Future<VpnConfig?> _runAutoMode(VpnConfig blocked) async {
    _log('🔍 E-2002: Определяем тип блокировки...');
    final bt = await BlockDetector.detect(blocked)
        .timeout(const Duration(seconds: 2), onTimeout: () => BlockType.timeout);
    _log('🔍 E-2003: Тип: ${bt.name}');

    if (bt == BlockType.none) {
      _log('✅ E-2004: Блокировки нет — прямое подключение');
      return blocked;
    }

    // Проверяем белые списки
    final whitelistActive = await WhitelistBypassEngine.isWhitelistActive()
        .timeout(const Duration(seconds: 2), onTimeout: () => false);
    final isMobile = await WhitelistBypassEngine.isMobileNetwork()
        .timeout(const Duration(seconds: 1), onTimeout: () => false);
    final net = AiMemory.netClass(isMobile, whitelistActive);

    if (whitelistActive) {
      _log('🟡 E-2005: Белые списки активны (${isMobile ? "мобильный" : "WiFi"})');
    }

    const kMaxAttempts = 12;
    final cascade = await _buildCascade(bt, whitelistActive, isMobile);
    final limited = cascade.take(kMaxAttempts).toList();

    // Обучение: упорядочиваем каскад по ЗАМЕРЕННОЙ задержке успешных проб на
    // этом классе сети (в т.ч. из прошлых запусков — память персистится).
    // Самая быстрая рабочая стратегия идёт первой; неизученные — за ними, по
    // статическому приоритету каскада. ИИ учится не просто «что работало», а
    // «что работало БЫСТРЕЕ здесь».
    final ranked = AiMemory.rankedTypes(net);
    if (ranked.isNotEmpty) {
      int rank(BypassStrategy s) {
        final i = ranked.indexOf(s.type);
        return i < 0 ? 1000 + s.priority : i;
      }
      limited.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    final fastest = ranked.isNotEmpty ? ranked.first : AiMemory.winnerFor(net);
    _log('🤖 E-2006: Cascade: ${limited.length} стратегий'
        '${fastest != null ? " (лидер: $fastest"
            "${ranked.isNotEmpty ? " ${AiMemory.latencyFor(net, fastest)}ms" : ""})" : ""}');

    // ПАНИК-ФЛОР: если ВСЕ кандидаты сейчас в cooldown — значит ИИ временно
    // забанил всё. Не оставляем пользователя без обхода: чистим блеклист и
    // пробуем заново. Это страховка «ИИ не должна расхерачить все системы».
    if (limited.isNotEmpty && limited.every((s) => StrategyBlacklist.isFailed(s.type))) {
      _log('🛟 Все стратегии в cooldown — паник-режим: сбрасываю блеклист');
      StrategyBlacklist.clear();
    }

    VpnConfig? firstBuilt;   // best-effort на случай, если ни один не пройдёт пробу

    for (int i = 0; i < limited.length; i++) {
      if (!_isRunning) return null;
      final s = limited[i];
      if (StrategyBlacklist.isFailed(s.type)) continue;
      currentStrategyId   = i + 1;
      currentStrategyName = s.type.replaceAll('_', ' ');
      _log('🤖 #${i+1}/${limited.length} · ${s.type}');

      // Задержка между попытками (имитирует браузер, не триггерит ML)
      if (i > 0) await Future.delayed(TspuBypassWindowDetector.getRetryDelay(i));

      final result = await _applyStrategy(blocked, s);
      if (result != null) {
        firstBuilt ??= result;
        // ВЕРИФИКАЦИЯ: реально ли подключается этот вариант. Раньше каскад
        // принимал первый ПОСТРОЕННЫЙ конфиг без проверки связи — обход был
        // «наугад». Теперь пробуем реальный TLS-коннект к ноде и принимаем
        // только то, что измеримо работает.
        final sw = Stopwatch()..start();
        final ok = await BypassProber.probe(result)
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
        sw.stop();
        if (ok) {
          AiMemory.recordWinner(net, s.type);      // запоминаем победителя для этой сети
          AiMemory.recordLatency(net, s.type, sw.elapsedMilliseconds); // и его скорость
          StrategyBlacklist.markSuccess(s.type);   // сработало → снять возможный бан
          AiMemory.onBlacklistChanged();
          _log('✅ E-2007: Обход проверен (${sw.elapsedMilliseconds}ms): ${s.type}');
          return result;
        }
        _log('· ${s.type}: конфиг построен, проба связи не прошла');
      }
      StrategyBlacklist.markFailed(s.type);
      AiMemory.onBlacklistChanged();
    }

    // Ни один кандидат не прошёл пробу. Не теряем шанс: отдаём первый
    // построенный конфиг как best-effort (старое поведение, сеть безопасности).
    if (firstBuilt != null) {
      _log('⚠ E-2008: ни один вариант не прошёл пробу — best-effort');
      return firstBuilt;
    }
    _log('✗ E-2008: Все методы не прошли — смена ноды');
    return null;
  }

  // (Победитель теперь хранится в AiMemory по классу сети — персистится.)

  // ── Построение каскада стратегий ──────────────────────────────────────────
  Future<List<BypassStrategy>> _buildCascade(
      BlockType bt, bool whitelistActive, bool isMobile) async {
    final sni = await WhitelistBypassEngine.getBestSni();

    // Ротирующие SNI для разных попыток
    final sniList = isMobile
        ? WhitelistBypassEngine.kMobileSniWhitelist
        : WhitelistBypassEngine.kWifiSniList;
    String nextSni(int offset) => sniList[(DateTime.now().millisecondsSinceEpoch + offset) % sniList.length];

    // Порядок актуализирован 28.06.2026: ведём Reality/xHTTP (detection
    // stable-low), Hysteria2 понижен — его QUIC-fingerprint деградирует (~40%).
    return [
      // ═══ 1: VLESS + Reality + xHTTP — ЛУЧШИЙ метод июня 2026 ═══
      BypassStrategy(priority: 1, type: 'vless_xhttp',
          params: {'path': '/api/v${DateTime.now().minute % 9 + 1}/stream', 'mode': 'packet-up',
                   'sni': sni, 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 2: VLESS + Reality + RAW + XTLS-Vision ═══
      BypassStrategy(priority: 2, type: 'vless_xtls_vision',
          params: {'sni': 'vk.com', 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 3: Reality + VK SNI ═══
      BypassStrategy(priority: 3, type: 'vless_reality_vk',
          params: {'sni': 'vk.com', 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 4: Reality + Yandex SNI ═══
      BypassStrategy(priority: 4, type: 'vless_reality_yandex',
          params: {'sni': 'yandex.ru', 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 5: Reality + gRPC ═══
      BypassStrategy(priority: 5, type: 'vless_grpc_reality',
          params: {'service': 'GrpcService', 'sni': sni,
                   'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 6: xHTTP другой путь ═══
      BypassStrategy(priority: 6, type: 'vless_xhttp_alt',
          params: {'path': '/upload/chunk/${DateTime.now().second}', 'mode': 'stream',
                   'sni': nextSni(200)}),

      // ═══ 7: Hysteria2 (QUIC) — понижен: деградирует, но иногда проходит ═══
      BypassStrategy(priority: 7, type: 'hysteria2_fallback',
          params: {'udp_hop': true, 'brutal': false}),

      // ═══ 8: Reality + Sber SNI ═══
      BypassStrategy(priority: 8, type: 'vless_reality_sber',
          params: {'sni': 'sber.ru', 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 9: Фрагментация ClientHello (обход поведенческого анализа) ═══
      BypassStrategy(priority: 9, type: 'vless_fragmented',
          params: {'min': 1, 'max': 5, 'interval': '20-100ms', 'sni': sni}),

      // ═══ 10: Reality + MTS SNI (оператор в белом списке) ═══
      BypassStrategy(priority: 10, type: 'vless_reality_mts',
          params: {'sni': 'mts.ru', 'fingerprint': TlsFingerprint.kChrome134Fingerprint}),

      // ═══ 11: gRPC без Reality (fallback) ═══
      BypassStrategy(priority: 11, type: 'vless_grpc_plain',
          params: {'service': 'TunService', 'sni': nextSni(300)}),

      // ═══ 12: Hysteria2 другой порт — последний резерв ═══
      BypassStrategy(priority: 12, type: 'hysteria2_alt_port',
          params: {'port_hint': 8443, 'udp_hop': true}),

      // (убраны как нереализуемые на xray-core: vless_reality_ipv6 — нет
      //  обработчика/нельзя форсировать IPv6; ShadowTLS — не поддерживается.)
    ];
  }

  // ── Применение стратегии ──────────────────────────────────────────────────
  Future<VpnConfig?> _applyStrategy(VpnConfig blocked, BypassStrategy s) async {
    try {
      switch (s.type) {
        case 'hysteria2_fallback':
        case 'hysteria2_alt_port':
          return _patchHysteria2(blocked,
              altPort: s.params['port_hint'] as int?);

        case 'vless_xhttp':
        case 'vless_xhttp_alt':
          return _patchXHttp(blocked,
              path: s.params['path'] as String? ?? '/api/stream',
              mode: s.params['mode'] as String? ?? 'packet-up',
              sni: s.params['sni'] as String? ?? 'vk.com');

        case 'vless_xtls_vision':
          return _patchVision(blocked,
              s.params['sni'] as String? ?? 'vk.com');
        case 'vless_reality_vk':
        case 'vless_reality_yandex':
        case 'vless_reality_sber':
        case 'vless_reality_mts':
          return _patchReality(blocked,
              s.params['sni'] as String? ?? 'vk.com');

        case 'vless_grpc_reality':
        case 'vless_grpc_plain':
          return _patchGrpc(blocked,
              sni: s.params['sni'] as String? ?? 'vk.com',
              service: s.params['service'] as String? ?? 'GrpcService');

        case 'shadowtls_v3':
          return _patchShadowTls(blocked,
              serverName: s.params['server_name'] as String? ?? 'vk.com');

        case 'vless_fragmented':
          return _patchFragmented(blocked,
              sni: s.params['sni'] as String? ?? 'vk.com');

        default:
          // Стратегия без обработчика — раньше молча проваливалась (null) и
          // засоряла blacklist. Теперь это видно в логах для отладки каскада.
          _log('⚠ Нет обработчика стратегии: ${s.type} — пропуск');
          return null;
      }
    } catch (e) {
      _log('⚠ Strategy error (${s.type}): $e');
      return null;
    }
  }


  // ЗАДАЧА 8: Поведенческая маскировка трафика
  // Имитирует браузерный паттерн — ТСПУ ML не находит VPN сигнатуру
  static Future<void> applyTrafficMasking() async {
    // Случайная задержка 20-150мс между установкой соединения
    // Браузер тоже делает небольшие паузы при загрузке страниц
    final delay = 20 + (DateTime.now().millisecond % 130);
    await Future.delayed(Duration(milliseconds: delay));
  }

  // Возвращает случайный интервал отправки keepalive пакетов
  // Имитирует поведение Chrome при idle соединении
  static int getBrowserKeepaliveInterval() {
    // Chrome отправляет keepalive каждые 45-75 секунд
    return 45 + (DateTime.now().millisecond % 30);
  }

  // ── Стратегии белых списков ────────────────────────────────────────────────
  Future<VpnConfig?> _tryWhitelistStrategies(VpnConfig blocked) async {
    _log('📋 Пробуем whitelist стратегии...');
    final sniList = WhitelistBypassEngine.kMobileSniWhitelist.take(5).toList();
    for (final sni in sniList) {
      if (!_isRunning) return null;
      _log('  📋 Reality + SNI: $sni');
      final r = await _patchReality(blocked, sni);
      if (r != null) return r;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ПАТЧИ КОНФИГУРАЦИИ
  // ═══════════════════════════════════════════════════════════════════════

  // Hysteria2 — лучший метод апрель 2026
  VpnConfig? _patchHysteria2(VpnConfig cfg, {int? altPort}) {
    try {
      final uri = Uri.parse(cfg.link);
      if (uri.scheme.startsWith('hy2') || uri.scheme.startsWith('hysteria')) {
        // ЗАДАЧА 5: UDP Hop — меняем порт для обхода блокировки по порту
        // ТСПУ блокирует конкретный UDP порт — hop перепрыгивает на новый
        final basePort = uri.port > 0 ? uri.port : 443;
        
        // Hop порты: +1, +2, -1 от базового (имитирует легитимный UDP)
        final hopPort = altPort ?? (basePort + (DateTime.now().second % 3) - 1);
        final hopPortClamped = hopPort.clamp(1024, 65535);
        
        // Добавляем параметры hop в ссылку
        String link = cfg.link.split('#').first;
        // Для нативных hy2 конфигов — меняем порт напрямую
        if (altPort != null || hopPortClamped != basePort) {
          final newUri = uri.replace(port: hopPortClamped);
          link = newUri.toString().split('#').first;
        }
        // Параметр hopInterval для xray 26.x (UDP Hop interval)
        final patched = '$link#hy2_hop_port=${hopPortClamped}&hop_interval=30';
        return _makeCfg(cfg, patched, '[Hy2+Hop:$hopPortClamped]');
      }
      // VLESS/VMess fallback на Hysteria2
      final link = cfg.link
          .split('#whitelist_df=').first
          .split('#fragment=').first
          .split('#hy2_fallback').first
          .split('#hy2_hop').first;
      return _makeCfg(cfg, '$link#hy2_fallback', '[Hy2-fallback]');
    } catch (_) { return null; }
  }

  // VLESS + xHTTP транспорт (лучший TCP-метод апрель 2026)
  // Используем StealthEngine.buildXhttpConfig для точного конфига
  VpnConfig? _patchXHttp(VpnConfig cfg, {
    String path = '/api/v1/stream',
    String mode = 'packet-up',
    String sni  = 'vk.com',
  }) {
    try {
      // Извлекаем параметры из ссылки
      final uri  = Uri.parse(cfg.link.split('#').first);
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : 443;
      final uuid = uri.userInfo.isNotEmpty ? uri.userInfo : '';
      
      // Если можем извлечь uuid — строим полный xHTTP конфиг
      if (uuid.isNotEmpty && host.isNotEmpty) {
        _log('🌐 xHTTP: строим полный конфиг ($host:$port sni=$sni)');
        // Добавляем маркер для _connectWith чтобы он использовал xHTTP путь
        final patched = '${cfg.link.split('#').first}'
            '#xhttp_sni=${Uri.encodeComponent(sni)}'
            '&path=${Uri.encodeComponent(path)}&mode=$mode'
            '&host=${Uri.encodeComponent(host)}&port=$port&uuid=${Uri.encodeComponent(uuid)}'
          '&padding=100-500';
        return _makeCfg(cfg, patched, '[xHTTP:$sni]');
      }
      
      // Fallback: просто добавляем маркер
      final link = cfg.link.split('#').first;
      return _makeCfg(cfg, '$link#xhttp_sni=${Uri.encodeComponent(sni)}&path=${Uri.encodeComponent(path)}', '[xHTTP:$sni]');
    } catch (e) {
      _log('xHTTP patch error: $e');
      return null;
    }
  }

  // VLESS + Reality + XTLS-Vision — отдельный маркер для честного builder.
  // _connectWith по #vision_sni= строит конфиг через buildVlessVisionConfig
  // (гарантированно корректные realitySettings + flow), если в ноде есть pbk/sid.
  VpnConfig? _patchVision(VpnConfig cfg, String sni) {
    try {
      final cleanLink = cfg.link
          .split('#whitelist_df=').first
          .split('#vision_sni=').first
          .split('#xhttp_sni=').first
          .split('#fragment=').first;
      final patched = '$cleanLink#vision_sni=${Uri.encodeComponent(sni)}'
          '&fp=${TlsFingerprint.kChrome134Fingerprint}';
      return _makeCfg(cfg, patched, '[Vision:$sni]');
    } catch (_) { return null; }
  }

  // VLESS + Reality + SNI из белого списка
  VpnConfig? _patchReality(VpnConfig cfg, String sni) {
    try {
      final cleanLink = cfg.link
          .split('#whitelist_df=').first
          .split('#fragment=').first
          .split('#xhttp_sni=').first;
      final patched = '$cleanLink#whitelist_df=${Uri.encodeComponent(sni)}'
          '&fp=${TlsFingerprint.kChrome134Fingerprint}';
      return _makeCfg(cfg, patched, '[Reality:$sni]');
    } catch (_) { return null; }
  }

  // VLESS + gRPC
  VpnConfig? _patchGrpc(VpnConfig cfg, {
    String sni     = 'vk.com',
    String service = 'GrpcService',
  }) {
    try {
      final link = cfg.link.split('#').first;
      final patched = '$link#grpc_sni=${Uri.encodeComponent(sni)}&svc=$service';
      return _makeCfg(cfg, patched, '[gRPC:$sni]');
    } catch (_) { return null; }
  }

  // ShadowTLS v3 — ЧЕСТНОЕ ПОВЕДЕНИЕ.
  // ВАЖНО: flutter_v2ray работает на xray-core, у которого НЕТ нативного
  // shadowtls-outbound (это фича sing-box / shadowsocks-rust). Поэтому на этом
  // стеке настоящий ShadowTLS-туннель построить нельзя — он бы не запустился.
  // Реалистичный эквивалент «настоящий TLS к легитимному домену» — это Reality
  // c whitelist-SNI. Делегируем туда, не притворяясь отдельным транспортом.
  // ShadowTLS убран из авто-каскада (_buildCascade); этот метод оставлен для
  // ручного режима BypassMode.shadowtls, чтобы подключение всё равно прошло.
  VpnConfig? _patchShadowTls(VpnConfig cfg, {String serverName = 'vk.com'}) {
    _log('ℹ ShadowTLS недоступен на xray-core → Reality c SNI: $serverName');
    return _patchReality(cfg, serverName);
  }

  // Fragmented TLS (1-5 байт фрагменты — обходит поведенческий анализ)
  VpnConfig? _patchFragmented(VpnConfig cfg, {String sni = 'vk.com'}) {
    try {
      final link = cfg.link.split('#').first;
      final patched = '$link#fragment=1-5,20-100ms&sni=${Uri.encodeComponent(sni)}';
      return _makeCfg(cfg, patched, '[Frag:$sni]');
    } catch (_) { return null; }
  }

  VpnConfig _makeCfg(VpnConfig orig, String link, String suffix) => VpnConfig(
    name:        '${orig.name} $suffix',
    link:        link,
    customName:  orig.customName,
    groupName:   orig.groupName,
    sourceUrl:   orig.sourceUrl,
    isManual:    orig.isManual,
    isAiPatched: true,
    isFavourite: orig.isFavourite,
  );
}