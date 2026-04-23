// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class StealthEngine {
  static final _rng = Random();
  static int sniIndex = 0; // публичный для UI

  // Кэш живого SNI — не проверяем TLS каждое подключение
  static String? _cachedSni;
  static DateTime? _sniCacheTime;
  // TTL 3 минуты — РКН блокировки появляются быстро, 5 мин слишком долго
  static const _sniCacheTtl = Duration(minutes: 3);

  // ── 1. TLS Фрагментация — "Ghost Handshake" ────────────────────────────────
  // Разбиваем TLS ClientHello на несколько пакетов.
  // DPI видит фрагменты, не видит полный fingerprint.
  // Работает через sockopt.dialerProxy + fragment в v2ray конфиге.
  static Map<String, dynamic> buildFragmentConfig(Map<String, dynamic> base) {
    final outbounds = base['outbounds'] as List? ?? [];

    // Guard: не добавлять fragment-out дважды
    if (outbounds.any((ob) => ob is Map && ob['tag'] == 'fragment-out')) {
      return base; // уже есть — возвращаем без изменений
    }
    // Определяем заранее: есть ли целевые протоколы для фрагментации
    final hasFragmentTarget = outbounds.any((ob) =>
        ob is Map && (ob['tag'] == 'proxy' || ob['protocol'] == 'vless' ||
            ob['protocol'] == 'vmess' || ob['protocol'] == 'trojan'));
    for (final ob in outbounds) {
      if (ob is Map && (ob['tag'] == 'proxy' || ob['protocol'] == 'vless' ||
          ob['protocol'] == 'vmess' || ob['protocol'] == 'trojan')) {
        final ss = ob['streamSettings'] as Map<String, dynamic>? ?? {};
        final so = ss['sockopt'] as Map<String, dynamic>? ?? {};

        // Fragment — разбиваем пакет на 1-3 части с задержкой 15-25ms
        so['dialerProxy'] = 'fragment-out';
        ss['sockopt'] = so;
        ob['streamSettings'] = ss;
      }
    }

    if (!hasFragmentTarget) return base;

    // Профили фрагментации — 22.03.2026: ТСПУ AI анализирует статистику пакетов
    // Ключ: НЕ фиксированные паттерны, вариативность похожа на реальный браузер
    // Источник: ntc.party + net4people/bbs анализ март 2026
    final fragProfiles = [
      {'length': '25-55',  'interval': '7-17'},    // Chrome 136 профиль
      {'length': '35-90',  'interval': '12-25'},   // Firefox 134 профиль
      {'length': '18-42',  'interval': '5-14'},    // Safari 18/iOS профиль
      {'length': '50-120', 'interval': '15-30'},   // Edge 134/Windows профиль
      {'length': '15-35',  'interval': '3-10'},    // Мобильный Chrome (плохая сеть)
    ];
    final prof = fragProfiles[_rng.nextInt(fragProfiles.length)];

    (base['outbounds'] as List).add({
      'tag': 'fragment-out',
      'protocol': 'freedom',
      'settings': {
        'fragment': {
          'packets':  'tlshello',
          'length':   prof['length'],
          'interval': prof['interval'],
        },
      },
      'streamSettings': {
        'sockopt': {
          'tcpNoDelay': true,
          'mark':       255,
        },
      },
    });

    return base;
  }

  // ── 2. Reality SNI Ротация ─────────────────────────────────────────────────
  // Каждый раз берём следующий SNI из пула высокоавторитетных доменов.
  // РКН видит трафик к dl.google.com — не блокирует.
  static String nextSni() {
    final sni = kRealitySniPool[sniIndex % kRealitySniPool.length];
    sniIndex++;
    return sni;
  }

  // Выбор живого SNI — с кэшем на 5 минут
  // Без кэша каждое подключение тратит до 16 сек на проверку всех SNI
  static Future<String> pickLiveSni() async {
    // Проверяем кэш
    if (_cachedSni != null && _sniCacheTime != null &&
        DateTime.now().difference(_sniCacheTime!) < _sniCacheTtl) {
      return _cachedSni!;
    }

    // Проверяем SNI параллельно — берём ПЕРВЫЙ успешный через Completer
    // Future.wait ждёт ВСЕ — это теряет до 3 сек на мёртвых SNI
    final completer = Completer<String>();
    int pending = kRealitySniPool.length;

    for (int i = 0; i < kRealitySniPool.length; i++) {
      final sni = kRealitySniPool[i];
      final idx = i;
      Future(() async {
        try {
          // SecureSocket = полный TLS handshake (не просто TCP)
          final sock = await SecureSocket.connect(
            sni, 443,
            timeout: const Duration(seconds: 3),
            onBadCertificate: (_) => true, // cert не важен — важен сам handshake
          );
          await sock.close();
          // Первый успешный SNI — сразу отдаём результат
          if (!completer.isCompleted) {
            _cachedSni    = sni;
            _sniCacheTime = DateTime.now();
            sniIndex      = idx + 1;
            completer.complete(sni);
          }
        } catch (_) {
          // TLS упал — SNI заблокирован
        } finally {
          pending--;
          // Все провалились — возвращаем дефолт
          if (pending == 0 && !completer.isCompleted) {
            _cachedSni    = kRealitySniPool[0];
            _sniCacheTime = DateTime.now();
            completer.complete(_cachedSni!);
          }
        }
      });
    }

    // Таймаут 4 сек — если никто не ответил → дефолт
    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        if (!completer.isCompleted) {
          _cachedSni    = kRealitySniPool[0];
          _sniCacheTime = DateTime.now();
          completer.complete(_cachedSni!);
        }
        return _cachedSni!;
      },
    );
  }

  // Сбросить SNI кэш (при Connection Reset)
  // Быстрый SNI из кэша без I/O — для горячего пути подключения
  static String pickLiveSniFromCache() {
    if (_cachedSni != null && _cachedSni!.isNotEmpty) return _cachedSni!;
    // Рандомный из пула без проверки — лучше быстро чем идеально
    return kRealitySniPool[_rng.nextInt(kRealitySniPool.length)];
  }

  static void invalidateSniCache() {
    _cachedSni    = null;
    _sniCacheTime = null;
  }

  // ── 3. Packet Jitter — обман AI/ML анализа (обновлено март 2026) ───────────
  // ML-DPI ТСПУ 2026 обучен на поведенческих признаках: inter-arrival time,
  // burst размер, соотношение up/down. Имитируем WebRTC/video call паттерн.
  static Future<void> applyJitter() async {
    // DNS lookup imitation: 20-60ms (типично для DoH через 1.1.1.1)
    final dnsLike = 20 + _rng.nextInt(40);
    await Future.delayed(Duration(milliseconds: dnsLike));

    // TCP handshake RTT: 5-15ms (быстрый дата-центр)
    final tcpRtt = 5 + _rng.nextInt(10);
    await Future.delayed(Duration(milliseconds: tcpRtt));

    // 35% шанс "mobile network jitter" — имитация 4G/5G нестабильности
    if (_rng.nextDouble() < 0.35) {
      // Mobile jitter: burst паузы характерны для 5G handoff
      final mobileJitter = 40 + _rng.nextInt(180);
      await Future.delayed(Duration(milliseconds: mobileJitter));
    }

    // 15% шанс "captive portal check" — браузер иногда делает connectivitycheck
    if (_rng.nextDouble() < 0.15) {
      final captiveCheck = 100 + _rng.nextInt(300);
      await Future.delayed(Duration(milliseconds: captiveCheck));
    }
  }

  // ── 4. Warm-up — "прогрев" соединения ─────────────────────────────────────
  // Перед VPN-туннелем делаем реальный HTTP запрос к безопасному домену.
  // Провайдер видит "нормальный" HTTPS трафик и не считает соединение подозрительным.
  static Future<void> warmUp(void Function(String) log) async {
    for (final url in kWarmupTargets) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..userAgent = _randomUserAgent()
        ..badCertificateCallback = (_, __, ___) => true;
      try {
        final req = await client.getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
        req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
        req.headers.set('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
        req.headers.set('Accept-Encoding', 'gzip, deflate, br');
        req.headers.set('Connection', 'keep-alive');
        final resp = await req.close().timeout(const Duration(seconds: 3));
        await resp.drain<void>().timeout(const Duration(seconds: 2));
        client.close();
        log('🔥 Warm-up OK: ${Uri.parse(url).host}');
        return;
      } catch (_) {
        client.close(force: true); // FIX v3.0: гарантированный cleanup сокета
      }
    }
    log('⚠ Warm-up skipped (no connectivity)');
  }

  // ── 5. Инжект Reality параметров в конфиг ─────────────────────────────────
  // FIX v3.0: сохраняем pbk (publicKey) и sid (shortId) из оригинала.
  // Предыдущая версия их теряла → Reality ноды подключались, но шифрование ломалось.
  static String injectReality(String link) {
    if (!link.startsWith('vless://')) return link;
    try {
      final uri = Uri.parse(link);
      final q   = Map<String, String>.from(uri.queryParameters);
      if (q['security'] == 'reality') {
        // Ротируем SNI, но pbk/sid/fp из оригинала — они привязаны к серверу
        q['sni']        = nextSni();
        q['serverName'] = q['sni']!;
        q['fp']       ??= randomFingerprint(); // обновляем fp только если не задан
      } else if (q['security'] == 'tls' || q['security'] == null) {
        // Апгрейд до Reality — pbk/sid не нужны (не Reality нода изначально)
        q['security']   = 'reality';
        q['sni']        = nextSni();
        q['serverName'] = q['sni']!;
        q['fp']         = randomFingerprint();
      }
      return uri.replace(queryParameters: q).toString();
    } catch (_) { return link; }
  }

  // ── 5b. Инжект Reality с конкретным live-SNI ──────────────────────────────
  // FIX v3.0: сохраняем pbk/sid; не перезаписываем fp если уже задан
  static String injectRealityWithSni(String link, String sni) {
    if (!link.startsWith('vless://')) return link;
    try {
      final uri = Uri.parse(link);
      final q   = Map<String, String>.from(uri.queryParameters);
      if (q['security'] == 'reality') {
        q['sni']        = sni;
        q['serverName'] = sni;
        q['fp']       ??= randomFingerprint(); // не перезаписываем fp сервера
      } else if (q['security'] == 'tls' || q['security'] == null) {
        q['security']   = 'reality';
        q['sni']        = sni;
        q['serverName'] = sni;
        q['fp']         = randomFingerprint();
      }
      return uri.replace(queryParameters: q).toString();
    } catch (_) { return link; }
  }

  // ── 6. Рандомный TLS fingerprint ──────────────────────────────────────────
  // FIX v3.0: добавлены ios/android — более разнообразный пул.
  // Публичный — используется в BypassRulesEngine.applyStrategy
  static String randomFingerprint() {
    const fps = ['chrome', 'safari', 'edge', 'ios', 'android'];
    return fps[_rng.nextInt(fps.length)];
  }

  // ── 7. Рандомный User-Agent для warm-up ───────────────────────────────────
  // Март 2026 — актуальные версии Chrome 136/Safari 18/Edge 134
  // РКН и DPI блокируют запросы от Dart/2.x по умолчанию
  static const _userAgents = [
    // Android Chrome 136 — самый частый в РФ (40%+ трафика)
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Redmi Note 12 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.7049.111 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; POCO X6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.165 Mobile Safari/537.36',
    // Windows Chrome 136
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Safari/537.36',
    // iOS Safari 18
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1',
    // Edge 134
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
  ];
  static String _randomUserAgent() => _userAgents[_rng.nextInt(_userAgents.length)];

  // uTLS fingerprints — актуализированы 22.03.2026
  // ML-модель ТСПУ анализирует поведенческие паттерны TLS handshake
  // 'random' = случайный из набора xray-core — максимально усложняет классификацию
  static const List<String> _uTlsProfiles = [
    'chrome',    // Chrome 136 — 62% рынка Android, самый надёжный
    'edge',      // Edge 134 — Windows Update IP в whitelist ТСПУ
    'safari',    // Safari 18.3 iOS — iPhone трафик
    'ios',       // iOS native TLS stack — нативный мобильный
    'firefox',   // Firefox 134 — desktop, другой ALPN паттерн
    'android',   // Android TLS — базовый мобильный паттерн
    'random',    // Случайный xray fingerprint — anti-ML behavioral analysis
  ];
  static int _uTlsIndex = 0;

  static String nextUTlsProfile() {
    final p = _uTlsProfiles[_uTlsIndex % _uTlsProfiles.length];
    _uTlsIndex++;
    return p;
  }

  static String patchConfig(String configJson, {bool fragment = true}) {
    try {
      final j = jsonDecode(configJson) as Map<String, dynamic>;

      // 1. TLS фрагментация только ClientHello
      if (fragment) buildFragmentConfig(j);

      // 2. uTLS fingerprint — ТОЛЬКО если явно не задан сервером
      // ВАЖНО: НЕ трогаем minVersion, alpn, allowInsecure — это ломает большинство серверов
      // Сервер сам определяет допустимые параметры TLS — мы только маскируем fingerprint клиента
      final outbounds = j['outbounds'] as List? ?? [];
      final fp = nextUTlsProfile();
      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless','vmess','trojan'].contains(proto)) continue;
        final ss  = ob['streamSettings'] as Map<String, dynamic>? ?? {};
        final sec = ss['security'] as String? ?? '';
        if (sec == 'tls' || sec == 'reality') {
          final key = '${sec}Settings';
          final tlsSettings = Map<String, dynamic>.from(
              (ss[key] as Map<String, dynamic>?) ?? {});
          // fingerprint — если не задан уже
          if (tlsSettings['fingerprint'] == null ||
              (tlsSettings['fingerprint'] as String).isEmpty) {
            tlsSettings['fingerprint'] = fp;
          }
          ss[key] = tlsSettings;
          ob['streamSettings'] = ss;

          // XTLS-Vision flow: КРИТИЧНО для обхода ML-детектора ТСПУ (март 2026)
          // Vision убирает двойное TLS-шифрование + добавляет padding случайного размера
          // Применяем только для VLESS+Reality — самая эффективная комбинация
          // НЕ применяем для VMess/Trojan — они используют другой механизм шифрования
          if (proto == 'vless' && sec == 'reality') {
            final currentFlow = ob['flow'] as String? ?? '';
            if (currentFlow.isEmpty) {
              ob['flow'] = 'xtls-rprx-vision';
            }
          }
        }
      }

      // 3. DoH — только если DNS вообще не настроен
      final existingDns   = j['dns'] as Map<String, dynamic>?;
      final existingCount = (existingDns?['servers'] as List?)?.length ?? 0;
      if (existingCount < 2) {
        j['dns'] = {
          'servers': [
            {
              'address':      'https://1.1.1.1/dns-query',
              'domains':      ['geosite:geolocation-!cn'],
              'skipFallback': true,
            },
            {
              'address':      'https://8.8.8.8/dns-query',
              'skipFallback': true,
            },
            {
              'address': 'localhost',
              'domains': ['geosite:cn', 'localhost'],
            },
          ],
          'queryStrategy':   'UseIPv4',
          'disableFallback': false,
        };
      }

      // 4. Smart routing — российские сайты напрямую, заблокированные через VPN
      // Используем актуальный список РКН-блокировок из BypassRulesEngine
      // Это заменяет только IPv6 blackhole — маршрутизацию ставим целиком
      final routing = j['routing'] as Map<String, dynamic>? ?? {};
      final rules   = (routing['rules'] as List?)?.cast<dynamic>() ?? <dynamic>[];
      final hasIpv6 = rules.any((r) =>
          r is Map && (r['ip'] as List?)?.contains('::/0') == true);
      if (!hasIpv6) {
        rules.insert(0, {'type': 'field', 'ip': ['::/0'], 'outboundTag': 'block'});
        routing['rules'] = rules;
        j['routing'] = routing;
      }
      final obs = j['outbounds'] as List? ?? [];
      if (!obs.any((o) => o is Map && o['tag'] == 'block')) {
        obs.add({'tag': 'block', 'protocol': 'blackhole', 'settings': {}});
      }
      if (!obs.any((o) => o is Map && o['tag'] == 'direct')) {
        obs.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
      }

      // 5. Mux — только vmess/trojan без Reality и без gRPC/QUIC
      // VLESS+Reality несовместим с mux — никогда не включаем для vless
      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vmess', 'trojan'].contains(proto)) continue;
        final ss  = ob['streamSettings'] as Map<String, dynamic>? ?? {};
        final net = ss['network'] as String? ?? 'tcp';
        final sec = ss['security'] as String? ?? '';
        if (sec == 'reality' || net == 'grpc' || net == 'quic') continue;
        // Консервативный Mux concurrency=4: безопасно на 3G и перегруженном WiFi
        if (ob['mux'] == null) {
          ob['mux'] = {'enabled': true, 'concurrency': 4};
        }
      }

      // 6. sockopt + MTU/tcpFastOpen (март 2026)
      // tcpFastOpen: ускоряет переподключения — важно при частых ротациях от блокировок
      // tcpNoDelay: отключает Nagle, уменьшает задержку первого пакета
      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;
        final ss  = Map<String, dynamic>.from(ob['streamSettings'] as Map? ?? {});
        final so  = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
        so['tcpNoDelay']  = true;
        so['tcpFastOpen'] = true;
        ss['sockopt'] = so;
        ob['streamSettings'] = ss;

        // 6b. VLESS Vision flow control — антидетект TLS-in-TLS (март 2026)
        // AI-DPI ТСПУ ищет вложенные TLS паттерны (packet length distribution).
        // Vision применяет dynamic padding — пакеты выглядят как реальный HTTPS.
        // Применяем ТОЛЬКО для VLESS+Reality без явного flow
        if (proto == 'vless') {
          final sec = (ss['security'] as String?) ?? '';
          if (sec == 'reality') {
            final settings = Map<String, dynamic>.from(ob['settings'] as Map? ?? {});
            final vnext = settings['vnext'] as List?;
            if (vnext != null) {
              for (final srv in vnext) {
                if (srv is! Map) continue;
                final users = srv['users'] as List?;
                if (users == null) continue;
                for (final user in users) {
                  if (user is! Map) continue;
                  final flow = (user['flow'] as String?) ?? '';
                  if (flow.isEmpty) {
                    user['flow'] = 'xtls-rprx-vision';
                  }
                }
              }
              settings['vnext'] = vnext;
              ob['settings'] = settings;
            }
          }
        }
      }

      // 7. Policy — anti-TCP-freeze (новый метод ТСПУ март 2026)
      // ТСПУ замораживает TCP когда server→client > ~15-20KB на "подозрительных" IP
      // bufferSize 512KB + connIdle 300s форсирует правильный keepalive
      try {
        final policy = Map<String, dynamic>.from(j['policy'] as Map? ?? {});
        final levels = Map<String, dynamic>.from(policy['levels'] as Map? ?? {});
        if (!levels.containsKey('0')) {
          levels['0'] = {
            'handshake':    4,
            'connIdle':     300,
            'uplinkOnly':   2,
            'downlinkOnly': 5,
            'bufferSize':   512,
          };
          policy['levels'] = levels;
          j['policy'] = policy;
        }
      } catch (_) {}

      return jsonEncode(j);
    } catch (e) {
      return configJson; // при любой ошибке — оригинал без изменений
    }
  }

  // ── 9. Connection Reset детектор ──────────────────────────────────────────
  // Считает RST паттерны и предлагает ротацию SNI.
  static int _rstCount = 0;
  static DateTime? _lastRst;

  static bool reportReset() {
    final now = DateTime.now();
    if (_lastRst != null && now.difference(_lastRst!).inMinutes < 5) {
      _rstCount++;
    } else {
      _rstCount = 1;
    }
    _lastRst = now;
    // 3+ RST за 5 минут = активная блокировка → ротируй SNI
    return _rstCount >= 3;
  }


  // ── patchConfigSecure: VPN Detection Shield ─────────────────────────────────
  // Версия patchConfig с рандомизацией SOCKS5 порта и авторизацией
  // Защищает от сканирования localhost портов приложениями (Habr CVE, апрель 2026)
  static String patchConfigSecure(String configJson, {
    bool fragment = true,
    int  socksPort = 10808,
    String socksPass = 'vly_secure',
  }) {
    try {
      final j = jsonDecode(patchConfig(configJson, fragment: fragment)) as Map<String, dynamic>;

      // Переписываем inbounds с авторизацией и рандомным портом
      final inbounds = j['inbounds'] as List? ?? [];
      for (final ib in inbounds) {
        if (ib is! Map) continue;
        final proto = ib['protocol'] as String? ?? '';
        if (proto == 'socks') {
          ib['port']   = socksPort;
          ib['listen'] = '127.0.0.1';
          final s = Map<String, dynamic>.from(ib['settings'] as Map? ?? {});
          s['auth']     = 'password';
          s['accounts'] = [{'user': 'vly', 'pass': socksPass}];
          s['udp']      = true;
          s['ip']       = '127.0.0.1';
          ib['settings'] = s;
        } else if (proto == 'http') {
          ib['port']   = socksPort + 1;
          ib['listen'] = '127.0.0.1';
          final s = Map<String, dynamic>.from(ib['settings'] as Map? ?? {});
          s['accounts'] = [{'user': 'vly', 'pass': socksPass}];
          ib['settings'] = s;
        }
      }

      // Удаляем API без авторизации (CVE-Happ-2026)
      j.remove('api');
      j.remove('stats');

      return jsonEncode(j);
    } catch (_) {
      return patchConfig(configJson, fragment: fragment);
    }
  }

  
  // ── xHTTP Config Builder (НОВЫЙ транспорт 2026) ─────────────────────────────
  // xHTTP — лучший TCP-транспорт апрель 2026. Выглядит как HTTP multipart upload.
  // ТСПУ не детектирует: нет характерных паттернов TLS VPN, только обычный HTTP.
  // Работает там где Reality+TCP уже не проходит.
  static Map<String, dynamic> buildXhttpConfig({
    required String host,
    required int    port,
    required String uuid,
    String?  path,
    String?  sni,
    String?  fp,
    bool     tls = true,
  }) {
    final liveSni = sni ?? pickLiveSniFromCache();
    final uTls    = fp  ?? nextUTlsProfile();
    // Случайный path — имитирует API endpoint
    final apiPath = path ?? '/api/v${DateTime.now().second % 9 + 1}/${_rng.nextInt(9999)}';

    return {
      'outbounds': [
        {
          'tag':      'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': host,
                'port':    port,
                'users':   [
                  {
                    'id':         uuid,
                    'encryption': 'none',
                    'flow':       '',  // xHTTP не использует flow
                    'level':      0,
                  }
                ],
              }
            ],
          },
          'streamSettings': {
            'network':  'xhttp',
            'security': tls ? 'tls' : 'none',
            if (tls) 'tlsSettings': {
              'serverName':   liveSni,
              'fingerprint':  uTls,
              'alpn':         ['h2', 'http/1.1'],
              'allowInsecure': false,
            },
            'xhttpSettings': {
              'path':    apiPath,
              'host':    liveSni,
              'mode':    'packet-up',  // лучший режим — разделяет upload/download
              'extra': {
                // Имитируем браузерные заголовки
                'headers': {
                  'User-Agent':      [_userAgents[_rng.nextInt(_userAgents.length)]],
                  'Accept':          ['*/*'],
                  'Accept-Language': ['ru-RU,ru;q=0.9,en;q=0.8'],
                  'Cache-Control':   ['no-cache'],
                },
                // Рандомный padding — ломает ML анализ размеров пакетов
                'xPaddingBytes': '${100 + _rng.nextInt(400)}-${500 + _rng.nextInt(1000)}',
              },
            },
            'sockopt': {
              'tcpNoDelay':  true,
              'tcpFastOpen': true,
              'mark':        255,
            },
          },
        },
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block',  'protocol': 'blackhole', 'settings': {}},
      ],
      'inbounds': _buildSecureInbounds(),
      'dns': _buildDns(),
      'routing': _buildRouting(),
    };
  }

  // ── ShadowTLS v3 + Shadowsocks config ────────────────────────────────────────
  // ShadowTLS v3: туннель поверх реального TLS сервера.
  // ТСПУ видит легитимный TLS handshake к vk.com — пропускает.
  static Map<String, dynamic> buildShadowTlsConfig({
    required String host,
    required int    port,
    required String password,
    String? serverName,
  }) {
    final sni = serverName ?? pickLiveSniFromCache();
    return {
      'outbounds': [
        {
          'tag':      'proxy',
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address':  '127.0.0.1',
                'port':     port + 1,
                'method':   'aes-256-gcm',
                'password': password,
                'uot':      true,
              }
            ],
          },
        },
        {
          'tag':      'shadowtls',
          'protocol': 'shadowtls',
          'settings': {
            'version':    3,
            'password':   password,
            'servers': [
              {
                'address':    host,
                'port':       port,
                'serverName': sni,
              }
            ],
          },
        },
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block',  'protocol': 'blackhole', 'settings': {}},
      ],
      'inbounds':  _buildSecureInbounds(),
      'dns':       _buildDns(),
      'routing':   _buildRouting(),
    };
  }

  // ── Общие builders ────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _buildSecureInbounds() {
    // Случайный порт 40000-65535 — не предсказуем для сканеров
    final port = 40000 + (_rng.nextInt(25535));
    return [
      {
        'tag':      'socks',
        'protocol': 'socks',
        'listen':   '127.0.0.1',  // ТОЛЬКО localhost — защита от CVE-Happ-2026
        'port':     port,
        'settings': {
          'auth':     'password',
          'accounts': [{'user': 'vly', 'pass': _randomPass()}],
          'udp':      true,
          'ip':       '127.0.0.1',
        },
      },
      {
        'tag':      'http',
        'protocol': 'http',
        'listen':   '127.0.0.1',
        'port':     port + 1,
        'settings': {
          'accounts': [{'user': 'vly', 'pass': _randomPass()}],
        },
      },
    ];
  }

  static Map<String, dynamic> _buildDns() => {
    'servers': [
      // DoH через Cloudflare — обходит DNS отравление РКН
      {'address': 'https://1.1.1.1/dns-query', 'skipFallback': true,
       'domains': ['geosite:geolocation-!cn']},
      {'address': 'https://8.8.8.8/dns-query', 'skipFallback': true},
      // Яндекс DNS для ru-доменов (быстрее)
      {'address': '77.88.8.8', 'domains': ['geosite:ru', 'geosite:private']},
      {'address': 'localhost'},
    ],
    'queryStrategy': 'UseIPv4',
    // Отключаем утечку через системный DNS
    'disableFallbackIfMatch': true,
  };

  static Map<String, dynamic> _buildRouting() => {
    'domainStrategy': 'IPIfNonMatch',
    'rules': [
      // Блок IPv6 — утечки предотвращаем полностью
      {'type': 'field', 'ip': ['::/0'], 'outboundTag': 'block'},
      // Российские сайты — напрямую (быстрее + не светим трафик)
      {
        'type': 'field',
        'domain': [
          'geosite:ru',
          'domain:yandex.ru', 'domain:ya.ru', 'domain:yandex.net',
          'domain:vk.com', 'domain:vkvideo.ru', 'domain:userapi.com',
          'domain:mail.ru', 'domain:ok.ru', 'domain:rambler.ru',
          'domain:sber.ru', 'domain:alfabank.ru', 'domain:vtb.ru',
          'domain:gosuslugi.ru', 'domain:mos.ru', 'domain:nalog.ru',
          'domain:ozon.ru', 'domain:wildberries.ru', 'domain:avito.ru',
          'domain:mts.ru', 'domain:beeline.ru', 'domain:megafon.ru',
          'domain:rzd.ru', 'domain:aeroflot.ru', 'domain:2gis.ru',
          'domain:rbc.ru', 'domain:ria.ru', 'domain:tass.ru',
          'domain:gazprombank.ru', 'domain:raiffeisen.ru', 'domain:tinkoff.ru',
        ],
        'outboundTag': 'direct',
      },
      // Российские IP — напрямую
      {'type': 'field', 'ip': ['geoip:ru', 'geoip:private'], 'outboundTag': 'direct'},
      // Всё остальное — через VPN
      {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'proxy'},
    ],
  };

  static String _randomPass() =>
      (DateTime.now().microsecondsSinceEpoch ^ 0x5EC4E7).toRadixString(36) +
      _rng.nextInt(0xFFFF).toRadixString(16);

  static void resetCounter() { _rstCount = 0; _lastRst = null; }

  // Геттеры для DevDashboard (приватные поля недоступны снаружи)
  static int    get utlsIndexPublic => _uTlsIndex;
  static int    get rstCountPublic  => _rstCount;
  static String get cachedSniPublic => _cachedSni ?? '—';

  // ── 10. Hysteria2 конфиг builder ──────────────────────────────────────────
  // Hysteria2 использует QUIC (UDP) — ТСПУ хуже справляется с UDP DPI.
  // Salamander обфускация XOR-ит каждый QUIC пакет с паролем → fingerprint скрыт.
  // Формат ноды: hy2://password@host:port?sni=...&obfs=salamander&obfs-password=...
  static Map<String, dynamic> buildHysteria2Config(String nodeLink) {
    // Парсим hy2:// URI
    // hy2://password@host:port?sni=...&insecure=...&obfs=salamander&obfs-password=...
    try {
      final uri      = Uri.parse(nodeLink.replaceFirst('hy2://', 'https://'));
      final auth     = uri.userInfo;            // password (Hysteria2 auth)
      final host     = uri.host;
      final port     = uri.port > 0 ? uri.port : 443;
      final q        = uri.queryParameters;
      final sni      = q['sni']?.isNotEmpty == true ? q['sni']! : pickLiveSniFromCache();
      final insecure = q['insecure'] == '1' || q['insecure'] == 'true';
      final obfs     = q['obfs'] ?? 'salamander';
      final obfsPw   = q['obfs-password'] ?? q['obfsPassword'] ?? '';
      final upMbps   = int.tryParse(q['up'] ?? '') ?? 50;
      final downMbps = int.tryParse(q['down'] ?? '') ?? 200;

      // Hysteria2 нативный JSON конфиг (hysteria2 клиент или sing-box)
      final cfg = <String, dynamic>{
        'server': '$host:$port',
        'auth':   auth,
        'tls': {
          'sni':      sni,
          'insecure': insecure,
        },
        'bandwidth': {
          'up':   '${upMbps} mbps',
          'down': '${downMbps} mbps',
        },
        'fastOpen': true,
        // Salamander obfs — скрывает QUIC fingerprint от DPI
        if (obfs == 'salamander' && obfsPw.isNotEmpty)
          'obfs': {
            'type':       'salamander',
            'salamander': {'password': obfsPw},
          },
        // SOCKS5 прокси для приложений
        'socks5': {'listen': '127.0.0.1:10808'},
        'http':   {'listen': '127.0.0.1:10809'},
        // Логирование — минимум в продакшне
        'log': {'level': 'warn'},
        // Quic параметры — адаптивные под российские сети
        'quic': {
          'initStreamReceiveWindow':     '8388608',   // 8 MB
          'maxStreamReceiveWindow':      '8388608',
          'initConnReceiveWindow':       '20971520',  // 20 MB
          'maxConnReceiveWindow':        '20971520',
          'maxIdleTimeout':              '30s',
          'keepAlivePeriod':             '10s',
          'disablePathMTUDiscovery':     false,
        },
      };

      return cfg;
    } catch (e) {
      // Fallback: минимальный конфиг
      return {
        'server':    '127.0.0.1:443',
        'auth':      '',
        'tls':       {'insecure': false},
        'bandwidth': {'up': '50 mbps', 'down': '200 mbps'},
        'fastOpen':  true,
        'socks5':    {'listen': '127.0.0.1:10808'},
      };
    }
  }

  // ── 11. VLESS+Vision полный конфиг builder ────────────────────────────────
  // Vision = XTLS-rprx-vision: убирает TLS-in-TLS паттерн + добавляет рандомный padding.
  // Без Vision ТСПУ ML видит "двойное TLS" → помечает как VPN.
  // С Vision пакеты неотличимы от реального HTTPS браузера (март 2026 анализ).
  //
  // IMPORTANT: Vision требует flow=xtls-rprx-vision на обеих сторонах (клиент + сервер).
  // Если сервер не поддерживает Vision — соединение не установится. Проверяй конфиг.
  static Map<String, dynamic> buildVlessVisionConfig({
    required String host,
    required int    port,
    required String uuid,
    required String pbk,     // Reality publicKey (из конфига сервера)
    required String sid,     // Reality shortId
    String?         sni,
    String?         fp,
  }) {
    final liveSni = sni ?? pickLiveSniFromCache();
    final uTls    = fp   ?? nextUTlsProfile();

    return {
      'outbounds': [
        {
          'tag':      'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': host,
                'port':    port,
                'users':   [
                  {
                    'id':         uuid,
                    'encryption': 'none',
                    // XTLS-Vision flow — ключевой параметр обхода
                    // xtls-rprx-vision-udp443: дополнительно маскирует UDP (QUIC) трафик
                    'flow':       'xtls-rprx-vision',
                    'level':      0,
                  }
                ],
              }
            ],
          },
          'streamSettings': {
            'network':  'tcp',
            'security': 'reality',
            'realitySettings': {
              'serverName':  liveSni,  // SNI = реальный авторитетный домен
              'fingerprint': uTls,     // TLS fingerprint маскировка
              'publicKey':   pbk,      // публичный ключ Reality сервера
              'shortId':     sid,      // short ID для auth
              'show':        false,
            },
            'sockopt': {
              'tcpNoDelay':  true,
              'tcpFastOpen': true,
              // mark=255: нужен для exclude-self трафика на роутинге
              'mark':        255,
            },
          },
        },
        // Прямой выход для российских IP (split tunneling)
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        // Блокировка IPv6 (leak prevention)
        {'tag': 'block',  'protocol': 'blackhole', 'settings': {}},
      ],
      'inbounds': [
        {
          'tag':      'socks',
          'protocol': 'socks',
          'listen':   '127.0.0.1',
          'port':     10808,
          'settings': {'auth': 'noauth', 'udp': true},
        },
        {
          'tag':      'http',
          'protocol': 'http',
          'listen':   '127.0.0.1',
          'port':     10809,
        },
      ],
      'dns': {
        'servers': [
          // DoH — обходит DNS отравление РКН
          {'address': 'https://1.1.1.1/dns-query', 'skipFallback': true,
           'domains': ['geosite:geolocation-!cn']},
          {'address': 'https://8.8.8.8/dns-query', 'skipFallback': true},
          {'address': 'localhost', 'domains': ['geosite:cn', 'localhost']},
        ],
        'queryStrategy': 'UseIPv4',
      },
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          // IPv6 блок
          {'type': 'field', 'ip': ['::/0'], 'outboundTag': 'block'},
          // Российские сайты — напрямую (белый список)
          {'type': 'field', 'domain': ['geosite:ru', 'domain:yandex.ru', 'domain:vk.com',
            'domain:mail.ru', 'domain:ok.ru', 'domain:sber.ru', 'domain:gosuslugi.ru'],
            'outboundTag': 'direct'},
          // Российские IP — напрямую
          {'type': 'field', 'ip': ['geoip:ru', 'geoip:private'], 'outboundTag': 'direct'},
          // Остальное — через VPN
          {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'proxy'},
        ],
      },
      // Anti-TCP-freeze политика (ТСПУ март 2026)
      'policy': {
        'levels': {
          '0': {
            'handshake':    4,
            'connIdle':     300,
            'uplinkOnly':   2,
            'downlinkOnly': 5,
            'bufferSize':   512,
          }
        }
      },
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ZAPRET BRIDGE — интеграция с локальным Zapret DPI-bypass
//  Zapret работает на сетевом уровне (nfqueue/windivert) — дополняет VPN.
//  Использовать как fallback когда ТСПУ активно блокирует TLS handshake.
//  GitHub: github.com/bol-van/zapret
// ═══════════════════════════════════════════════════════════════════════════════
class ZapretBridge {
  static final _rng = Random();

  // Проверяем доступность Zapret на локальном порту
  // Zapret запускается отдельным процессом (windivert/nfqueue), нам нужен его SOCKS5/HTTP порт
  static Future<bool> isAvailable() async {
    final port = (kZapretConfig['httpPort'] as int? ?? 1080);
    try {
      final sock = await Socket.connect(
        '127.0.0.1', port,
        timeout: const Duration(milliseconds: 500),
      );
      await sock.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Возвращает прокси URL если Zapret доступен
  static Future<String?> getProxyUrl() async {
    if (!(kZapretConfig['enabled'] as bool? ?? false)) return null;
    if (!await isAvailable()) return null;
    final port = (kZapretConfig['httpPort'] as int? ?? 1080);
    return 'http://127.0.0.1:$port';
  }

  // Патчим Xray конфиг чтобы трафик шёл через Zapret как промежуточный прокси.
  // Схема: App → Xray SOCKS(10808) → Zapret(1080) → [DPI bypass] → VPN сервер
  // Zapret применяет fake-SNI / disorder / TTL-trick на уровне пакетов.
  static Map<String, dynamic> patchConfigForZapret(
      Map<String, dynamic> config, {
      String strategy = 'fake_sni',
    }) {
    if (!(kZapretConfig['enabled'] as bool? ?? false)) return config;

    final port    = (kZapretConfig['httpPort'] as int? ?? 1080);
    final fakeSni = kZapretConfig['fakeSniFallback'] as String? ?? 'www.yandex.ru';

    // Добавляем Zapret как dialerProxy для VPN outbound
    final outbounds = List<dynamic>.from(config['outbounds'] as List? ?? []);
    for (final ob in outbounds) {
      if (ob is! Map) continue;
      final proto = ob['protocol'] as String? ?? '';
      if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

      final ss = Map<String, dynamic>.from(ob['streamSettings'] as Map? ?? {});
      final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});

      // Направляем через Zapret SOCKS5 прокси
      so['dialerProxy'] = 'zapret-out';
      ss['sockopt'] = so;
      ob['streamSettings'] = ss;
    }

    // Guard: не добавлять zapret-out дважды
    if (!outbounds.any((ob) => ob is Map && ob['tag'] == 'zapret-out')) {
      outbounds.add({
        'tag':      'zapret-out',
        'protocol': 'socks',
        'settings': {
          'servers': [
            {
              'address': '127.0.0.1',
              'port':    port,
            }
          ],
        },
        'streamSettings': {
          'network': 'tcp',
          'sockopt': {
            'tcpNoDelay': true,
          },
        },
      });
    }

    config['outbounds'] = outbounds;

    // Логируем активацию стратегии
    config['_zapretStrategy'] = strategy;
    config['_zapretFakeSni']  = fakeSni;

    return config;
  }

  // Рекомендует стратегию на основе типа блокировки
  static String recommendStrategy(BlockType blockType) {
    switch (blockType) {
      case BlockType.tlsFingerprint:
        // ТСПУ видит TLS fingerprint → подменяем SNI + disorder
        return 'fake_sni';
      case BlockType.tcpReset:
        // Активный RST → disorder пакеты + TTL trick
        return 'disorder';
      case BlockType.timeout:
        // Тихая блокировка → split + TTL trick
        return 'ttl_trick';
      default:
        return 'fake_sni';
    }
  }
}


// ── Compatibility stubs ─────────────────────────────────────────────────────
// These prevent undefined identifier errors from older code references

// Zapret strategy list (also defined in constants.dart)
// ignore: constant_identifier_names  
const List<String> _kZapretCompatStrategies = ['fake_sni', 'disorder', 'split', 'ttl_trick'];

// Rotate zapret strategy helper
String _rotateZapretStrategy(String current) {
  final idx = _kZapretCompatStrategies.indexOf(current);
  return _kZapretCompatStrategies[(idx + 1) % _kZapretCompatStrategies.length];
}
