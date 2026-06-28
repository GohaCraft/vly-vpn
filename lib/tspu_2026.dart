// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

class TspuCountermeasures2026 {
  static final _rng = Random();

  // ── Детектор типа блокировки по коду ошибки ────────────────────────────────
  // Разные типы блокировок требуют разных контрмер
  static BlockType classifyError(String errorMsg) {
    final e = errorMsg.toLowerCase();
    // TCP RST — активная блокировка (ТСПУ инжектирует RST)
    if (e.contains('connection reset') || e.contains('econnreset')) {
      return BlockType.tcpReset;
    }
    // TLS Handshake failure — DPI блокирует по TLS fingerprint
    if (e.contains('handshake') || e.contains('tls') || e.contains('ssl')) {
      return BlockType.tlsFingerprint;
    }
    // DNS — отравление или блокировка resolver
    if (e.contains('dns') || e.contains('lookup') || e.contains('resolve')) {
      return BlockType.dnsPoisoning;
    }
    // Timeout без RST — "тихая" блокировка (blackhole routing)
    if (e.contains('timeout') || e.contains('timed out')) {
      return BlockType.timeout;
    }
    // Port blocked — весь порт заблокирован на уровне BGP/firewall
    if (e.contains('refused') || e.contains('econnrefused')) {
      return BlockType.portBlocked;
    }
    return BlockType.timeout;
  }

  // ── Выбор оптимальной стратегии по типу блокировки ─────────────────────────
  // Вместо случайного перебора — целенаправленный выбор
  static List<int> prioritizedStrategies(BlockType blockType) {
    switch (blockType) {
      case BlockType.tcpReset:
        // RST → фрагментация + смена порта + Reality SNI rotate
        return [1, 4, 5, 6, 7, 43, 44, 45, 56, 57, 58];
      case BlockType.tlsFingerprint:
        // TLS fingerprint → смена uTLS + CDN fallback + Reality SNI
        return [1, 9, 10, 16, 17, 18, 19, 11, 12, 66, 67];
      case BlockType.dnsPoisoning:
        // DNS poisoning → DoH стратегии
        return [51, 52, 53, 54, 55];
      case BlockType.portBlocked:
        // Port blocked → смена порта (443, 8443, CF ports)
        return [4, 5, 6, 7, 8, 61, 62, 63, 64, 65];
      case BlockType.timeout:
        // Timeout → смена ноды + CDN
        return [71, 72, 73, 99, 100, 11, 12, 81, 82, 83];
      default:
        // Unknown → Tier 1 strategies
        return [1, 2, 3, 9, 10, 11];
    }
  }

  // ── Случайный padding для снижения энтропийных признаков ────────────────────
  // ТСПУ детектирует низкоэнтропийные пакеты как VPN
  // Добавляем рандомный User-Agent и фейковые заголовки
  static Map<String, String> antiEntropyHeaders() {
    final agents = [
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/$kChromeFull',
      'Mozilla/5.0 (iPhone; CPU iPhone OS $kIosUaVersion) AppleWebKit/605.1.15 Safari/604.1',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edge/$kEdgeFull',
      'Dalvik/2.1.0 (Linux; Android 14; SM-S928B Build/UP1A.231005.007)',
    ];
    final ua = agents[_rng.nextInt(agents.length)];
    return {
      'User-Agent':      ua,
      'Accept-Language': _randomAcceptLanguage(),
      'Cache-Control':   _rng.nextBool() ? 'no-cache' : 'max-age=0',
    };
  }

  static String _randomAcceptLanguage() {
    final langs = ['ru-RU,ru;q=0.9,en;q=0.8', 'en-US,en;q=0.9', 'ru,en-US;q=0.9,en;q=0.8'];
    return langs[_rng.nextInt(langs.length)];
  }

  // ── Adaptive delay: имитация сетевого стека конкретного устройства ──────────
  // ТСПУ 2026: ML обнаруживает VPN по "идеальным" задержкам (0ms jitter)
  // Реальные устройства имеют jitter 2-15ms на каждом пакете
  static Duration adaptiveDelay(Duration base) {
    // Добавляем gaussian-like jitter ±15% к базовой задержке
    final jitterMs = (base.inMilliseconds * 0.15 * (_rng.nextDouble() * 2 - 1)).round();
    final total = (base.inMilliseconds + jitterMs).clamp(5, 5000);
    return Duration(milliseconds: total);
  }

  // ── Проверка: заблокирован ли порт полностью ────────────────────────────────
  static Future<bool> isPortReachable(String host, int port) async {
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 2000));
      await s.close();
      return true;
    } catch (_) { return false; }
  }

  // ── Обнаружение режима "замедления" (не блокировка, а throttling) ───────────
  // ТСПУ иногда замедляет, а не блокирует — распознаём по RTT > 2000ms
  static Future<ThrottleState> detectThrottle(String host, int port) async {
    try {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 5000));
      sw.stop();
      await s.close();
      final rtt = sw.elapsedMilliseconds;
      if (rtt > 3000) return ThrottleState.heavyThrottle;
      if (rtt > 1500) return ThrottleState.lightThrottle;
      return ThrottleState.normal;
    } on TimeoutException {
      return ThrottleState.blocked;
    } catch (_) {
      return ThrottleState.blocked;
    }
  }
}

enum ThrottleState { normal, lightThrottle, heavyThrottle, blocked }

// ═══════════════════════════════════════════════════════════════════════════════
//  ADAPTIVE MIMICRY ENGINE  (апрель 2026)
//
//  Концепция: имитация ПОЛНОГО цифрового следа обычного пользователя.
//  Источник: habr.com/articles/1012926 «Адаптивная мимикрия: как обмануть DPI»
// ═══════════════════════════════════════════════════════════════════════════════
class AdaptiveMimicryEngine {
  static final _rng = Random();
  static _DigitalPersona? _currentPersona;

  static _DigitalPersona generatePersona() {
    final personas = [
      _DigitalPersona(
        device: 'Pixel 8 Pro', os: 'Android 14', browser: 'Chrome $kChromeMajor',
        userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
        tlsFp: 'chrome', screenRes: '1344x2992', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9,en;q=0.8', mtu: 1400, tcpWindow: 65535, ttl: 64,
        sessionMinutes: 15 + _rng.nextInt(45), requestInterval: const Duration(milliseconds: 800), idleChance: 0.15,
      ),
      _DigitalPersona(
        device: 'Samsung S24 Ultra', os: 'Android 14', browser: 'Chrome $kChromeMajor',
        userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Mobile Safari/537.36',
        tlsFp: 'chrome', screenRes: '1440x3120', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7', mtu: 1400, tcpWindow: 65535, ttl: 64,
        sessionMinutes: 20 + _rng.nextInt(60), requestInterval: const Duration(milliseconds: 600), idleChance: 0.12,
      ),
      _DigitalPersona(
        device: 'iPhone 15 Pro', os: 'iOS $kSafariVersion', browser: 'Safari $kSafariVersion',
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS $kIosUaVersion like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$kSafariVersion Mobile/15E148 Safari/604.1',
        tlsFp: 'safari', screenRes: '1179x2556', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9', mtu: 1500, tcpWindow: 131072, ttl: 64,
        sessionMinutes: 10 + _rng.nextInt(30), requestInterval: const Duration(milliseconds: 1200), idleChance: 0.20,
      ),
      _DigitalPersona(
        device: 'Windows Desktop', os: 'Windows 11', browser: 'Edge $kChromeMajor',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$kChromeFull Safari/537.36 Edg/$kEdgeFull',
        tlsFp: 'edge', screenRes: '1920x1080', timezone: 'Europe/Moscow',
        language: 'ru,en-US;q=0.9,en;q=0.8', mtu: 1500, tcpWindow: 65535, ttl: 128,
        sessionMinutes: 60 + _rng.nextInt(180), requestInterval: const Duration(milliseconds: 300), idleChance: 0.08,
      ),
    ];

    _currentPersona = personas[_rng.nextInt(personas.length)];
    return _currentPersona!;
  }

  static _DigitalPersona get persona => _currentPersona ?? generatePersona();

  static Map<String, String> personaHeaders() {
    final p = persona;
    return {
      'User-Agent': p.userAgent, 'Accept-Language': p.language,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cache-Control': _rng.nextBool() ? 'no-cache' : 'max-age=0',
      'Sec-Ch-Ua-Platform': p.os.contains('Android') ? '"Android"' : (p.os.contains('iOS') ? '"iOS"' : '"Windows"'),
      'Sec-Ch-Ua-Mobile': p.os.contains('Windows') ? '?0' : '?1',
      'Sec-Fetch-Dest': 'document', 'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none', 'Upgrade-Insecure-Requests': '1',
    };
  }

  static Future<void> behavioralDelay() async {
    final p = persona;
    final baseMs = p.requestInterval.inMilliseconds;
    final jitter = (baseMs * 0.3 * (_rng.nextDouble() * 2 - 1)).round();
    await Future.delayed(Duration(milliseconds: (baseMs + jitter).clamp(50, 5000)));

    if (_rng.nextDouble() < p.idleChance) {
      await Future.delayed(Duration(milliseconds: 2000 + _rng.nextInt(8000)));
    }
    if (_rng.nextDouble() < 0.05) {
      await Future.delayed(Duration(milliseconds: 5000 + _rng.nextInt(15000)));
    }
  }

  static String applyNetworkProfile(String configJson) {
    try {
      final j = jsonDecode(configJson) as Map<String, dynamic>;
      final p = persona;
      final outbounds = j['outbounds'] as List? ?? [];

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

        final ss = Map<String, dynamic>.from(ob['streamSettings'] as Map? ?? {});
        final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
        so['mark'] = p.ttl == 128 ? 128 : 255;
        so['tcpFastOpen'] = true;
        so['tcpNoDelay'] = true;
        ss['sockopt'] = so;
        ob['streamSettings'] = ss;

        final sec = ss['security'] as String? ?? '';
        if (sec == 'tls' || sec == 'reality') {
          final key = '${sec}Settings';
          final tls = Map<String, dynamic>.from(ss[key] as Map? ?? {});
          if (tls['fingerprint'] == null || (tls['fingerprint'] as String).isEmpty) {
            tls['fingerprint'] = p.tlsFp;
          }
          ss[key] = tls;
          ob['streamSettings'] = ss;
        }
      }

      return jsonEncode(j);
    } catch (_) { return configJson; }
  }

  static void resetPersona() { _currentPersona = null; }
}

class _DigitalPersona {
  final String device, os, browser, userAgent, tlsFp, screenRes, timezone, language;
  final int mtu, tcpWindow, ttl, sessionMinutes;
  final Duration requestInterval;
  final double idleChance;
  const _DigitalPersona({
    required this.device, required this.os, required this.browser, required this.userAgent,
    required this.tlsFp, required this.screenRes, required this.timezone, required this.language,
    required this.mtu, required this.tcpWindow, required this.ttl, required this.sessionMinutes,
    required this.requestInterval, required this.idleChance,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANTI-VPN-TARIFF DETECTION ENGINE  (апрель 2026)
//
//  МТС берёт 87₽/сутки за VPN-трафик. Минцифры просит всех операторов ввести плату.
//  Решение: делать трафик неотличимым от обычного веб-браузинга.
// ═══════════════════════════════════════════════════════════════════════════════
class AntiVpnTariffEngine {
  static final _rng = Random();
  static bool _isActive = false;
  static Timer? _heartbeatTimer;

  static const List<Map<String, String>> _backgroundRequests = [
    {'url': 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css',
     'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/$kChromeFull', 'accept': 'text/css,*/*;q=0.1'},
    {'url': 'https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap',
     'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15', 'accept': 'text/css,*/*;q=0.1'},
    {'url': 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js',
     'ua': 'Mozilla/5.0 (Linux; Android 14) Chrome/$kChromeFull', 'accept': '*/*'},
    {'url': 'https://unpkg.com/react@18/umd/react.production.min.js',
     'ua': 'Mozilla/5.0 (iPhone; CPU iPhone OS $kIosUaVersion like Mac OS X) Safari/604.1', 'accept': '*/*'},
    {'url': 'https://cdn.jsdelivr.net/npm/lodash@4.17.21/lodash.min.js',
     'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/$kFirefoxVersion', 'accept': '*/*'},
  ];

  static void enable({void Function(String)? log}) {
    if (_isActive) return;
    _isActive = true;
    log?.call('🛡 Anti-VPN-Tariff: ENABLED — traffic mimicking browser patterns');
  }

  static void disable({void Function(String)? log}) {
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    log?.call('🛡 Anti-VPN-Tariff: DISABLED');
  }

  static bool get isActive => _isActive;

  static Future<void> _sendBackgroundRequest(Map<String, String> req) async {
    try {
      final uri = Uri.parse(req['url']!);
      final client = HttpClient();
      client.userAgent = req['ua'];
      final request = await client.getUrl(uri);
      request.headers.set('Accept', req['accept']!);
      request.headers.set('Accept-Encoding', 'gzip, deflate, br');
      final response = await request.close();
      await response.drain();
      client.close();
    } catch (_) {}
  }

  static void startHeartbeat({void Function(String)? log}) {
    _heartbeatTimer?.cancel();
    void scheduleNext() {
      if (!_isActive) return;
      final delayMs = 15000 + _rng.nextInt(30000);
      _heartbeatTimer = Timer(Duration(milliseconds: delayMs), () async {
        if (!_isActive) return;
        final count = 1 + _rng.nextInt(3);
        final shuffled = List<Map<String, String>>.from(_backgroundRequests)..shuffle(_rng);
        for (int i = 0; i < count && i < shuffled.length; i++) {
          unawaited(_sendBackgroundRequest(shuffled[i]));
          await Future.delayed(Duration(milliseconds: 50 + _rng.nextInt(200)));
        }
        scheduleNext();
      });
    }
    scheduleNext();
    log?.call('🛡 Anti-VPN-Tariff: heartbeat started — browser traffic simulation');
  }

  static Future<bool> isTariffActive({required int currentSpeedBps, required int expectedSpeedBps}) async {
    if (currentSpeedBps < expectedSpeedBps * 0.3) return true;
    int cdnReachable = 0;
    for (final req in _backgroundRequests.take(3)) {
      try {
        final uri = Uri.parse(req['url']!);
        final s = await Socket.connect(uri.host, 443, timeout: const Duration(milliseconds: 1500));
        await s.close();
        cdnReachable++;
      } catch (_) {}
    }
    return cdnReachable < 2;
  }
}

class SmartVpnTimer {
  static Timer? _idleTimer;
  static Timer? _trafficTimer;
  static int _idleMinutes = 0;
  static bool _isActive = false;

  // Настройки
  static int idleTimeoutMinutes = 15;  // Отключить VPN через 15 мин без активности
  static int trafficCheckIntervalSec = 30; // Проверять трафик каждые 30 сек
  static int monthlyLimitGB = 15;  // Лимит международного трафика (ГБ)

  // Статистика
  static int monthlyTrafficBytes = 0; // Трафик за месяц
  static DateTime _monthStart = DateTime.now();

  static bool get isActive => _isActive;
  static int get idleMinutes => _idleMinutes;
  static int get monthlyTrafficGB => monthlyTrafficBytes ~/ (1024 * 1024 * 1024);
  static int get monthlyTrafficRemainingGB => monthlyLimitGB - monthlyTrafficGB;
  static bool get isNearLimit => monthlyTrafficGB >= monthlyLimitGB * 0.8; // 80% лимита

  static void start({
    required void Function() onIdleTimeout,
    required int Function() getCurrentSpeed,
    void Function(String)? log,
  }) {
    stop();
    _isActive = true;
    
    _idleMinutes = 0;

    // Проверка сброса месячного лимита
    final now = DateTime.now();
    if (now.month != _monthStart.month || now.year != _monthStart.year) {
      monthlyTrafficBytes = 0;
      _monthStart = now;
      log?.call('📊 Monthly traffic counter reset');
    }

    // Таймер бездействия
    _idleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_isActive) return;
      final speed = getCurrentSpeed();
      if (speed > 1024) { // >1 КБ/с = активность
        
        _idleMinutes = 0;
      } else {
        _idleMinutes++;
        if (_idleMinutes >= idleTimeoutMinutes) {
          log?.call('⏰ Smart Timer: ${_idleMinutes}min idle — auto-disconnecting VPN');
          onIdleTimeout();
        }
      }
    });

    // Таймер учёта трафика
    _trafficTimer = Timer.periodic(Duration(seconds: trafficCheckIntervalSec), (_) {
      if (!_isActive) return;
      final speed = getCurrentSpeed();
      if (speed > 0) {
        monthlyTrafficBytes += speed * trafficCheckIntervalSec;
      }
    });

    log?.call('⏰ Smart VPN Timer started — ${idleTimeoutMinutes}min idle timeout, ${monthlyLimitGB}GB monthly limit');
  }

  static void stop() {
    _isActive = false;
    _idleTimer?.cancel();
    _trafficTimer?.cancel();
    _idleTimer = null;
    _trafficTimer = null;
    _idleMinutes = 0;
  }

  static void recordActivity() {
    
    _idleMinutes = 0;
  }

  static void reset() {
    _idleMinutes = 0;
    
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  KILL SWITCH v2 — полная блокировка при обрыве VPN
//
//  Kill Switch v1: просто блокирует интернет при обрыве VPN.
//  Kill Switch v2: блокирует ВСЁ — IPv6, WebRTC, DNS, mDNS, SSDP.
//  Источник: рекомендации habr.com/articles/1017492 (31.03.2026)
// ═══════════════════════════════════════════════════════════════════════════════
class KillSwitchV2 {
  static bool _isActive = false;
  static bool _isTriggered = false;
  static DateTime? _triggeredAt;

  // Что блокирует Kill Switch v2:
  // 1. IPv6 — предотвращает утечку через IPv6 (провайдер видит реальный IP)
  // 2. WebRTC — предотвращает утечку локального IP через STUN/TURN
  // 3. DNS — блокирует DNS-запросы вне VPN туннеля
  // 4. mDNS — блокирует multicast DNS (локальная сеть)
  // 5. SSDP — блокирует UPnP обнаружение устройств
  // 6. Non-VPN traffic — блокирует ВЕСЬ трафик кроме VPN туннеля
  static const List<String> blockedProtocols = [
    'ipv6',     // Блокировка IPv6
    'webrtc',   // Блокировка WebRTC
    'dns-leak', // Блокировка DNS утечек
    'mdns',     // Блокировка multicast DNS
    'ssdp',     // Блокировка UPnP/SSDP
    'non-vpn',  // Блокировка всего кроме VPN
  ];

  static bool get isActive => _isActive;
  static bool get isTriggered => _isTriggered;
  static int get triggerDurationSec =>
      _triggeredAt != null ? DateTime.now().difference(_triggeredAt!).inSeconds : 0;

  static void enable({void Function(String)? log}) {
    _isActive = true;
    _isTriggered = false;
    _triggeredAt = null;
    log?.call('🛡 Kill Switch v2: ENABLED — ${blockedProtocols.length} protections active');
  }

  static void disable({void Function(String)? log}) {
    _isActive = false;
    if (_isTriggered) {
      _isTriggered = false;
      _triggeredAt = null;
      log?.call('🛡 Kill Switch v2: DISABLED — traffic restored');
    }
  }

  static void trigger({void Function(String)? log}) {
    if (!_isActive) return;
    _isTriggered = true;
    _triggeredAt = DateTime.now();
    log?.call('🚨 Kill Switch v2: TRIGGERED — all non-VPN traffic blocked');
  }

  static void restore({void Function(String)? log}) {
    if (!_isTriggered) return;
    _isTriggered = false;
    _triggeredAt = null;
    log?.call('🛡 Kill Switch v2: RESTORED — traffic flowing through VPN');
  }

  // Получить список активных блокировок
  static List<String> getActiveBlocks() {
    if (!_isActive) return [];
    return blockedProtocols;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RESIDENTIAL IP DETECTOR — проверка что IP сервера не дата-центр
//
//  Операторы и ТСПУ используют базы IP-репутации (MaxMind, IP2Location)
//  для определения VPN-серверов по ASN дата-центров.
//  Residential IP = IP домашнего провайдера, не хостинга.
//  Residential IP сложнее заблокировать — это «обычный пользователь».
// ═══════════════════════════════════════════════════════════════════════════════
class ResidentialIpDetector {
  // ASN дата-центров которые ВСЕГДА в чёрных списках VPN
  static const Set<int> _datacenterASNs = {
    // Хостинги
    14618,  // Amazon AWS
    16509,  // Amazon AWS
    15169,  // Google Cloud
    8075,   // Microsoft Azure
    13335,  // Cloudflare
    20473,  // Vultr
    63949,  // Linode/Akamai
    54825,  // OVH
    16276,  // OVH
    24940,  // Hetzner
    212238, // Hetzner Cloud
    46562,  // Total Server Solutions
    36352,  // ColoCrossing
    53667,  // FranTech (BuyVM)
    40676,  // Psychz Networks
    32489,  // A2 Hosting
    394713, // ReliableSite
    62904,  // Eonix
    46844,  // Sharktech
    19994,  // Rackspace
    32244,  // Liquid Web
    31898,  // Oracle Cloud
    44356,  // Selectel
    49505,  // Selectel
    200350, // Wildberries (сотрудничает с РКН)
    207634, // Ozon (сотрудничает с РКН)
    57724,  // Avito (сотрудничает с РКН)
    31261,  // Сбербанк (сотрудничает с РКН)
    47541,  // VK (сотрудничает с РКН)
    13238,  // Яндекс (сотрудничает с РКН)
  };

  // Residential IP — проверка по IP-диапазонам
  // Если IP в диапазоне домашнего провайдера → residential
  static const List<Map<String, String>> _residentialRanges = [
    // МТС (домашние абоненты)
    {'start': '95.24.0.0', 'end': '95.31.255.255', 'name': 'MTS Residential'},
    {'start': '176.59.0.0', 'end': '176.59.255.255', 'name': 'MTS Residential'},
    // Билайн
    {'start': '178.176.0.0', 'end': '178.191.255.255', 'name': 'Beeline Residential'},
    // МегаФон
    {'start': '31.173.0.0', 'end': '31.173.255.255', 'name': 'MegaFon Residential'},
    // Ростелеком
    {'start': '178.184.0.0', 'end': '178.187.255.255', 'name': 'Rostelecom Residential'},
    // Дом.ру
    {'start': '188.162.0.0', 'end': '188.163.255.255', 'name': 'Dom.ru Residential'},
  ];

  static int _ipToInt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  // Проверить: является ли IP дата-центром
  static bool isDatacenter(int asn) => _datacenterASNs.contains(asn);

  // Проверить: является ли IP residential
  static bool isResidential(String ip) {
    try {
      final ipInt = _ipToInt(ip);
      for (final range in _residentialRanges) {
        final start = _ipToInt(range['start']!);
        final end = _ipToInt(range['end']!);
        if (ipInt >= start && ipInt <= end) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Получить ASN из IP (через публичный API)
  static Future<int?> getAsn(String ip) async {
    try {
      final uri = Uri.parse('https://ip-api.com/json/$ip?fields=as');
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', kStealthUA);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final asStr = json['as'] as String? ?? '';
      final match = RegExp(r'AS(\d+)').firstMatch(asStr);
      if (match != null) return int.parse(match.group(1)!);
      return null;
    } catch (_) {
      return null;
    }
  }

  // Полная проверка IP: residential + ASN + blacklist
  static Future<IpReputationResult> checkIp(String ip) async {
    final asn = await getAsn(ip);
    final isDc = asn != null && isDatacenter(asn);
    final isRes = isResidential(ip);

    return IpReputationResult(
      ip: ip,
      asn: asn,
      isDatacenter: isDc,
      isResidential: isRes,
      isBlacklisted: isDc, // Дата-центр = в чёрном списке
      riskScore: isDc ? 90 : (isRes ? 10 : 50), // 0-100
    );
  }
}

class IpReputationResult {
  final String ip;
  final int? asn;
  final bool isDatacenter;
  final bool isResidential;
  final bool isBlacklisted;
  final int riskScore; // 0-100

  const IpReputationResult({
    required this.ip,
    required this.asn,
    required this.isDatacenter,
    required this.isResidential,
    required this.isBlacklisted,
    required this.riskScore,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TRAFFIC CAMOUFLAGE ENGINE
//
//  Маскировка VPN трафика под конкретные популярные сервисы/протоколы.
//  Каждый режим применяет специфичные заголовки, пути, SNI и паттерны
//  которые неотличимы от реального трафика этого сервиса.
//
//  Режимы:
//  • none       — без маскировки (чистый VLESS/VMess)
//  • browser    — обычный HTTPS браузер (Google Chrome)
//  • telegram   — Telegram MTProto через CDN (уже реализован)
//  • netflix    — Netflix видеостриминг (HTTP/2, chunked transfer)
//  • youtube    — YouTube видео (специфичные пути googleapis.com)
//  • discord    — Discord WebSocket (gateway.discord.gg паттерн)
//  • cloudflare — Cloudflare WARP (WireGuard-like UDP паттерн через TCP)
//  • microsoft  — Windows Update / Office 365 (login.microsoft.com)
//  • apple      — iCloud синхронизация (mask.icloud.com Private Relay)
//  • naive      — NaïveProxy: HTTP CONNECT через H2 (как Chrome proxy)
// ═══════════════════════════════════════════════════════════════════════════════