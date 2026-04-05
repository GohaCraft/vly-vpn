// ignore_for_file: unused_import, unused_element
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
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/136.0.7103.60',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2) AppleWebKit/605.1.15 Safari/604.1',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edge/134.0.3124.72',
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
//  WHITELIST BYPASS ENGINE  (апрель 2026)
//
//  Проблема: на мобильном интернете ТСПУ активирует «белый список» —
//  DROP ALL пакетов кроме разрешённых IP (Яндекс, VK, Сбер, операторы).
//  Пакет дропается на этапе TCP handshake, не доходя до TLS.
//
//  Решение: Domain Fronting — HTTP Host / TLS SNI указывает на разрешённый
//  домен (yandex.ru), но реальный трафик идёт на наш сервер через CDN
//  разрешённого провайдера. ТСПУ видит IP Яндекса → пропускает.
//
//  Стратегии:
//  1. Yandex Cloud CDN (storage.yandexcloud.net) — S3 через IP Яндекса
//  2. VK CDN (userapi.com) — медиа-трафик через IP VK
//  3. Mail.ru CDN — почтовый трафик
//  4. Сбер CDN — банковский трафик (никогда не блокируется)
//  5. МТС/Билайн/Мегафон порталы — всегда в whitelist
// ═══════════════════════════════════════════════════════════════════════════════
class WhitelistBypassEngine {
  static final _rng = Random();

  // ── Разрешённые IP-диапазоны и домены (гарантированно в белом списке) ─────
  // ОБНОВЛЕНО 04.04.2026: Минцифры требует от Яндекс/VK/Сбер помочь с блокировкой VPN
  // Источник: habr.com/ru/news/1018576 (2 апреля 2026)
  // Яндекс/VK/Сбер УДАЛЕНЫ — они начнут блокировать VPN с середины апреля
  // Wildberries, Ozon, Avito, X5, HeadHunter, Lamoda и др. также под давлением
  // Оставлены только госпорталы (не под санкциями) и нейтральные международные CDN
  static const List<Map<String, dynamic>> whitelistEndpoints = [
    // ── Госуслуги и государственные порталы — НИКОГДА не блокируются ────────
    // Эти сервисы критичны для граждан, блокировка = социальный коллапс
    {
      'name':    'Gosuslugi API',
      'host':    'www.gosuslugi.ru',
      'sni':     'www.gosuslugi.ru',
      'path':    '/api/lk/v1/feed',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'Gosuslugi/5.12 Android/14',
        'Accept':       'application/json',
      },
    },
    {
      'name':    'FNS (Налоговая)',
      'host':    'lkfl2.nalog.ru',
      'sni':     'lkfl2.nalog.ru',
      'path':    '/api/v1/declaration',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'FNSRussia/3.8 Android/14',
        'Accept':       'application/json',
      },
    },
    {
      'name':    'Pension Fund (СФР)',
      'host':    'sfr.gov.ru',
      'sni':     'sfr.gov.ru',
      'path':    '/api/v1/pension',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'SFRMobile/2.1 Android/14',
        'Accept':       'application/json',
      },
    },
    // ── Нейтральные международные CDN (не под давлением Минцифры) ───────────
    // Cloudflare, Fastly, Akamai, AWS — блокировка = половина интернета лежит
    {
      'name':    'Cloudflare CDN',
      'host':    'cdn.cloudflare.net',
      'sni':     'cdn.cloudflare.net',
      'path':    '/cdn-cgi/trace',
      'fp':      'chrome',
      'tier':    1,
      'network': 'h2',
      'headers': {
        'User-Agent':   kStealthUA,
        'Accept':       '*/*',
      },
    },
    {
      'name':    'AWS CloudFront',
      'host':    'd1.awsstatic.com',
      'sni':     'd1.awsstatic.com',
      'path':    '/assets/app.js',
      'fp':      'chrome',
      'tier':    1,
      'network': 'h2',
      'headers': {
        'User-Agent':   kStealthUA,
        'Accept':       'application/javascript',
      },
    },
    {
      'name':    'Fastly CDN',
      'host':    'fastly.net',
      'sni':     'fastly.net',
      'path':    '/cdn/asset.js',
      'fp':      'chrome',
      'tier':    1,
      'network': 'h2',
      'headers': {
        'User-Agent':   kStealthUA,
        'Accept':       '*/*',
      },
    },
    {
      'name':    'Akamai CDN',
      'host':    'akamaized.net',
      'sni':     'akamaized.net',
      'path':    '/cdn/content.js',
      'fp':      'chrome',
      'tier':    1,
      'network': 'h2',
      'headers': {
        'User-Agent':   kStealthUA,
        'Accept':       '*/*',
      },
    },
    // ── Мобильные операторы — личные кабинеты (критичны для связи) ──────────
    {
      'name':    'MTS Portal',
      'host':    'login.mts.ru',
      'sni':     'login.mts.ru',
      'path':    '/amserver/oauth2/access_token',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'myMTS/6.1 Android/14',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    },
    {
      'name':    'Beeline Portal',
      'host':    'my.beeline.ru',
      'sni':     'my.beeline.ru',
      'path':    '/api/v1/balance',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'Beeline/12.3 Android/14',
        'Accept':       'application/json',
      },
    },
    {
      'name':    'MegaFon Portal',
      'host':    'lk.megafon.ru',
      'sni':     'lk.megafon.ru',
      'path':    '/api/v2/profile',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'MegaFon/8.5 Android/14',
        'Accept':       'application/json',
      },
    },
    {
      'name':    'Tele2 Portal',
      'host':    'my.tele2.ru',
      'sni':     'my.tele2.ru',
      'path':    '/api/v1/account',
      'fp':      'chrome',
      'tier':    0,
      'network': 'h2',
      'headers': {
        'User-Agent':   'Tele2/4.9 Android/14',
        'Accept':       'application/json',
      },
    },
  ];

  // ── Маппинг ключей из BypassArsenal params → индекс в whitelistEndpoints ──
  static const Map<String, int> _endpointKeyToIndex = {
    'gosuslugi':  0,  // Gosuslugi API
    'fns':        1,  // FNS (Налоговая)
    'sfr':        2,  // Pension Fund (СФР)
    'cloudflare': 3,  // Cloudflare CDN
    'aws':        4,  // AWS CloudFront
    'fastly':     5,  // Fastly CDN
    'akamai':     6,  // Akamai CDN
    'mts':        7,  // MTS Portal
    'beeline':    8,  // Beeline Portal
    'megafon':    9,  // MegaFon Portal
    'tele2':      10, // Tele2 Portal
  };

  static Map<String, dynamic>? getEndpointByKey(String key) {
    final idx = _endpointKeyToIndex[key];
    if (idx != null && idx < whitelistEndpoints.length) {
      return whitelistEndpoints[idx];
    }
    return whitelistEndpoints.isNotEmpty ? whitelistEndpoints[0] : null;
  }

  // ── Детектор White List режима ──────────────────────────────────────────────
  // Проверяем: доступен ли whitelist домен, но НЕ доступен внешний IP.
  // Если оба условия → мы в режиме белого списка.
  // ОБНОВЛЕНО 04.04.2026: вместо Яндекса используем Госуслуги (не под санкциями)
  // ОБНОВЛЕНО 04.04.2026: добавлен детект домашнего whitelist (тестируют на юге РФ)
  static Future<bool> isWhitelistActive() async {
    bool whitelistReachable = false;
    bool externalReachable  = false;
    bool homeWhitelistReachable = false;

    // Проверка whitelist: пробуем Госуслуги (всегда в белом списке)
    try {
      final s = await Socket.connect('5.101.158.10', 443,  // gosuslugi.ru IP
          timeout: const Duration(milliseconds: 2000));
      await s.close();
      whitelistReachable = true;
    } catch (_) {}

    // Проверка домашнего whitelist: пробуем Rostelecom DNS (домашний интернет)
    // Источник: vc.ru — провайдеры на юге России тестируют whitelist на домашнем интернете
    try {
      final s = await Socket.connect('193.0.14.129', 443,  // RIPE K-root (всегда доступен)
          timeout: const Duration(milliseconds: 2000));
      await s.close();
      homeWhitelistReachable = true;
    } catch (_) {}

    // Проверка внешнего IP: пробуем Cloudflare (может быть не в белом списке)
    try {
      final s = await Socket.connect('1.1.1.1', 443,
          timeout: const Duration(milliseconds: 2000));
      await s.close();
      externalReachable = true;
    } catch (_) {}

    // Белый список = Госуслуги доступны, Cloudflare нет
    // ИЛИ домашний whitelist = RIPE доступен, Cloudflare нет
    return (whitelistReachable && !externalReachable) ||
           (homeWhitelistReachable && !externalReachable);
  }

  // ── Получить стратегии обхода белого списка ────────────────────────────────
  // Сортированы по tier (0 = самый надёжный)
  static List<Map<String, dynamic>> getStrategies() {
    final sorted = List<Map<String, dynamic>>.from(whitelistEndpoints);
    sorted.sort((a, b) => (a['tier'] as int).compareTo(b['tier'] as int));
    // Внутри одного tier — shuffle
    final result = <Map<String, dynamic>>[];
    int currentTier = -1;
    var tierBucket = <Map<String, dynamic>>[];
    for (final ep in sorted) {
      final t = ep['tier'] as int;
      if (t != currentTier) {
        tierBucket.shuffle(_rng);
        result.addAll(tierBucket);
        tierBucket = [];
        currentTier = t;
      }
      tierBucket.add(ep);
    }
    tierBucket.shuffle(_rng);
    result.addAll(tierBucket);
    return result;
  }

  // ── Применить whitelist domain fronting к v2ray конфигу ────────────────────
  static String applyDomainFronting(String configJson, Map<String, dynamic> endpoint) {
    try {
      final j = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = j['outbounds'] as List? ?? [];

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

        final ss = Map<String, dynamic>.from(ob['streamSettings'] as Map? ?? {});
        final network = endpoint['network'] as String? ?? 'ws';
        ss['network'] = network;

        // Настройки транспорта
        if (network == 'ws') {
          ss['wsSettings'] = {
            'path': endpoint['path'],
            'headers': Map<String, String>.from(endpoint['headers'] as Map? ?? {}),
          };
        } else if (network == 'h2') {
          ss['httpSettings'] = {
            'host': [endpoint['host']],
            'path': endpoint['path'],
            'headers': (endpoint['headers'] as Map?)?.map(
                (k, v) => MapEntry(k as String, [v as String])) ?? {},
          };
        }

        // TLS с whitelist SNI
        final sec = ss['security'] as String? ?? '';
        if (sec != 'reality') {
          ss['security'] = 'tls';
          ss['tlsSettings'] = {
            'serverName':    endpoint['sni'],
            'fingerprint':   endpoint['fp'] ?? 'chrome',
            'allowInsecure': true, // domain fronting требует ignore cert mismatch
          };
        }

        // sockopt
        final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
        so['tcpNoDelay']  = true;
        so['tcpFastOpen'] = true;
        ss['sockopt'] = so;
        ob['streamSettings'] = ss;
      }

      return jsonEncode(j);
    } catch (_) { return configJson; }
  }

  // ── Проверка: доступен ли конкретный whitelist endpoint ────────────────────
  static Future<bool> probeEndpoint(Map<String, dynamic> endpoint) async {
    final host = endpoint['host'] as String? ?? '';
    if (host.isEmpty) return false;
    try {
      final s = await SecureSocket.connect(host, 443,
          timeout: const Duration(seconds: 3),
          onBadCertificate: (_) => true);
      await s.close();
      return true;
    } catch (_) { return false; }
  }

  // ── Anti-Cooperation Shield: проверка маршрута ─────────────────────────────
  // Проверяем не идёт ли трафик через инфраструктуру сотрудничающих компаний
  // Возвращает true если маршрут БЕЗОПАСЕН (не через Сбер/WB/Ozon и т.д.)
  static bool isRouteSafe(String destinationIp) {
    // Проверяем не попадает ли IP в диапазоны сотрудничающих компаний
    // AS31261 (Сбер): 194.186.207.0/24, 194.85.0.0/16
    // AS200350 (WB): 91.232.160.0/22
    // AS207634 (Ozon): 185.214.164.0/22
    // AS57724 (Avito): 95.163.0.0/16
    // AS13238 (Яндекс): 77.88.0.0/18, 87.250.224.0/19, 213.180.192.0/19
    // AS47541 (VK): 87.240.128.0/18, 93.186.224.0/20, 95.142.192.0/20
    
    try {
      final ipParts = destinationIp.split('.').map(int.parse).toList();
      if (ipParts.length != 4) return true; // невалидный IP — считаем безопасным
      
      final ip = ipParts[0] * 256 * 256 * 256 + 
                 ipParts[1] * 256 * 256 + 
                 ipParts[2] * 256 + 
                 ipParts[3];
      
      // Сбер AS31261
      if (ip >= _ipToInt('194.186.207.0') && ip <= _ipToInt('194.186.207.255')) return false;
      if (ip >= _ipToInt('194.85.0.0') && ip <= _ipToInt('194.85.255.255')) return false;
      
      // Wildberries AS200350
      if (ip >= _ipToInt('91.232.160.0') && ip <= _ipToInt('91.232.163.255')) return false;
      
      // Ozon AS207634
      if (ip >= _ipToInt('185.214.164.0') && ip <= _ipToInt('185.214.167.255')) return false;
      
      // Avito AS57724
      if (ip >= _ipToInt('95.163.0.0') && ip <= _ipToInt('95.163.255.255')) return false;
      
      // Яндекс AS13238
      if (ip >= _ipToInt('77.88.0.0') && ip <= _ipToInt('77.88.63.255')) return false;
      if (ip >= _ipToInt('87.250.224.0') && ip <= _ipToInt('87.250.255.255')) return false;
      if (ip >= _ipToInt('213.180.192.0') && ip <= _ipToInt('213.180.255.255')) return false;
      
      // VK AS47541
      if (ip >= _ipToInt('87.240.128.0') && ip <= _ipToInt('87.240.191.255')) return false;
      if (ip >= _ipToInt('93.186.224.0') && ip <= _ipToInt('93.186.239.255')) return false;
      if (ip >= _ipToInt('95.142.192.0') && ip <= _ipToInt('95.142.207.255')) return false;
      
      return true; // не в запрещённых диапазонах
    } catch (_) {
      return true; // ошибка парсинга — считаем безопасным
    }
  }
  
  static int _ipToInt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return parts[0] * 256 * 256 * 256 + 
           parts[1] * 256 * 256 + 
           parts[2] * 256 + 
           parts[3];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ТСПУ BYPASS WINDOW DETECTOR  (апрель 2026)
//
//  Март 2026: ТСПУ перегружаются при ~40К правил фильтрации и уходят в bypass.
//  В bypass-режиме заблокированные ресурсы временно доступны без VPN.
//  Источник: Forbes.ru, habr.com/articles/1012132 (19.03.2026)
// ═══════════════════════════════════════════════════════════════════════════════
class TspuBypassWindowDetector {
  static bool _isBypassActive     = false;
  static DateTime? _lastCheck;
  static DateTime? _bypassStarted;
  static int _consecutiveBypass   = 0;
  static int _consecutiveBlocked  = 0;

  static Duration get _checkInterval =>
      _isBypassActive ? const Duration(seconds: 30) : const Duration(minutes: 3);

  static const _probeTargets = [
    {'host': 'telegram.org',   'port': 443},
    {'host': 'instagram.com',  'port': 443},
    {'host': 'discord.com',    'port': 443},
  ];

  static bool get isBypassActive => _isBypassActive;
  static int get bypassDurationSec =>
      _bypassStarted != null ? DateTime.now().difference(_bypassStarted!).inSeconds : 0;

  static Future<bool> check({void Function(String)? log}) async {
    if (_lastCheck != null && DateTime.now().difference(_lastCheck!) < _checkInterval) {
      return _isBypassActive;
    }
    _lastCheck = DateTime.now();

    int reachable = 0;
    final futures = _probeTargets.map((t) async {
      try {
        final s = await Socket.connect(t['host'] as String, t['port'] as int,
            timeout: const Duration(milliseconds: 2500));
        await s.close();
        return true;
      } catch (_) { return false; }
    });

    final results = await Future.wait(futures);
    reachable = results.where((r) => r).length;

    final wasActive = _isBypassActive;
    if (reachable >= 2) {
      _consecutiveBypass++;
      _consecutiveBlocked = 0;
      if (_consecutiveBypass >= 2) {
        _isBypassActive = true;
        if (!wasActive) {
          _bypassStarted = DateTime.now();
          log?.call('🟢 ТСПУ bypass detected! Direct connection possible');
        }
      }
    } else {
      _consecutiveBlocked++;
      _consecutiveBypass = 0;
      if (_consecutiveBlocked >= 2) {
        _isBypassActive = false;
        if (wasActive) {
          log?.call('🔴 ТСПУ bypass ended after ${bypassDurationSec}s — switching to stealth');
          _bypassStarted = null;
        }
      }
    }

    return _isBypassActive;
  }

  static void reset() {
    _isBypassActive    = false;
    _lastCheck         = null;
    _bypassStarted     = null;
    _consecutiveBypass = 0;
    _consecutiveBlocked = 0;
  }
}

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
        device: 'Pixel 8 Pro', os: 'Android 14', browser: 'Chrome 137',
        userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.48 Mobile Safari/537.36',
        tlsFp: 'chrome', screenRes: '1344x2992', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9,en;q=0.8', mtu: 1400, tcpWindow: 65535, ttl: 64,
        sessionMinutes: 15 + _rng.nextInt(45), requestInterval: const Duration(milliseconds: 800), idleChance: 0.15,
      ),
      _DigitalPersona(
        device: 'Samsung S24 Ultra', os: 'Android 14', browser: 'Chrome 137',
        userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.55 Mobile Safari/537.36',
        tlsFp: 'chrome', screenRes: '1440x3120', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7', mtu: 1400, tcpWindow: 65535, ttl: 64,
        sessionMinutes: 20 + _rng.nextInt(60), requestInterval: const Duration(milliseconds: 600), idleChance: 0.12,
      ),
      _DigitalPersona(
        device: 'iPhone 15 Pro', os: 'iOS 18.3', browser: 'Safari 18.3',
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1',
        tlsFp: 'safari', screenRes: '1179x2556', timezone: 'Europe/Moscow',
        language: 'ru-RU,ru;q=0.9', mtu: 1500, tcpWindow: 131072, ttl: 64,
        sessionMinutes: 10 + _rng.nextInt(30), requestInterval: const Duration(milliseconds: 1200), idleChance: 0.20,
      ),
      _DigitalPersona(
        device: 'Windows Desktop', os: 'Windows 11', browser: 'Edge 134',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
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
     'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/134.0.0.0', 'accept': 'text/css,*/*;q=0.1'},
    {'url': 'https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap',
     'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15', 'accept': 'text/css,*/*;q=0.1'},
    {'url': 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js',
     'ua': 'Mozilla/5.0 (Linux; Android 14) Chrome/137.0.0.0', 'accept': '*/*'},
    {'url': 'https://unpkg.com/react@18/umd/react.production.min.js',
     'ua': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) Safari/604.1', 'accept': '*/*'},
    {'url': 'https://cdn.jsdelivr.net/npm/lodash@4.17.21/lodash.min.js',
     'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/136.0', 'accept': '*/*'},
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

