// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

class NetworkCountermeasures2026 {
  static final _rng = Random();

  // ── Детектор типа блокировки по коду ошибки ────────────────────────────────
  // Разные типы блокировок требуют разных контрмер
  static BlockType classifyError(String errorMsg) {
    final e = errorMsg.toLowerCase();
    // TCP RST — активная блокировка (DPI инжектирует RST)
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
