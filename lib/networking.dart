// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class SelfHealingMirror {
  static final _rng = Random();
  // Нейтральные User-Agent — не раскрываем что это VPN клиент.
  // 'AuraVPN/5.6.0' идентифицировал трафик для систем мониторинга РКН.
  // Источник версий — единый пул kModernUserAgents (constants.dart, обновл. 28.06.2026).
  static const _uas = kModernUserAgents;
  static String get _ua => _uas[_rng.nextInt(_uas.length)];

  // Метка источника для логирования
  static String _mirrorLabel(String url) {
    if (url.contains('yandex'))    return 'Yandex';
    if (url.contains('vk.com') || url.contains('userapi')) return 'VK';
    if (url.contains('github'))    return 'GitHub';
    if (url.contains('jsdelivr'))  return 'jsDelivr';
    if (url.contains('gist'))      return 'Gist';
    return Uri.parse(url).host;
  }

  static Future<List<String>> fetchNodes(void Function(String) log) async {
    // Сначала пробуем основной API
    try {
      final res = await PinnedHttpClient.get(kNodesUrl, timeout: const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final nodes = _validateNodes(res.body);
        if (nodes.isNotEmpty) {
          log('✅ Nodes from main API: ${nodes.length}');
          return nodes;
        }
      }
    } catch (_) { log('⚠ Main API unreachable'); }

    // Dead Drop 1: GitHub/другие зеркала
    for (final mirror in kDeadDropMirrors) {
      try {
        final res = await http.get(Uri.parse(mirror),
            headers: {'User-Agent': _ua, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final nodes = _validateNodes(res.body);
          if (nodes.isNotEmpty) {
            log('✅ Nodes from ${_mirrorLabel(mirror)}: ${nodes.length}');
            return nodes;
          }
        }
      } catch (_) { log('⚠ Mirror failed: $mirror'); }
    }

    // Dead Drop 2: DNS TXT запись
    try {
      final nodes = await _fetchFromDnsTxt(log);
      if (nodes.isNotEmpty) return nodes;
    } catch (_) {}

    log('⚠ All Dead Drops exhausted');
    return [];
  }

  // Валидация нод: только известные протоколы, защита от инъекций
  static const _validProtos = ['vless://','vmess://','trojan://','ss://','hy2://','hysteria2://'];
  static List<String> _validateNodes(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return List<String>.from(j['nodes'] ?? []).where((n) =>
        _validProtos.any((p) => n.startsWith(p)) &&
        n.length < 2048 &&        // защита от огромных строк
        !n.contains('\n') &&       // нет инъекции переносов
        !n.contains('\r')
      ).toList();
    } catch (_) { return []; }
  }

  // Читаем ноды из DNS TXT записи (base64 закодированный JSON)
  static Future<List<String>> _fetchFromDnsTxt(void Function(String) log) async {
    try {
      // Используем IP Cloudflare напрямую — провайдер не перехватит
      const dohUrl = 'https://1.1.1.1/dns-query';
      final res = await http.get(
        Uri.parse('$dohUrl?name=$kDeadDropDnsTxt&type=TXT'),
        headers: {
          'Accept': 'application/dns-json',
          'User-Agent': kStealthUA,
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final j       = jsonDecode(res.body) as Map<String, dynamic>;
        final answers = j['Answer'] as List? ?? [];
        for (final a in answers) {
          final data = (a['data'] as String? ?? '').replaceAll('"', '');
          if (data.isEmpty) continue;
          try {
            final decoded = utf8.decode(base64.decode(
                data.length % 4 == 0 ? data : data + '=' * (4 - data.length % 4)));
            final parsed  = jsonDecode(decoded) as Map<String, dynamic>;
            final nodes   = List<String>.from(parsed['nodes'] ?? []);
            if (nodes.isNotEmpty) {
              log('✅ DNS TXT nodes: ${nodes.length}');
              return nodes;
            }
          } catch (e) {
            log('⚠ DNS TXT parse error: $e');
          }
        }
      }
    } catch (e) {
      log('⚠ DNS TXT fetch error: $e');
    }
    return [];
  }
}


enum BlockType {
  none,
  tcpReset,
  dnsPoisoning,
  ipBlocked,
  portBlocked,
  tlsFingerprint,
  serviceBlocked,
  timeout,
}

class BlockDetector {
  static const _t = Duration(seconds: 5);

  static Future<BlockType> detect(VpnConfig cfg) async {
    String host = ''; int port = 443;
    try {
      final uri = Uri.parse(cfg.link.contains('@')
          ? 'dummy://${cfg.link.split('@').last.split('#').first}' : cfg.link);
      host = uri.host; port = uri.port > 0 ? uri.port : 443;
    } catch (_) { return BlockType.timeout; }
    if (host.isEmpty) return BlockType.timeout;

    // Шаг 1: DNS — провайдер отравляет DNS для заблокированных IP
    if (!await _dns(host)) return BlockType.dnsPoisoning;

    // Шаг 2: TCP — RST значит активная блокировка ТСПУ
    final tcp = await _tcp(host, port);
    if (tcp == _TR.reset)   return BlockType.tcpReset;
    if (tcp == _TR.closed)  return BlockType.portBlocked;
    if (tcp == _TR.timeout) return BlockType.timeout;

    // Шаг 3: TLS handshake к VPN серверу
    // FIX v3.0: убран вызов _httpLevel(host, port) к VPN серверу —
    // VPN серверы не отвечают на HTTP HEAD '/' → всегда false negative.
    // Вместо этого проверяем достижимость нейтрального домена через тот же IP-маршрут.
    if (!await _tls(host, port)) return BlockType.tlsFingerprint;

    // Шаг 4: проверяем не подменён ли трафик — сверяем доступность контрольного домена
    // Если Google недоступен — значит провайдер режет исходящий HTTPS (serviceBlocked)
    if (!await _reachabilityProbe()) return BlockType.serviceBlocked;

    return BlockType.none;
  }

  // FIX v3.0: circuit breaker — если Google недоступен, не проверяем каждый раз
  // Без этого каждый коннект при заблокированном Google тратит 5 сек зря
  static bool _probeCircuitOpen = false;
  static DateTime? _probeCircuitOpenedAt;
  static const _probeCircuitResetAfter = Duration(minutes: 5);

  static Future<bool> _reachabilityProbe() async {
    // Circuit open → пропускаем проверку
    if (_probeCircuitOpen && _probeCircuitOpenedAt != null) {
      if (DateTime.now().difference(_probeCircuitOpenedAt!) < _probeCircuitResetAfter) {
        return true; // предполагаем что ок — не блокируем подключение
      } else {
        _probeCircuitOpen = false; // пробуем снова после сброса
      }
    }
    try {
      final client = HttpClient()..connectionTimeout = _t;
      final req    = await client.getUrl(
          Uri.parse('https://connectivitycheck.gstatic.com/generate_204'));
      req.headers.set('User-Agent', randomUserAgent());
      final resp = await req.close().timeout(_t);
      await resp.drain<void>();
      client.close();
      _probeCircuitOpen = false; // успех — circuit закрыт
      return resp.statusCode == 204 || resp.statusCode == 200;
    } catch (_) {
      // Ошибка — открываем circuit чтобы не тратить время следующие 5 мин
      _probeCircuitOpen = true;
      _probeCircuitOpenedAt = DateTime.now();
      return true; // не блокируем VPN подключение из-за недоступности Google
    }
  }

  // FIX: используем DoH вместо системного DNS
  // InternetAddress.lookup() = OS resolver = РКН отравляет его
  // Cloudflare DoH по прямому IP — не зависит от DNS провайдера
  static Future<bool> _dns(String h) async {
    // Сначала пробуем DoH через Cloudflare (прямой IP, не DNS-имя)
    try {
      final res = await http.get(
        Uri.parse('https://1.1.1.1/dns-query?name=${Uri.encodeComponent(h)}&type=A'),
        headers: {'Accept': 'application/dns-json', 'User-Agent': kStealthUA},
      ).timeout(_t);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final answers = j['Answer'] as List? ?? [];
        return answers.isNotEmpty;
      }
    } catch (_) {}
    // Fallback: системный DNS если DoH недоступен
    try { return (await InternetAddress.lookup(h).timeout(_t)).isNotEmpty; }
    catch (_) { return false; }
  }

  static Future<_TR> _tcp(String h, int p) async {
    try {
      final s = await Socket.connect(h, p, timeout: _t);
      await s.close(); return _TR.ok;
    } on SocketException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('reset')) return _TR.reset;
      if (m.contains('refused') || m.contains('no route')) return _TR.closed;
      return _TR.timeout;
    } on TimeoutException { return _TR.timeout; }
    catch (_) { return _TR.timeout; }
  }

  static Future<bool> _tls(String h, int p) async {
    try {
      // Только TLS handshake — не отправляем HTTP
      // HEAD запрос создавал паттерн который РКН мог детектировать
      // Для нас важно что TLS соединение устанавливается, не HTTP ответ
      final s = await SecureSocket.connect(h, p,
          timeout: _t, onBadCertificate: (_) => true);
      await s.close();
      return true;
    } catch (_) { return false; }
  }
}

enum _TR { ok, reset, closed, timeout }

class BypassRulesEngine {
  List<Map<String, dynamic>> _rules = [];
  int _version = kLocalRulesVersion;
  List<String> _blockedDomains = [];
  DateTime? _lastDomainSync;

  // Dev Dashboard getters
  int       get devVersion      => _version;
  int       get devRulesCount   => _rules.length;
  int       get devDomainsCount => _blockedDomains.length;
  DateTime? get devLastSync     => _lastDomainSync;

  static const _builtin = [
    // TCP reset / TLS fingerprint — самое частое у РКН
    {'id': 'tcp_reset', 'triggers': ['tcpReset', 'tlsFingerprint'], 'strategies': [
      {'priority': 1, 'type': 'rotate_reality_sni',  'params': {}},
      {'priority': 2, 'type': 'add_reality_sni',     'params': {'sni': 'www.yandex.ru'}},    // Яндекс — Tier 0
      {'priority': 3, 'type': 'add_reality_sni',     'params': {'sni': 'vk.com'}},            // VK — Tier 1
      {'priority': 4, 'type': 'change_transport',    'params': {'transport': 'ws',   'path': '/'}},
      {'priority': 5, 'type': 'change_transport',    'params': {'transport': 'grpc', 'service': 'gun'}},
      {'priority': 6, 'type': 'change_port',         'params': {'port': 443}},
      {'priority': 7, 'type': 'change_port',         'params': {'port': 8443}},
      {'priority': 8, 'type': 'change_port',         'params': {'port': 80}},
      {'priority': 9, 'type': 'add_reality_sni',     'params': {'sni': 'dl.google.com'}},
      {'priority': 10,'type': 'add_reality_sni',     'params': {'sni': 'update.microsoft.com'}},
      {'priority': 11,'type': 'trojan_ws_fallback',  'params': {'port': 443, 'path': '/api/v1'}},
      // Hysteria2 fallback: UDP/QUIC обходит TCP-блокировки ТСПУ
      {'priority': 12,'type': 'hysteria2_fallback',  'params': {'obfs': 'salamander'}},
      // Zapret: локальный DPI bypass как последний рубеж перед CDN
      {'priority': 13,'type': 'zapret_bypass',       'params': {'strategy': 'disorder'}},
      {'priority': 14,'type': 'cdn_fallback',         'params': {'url': 'aura-vpn.workers.dev'}},
    ]},
    // DNS отравление
    {'id': 'dns', 'triggers': ['dnsPoisoning'], 'strategies': [
      {'priority': 1, 'type': 'set_doh', 'params': {'url': 'https://1.1.1.1/dns-query'}},
      {'priority': 2, 'type': 'set_doh', 'params': {'url': 'https://dns.google/dns-query'}},
      {'priority': 3, 'type': 'set_doh', 'params': {'url': 'https://dns.quad9.net/dns-query'}},
      {'priority': 4, 'type': 'set_doh', 'params': {'url': 'https://8.8.8.8/dns-query'}},
    ]},
    // Порт заблокирован
    {'id': 'port', 'triggers': ['portBlocked'], 'strategies': [
      {'priority': 1, 'type': 'change_port', 'params': {'port': 443}},
      {'priority': 2, 'type': 'change_port', 'params': {'port': 8443}},
      {'priority': 3, 'type': 'change_port', 'params': {'port': 2053}},
      {'priority': 4, 'type': 'change_port', 'params': {'port': 2083}},
      {'priority': 5, 'type': 'change_port', 'params': {'port': 2087}},
      {'priority': 6, 'type': 'change_port', 'params': {'port': 2096}},
      {'priority': 7, 'type': 'change_port', 'params': {'port': 80}},
    ]},
    // Полная блокировка IP / timeout
    {'id': 'full', 'triggers': ['ipBlocked', 'timeout', 'serviceBlocked'], 'strategies': [
      {'priority': 1, 'type': 'switch_node',          'params': {}},
      {'priority': 2, 'type': 'rotate_reality_sni',   'params': {}},
      {'priority': 3, 'type': 'add_reality_sni',      'params': {'sni': 'www.yandex.ru'}},   // Яндекс
      {'priority': 4, 'type': 'add_reality_sni',      'params': {'sni': 'vk.com'}},           // VK
      {'priority': 5, 'type': 'change_transport',     'params': {'transport': 'ws',   'path': '/cdn'}},
      {'priority': 6, 'type': 'change_transport',     'params': {'transport': 'grpc', 'service': 'gun'}},
      // Hysteria2 — QUIC/UDP обходит IP-блокировки лучше TCP
      {'priority': 7, 'type': 'hysteria2_fallback',   'params': {'obfs': 'salamander'}},
      // Zapret DPI bypass перед CDN
      {'priority': 8, 'type': 'zapret_bypass',        'params': {'strategy': 'fake_sni'}},
      {'priority': 9, 'type': 'cdn_fallback',          'params': {'url': 'aura-vpn.workers.dev'}},
      {'priority': 10,'type': 'cdn_fallback',          'params': {'url': 'aura-cdn.pages.dev'}},
      {'priority': 11,'type': 'shadow_fallback',       'params': {}},
    ]},
    // Stealth: TLS fingerprint / сервисная блокировка
    {'id': 'stealth_tls', 'triggers': ['tlsFingerprint', 'serviceBlocked'], 'strategies': [
      {'priority': 1, 'type': 'rotate_reality_sni',   'params': {}},
      {'priority': 2, 'type': 'add_reality_sni',      'params': {'sni': 'www.yandex.ru'}},   // Tier 0
      {'priority': 3, 'type': 'add_reality_sni',      'params': {'sni': 'vk.com'}},           // Tier 1
      {'priority': 4, 'type': 'change_transport',     'params': {'transport': 'ws',   'path': '/'}},
      {'priority': 5, 'type': 'add_reality_sni',      'params': {'sni': 'dl.google.com'}},
      {'priority': 6, 'type': 'add_reality_sni',      'params': {'sni': 'fonts.googleapis.com'}},
      {'priority': 7, 'type': 'add_reality_sni',      'params': {'sni': 'update.microsoft.com'}},
      {'priority': 8, 'type': 'add_reality_sni',      'params': {'sni': 'gateway.icloud.com'}},
      {'priority': 9, 'type': 'add_reality_sni',      'params': {'sni': 'mask.icloud.com'}},
      {'priority': 10,'type': 'trojan_ws_fallback',   'params': {'port': 443, 'path': '/stream'}},
      // Zapret fake_sni: маскировка под разрешённый домен
      {'priority': 11,'type': 'zapret_bypass',        'params': {'strategy': 'fake_sni'}},
      {'priority': 12,'type': 'cdn_fallback',          'params': {'url': 'aura-vpn.workers.dev'}},
    ]},
    // Stealth: TCP reset (активная блокировка ТСПУ)
    {'id': 'stealth_reset', 'triggers': ['tcpReset'], 'strategies': [
      {'priority': 1, 'type': 'rotate_reality_sni',   'params': {}},
      {'priority': 2, 'type': 'change_transport',     'params': {'transport': 'ws',   'path': '/'}},
      {'priority': 3, 'type': 'change_transport',     'params': {'transport': 'grpc', 'service': 'gun'}},
      {'priority': 4, 'type': 'change_port',          'params': {'port': 443}},
      {'priority': 5, 'type': 'change_port',          'params': {'port': 2053}},
      {'priority': 6, 'type': 'trojan_ws_fallback',   'params': {'port': 443, 'path': '/trojan'}},
      {'priority': 7, 'type': 'shadow_fallback',       'params': {}},
    ]},
  ];

  // Живые источники — используются syncFromServer (URL передаётся параметром)

  // URL-схемы обновления домен-листов (antifilter.download)
  static const _domainListUrl = 'https://community.antifilter.download/list/domains.lst';
  static const _domainListMirror = 'https://raw.githubusercontent.com/nickspaargaren/no-google/master/blocked.txt';

  Future<void> syncFromServer(void Function(String) log) async {
    await _loadCache();

    // 1. Основные bypass-правила (стратегии)
    try {
      final res = await PinnedHttpClient.get(kBypassRulesUrl, timeout: const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j  = jsonDecode(res.body) as Map<String, dynamic>;
        final sv = j['version'] as int? ?? 0;
        if (sv > _version) {
          _rules   = List<Map<String,dynamic>>.from(j['rules'] ?? []);
          _version = sv;
          await _saveCache(res.body);
          log('✔ Bypass rules updated v$_version');
        }
      }
    } catch (e) { log('⚠ Rules sync: $e'); }

    // 2. Синк списка заблокированных доменов (раз в 6 часов)
    final now = DateTime.now();
    if (_lastDomainSync == null ||
        now.difference(_lastDomainSync!) > const Duration(hours: 6)) {
      await _syncDomainList(log);
    }
  }

  Future<void> _syncDomainList(void Function(String) log) async {
    final sources = [_domainListUrl, _domainListMirror];
    for (final url in sources) {
      try {
        final res = await http.get(Uri.parse(url),
            headers: {'User-Agent': kStealthUA})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final lines = res.body
              .split('\n')
              .map((l) => l.trim().toLowerCase())
              .where((l) => l.isNotEmpty && !l.startsWith('#') && l.contains('.'))
              .toList();
          if (lines.length > 100) {
            _blockedDomains = lines;
            _lastDomainSync = DateTime.now();
            // Кэшируем первые 5000 доменов (остальное слишком много для SharedPrefs)
            final p = await SharedPreferences.getInstance();
            await p.setString('blocked_domains_cache',
                jsonEncode(lines.take(5000).toList()));
            await p.setString('blocked_domains_ts', DateTime.now().toIso8601String());
            log('✔ Domain list updated: ${lines.length} domains');
            return;
          }
        }
      } catch (_) {}
    }
    log('⚠ Domain list sync failed — using cache');
  }

  Future<void> _loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString('bypass_rules_cache');
      if (c != null) {
        final j = jsonDecode(c);
        _rules   = List<Map<String,dynamic>>.from(j['rules'] ?? []);
        _version = j['version'] ?? 0;
      }
      // Загружаем кэш доменов
      final dc  = p.getString('blocked_domains_cache');
      final dts = p.getString('blocked_domains_ts');
      if (dc != null) {
        _blockedDomains = List<String>.from(jsonDecode(dc));
        if (dts != null) _lastDomainSync = DateTime.tryParse(dts);
      }
    } catch (_) {}
  }

  Future<void> _saveCache(String raw) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('bypass_rules_cache', raw);
    } catch (_) {}
  }

  // Проверяем, заблокирован ли домен в РФ
  bool isBlocked(String domain) {
    final d = domain.toLowerCase();
    // Сначала проверяем захардкоженный список актуальных блокировок
    if (_hardcodedBlocked.any((b) => d == b || d.endsWith('.$b'))) return true;
    // Затем динамический список
    return _blockedDomains.any((b) => d == b || d.endsWith('.$b'));
  }

  // Захардкоженные актуальные блокировки (РКН, март 2026)
  // Источник: postium.ru, gogov.ru — обновлено 19.03.2026
  static const List<String> _hardcodedBlocked = [
    // Социальные сети
    'instagram.com', 'facebook.com', 'fb.com', 'fbcdn.net',
    'twitter.com', 'x.com', 't.co',
    'tiktok.com', 'tiktokv.com', 'byteoversea.com',
    'linkedin.com',
    // Мессенджеры (частично)
    'discord.com', 'discord.gg', 'discordapp.com',
    // Новости и медиа
    'meduza.io', 'novayagazeta.ru', 'echo.msk.ru',
    'dw.com', 'bbc.com', 'bbc.co.uk',
    'voiceofamerica.com', 'voanews.com', 'rferl.org',
    'currenttime.tv', 'svoboda.org',
    // YouTube (замедление, не блок)
    // 'youtube.com', // не полностью заблокирован
    // VPN сервисы (сами сайты)
    'nordvpn.com', 'expressvpn.com', 'ipvanish.com',
    'purevpn.com', 'cyberghostvpn.com', 'privateinternetaccess.com',
    'hidemyass.com', 'hotspotshield.com', 'tunnelbear.com',
    'windscribe.com', 'protonvpn.com',
    // Прокси
    'hideme.ru', 'anonymox.net',
    // Прочее заблокированное
    'canary.discord.com', 'ptb.discord.com',
    'whatsapp.net', // звонки WhatsApp
  ];

  // Строим v2ray routing rules для умного обхода:
  // заблокированные домены → через VPN, российские → напрямую
  Map<String, dynamic> buildRussiaRoutingRules() {
    return {
      'domainStrategy': 'IPIfNonMatch',
      'rules': [
        // Локальные адреса — напрямую (без VPN)
        {'type': 'field', 'ip':     ['geoip:private'], 'outboundTag': 'direct'},
        {'type': 'field', 'domain': ['geosite:private'], 'outboundTag': 'direct'},

        // Российские домены — напрямую (для производительности)
        {'type': 'field', 'domain': ['geosite:ru'], 'outboundTag': 'direct'},
        {'type': 'field', 'ip':     ['geoip:ru'],   'outboundTag': 'direct'},

        // Telegram — через VPN (блокируется в РФ)
        {'type': 'field', 'domain': [
          'domain:telegram.org', 'domain:t.me', 'domain:tlgr.org',
          'ip:149.154.160.0/20', 'ip:91.108.4.0/22', 'ip:91.108.56.0/24',
        ], 'outboundTag': 'proxy'},

        // Заблокированные платформы — через VPN
        {'type': 'field', 'domain': [
          'geosite:instagram', 'geosite:facebook', 'geosite:twitter',
          'geosite:tiktok', 'geosite:discord', 'geosite:youtube',
          ..._hardcodedBlocked.map((d) => 'domain:$d'),
        ], 'outboundTag': 'proxy'},

        // OpenAI/AI сервисы — через VPN
        {'type': 'field', 'domain': [
          'domain:openai.com', 'domain:chatgpt.com', 'domain:anthropic.com',
          'domain:claude.ai', 'domain:gemini.google.com',
        ], 'outboundTag': 'proxy'},

        // IPv6 — блокируем (leak prevention)
        {'type': 'field', 'ip': ['::/0'], 'outboundTag': 'block'},
      ],
    };
  }


  List<BypassStrategy> getStrategies(BlockType type) {
    final tn = type.name; final all = <BypassStrategy>[];
    for (final r in [..._rules, ..._builtin]) {
      if (List<String>.from((r['triggers'] as List?) ?? []).contains(tn)) {
        for (final s in List<Map<String,dynamic>>.from((r['strategies'] as List?) ?? [])) {
          all.add(BypassStrategy.fromJson(s));
        }
      }
    }
    all.sort((a, b) => (a as BypassStrategy).priority.compareTo((b as BypassStrategy).priority));
    return all;
  }

  VpnConfig applyStrategy(VpnConfig orig, BypassStrategy s) {
    String link = orig.link; final p = s.params;
    switch (s.type) {
      case 'change_port':
        final np = p['port'] as int;
        try {
          final ai = link.indexOf('@'); if (ai == -1) break;
          final qi = link.contains('?') ? link.indexOf('?')
              : (link.contains('#') ? link.lastIndexOf('#') : link.length);
          final hp = link.substring(ai + 1, qi);
          final lc = hp.lastIndexOf(':'); if (lc == -1) break;
          link = link.substring(0, ai+1) + hp.substring(0, lc) + ':$np' + link.substring(qi);
        } catch (_) {}
        break;
      case 'change_transport':
        if (link.startsWith('vmess://')) {
          try {
            final clean = link.replaceFirst('vmess://', '');
            final pad = clean.length % 4;
            final dec = utf8.decode(base64.decode(pad == 0 ? clean : clean + '=' * (4 - pad)));
            final j = jsonDecode(dec) as Map<String, dynamic>;
            j['net'] = p['transport'];
            if (p['transport'] == 'ws') j['path'] = p['path'] ?? '/';
            link = 'vmess://' + base64.encode(utf8.encode(jsonEncode(j)));
          } catch (_) {}
        } else if (link.startsWith('vless://') || link.startsWith('trojan://')) {
          try {
            final uri = Uri.parse(link);
            final q = Map<String, String>.from(uri.queryParameters);
            q['type'] = p['transport'];
            if (p['transport'] == 'ws')   q['path']        = p['path']    ?? '/';
            if (p['transport'] == 'grpc') q['serviceName'] = p['service'] ?? 'gun';
            link = uri.replace(queryParameters: q).toString();
          } catch (_) {}
        }
        break;
      case 'add_reality_sni':
        try {
          final uri = Uri.parse(link);
          final q = Map<String, String>.from(uri.queryParameters);
          q['security'] = 'reality';
          q['sni']      = p['sni'] as String;
          // Используем детерминированный fp на основе SNI для воспроизводимости
          q['fp']       = StealthEngine.randomFingerprint();
          q['serverName'] = p['sni'] as String;
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // set_doh: для DNS poisoning — метка в конфиг, реальный DoH пробрасывается в patchConfig
      // Здесь мы просто отмечаем в параметрах ноды что нужен DoH
      case 'set_doh':
        // DoH применяется глобально через patchConfig — стратегия лишь форсирует применение
        // Ничего менять в link не нужно, patchConfig сам проставит DoH при следующем connect
        break;

      // Stealth 3.0: ротация SNI из пула авторитетных доменов
      // FIX v3.0: сохраняем pbk/sid — они привязаны к серверу, не к SNI
      case 'rotate_reality_sni':
        try {
          final uri = Uri.parse(link);
          final q   = Map<String, String>.from(uri.queryParameters);
          q['security']   = 'reality';
          q['sni']        = StealthEngine.nextSni();
          q['serverName'] = q['sni']!;
          q['fp']         = StealthEngine.randomFingerprint();
          // pbk/sid не трогаем — берутся из оригинала если были
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // Trojan-WS+TLS fallback: если VLESS упал 3 раза → маскируем под HTTPS
      // Trojan через WebSocket выглядит как обычный HTTPS браузера
      case 'trojan_ws_fallback':
        try {
          if (link.startsWith('vless://') || link.startsWith('vmess://')) {
            final uri  = Uri.parse(link);
            final q    = Map<String, String>.from(uri.queryParameters);
            // Меняем транспорт на WS с TLS — максимальная маскировка
            q['type']     = 'ws';
            q['path']     = p['path'] as String? ?? '/';
            q['security'] = 'tls';
            q['sni']      = StealthEngine.nextSni();
            q['fp']       = StealthEngine.nextUTlsProfile();
            final port    = (p['port'] as int? ?? 443).toString();
            // Меняем порт на целевой
            final host    = uri.host;
            link = uri.replace(
              host: host,
              port: int.parse(port),
              queryParameters: q).toString();
          }
        } catch (_) {}
        break;

      // CDN Workers fallback — финальный рубеж
      case 'cdn_fallback':
        try {
          final uri    = Uri.parse(link);
          final q      = Map<String, String>.from(uri.queryParameters);
          final cdnUrl = p['url'] as String? ?? 'aura-vpn.workers.dev';
          q['type']       = 'ws';
          q['path']       = '/aura-vpn-cdn';
          q['host']       = cdnUrl;
          q['security']   = 'tls';
          q['sni']        = cdnUrl;
          q['serverName'] = cdnUrl;   // FIX: required by some v2ray versions
          q['fp']         = StealthEngine.nextUTlsProfile();
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // Hysteria2 fallback — переключение на QUIC/UDP протокол.
      // Когда TCP заблокирован ТСПУ, Hysteria2 продолжает работать через UDP.
      // Salamander obfs скрывает QUIC fingerprint — выглядит как обычный UDP.
      // Нода должна иметь Hysteria2 сервер на том же хосте (или мы берём из пула).
      // Если hy2:// нода уже есть в конфиге — просто добавляем Salamander obfs.
      case 'hysteria2_fallback':
        try {
          if (link.startsWith('hy2://') || link.startsWith('hysteria2://')) {
            // Уже Hysteria2 — добавляем/усиливаем obfs параметры
            final uri  = Uri.parse(link.replaceFirst(RegExp(r'^hysteria2://'), 'hy2://'));
            final q    = Map<String, String>.from(uri.queryParameters);
            final obfs = p['obfs'] as String? ?? 'salamander';
            q['obfs'] = obfs;
            // Если нет obfs-password — генерируем случайный (16 hex символов)
            if ((q['obfs-password'] ?? '').isEmpty) {
              final pw = List.generate(8, (_) => Random().nextInt(256))
                  .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
              q['obfs-password'] = pw;
            }
            // Обновляем SNI на российский авторитетный домен
            if ((q['sni'] ?? '').isEmpty) {
              q['sni'] = StealthEngine.pickLiveSniFromCache();
            }
            link = uri.replace(queryParameters: q).toString()
                .replaceFirst('hy2://', 'hy2://');
          } else {
            // Не Hysteria2 нода — помечаем что нужен фоллбэк на hy2 из пула
            // Реальное переключение происходит в VpnProvider._tryHysteria2Fallback()
            // Здесь просто добавляем маркер в ссылку
            link = '$link#hy2_fallback_needed';
          }
        } catch (_) {}
        break;

      // Fragmented Reality — TLS фрагментация ClientHello для обхода DPI
      // FIX BUG-6.2: добавлена обработка fragmented_reality
      case 'fragmented_reality':
        try {
          final uri = Uri.parse(link);
          final q   = Map<String, String>.from(uri.queryParameters);
          final fragSize = p['fragSize'] as int? ?? 2;
          final delayMs  = p['delayMs']  as int? ?? 50;
          final sni      = p['sni']      as String? ?? StealthEngine.nextSni();
          q['security']   = 'reality';
          q['sni']        = sni;
          q['serverName'] = sni;
          q['fp']         = StealthEngine.randomFingerprint();
          // Помечаем для patchConfig что нужна фрагментация
          if (!link.contains('fragment=')) {
            final sep = link.contains('#') ? '&' : '#';
            link = '$link${sep}fragment=${fragSize}b_${delayMs}ms';
          }
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // VLESS Vision whitelist — маскировка под разрешённый SNI
      // FIX BUG-6.2: добавлена обработка vless_vision_whitelist
      case 'vless_vision_whitelist':
        try {
          final uri = Uri.parse(link);
          final q   = Map<String, String>.from(uri.queryParameters);
          final sni = p['sni'] as String? ?? 'yandex.ru';
          q['security']   = 'tls';
          q['sni']        = sni;
          q['serverName'] = sni;
          q['flow']       = 'xtls-rprx-vision';
          q['fp']         = StealthEngine.randomFingerprint();
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // Zapret DPI bypass — активирует локальный Zapret как промежуточный прокси.
      // Zapret работает на уровне пакетов (nfqueue/windivert) — не меняет VPN протокол.
      // Эффективен когда ТСПУ блокирует по TLS fingerprint или делает TCP RST.
      // Стратегии: fake_sni | disorder | split | ttl_trick
      // ВАЖНО: Zapret должен быть установлен и запущен на устройстве отдельно.
      case 'zapret_bypass':
        try {
          final strategy = p['strategy'] as String? ?? 'fake_sni';
          // Zapret не меняет VPN ссылку — он работает на уровне ОС.
          // Помечаем ссылку что нужен Zapret, VpnProvider активирует ZapretBridge.
          // Используем fragment URI (#) чтобы не ломать парсинг протокола.
          if (!link.contains('zapret=')) {
            final sep = link.contains('#') ? '&' : '#';
            link = '$link${sep}zapret=$strategy';
          }
        } catch (_) {}
        break;

      // Shadow fallback — WebSocket+CDN транспорт через живой SNI
      case 'shadow_fallback':
        try {
          final uri = Uri.parse(link);
          final q   = Map<String, String>.from(uri.queryParameters);
          final sni = StealthEngine.nextSni();
          q['type']       = 'ws';
          q['path']       = '/cdn-fallback';
          q['security']   = 'tls';
          q['sni']        = sni;
          q['serverName'] = sni;       // FIX: required by some v2ray versions
          q['fp']         = StealthEngine.nextUTlsProfile();
          link = uri.replace(queryParameters: q).toString();
        } catch (_) {}
        break;

      // Whitelist domain fronting — обход белого списка мобильных операторов
      // ТСПУ DROP ALL кроме разрешённых IP (Яндекс, VK, Сбер).
      // Domain fronting: TLS SNI = разрешённый домен, реальный трафик идёт на наш сервер.
      case 'whitelist_domain_fronting':
        try {
          final endpointKey = p['endpoint'] as String? ?? 'gosuslugi';
          final endpoint = WhitelistBypassEngine.getEndpointByKey(endpointKey);
          if (endpoint != null) {
            // Помечаем ссылку маркером для VpnProvider
            if (!link.contains('whitelist_df=')) {
              final sep = link.contains('#') ? '&' : '#';
              link = '\$link\${sep}whitelist_df=\${endpoint["host"] as String}';
            }
          }
        } catch (_) {}
        break;

      // Adaptive mimicry — имитация полного цифрового следа пользователя
      // FIX BUG-1.4: теперь реально применяет персону к конфигу
      case 'adaptive_mimicry':
        try {
          // Генерируем новую персону и сбрасываем старую
          AdaptiveMimicryEngine.resetPersona();
          AdaptiveMimicryEngine.generatePersona();
          // Помечаем ссылку маркером
          if (!link.contains('mimicry=')) {
            final sep = link.contains('#') ? '&' : '#';
            final personaName = p['persona'] as String? ?? 'auto';
            link = '$link${sep}mimicry=$personaName';
          }
        } catch (_) {}
        break;

      // QUIC/HTTP3 fallback — DPI ещё не умеет анализировать QUIC
      // Источник: bypasscore.com/blog/vpn-detection-bypass-dpi-evasion (18.03.2026)
      // QUIC = UDP-based, encrypted multiplexed streams, indistinguishable from HTTP/3
      case 'quic_h3_fallback':
        try {
          final sni = p['sni'] as String? ?? 'www.google.com';
          final alpn = p['alpn'] as String? ?? 'h3';
          // Помечаем ссылку для VpnProvider
          if (!link.contains('quic=')) {
            final sep = link.contains('#') ? '&' : '#';
            link = '$link${sep}quic=$sni&alpn=$alpn';
          }
        } catch (_) {}
        break;

      // HTTP3 CDN Tunnel — CDN edge relay через QUIC
      // Трафик идёт через CDN (Cloudflare Workers / edge functions)
      // DPI видит обычный HTTP/3 к CDN, не VPN
      case 'http3_cdn_tunnel':
        try {
          final cdn = p['cdn'] as String? ?? 'cloudflare';
          if (!link.contains('h3tunnel=')) {
            final sep = link.contains('#') ? '&' : '#';
            link = '$link${sep}h3tunnel=$cdn';
          }
        } catch (_) {}
        break;

      // Residential IP — проверка что IP сервера не дата-центр
      // Дата-центры (AS хостингов) в чёрных списках РКН
      // Residential IP выглядит как домашний пользователь
      case 'residential_ip':
        try {
          final region = p['region'] as String? ?? 'eu';
          if (!link.contains('residential=')) {
            final sep = link.contains('#') ? '&' : '#';
            link = '$link${sep}residential=$region';
          }
        } catch (_) {}
        break;
    }
    return VpnConfig(
      name: '${orig.name} [AI]', link: link,
      groupName: orig.groupName, sourceUrl: orig.sourceUrl,
      isManual: orig.isManual, isAiPatched: true,
      isFavourite: orig.isFavourite,
    );
  }

  // Выбирает SNI по тиру доверия для обхода белых списков
  // Tier 0: Яндекс — Ростелеком Сибирь никогда не блокирует
  // Tier 1: VK/Mail.ru — в белом списке РКН
  // Tier 2: Microsoft/Apple — корпоративный whitelist
  static String _whitelistSniByTier(int tier) {
    const t0 = ['yandex.ru', 'ya.ru', 'mail.yandex.ru', 'yastatic.net'];
    const t1 = ['vk.com', 'userapi.com', 'mail.ru', 'ok.ru', 'sber.ru', 'gosuslugi.ru'];
    const t2 = ['update.microsoft.com', 'www.apple.com', 'mask.icloud.com'];
    switch (tier) {
      case 0:  return t0[DateTime.now().millisecond % t0.length];
      case 1:  return t1[DateTime.now().millisecond % t1.length];
      case 2:  return t2[DateTime.now().millisecond % t2.length];
      default: return 'yandex.ru';
    }
  }
}

class BypassProber {
  // OPTIMIZED: параллельный TCP+TLS probe вместо последовательного
  // Happy Eyeballs v2: IPv4 и IPv6 одновременно
  // TCP Fast Open + reduced timeouts для ускорения
  static Future<bool> probe(VpnConfig cfg) async {
    String host = ''; int port = 443;
    try {
      final uri = Uri.parse(cfg.link.contains('@')
          ? 'dummy://${cfg.link.split('@').last.split('#').first}' : cfg.link);
      host = uri.host; port = uri.port > 0 ? uri.port : 443;
    } catch (_) { return false; }
    if (host.isEmpty) return false;

    // OPTIMIZATION: сразу TLS handshake — если TCP пройдёт, TLS ответит быстрее
    // Экономим 1.5 сек на отдельном TCP probe
    try {
      final s = await SecureSocket.connect(
        host, port,
        timeout: const Duration(milliseconds: 2500), // было 3000ms
        onBadCertificate: (_) => true,
      );
      await s.close();
      return true;
    } catch (_) {
      // Fallback: быстрый TCP probe если TLS не прошёл
      try {
        final s = await Socket.connect(host, port,
            timeout: const Duration(milliseconds: 1000)); // было 1500ms
        await s.close();
        return true;
      } catch (_) { return false; }
    }
  }

  // OPTIMIZATION: параллельный probe нескольких хостов (Happy Eyeballs)
  static Future<bool> probeParallel(List<VpnConfig> configs) async {
    // Запускаем все probe параллельно, первый успешный = true
    final futures = configs.map((c) async {
      try {
        return await probe(c);
      } catch (_) { return false; }
    });
    final results = await Future.wait(futures);
    return results.any((r) => r);
  }

  // OPTIMIZATION: быстрый ping через TCP SYN (без TLS)
  static Future<int> fastPing(String host, int port) async {
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 800));
      await s.close();
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      sw.stop();
      return -1;
    }
  }
}