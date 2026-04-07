// ignore_for_file: unused_import, unused_element
part of 'main.dart';

enum CamouflageMode {
  none,        // без маскировки
  browser,     // HTTPS браузер (Chrome)
  telegram,    // Telegram MTProto CDN
  netflix,     // Netflix видеостриминг
  youtube,     // YouTube / googleapis
  discord,     // Discord WebSocket gateway
  cloudflare,  // Cloudflare WARP-style
  microsoft,   // Windows Update / Office 365
  apple,       // iCloud / Private Relay
  naive,       // NaïveProxy HTTP CONNECT
}

extension CamouflageModeExt on CamouflageMode {
  String get label {
    switch (this) {
      case CamouflageMode.none:        return 'Без маскировки';
      case CamouflageMode.browser:     return 'HTTPS браузер';
      case CamouflageMode.telegram:    return 'Telegram CDN';
      case CamouflageMode.netflix:     return 'Netflix Stream';
      case CamouflageMode.youtube:     return 'YouTube Video';
      case CamouflageMode.discord:     return 'Discord Gateway';
      case CamouflageMode.cloudflare:  return 'Cloudflare WARP';
      case CamouflageMode.microsoft:   return 'Windows Update';
      case CamouflageMode.apple:       return 'iCloud Sync';
      case CamouflageMode.naive:       return 'NaïveProxy H2';
    }
  }
  String get emoji {
    switch (this) {
      case CamouflageMode.none:        return '🔓';
      case CamouflageMode.browser:     return '🌐';
      case CamouflageMode.telegram:    return '✈️';
      case CamouflageMode.netflix:     return '🎬';
      case CamouflageMode.youtube:     return '▶️';
      case CamouflageMode.discord:     return '🎮';
      case CamouflageMode.cloudflare:  return '🟠';
      case CamouflageMode.microsoft:   return '🪟';
      case CamouflageMode.apple:       return '🍎';
      case CamouflageMode.naive:       return '🔀';
    }
  }
  String get description {
    switch (this) {
      case CamouflageMode.none:
        return 'Чистый VLESS/VMess без дополнительной маскировки';
      case CamouflageMode.browser:
        return 'Трафик выглядит как Chrome посещающий Google.com';
      case CamouflageMode.telegram:
        return 'MTProto CDN — как Telegram звонки и медиа';
      case CamouflageMode.netflix:
        return 'HTTP/2 chunked stream — Netflix video buffering';
      case CamouflageMode.youtube:
        return 'googlevideo.com adaptive bitrate — YouTube 4K';
      case CamouflageMode.discord:
        return 'WebSocket gateway.discord.gg — Discord real-time';
      case CamouflageMode.cloudflare:
        return 'Cloudflare WARP endpoint — обычный мобильный VPN';
      case CamouflageMode.microsoft:
        return 'Windows Update / Office 365 sync — корпоративный';
      case CamouflageMode.apple:
        return 'iCloud Private Relay mask.icloud.com — iOS трафик';
      case CamouflageMode.naive:
        return 'NaïveProxy: HTTP CONNECT через H2 — анти-DPI прокси';
    }
  }
}

class TrafficCamouflageEngine {
  static final _rng = Random();

  // ── Главный метод: применяет маскировку к v2ray конфигу ─────────────────────
  static String apply(String configJson, CamouflageMode mode) {
    if (mode == CamouflageMode.none) return configJson;
    try {
      final j = jsonDecode(configJson) as Map<String, dynamic>;
      switch (mode) {
        case CamouflageMode.browser:    _applyBrowser(j);    break;
        case CamouflageMode.telegram:   _applyTelegram(j);   break;
        case CamouflageMode.netflix:    _applyNetflix(j);    break;
        case CamouflageMode.youtube:    _applyYoutube(j);    break;
        case CamouflageMode.discord:    _applyDiscord(j);    break;
        case CamouflageMode.cloudflare: _applyCloudflare(j); break;
        case CamouflageMode.microsoft:  _applyMicrosoft(j);  break;
        case CamouflageMode.apple:      _applyApple(j);      break;
        case CamouflageMode.naive:      _applyNaive(j);      break;
        default: break;
      }
      return jsonEncode(j);
    } catch (_) { return configJson; }
  }

  // ── Применяет маскировку к каждому outbound ─────────────────────────────────
  static void _patchOutbounds(
    Map<String, dynamic> j,
    String network,
    Map<String, dynamic> networkSettings,
    String sni,
    String fingerprint, {
    bool disableMux = false,
    Map<String, dynamic>? extraSockopt,
  }) {
    final outbounds = j['outbounds'] as List? ?? [];
    for (final ob in outbounds) {
      if (ob is! Map) continue;
      final proto = ob['protocol'] as String? ?? '';
      if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

      final ss = Map<String, dynamic>.from(ob['streamSettings'] as Map? ?? {});
      ss['network'] = network;
      ss[networkSettings.keys.first] = networkSettings.values.first;

      // TLS настройки
      final sec = ss['security'] as String? ?? '';
      if (sec != 'reality') {
        ss['security'] = 'tls';
        final existingTls = Map<String, dynamic>.from(
            ss['tlsSettings'] as Map? ?? {});
        existingTls['serverName']  = sni;
        existingTls['fingerprint'] = fingerprint;
        existingTls['allowInsecure'] = false;
        ss['tlsSettings'] = existingTls;
      }

      // sockopt
      final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
      so['tcpNoDelay']  = true;
      so['tcpFastOpen'] = true;
      if (extraSockopt != null) so.addAll(extraSockopt);
      ss['sockopt'] = so;

      ob['streamSettings'] = ss;
      if (disableMux) ob['mux'] = {'enabled': false};
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BROWSER: Chrome посещает Google.com
  // WebSocket на 443, User-Agent Chrome 136, путь /search?q=...
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyBrowser(Map<String, dynamic> j) {
    final searches = ['news', 'weather', 'maps', 'translate', 'mail'];
    final path = '/search?q=${searches[_rng.nextInt(searches.length)]}&client=chrome';
    _patchOutbounds(j, 'ws', {
      'wsSettings': {
        'path': path,
        'headers': {
          'Host':            'www.google.com',
          'User-Agent':      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36',
          'Accept':          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Cache-Control':   'no-cache',
          'Pragma':          'no-cache',
        },
      },
    }, 'www.google.com', 'chrome');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TELEGRAM: MTProto CDN
  // Уже реализован в TelegramProtocol — делегируем
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyTelegram(Map<String, dynamic> j) {
    // Telegram MTProto через WebSocket — максимальная маскировка
    // Март 2026: РКН анализирует JA4+ fingerprint
    // Ротация CDN + реальный fingerprint iOS клиента
    final cdns = ['cdn4.telegram.org', 'cdn5.telegram.org', 'cdn1.telegram.org'];
    final sni  = cdns[DateTime.now().millisecond % cdns.length];
    _patchOutbounds(j, 'ws', {
      'wsSettings': {
        'path': '/api/v1',
        'headers': {
          'Host':            sni,
          'User-Agent':      'Telegram-iOS/10.6.1 (iPhone; iOS 18.4; Scale/3.00)',
          'Connection':      'Upgrade',
          'Upgrade':         'websocket',
          'Accept':          '*/*',
          'Accept-Language': 'ru-RU,ru;q=0.9',
          'Sec-WebSocket-Version':    '13',
          'Sec-WebSocket-Extensions': 'permessage-deflate; client_max_window_bits',
        },
      },
    }, sni, 'ios', disableMux: true,
    extraSockopt: {
      'tcpKeepAliveIdle':     30,
      'tcpKeepAliveInterval': 10,
      'tcpNoDelay':           true,
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NETFLIX: HTTP/2 видеостриминг
  // Chunked transfer encoding, Netflix-специфичные заголовки
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyNetflix(Map<String, dynamic> j) {
    // Netflix использует HTTP/2 через ocsp.apple.com-like CDN
    // Реальный Netflix: ipv4-anycast.prod.netflix.com
    _patchOutbounds(j, 'h2', {
      'httpSettings': {
        'host': ['api.netflix.com'],
        'path': '/v2/video/manifest',
        'method': 'POST',
        'headers': {
          'User-Agent':      ['Netflix/8.0 (Android 14; API 34; armeabi-v7a) ExoPlayer/2.18'],
          'Accept':          ['application/vnd.netflix.streaming.v1+json'],
          'Content-Type':    ['application/json'],
          'Accept-Encoding': ['gzip, deflate, br'],
          'Netflix-Request-Id': [_randomHex(32)],
        },
        'read_idle_timeout': '30s',
        'health_check_timeout': '15s',
      },
    }, 'www.netflix.com', 'chrome');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // YOUTUBE: googlevideo.com adaptive bitrate
  // Самый сложный для детектирования — огромный объём трафика
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyYoutube(Map<String, dynamic> j) {
    final videoId = _randomHex(11); // YouTube video ID формат
    final itag    = [137, 248, 313, 271][_rng.nextInt(4)]; // 4K/1080p/720p iTag
    _patchOutbounds(j, 'h2', {
      'httpSettings': {
        'host': ['rr1---sn-ab5l6ne7.googlevideo.com'],
        'path': '/videoplayback?id=$videoId&itag=$itag&source=youtube',
        'headers': {
          'User-Agent':      ['Mozilla/5.0 (Linux; Android 14) Chrome/136 YT/19.12.34'],
          'Accept':          ['*/*'],
          'Accept-Encoding': ['identity;q=1, *;q=0'],
          'Range':           ['bytes=0-'],
          'Referer':         ['https://www.youtube.com/watch?v=$videoId'],
        },
      },
    }, 'rr1---sn-ab5l6ne7.googlevideo.com', 'chrome');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DISCORD: WebSocket gateway.discord.gg
  // Real-time gaming трафик — характерные heartbeat пакеты
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyDiscord(Map<String, dynamic> j) {
    _patchOutbounds(j, 'ws', {
      'wsSettings': {
        'path': '/v10/?encoding=json&compress=zlib-stream',
        'headers': {
          'Host':       'gateway.discord.gg',
          'Origin':     'https://discord.com',
          'User-Agent': 'Mozilla/5.0 (Android 14; Mobile) Chrome/136 Discord/228.0',
          'Sec-WebSocket-Version':  '13',
          'Sec-WebSocket-Protocol': 'binary',
        },
      },
    }, 'gateway.discord.gg', 'chrome', disableMux: true);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CLOUDFLARE WARP: WARP endpoint
  // WARP использует UDP/WireGuard но мы имитируем через TCP+TLS
  // engage.cloudflareclient.com — реальный Cloudflare WARP IP
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyCloudflare(Map<String, dynamic> j) {
    _patchOutbounds(j, 'ws', {
      'wsSettings': {
        'path': '/v0/reg',
        'headers': {
          'Host':         'engage.cloudflareclient.com',
          'User-Agent':   '1.1.1.1/6.28 CFNetwork/1490.0.4 Darwin/23.2.0',
          'CF-Client-Version': '6.28',
          'CF-Trace':     'true',
        },
      },
    }, 'engage.cloudflareclient.com', 'chrome');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MICROSOFT: Windows Update / Office 365 sync
  // Корпоративный трафик — РКН НИКОГДА не блокирует (риск)
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyMicrosoft(Map<String, dynamic> j) {
    _patchOutbounds(j, 'h2', {
      'httpSettings': {
        'host': ['update.microsoft.com'],
        'path': '/v10/clientwebservice/client.asmx',
        'headers': {
          'User-Agent':   ['Windows-Update-Agent/10.0.19041.4355 Client-Protocol/2.33'],
          'Content-Type': ['text/xml; charset=utf-8'],
          'SOAPAction':   ['"http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/SyncUpdates"'],
          'Accept-Encoding': ['gzip'],
        },
      },
    }, 'update.microsoft.com', 'edge');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // APPLE: iCloud Private Relay
  // mask.icloud.com / iCloud sync — iOS устройства
  // Private Relay: Apple → Cloudflare → сервер (двойной hop)
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyApple(Map<String, dynamic> j) {
    _patchOutbounds(j, 'h2', {
      'httpSettings': {
        'host': ['mask.icloud.com'],
        'path': '/v3/PK/relay',
        'headers': {
          'User-Agent':  ['com.apple.CloudKit/1 CFNetwork/1490.0.4'],
          'X-Apple-Account-Info': [_randomHex(40)],
          'Accept':      ['*/*'],
          'Accept-Language': ['ru-RU'],
        },
      },
    }, 'mask.icloud.com', 'safari');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NAÏVE PROXY: HTTP CONNECT через HTTP/2
  // NaïveProxy паттерн: браузер отправляет CONNECT запрос как Chrome
  // ТСПУ видит обычный браузерный HTTPS — самый сложный для детектирования
  // ────────────────────────────────────────────────────────────────────────────
  static void _applyNaive(Map<String, dynamic> j) {
    // NaïveProxy использует HTTP/2 CONNECT — имитирует Chrome встроенный прокси
    _patchOutbounds(j, 'h2', {
      'httpSettings': {
        'host': ['www.google.com'],
        'path': '/',
        'method': 'CONNECT',
        'headers': {
          'User-Agent':      ['Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/136.0.7103.60'],
          'Accept':          ['text/html,application/xhtml+xml'],
          'Accept-Language': ['ru-RU,ru;q=0.9,en;q=0.8'],
          'Proxy-Connection':['keep-alive'],
          'Proxy-Authorization': ['Basic ${_randomBase64(20)}'],
        },
      },
    }, 'www.google.com', 'chrome');
  }

  // ── Хелперы ─────────────────────────────────────────────────────────────────
  static String _randomHex(int len) {
    final chars = '0123456789abcdef';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  static String _randomBase64(int byteLen) {
    final bytes = List.generate(byteLen, (_) => _rng.nextInt(256));
    return base64Encode(bytes);
  }
}


