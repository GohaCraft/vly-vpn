// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';


class SiberiaShield {
  static final _rng = Random();

  // Трекер соединений к IP-адресам: IP → список timestamp
  static final Map<String, List<DateTime>> _connTimestamps = {};
  // Заблокированные IP: IP → время когда разблокируется
  static final Map<String, DateTime> _blockedUntil = {};

  // Пороги детектора обновлены март 2026 (ntc.party анализ DPI)
  // DPI усилил ML-детектор: теперь режет на 2-х SYN за 8 сек к одному IP
  static const _maxConnsPerWindow = 1;    // 1 за окно (DPI 2026: 2 → блок)
  static const _windowSeconds     = 8;   // окно 8 сек (расширено с 5 до 8)
  static const _cooldownMinutes   = 4;   // 4 мин cooldown (DPI блокирует на 3)
  static const _pacingMs          = 3500; // 3.5 сек минимум между коннектами

  // ── 1. Connection Pacing — умный паузер ────────────────────────────────────
  static Future<void> paceConnection(String host) async {
    final now  = DateTime.now();
    final ip   = host;

    // Проверяем cooldown
    final blocked = _blockedUntil[ip];
    if (blocked != null && now.isBefore(blocked)) {
      final wait = blocked.difference(now);
      await Future.delayed(wait + Duration(seconds: 5 + _rng.nextInt(15)));
    }

    // Очищаем старые метки
    final cutoff = now.subtract(const Duration(seconds: _windowSeconds));
    _connTimestamps[ip] = (_connTimestamps[ip] ?? [])
        .where((t) => t.isAfter(cutoff)).toList();

    final recent = _connTimestamps[ip]!.length;

    // Первое подключение — всегда без задержки
    if (recent == 0) {
      (_connTimestamps[ip] ??= []).add(DateTime.now());
      return;
    }

    if (recent >= _maxConnsPerWindow) {
      // Слишком часто — пейсим
      final oldest = _connTimestamps[ip]!.first;
      final waitMs = oldest.add(const Duration(seconds: _windowSeconds + 1))
                          .difference(now).inMilliseconds;
      if (waitMs > 0) {
        final jitter = 300 + _rng.nextInt(700);
        await Future.delayed(Duration(milliseconds: waitMs + jitter));
      }
    } else {
      // Есть соединения, но в рамках — минимальный pacing
      final lastConn = _connTimestamps[ip]!.last;
      final sinceMs  = now.difference(lastConn).inMilliseconds;
      if (sinceMs < _pacingMs) {
        await Future.delayed(Duration(milliseconds: _pacingMs - sinceMs + _rng.nextInt(500)));
      }
    }

    (_connTimestamps[ip] ??= []).add(DateTime.now());
  }

  // ── 2. Report blocked IP — регистрируем что IP заблокирован ───────────────
  static void reportBlocked(String host) {
    _blockedUntil[host] = DateTime.now()
        .add(Duration(minutes: _cooldownMinutes, seconds: _rng.nextInt(60)));
  }

  // ── 3. patchConfig для Siberia Shield ─────────────────────────────────────
  // Включает mux совместимый с v2ray-core (flutter_v2ray использует v2ray, не xray)
  // Один туннель → меньше handshake → детектор бурста не срабатывает
  static String applyToConfig(String configJson) {
    try {
      final j         = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = j['outbounds'] as List? ?? [];

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

        final ss  = ob['streamSettings'] as Map<String, dynamic>? ?? {};
        final sec = ss['security'] as String? ?? '';
        final net = ss['network']  as String? ?? 'tcp';

        // Mux только для vmess/trojan — vless+reality несовместим
        // НЕ используем xmux/smux — это xray-only, v2ray их не знает
        if (['vmess', 'trojan'].contains(proto) &&
            sec != 'reality' && net != 'grpc' && net != 'quic') {
          // Включаем стандартный v2ray mux если ещё не включён
          if (ob['mux'] == null) {
            ob['mux'] = {
              'enabled':     true,
              'concurrency': 4, // меньше потоков = меньше видимых соединений
            };
          }
        }

        // TCP_FASTOPEN + keepalive для имитации стримингового трафика
        final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
        so['tcpNoDelay']       = true;
        so['tcpKeepAliveIdle'] = 100;
        // tcpFastOpen: уменьшает количество видимых RTT
        so['tcpFastOpen']      = true;
        ss['sockopt'] = so;
        ob['streamSettings'] = ss;
      }

      return jsonEncode(j);
    } catch (_) { return configJson; }
  }

  // ── 4. Decoy request — фоновый "обычный" трафик между VPN handshake ────────
  // провайдер видит: HTTP → пауза → HTTP → пауза → TLS (выглядит как браузер)
  // Без этого: тишина → TLS (явная сигнатура VPN)
  static Future<void> sendDecoy(void Function(String) log) async {
    final decoyUrls = [
      'https://www.google.com/generate_204',
      'https://www.msftconnecttest.com/connecttest.txt',
      'https://detectportal.firefox.com/success.txt',
    ];
    final url = decoyUrls[_rng.nextInt(decoyUrls.length)];
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..userAgent = StealthEngine._randomUserAgent();
    try {
      final req  = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 2));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      await resp.drain<void>().timeout(const Duration(seconds: 1));
      client.close();
    } catch (_) {
      client.close(force: true);
    }
  }

  // ── Публичные геттеры для Dev Dashboard ──────────────────────────────────
  static int  get blockedIpsCount => _blockedUntil.length;
  static int  get connHostsCount  => _connTimestamps.length;
  static void clearCooldowns() {
    _blockedUntil.clear();
    _connTimestamps.clear();
  }

  // ── 5. Cleanup — убираем старые записи из памяти ──────────────────────────
  static void cleanup() {
    final now = DateTime.now();
    _connTimestamps.removeWhere((_, ts) => ts.isEmpty ||
        ts.last.isBefore(now.subtract(const Duration(minutes: 10))));
    _blockedUntil.removeWhere((_, until) => until.isBefore(now));
  }
}



// ═══════════════════════════════════════════════════════════════════════════════
//  TELEGRAM FAST PROTOCOL  —  Специальный режим для Telegram
//
//  Telegram имеет собственные MTProto серверы — они блокируются отдельно.
//  Когда пользователь открывает Telegram, автоматически активируется
//  оптимальный транспорт для Telegram CDN серверов.
//
//  Telegram IP диапазоны (официальные):
//  149.154.160.0/20 и 91.108.4.0/22 (основные DC)
//  Стратегия: WebSocket через порт 443 с TLS + SNI от Cloudflare CDN
// ═══════════════════════════════════════════════════════════════════════════════

class TelegramProtocol {
  static final _rng = Random();

  // Telegram DC IP диапазоны — трафик к ним детектируется провайдер
  static const _tgCidrs = [
    '149.154.160.', '149.154.164.', '149.154.167.',
    '91.108.4.', '91.108.56.', '91.108.8.',
    '95.161.', '2001:67c:4e8:',
  ];

  // SNI домены которые хорошо работают для Telegram трафика через CDN
  static const _tgSniPool = [
    'cdn.tlgr.org',          // Telegram CDN
    'cdn4.telegram.org',     // Telegram CDN 4
    'cdn1.telegram.org',     // Telegram CDN 1
    'core.telegram.org',     // Telegram Core API
    'speed.cloudflare.com',  // Cloudflare CDN
    'ajax.googleapis.com',   // Google CDN (всегда доступен)
    'dl.google.com',         // Google DL
  ];

  static bool isTelegramHost(String host) =>
      host.endsWith('telegram.org') ||
      host.endsWith('tlgr.org') ||
      host.endsWith('t.me') ||
      _tgCidrs.any((cidr) => host.startsWith(cidr));

  // Применяем Telegram-оптимизированный транспорт к конфигу
  // Вызывается когда детектируем Telegram трафик
  static String optimizeForTelegram(String configJson) {
    try {
      final j         = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = j['outbounds'] as List? ?? [];
      final sni       = _tgSniPool[_rng.nextInt(_tgSniPool.length)];

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = ob['protocol'] as String? ?? '';
        if (!['vless', 'vmess', 'trojan'].contains(proto)) continue;

        final ss = Map<String, dynamic>.from(
            ob['streamSettings'] as Map? ?? {});

        // Telegram хорошо работает через WebSocket на 443
        // Это самый стабильный транспорт для мессенджеров
        if (!['ws', 'websocket'].contains(ss['network'] as String? ?? '')) {
          ss['network'] = 'ws';
          ss['wsSettings'] = {
            'path': '/tg-${_rng.nextInt(999)}',  // рандомный путь — не паттерн
            'headers': {
              'Host': sni,
              'User-Agent': StealthEngine._randomUserAgent(),
            },
          };
        }

        // TLS с Telegram-совместимым SNI
        final sec = ss['security'] as String? ?? '';
        if (sec != 'reality') {
          ss['security'] = 'tls';
          ss['tlsSettings'] = {
            'serverName':  sni,
            'fingerprint': 'chrome',  // Chrome fingerprint для Telegram
            'allowInsecure': false,
          };
        }

        // Telegram критичен к latency — отключаем mux для него
        ob['mux'] = {'enabled': false};

        // Оптимизированные sockopt для мессенджеров
        final so = Map<String, dynamic>.from(ss['sockopt'] as Map? ?? {});
        so['tcpNoDelay']       = true;
        so['tcpFastOpen']      = true;
        so['tcpKeepAliveIdle'] = 30; // частый keepalive — важен для мессенджеров
        ss['sockopt'] = so;

        ob['streamSettings'] = ss;
      }

      return jsonEncode(j);
    } catch (_) { return configJson; }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BYPASS ARSENAL  —  100 стратегий обхода блокировок
//
//  Архитектура: каждая стратегия — это набор параметров для изменения
//  VPN конфига. Стратегии хранятся в приоритетном порядке.
//  AI агент (будущий) будет выбирать стратегию на основе:
//  - Типа блокировки (TCP reset / TLS fingerprint / DNS / IP block)
//  - Региона пользователя (Сибирь / Москва / и т.д.)
//  - Истории успешных подключений
//  - Актуальных новостей о блокировках (через API)
//
//  Пока: стратегии пронумерованы и сортируются по приоритету.
//  При провале стратегии N → переходим к N+1.
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  DPI COUNTERMEASURES 2026
//  Активные контрмеры против новых методов блокировок DPI (март 2026)
//
//  Основано на:
//  - ntc.party анализ поведения DPI Q1 2026
//  - Xray-core v26.x Vision framework changelog
//  - net4people/bbs #490: новые признаки ML-классификатора DPI
//  - boringssl fingerprint research (tlsfingerprint.io)
//
//  ML-DPI DPI 2026 анализирует:
//  1. Packet length distribution (типичный VPN имеет равномерное распределение)
//  2. Inter-arrival time patterns (регулярные интервалы = машина, не браузер)
//  3. TLS ClientHello entropy (VLESS без padding имеет низкую энтропию)
//  4. Server→Client первый ответ размер (Reality: точно 1369 байт — детектируется)
//  5. IPv6 traffic ratio (блокируются IPv6 потоки к подозрительным /48)
// ═══════════════════════════════════════════════════════════════════════════════
