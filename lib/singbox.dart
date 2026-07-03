// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, avoid_print, constant_identifier_names, always_use_package_imports
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SING-BOX CONFIG BUILDER — фаза 2 миграции ядра (см. docs/IOS_ARCHITECTURE.md)
//
//  Единый формат конфига для БУДУЩЕГО общего ядра sing-box (Android + iOS).
//  Пока это чистый Dart-трансформ с юнит-тестами формата — НЕ подключён к
//  рантайму (нативная часть sing-box приедет отдельно). Даёт проверяемый мост
//  «наша ссылка/стратегия → sing-box JSON», чтобы своп ядра был механическим.
//
//  Схема sing-box: https://sing-box.sagernet.org/configuration/
// ═══════════════════════════════════════════════════════════════════════════
class SingBoxConfigBuilder {
  // VLESS + Reality + XTLS-Vision → sing-box outbound (тип 'vless').
  // Возвращает готовый outbound-map или null, если ссылка не Reality-нода.
  static Map<String, dynamic>? vlessRealityOutbound(String link,
      {String? sni, String fingerprint = 'chrome'}) {
    try {
      if (!link.startsWith('vless://')) return null;
      final hash = link.indexOf('#');
      final core = hash >= 0 ? link.substring(0, hash) : link;
      final uri  = Uri.parse(core);
      final uuid = uri.userInfo;
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : 443;
      final q    = uri.queryParameters;
      final pbk  = q['pbk'] ?? '';
      if (uuid.isEmpty || host.isEmpty || pbk.isEmpty) return null; // не Reality
      final serverName = sni ?? q['sni'] ?? host;
      final flow = (q['flow'] ?? 'xtls-rprx-vision');

      return {
        'type': 'vless',
        'tag': 'proxy',
        'server': host,
        'server_port': port,
        'uuid': uuid,
        if (flow.isNotEmpty) 'flow': flow,
        'tls': {
          'enabled': true,
          'server_name': serverName,
          'utls': {'enabled': true, 'fingerprint': fingerprint},
          'reality': {
            'enabled': true,
            'public_key': pbk,
            if ((q['sid'] ?? '').isNotEmpty) 'short_id': q['sid'],
          },
        },
      };
    } catch (_) { return null; }
  }

  // Полный конфиг: tun-inbound + proxy-outbound + direct + базовый роутинг.
  // Строится вокруг любого outbound (напр. из vlessRealityOutbound).
  static Map<String, dynamic> fullConfig(Map<String, dynamic> outbound) => {
    'log': {'level': 'warn'},
    'inbounds': [
      {
        'type': 'tun',
        'tag': 'tun-in',
        'stack': 'mixed',
        'auto_route': true,
        'strict_route': true,
      }
    ],
    'outbounds': [
      outbound,
      {'type': 'direct', 'tag': 'direct'},
    ],
    'route': {
      'auto_detect_interface': true,
      'final': 'proxy',
      'rules': [
        // RU-домены/локалка — напрямую, остальное — в proxy (умный роутинг).
        {'ip_is_private': true, 'outbound': 'direct'},
      ],
    },
  };

  // Удобный хелпер: ссылка → готовый JSON-строкой (или null).
  static String? buildVlessReality(String link,
      {String? sni, String fingerprint = 'chrome'}) {
    final ob = vlessRealityOutbound(link, sni: sni, fingerprint: fingerprint);
    if (ob == null) return null;
    return jsonEncode(fullConfig(ob));
  }
}
