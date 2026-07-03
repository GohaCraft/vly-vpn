// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

class BypassArsenal {
  // Полный список стратегий — 100 вариантов обхода
  // Формат: {id, name, config_patch, triggers, priority}
  static const List<Map<String, dynamic>> strategies = [
    // ── TIER 1: Базовые (быстрые, работают в большинстве случаев) ────────────
    {'id': 1,  'name': 'Reality SNI rotate',        'type': 'rotate_reality_sni',  'priority': 1,  'params': {}},
    {'id': 2,  'name': 'WS port 443',               'type': 'change_transport',    'priority': 2,  'params': {'transport':'ws','path':'/','port':443}},
    {'id': 3,  'name': 'gRPC gun',                  'type': 'change_transport',    'priority': 3,  'params': {'transport':'grpc','service':'gun'}},
    {'id': 4,  'name': 'Port 8443',                 'type': 'change_port',         'priority': 4,  'params': {'port':8443}},
    {'id': 5,  'name': 'Port 2053 (CF)',             'type': 'change_port',         'priority': 5,  'params': {'port':2053}},
    {'id': 6,  'name': 'Port 2083 (CF)',             'type': 'change_port',         'priority': 6,  'params': {'port':2083}},
    {'id': 7,  'name': 'Port 2087 (CF)',             'type': 'change_port',         'priority': 7,  'params': {'port':2087}},
    {'id': 8,  'name': 'Port 2096 (CF)',             'type': 'change_port',         'priority': 8,  'params': {'port':2096}},
    {'id': 9,  'name': 'SNI: dl.google.com',         'type': 'add_reality_sni',     'priority': 9,  'params': {'sni':'dl.google.com'}},
    {'id': 10, 'name': 'SNI: update.microsoft.com', 'type': 'add_reality_sni',     'priority': 10, 'params': {'sni':'update.microsoft.com'}},
    // ── TIER 2: CDN обход ────────────────────────────────────────────────────
    {'id': 11, 'name': 'CF Workers CDN',             'type': 'cdn_fallback',        'priority': 11, 'params': {'url':'vly-vpn.workers.dev'}},
    {'id': 12, 'name': 'CF Pages CDN',               'type': 'cdn_fallback',        'priority': 12, 'params': {'url':'vly-cdn.pages.dev'}},
    {'id': 13, 'name': 'Trojan WS 443',              'type': 'trojan_ws_fallback',  'priority': 13, 'params': {'port':443,'path':'/'}},
    {'id': 14, 'name': 'Trojan WS /api',             'type': 'trojan_ws_fallback',  'priority': 14, 'params': {'port':443,'path':'/api/v1'}},
    {'id': 15, 'name': 'Shadow WS fallback',         'type': 'shadow_fallback',     'priority': 15, 'params': {}},
    {'id': 16, 'name': 'SNI: gateway.icloud.com',   'type': 'add_reality_sni',     'priority': 16, 'params': {'sni':'gateway.icloud.com'}},
    {'id': 17, 'name': 'SNI: mask.icloud.com',      'type': 'add_reality_sni',     'priority': 17, 'params': {'sni':'mask.icloud.com'}},
    {'id': 18, 'name': 'SNI: fonts.googleapis.com', 'type': 'add_reality_sni',     'priority': 18, 'params': {'sni':'fonts.googleapis.com'}},
    {'id': 19, 'name': 'SNI: cdn.cloudflare.com',   'type': 'add_reality_sni',     'priority': 19, 'params': {'sni':'cdn.cloudflare.com'}},
    {'id': 20, 'name': 'WS path /stream',            'type': 'change_transport',    'priority': 20, 'params': {'transport':'ws','path':'/stream'}},
    // ── TIER 3: Нестандартные порты ──────────────────────────────────────────
    {'id': 21, 'name': 'Port 80 (HTTP fallback)',    'type': 'change_port',         'priority': 21, 'params': {'port':80}},
    {'id': 22, 'name': 'Port 8080',                  'type': 'change_port',         'priority': 22, 'params': {'port':8080}},
    {'id': 23, 'name': 'Port 8888',                  'type': 'change_port',         'priority': 23, 'params': {'port':8888}},
    {'id': 24, 'name': 'Port 9443',                  'type': 'change_port',         'priority': 24, 'params': {'port':9443}},
    {'id': 25, 'name': 'Port 10443',                 'type': 'change_port',         'priority': 25, 'params': {'port':10443}},
    {'id': 26, 'name': 'Port 15000',                 'type': 'change_port',         'priority': 26, 'params': {'port':15000}},
    {'id': 27, 'name': 'Port 443 gRPC',              'type': 'change_transport',    'priority': 27, 'params': {'transport':'grpc','service':'Tun','port':443}},
    {'id': 28, 'name': 'gRPC /tun2',                 'type': 'change_transport',    'priority': 28, 'params': {'transport':'grpc','service':'tun2'}},
    {'id': 29, 'name': 'WS /health',                 'type': 'change_transport',    'priority': 29, 'params': {'transport':'ws','path':'/health'}},
    {'id': 30, 'name': 'WS /cdn-cgi/trace',          'type': 'change_transport',    'priority': 30, 'params': {'transport':'ws','path':'/cdn-cgi/trace'}},
    // ── TIER 4: Продвинутые SNI ───────────────────────────────────────────────
    {'id': 31, 'name': 'SNI: addons.mozilla.org',   'type': 'add_reality_sni',     'priority': 31, 'params': {'sni':'addons.mozilla.org'}},
    {'id': 32, 'name': 'SNI: aus5.mozilla.org',     'type': 'add_reality_sni',     'priority': 32, 'params': {'sni':'aus5.mozilla.org'}},
    {'id': 33, 'name': 'SNI: play.googleapis.com',  'type': 'add_reality_sni',     'priority': 33, 'params': {'sni':'play.googleapis.com'}},
    {'id': 34, 'name': 'SNI: ajax.googleapis.com',  'type': 'add_reality_sni',     'priority': 34, 'params': {'sni':'ajax.googleapis.com'}},
    {'id': 35, 'name': 'SNI: itunes.apple.com',     'type': 'add_reality_sni',     'priority': 35, 'params': {'sni':'itunes.apple.com'}},
    {'id': 36, 'name': 'SNI: cdn1.telegram.org',    'type': 'add_reality_sni',     'priority': 36, 'params': {'sni':'cdn1.telegram.org'}},
    {'id': 37, 'name': 'SNI: login.microsoft.com',  'type': 'add_reality_sni',     'priority': 37, 'params': {'sni':'login.microsoftonline.com'}},
    {'id': 38, 'name': 'SNI: download.microsoft',   'type': 'add_reality_sni',     'priority': 38, 'params': {'sni':'download.microsoft.com'}},
    {'id': 39, 'name': 'SNI: cdnjs.cloudflare.com', 'type': 'add_reality_sni',     'priority': 39, 'params': {'sni':'cdnjs.cloudflare.com'}},
    {'id': 40, 'name': 'SNI: speed.cloudflare.com', 'type': 'add_reality_sni',     'priority': 40, 'params': {'sni':'speed.cloudflare.com'}},
    // ── TIER 5: Смешанные стратегии ──────────────────────────────────────────
    {'id': 41, 'name': 'WS 8443 icloud SNI',        'type': 'change_transport',    'priority': 41, 'params': {'transport':'ws','path':'/','port':8443}},
    {'id': 42, 'name': 'Trojan /stream 8443',        'type': 'trojan_ws_fallback',  'priority': 42, 'params': {'port':8443,'path':'/stream'}},
    {'id': 43, 'name': 'Port 2082 (CF)',             'type': 'change_port',         'priority': 43, 'params': {'port':2082}},
    {'id': 44, 'name': 'Port 2086 (CF)',             'type': 'change_port',         'priority': 44, 'params': {'port':2086}},
    {'id': 45, 'name': 'Port 2095 (CF)',             'type': 'change_port',         'priority': 45, 'params': {'port':2095}},
    {'id': 46, 'name': 'gRPC /grpc',                 'type': 'change_transport',    'priority': 46, 'params': {'transport':'grpc','service':'grpc'}},
    {'id': 47, 'name': 'gRPC /vpn',                  'type': 'change_transport',    'priority': 47, 'params': {'transport':'grpc','service':'vpn'}},
    {'id': 48, 'name': 'WS /ws',                     'type': 'change_transport',    'priority': 48, 'params': {'transport':'ws','path':'/ws'}},
    {'id': 49, 'name': 'WS /v2',                     'type': 'change_transport',    'priority': 49, 'params': {'transport':'ws','path':'/v2'}},
    {'id': 50, 'name': 'WS /proxy',                  'type': 'change_transport',    'priority': 50, 'params': {'transport':'ws','path':'/proxy'}},
    // ── TIER 6: Экстремальные обходы ─────────────────────────────────────────
    {'id': 51, 'name': 'DoH Cloudflare 1.1.1.1',    'type': 'set_doh',             'priority': 51, 'params': {'url':'https://1.1.1.1/dns-query'}},
    {'id': 52, 'name': 'DoH Google 8.8.8.8',        'type': 'set_doh',             'priority': 52, 'params': {'url':'https://8.8.8.8/dns-query'}},
    {'id': 53, 'name': 'DoH Quad9',                  'type': 'set_doh',             'priority': 53, 'params': {'url':'https://dns.quad9.net/dns-query'}},
    {'id': 54, 'name': 'DoH AdGuard',                'type': 'set_doh',             'priority': 54, 'params': {'url':'https://dns.adguard.com/dns-query'}},
    {'id': 55, 'name': 'DoH NextDNS',                'type': 'set_doh',             'priority': 55, 'params': {'url':'https://dns.nextdns.io/dns-query'}},
    {'id': 56, 'name': 'Port 5443',                  'type': 'change_port',         'priority': 56, 'params': {'port':5443}},
    {'id': 57, 'name': 'Port 6443',                  'type': 'change_port',         'priority': 57, 'params': {'port':6443}},
    {'id': 58, 'name': 'Port 7443',                  'type': 'change_port',         'priority': 58, 'params': {'port':7443}},
    {'id': 59, 'name': 'Port 3443',                  'type': 'change_port',         'priority': 59, 'params': {'port':3443}},
    {'id': 60, 'name': 'Port 4443',                  'type': 'change_port',         'priority': 60, 'params': {'port':4443}},
    // ── TIER 7: HTTP/2 и специальные ─────────────────────────────────────────
    {'id': 61, 'name': 'H2 transport',               'type': 'change_transport',    'priority': 61, 'params': {'transport':'h2','path':'/'}},
    {'id': 62, 'name': 'H2 /api',                    'type': 'change_transport',    'priority': 62, 'params': {'transport':'h2','path':'/api'}},
    {'id': 63, 'name': 'WS /live 2053',              'type': 'change_transport',    'priority': 63, 'params': {'transport':'ws','path':'/live','port':2053}},
    {'id': 64, 'name': 'WS /media 2096',             'type': 'change_transport',    'priority': 64, 'params': {'transport':'ws','path':'/media','port':2096}},
    {'id': 65, 'name': 'WS /socket 8443',            'type': 'change_transport',    'priority': 65, 'params': {'transport':'ws','path':'/socket.io','port':8443}},
    {'id': 66, 'name': 'SNI rotate #2',              'type': 'rotate_reality_sni',  'priority': 66, 'params': {}},
    {'id': 67, 'name': 'SNI rotate #3',              'type': 'rotate_reality_sni',  'priority': 67, 'params': {}},
    {'id': 68, 'name': 'Trojan /api/v2',             'type': 'trojan_ws_fallback',  'priority': 68, 'params': {'port':443,'path':'/api/v2'}},
    {'id': 69, 'name': 'Trojan /upload',             'type': 'trojan_ws_fallback',  'priority': 69, 'params': {'port':2053,'path':'/upload'}},
    {'id': 70, 'name': 'Shadow /live',               'type': 'shadow_fallback',     'priority': 70, 'params': {}},
    // ── TIER 8: Ротация нод ───────────────────────────────────────────────────
    {'id': 71, 'name': 'Switch node',                'type': 'switch_node',         'priority': 71, 'params': {}},
    {'id': 72, 'name': 'SNI: www.google.com',        'type': 'add_reality_sni',     'priority': 72, 'params': {'sni':'www.google.com'}},
    {'id': 73, 'name': 'SNI: storage.googleapis',    'type': 'add_reality_sni',     'priority': 73, 'params': {'sni':'storage.googleapis.com'}},
    {'id': 74, 'name': 'SNI: accounts.google.com',   'type': 'add_reality_sni',     'priority': 74, 'params': {'sni':'accounts.google.com'}},
    {'id': 75, 'name': 'SNI: office.com',            'type': 'add_reality_sni',     'priority': 75, 'params': {'sni':'www.office.com'}},
    {'id': 76, 'name': 'Port 22 (SSH look)',         'type': 'change_port',         'priority': 76, 'params': {'port':22}},
    {'id': 77, 'name': 'Port 53 (DNS look)',         'type': 'change_port',         'priority': 77, 'params': {'port':53}},
    {'id': 78, 'name': 'Port 123 (NTP look)',        'type': 'change_port',         'priority': 78, 'params': {'port':123}},
    {'id': 79, 'name': 'WS /updates',               'type': 'change_transport',    'priority': 79, 'params': {'transport':'ws','path':'/updates'}},
    {'id': 80, 'name': 'WS /notifications',          'type': 'change_transport',    'priority': 80, 'params': {'transport':'ws','path':'/notifications'}},
    // ── TIER 9: CDN вариации ─────────────────────────────────────────────────
    {'id': 81, 'name': 'CF Workers v2',              'type': 'cdn_fallback',        'priority': 81, 'params': {'url':'vly-vpn-proxy.workers.dev'}},
    {'id': 82, 'name': 'CF Pages v2',                'type': 'cdn_fallback',        'priority': 82, 'params': {'url':'vly-proxy.pages.dev'}},
    {'id': 83, 'name': 'CF Workers v3',              'type': 'cdn_fallback',        'priority': 83, 'params': {'url':'vly-bypass.workers.dev'}},
    {'id': 84, 'name': 'WS /api/stream',             'type': 'change_transport',    'priority': 84, 'params': {'transport':'ws','path':'/api/stream'}},
    {'id': 85, 'name': 'gRPC /stream',               'type': 'change_transport',    'priority': 85, 'params': {'transport':'grpc','service':'stream'}},
    {'id': 86, 'name': 'Port 1443',                  'type': 'change_port',         'priority': 86, 'params': {'port':1443}},
    {'id': 87, 'name': 'Port 10080',                 'type': 'change_port',         'priority': 87, 'params': {'port':10080}},
    {'id': 88, 'name': 'Port 20443',                 'type': 'change_port',         'priority': 88, 'params': {'port':20443}},
    {'id': 89, 'name': 'SNI rotate #4',              'type': 'rotate_reality_sni',  'priority': 89, 'params': {}},
    {'id': 90, 'name': 'Switch node #2',             'type': 'switch_node',         'priority': 90, 'params': {}},
    // ── TIER 10: Последний рубеж ─────────────────────────────────────────────
    {'id': 91,  'name': 'SNI: microsoft.com',        'type': 'add_reality_sni',     'priority': 91, 'params': {'sni':'microsoft.com'}},
    {'id': 92,  'name': 'SNI: apple.com',            'type': 'add_reality_sni',     'priority': 92, 'params': {'sni':'www.apple.com'}},
    {'id': 93,  'name': 'SNI: cloudflare.com',       'type': 'add_reality_sni',     'priority': 93, 'params': {'sni':'cloudflare.com'}},
    {'id': 94,  'name': 'WS /chat',                  'type': 'change_transport',    'priority': 94, 'params': {'transport':'ws','path':'/chat'}},
    {'id': 95,  'name': 'WS /message',               'type': 'change_transport',    'priority': 95, 'params': {'transport':'ws','path':'/message'}},
    {'id': 96,  'name': 'Trojan /tg 2053',           'type': 'trojan_ws_fallback',  'priority': 96, 'params': {'port':2053,'path':'/tg'}},
    {'id': 97,  'name': 'Port 41194 (WG look)',      'type': 'change_port',         'priority': 97, 'params': {'port':41194}},
    {'id': 98,  'name': 'SNI rotate final',          'type': 'rotate_reality_sni',  'priority': 98, 'params': {}},
    {'id': 99,  'name': 'Switch node final',         'type': 'switch_node',         'priority': 99, 'params': {}},
    {'id': 100, 'name': 'Shadow final CDN',          'type': 'shadow_fallback',     'priority': 100,'params': {}},
    // ── TIER STEALTH 2026: Fragmented Reality + Whitelist bypass ─────────────
    // Март 2026: провайдер использует JA4+ fingerprint — нужна фрагментация первого TLS пакета
    {'id': 101, 'name': '🔀 Fragmented Reality 1-5b', 'type': 'fragmented_reality',  'priority': 0,  'params': {'fragSize':1, 'delayMs':50,  'sni':'yandex.ru'}},
    {'id': 102, 'name': '🔀 Fragmented Reality 3b',   'type': 'fragmented_reality',  'priority': 0,  'params': {'fragSize':3, 'delayMs':50,  'sni':'ya.ru'}},
    {'id': 103, 'name': '🔀 Fragmented Reality 5b',   'type': 'fragmented_reality',  'priority': 0,  'params': {'fragSize':5, 'delayMs':50,  'sni':'vk.com'}},
    {'id': 104, 'name': '🛡 Whitelist: Yandex SNI',   'type': 'vless_vision_whitelist','priority': 0, 'params': {'sni':'yandex.ru', 'tier':0}},
    {'id': 105, 'name': '🛡 Whitelist: VK SNI',       'type': 'vless_vision_whitelist','priority': 0, 'params': {'sni':'vk.com',    'tier':1}},
    {'id': 106, 'name': '🛡 Whitelist: mail.ru SNI',  'type': 'vless_vision_whitelist','priority': 0, 'params': {'sni':'mail.ru',   'tier':1}},
    {'id': 108, 'name': '🔀 Fragment 2b delay 30ms',  'type': 'fragmented_reality',   'priority': 0, 'params': {'fragSize':2, 'delayMs':30,  'sni':'mail.yandex.ru'}},
    {'id': 109, 'name': '🔀 Fragment 1b delay 100ms', 'type': 'fragmented_reality',   'priority': 0, 'params': {'fragSize':1, 'delayMs':100, 'sni':'userapi.com'}},
    {'id': 110, 'name': '🛡 Whitelist: MS Update',    'type': 'vless_vision_whitelist','priority': 0, 'params': {'sni':'update.microsoft.com','tier':2}},
    // ── TIER WHITELIST: Domain Fronting через разрешённые CDN ────────────────
    {'id': 111, 'name': '🟡 Whitelist: Gosuslugi',    'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'gosuslugi'}},
    {'id': 112, 'name': '🟡 Whitelist: FNS',          'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'fns'}},
    {'id': 113, 'name': '🟡 Whitelist: Cloudflare',   'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'cloudflare'}},
    {'id': 114, 'name': '🟡 Whitelist: AWS',          'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'aws'}},
    {'id': 115, 'name': '🟡 Whitelist: Fastly',       'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'fastly'}},
    {'id': 116, 'name': '🟡 Whitelist: Akamai',       'type': 'whitelist_domain_fronting','priority': 0, 'params': {'endpoint':'akamai'}},
    // ── TIER MIMICRY: Адаптивная мимикрия под реального пользователя ────────
    {'id': 117, 'name': '🎭 Mimicry: Pixel 8 Pro',    'type': 'adaptive_mimicry',     'priority': 0, 'params': {'persona':'pixel8pro'}},
    {'id': 118, 'name': '🎭 Mimicry: iPhone 15 Pro',  'type': 'adaptive_mimicry',     'priority': 0, 'params': {'persona':'iphone15pro'}},
    {'id': 119, 'name': '🎭 Mimicry: Win11 Edge',     'type': 'adaptive_mimicry',     'priority': 0, 'params': {'persona':'win11edge'}},
    {'id': 120, 'name': '🎭 Mimicry: Samsung S24',    'type': 'adaptive_mimicry',     'priority': 0, 'params': {'persona':'samsung_s24'}},
    // ── TIER QUIC/HTTP3: Обход DPI через QUIC (04.04.2026) ──────────────────
    // MTProxy мёртв (01.04.2026) — DPI детектит Fake-TLS по TLS fingerprint
    // QUIC/HTTP3 — DPI ещё не умеет полноценно анализировать QUIC
    // Источник: bypasscore.com/blog/vpn-detection-bypass-dpi-evasion (18.03.2026)
    {'id': 121, 'name': '⚡ QUIC: Google h3',        'type': 'quic_h3_fallback',      'priority': 0, 'params': {'sni':'www.google.com','alpn':'h3'}},
    {'id': 122, 'name': '⚡ QUIC: Cloudflare h3',     'type': 'quic_h3_fallback',      'priority': 0, 'params': {'sni':'cloudflare.com','alpn':'h3'}},
    {'id': 123, 'name': '⚡ QUIC: MS Azure h3',       'type': 'quic_h3_fallback',      'priority': 0, 'params': {'sni':'azure.microsoft.com','alpn':'h3'}},
    {'id': 124, 'name': '⚡ HTTP3: CDN Tunnel',       'type': 'http3_cdn_tunnel',      'priority': 0, 'params': {'cdn':'cloudflare'}},
    {'id': 125, 'name': '⚡ HTTP3: Edge Worker',      'type': 'http3_cdn_tunnel',      'priority': 0, 'params': {'cdn':'workers'}},
    // ── TIER RESIDENTIAL: Residential IP + Smart Timer ───────────────────────
    {'id': 126, 'name': '🏠 Residential: EU IP',      'type': 'residential_ip',        'priority': 0, 'params': {'region':'eu'}},
    {'id': 127, 'name': '🏠 Residential: US IP',      'type': 'residential_ip',        'priority': 0, 'params': {'region':'us'}},
    {'id': 128, 'name': '🏠 Residential: Asia IP',    'type': 'residential_ip',        'priority': 0, 'params': {'region':'asia'}},
  ];

  static final _rng = Random();

  // Тиры стратегий: внутри тира — случайный порядок (равноценны по качеству),
  // между тирами — строгий порядок (сначала лучшие).
  // Ни одна стратегия не ухудшает пинг — меняем только транспорт/порт/SNI.
  static List<Map<String, dynamic>> getStrategiesForBlock(String blockType) {
    // Каждый тир — список ID стратегий одного уровня качества
    // Tier 1: самые надёжные и быстрые (<=443, без лишних hop)
    // Tier N: экзотика и ротация нод (медленнее, но работает)
    final tierMap = <String, List<List<int>>>{
      'tcpReset': [
        [1, 2, 3],              // SNI rotate, WS/443, gRPC gun
        [9, 10, 16, 17, 18],   // Google/Apple/iCloud/Mozilla SNI
        [4, 5, 6, 7, 8],       // CF ports 443/8443/2053/2083/2087
        [41, 42, 66, 67],      // WS 8443, Trojan /api/v1, SNI rotates
        [11, 12, 13, 14],      // CDN Workers + Trojan WS fallback
        [71, 90, 99],          // Node switch
        [15, 68, 69, 100],     // Shadow fallback (last resort)
      ],
      'tlsFingerprint': [
        [1, 9, 10],            // SNI rotate + Google/Microsoft SNI
        [19, 33, 34, 18],      // CF/play.google/ajax.google SNI
        [2, 16, 17, 36],       // WS + iCloud + Telegram CDN SNI
        [37, 38, 39, 40],      // MS login/download/cdnjs/speed.CF SNI
        [11, 12, 15, 66],      // CDN + shadow
        [71, 81, 82, 83],      // CF Workers + node switch
        [90, 100],             // Final
      ],
      'portBlocked': [
        [4, 5, 6, 7, 8],       // CF ports (priority: 443, 8443, 2053, 2083, 2087)
        [43, 44, 45],          // CF 2082/2086/2095
        [21, 22, 23],          // 80/8080/8888
        [56, 57, 58, 59, 60],  // 5443/6443/7443/3443/4443
        [86, 87, 88],          // 1443/10080/20443
        [76, 77, 78],          // 22/53/123 (SSH/DNS/NTP look-alike)
        [71, 90, 99],          // Node switch
      ],
      'dnsPoisoning': [
        [51, 52, 53, 54, 55],  // All DoH providers (CF/Google/Quad9/AdGuard/NextDNS)
        [1, 2],                // SNI rotate + WS (не зависят от DNS)
        [11, 12],              // CDN Workers
        [71, 90],              // Node switch
      ],
      'ipBlocked': [
        [11, 12, 81, 82, 83],  // CF Workers (разные IP edge-серверов)
        [13, 14],              // Trojan WS 443
        [15, 100],             // Shadow fallback
        [71, 90, 99],          // Node switch
      ],
      'timeout': [
        [1, 2],                // SNI rotate + WS
        [4, 5, 6],             // CF ports
        [66, 67],              // Extra SNI rotates
        [11, 12],              // CDN
        [71, 90, 99],          // Node switch
      ],
      'serviceBlocked': [
        [2, 3, 11, 12],        // WS + gRPC + CDN
        [13, 14, 41, 42],      // Trojan WS variants
        [15, 81, 82, 83],      // Shadow + CF Workers
        [71, 90, 100],         // Node switch + final
      ],
      // ── Whitelist / mobile operator block ──────────────────────────────────
      'whitelistBlock': [
        [111, 113, 114],       // Gosuslugi, Cloudflare, AWS (tier 0 gov/CDN)
        [112, 115, 116],       // FNS, Fastly, Akamai
        [117, 118, 119, 120],  // Adaptive mimicry
        [121, 122, 123],       // QUIC/HTTP3 fallback
        [11, 12, 71, 90],      // CDN Workers + node switch
      ],
      // ── AI/ML-DPI detection — adaptive mimicry first ───────────────────────
      'mlDetection': [
        [117, 118, 119, 120],  // Adaptive mimicry (primary defense)
        [121, 122, 123],       // QUIC/HTTP3 (DPI не анализирует QUIC)
        [1, 9, 10],            // SNI rotate
        [111, 112, 113],       // Whitelist domain fronting
        [19, 33, 34],          // CF SNI
        [71, 90, 100],         // Node switch + final
      ],
      // ── QUIC specific — QUIC/HTTP3 стратегии ───────────────────────────────
      'quicBlocked': [
        [121, 122, 123, 124, 125], // All QUIC/HTTP3
        [126, 127, 128],       // Residential IP
        [117, 118, 119],       // Mimicry
        [1, 2, 3],             // SNI rotate
        [11, 12, 71, 90],      // CDN + node switch
      ],
      // ── Residential IP block ───────────────────────────────────────────────
      'residentialDetected': [
        [126, 127, 128],       // All residential regions
        [121, 122, 123],       // QUIC fallback
        [117, 118, 119],       // Mimicry
        [11, 12, 71, 90],      // CDN + node switch
      ],
    };

    final tiers = tierMap[blockType] ?? [List.generate(20, (i) => i + 1)];

    // Внутри каждого тира — shuffle (равноценны, рандом не ухудшает качество)
    // Между тирами — строгий порядок (tier1 всегда раньше tier10)
    final result = <Map<String, dynamic>>[];
    for (final tier in tiers) {
      final tierItems = strategies
          .where((s) => tier.contains(s['id'] as int))
          .toList()
        ..shuffle(_rng);
      result.addAll(tierItems);
    }
    return result;
  }

  // Получить 1 случайную стратегию из Tier1 для мгновенного первого retry
  static Map<String, dynamic>? getQuickRandom(String blockType) {
    final all = getStrategiesForBlock(blockType);
    if (all.isEmpty) return null;
    // Берём из первых 4 (Tier1)
    final pool = all.take(4).toList();
    return pool[_rng.nextInt(pool.length)];
  }
}



class BypassStrategy {
  final int priority;
  final String type;
  final Map<String, dynamic> params;
  const BypassStrategy({required this.priority, required this.type, required this.params});
  factory BypassStrategy.fromJson(Map<String, dynamic> j) => BypassStrategy(
    priority: j['priority'] ?? 99, type: j['type'] ?? '',
    params: Map<String, dynamic>.from(j['params'] ?? {}));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STEALTH ENGINE 3.0  —  Anti-DPI / Anti-JA4+ / Self-Healing
//  Март 2026: провайдер использует AI-анализ TLS fingerprint (JA4+) + DPI глубокий DPI
//  v3.0: race-based SNI, безопасный mux, расширенный SNI пул, защита pbk/sid,
//        гарантированный cleanup warmUp, рандомная фрагментация, IPv6 leak fix
// ═══════════════════════════════════════════════════════════════════════════════
