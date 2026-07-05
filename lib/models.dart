// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

class VpnConfig {
  // Схемы, которые считаем валидной нодой в подписке. Если строка не начинается
  // с одной из них — это не конфиг (HTML/капча/Happ-crypt), пропускаем.
  static const kSupportedSchemes = [
    'vless://', 'vmess://', 'trojan://', 'ss://', 'ssr://',
    'hysteria2://', 'hy2://', 'hysteria://', 'wireguard://',
    'shadowtls://', 'tuic://', 'juicity://', 'naive+https://',
  ];
  static bool isSupportedNodeLink(String l) =>
      kSupportedSchemes.any((p) => l.toLowerCase().startsWith(p));

  // Санитизация имени ноды: убираем управляющие символы и <>, режем длину —
  // чтобы HTML-инъекция из метки подписки (#...) не отображалась как имя.
  static String sanitizeNodeName(String name) {
    var n = name.replaceAll(RegExp(r'[\x00-\x1f<>]'), '').trim();
    if (n.length > 48) n = '${n.substring(0, 48)}…';
    return n;
  }

  String name;
  String customName;
  String link;
  String originalLink; // оригинальный ключ от провайдера (для кнопки "Сбросить")
  String groupName;
  String sourceUrl;
  String ping;
  int    pingMs;
  bool   isPinging  = false;
  bool   isFavourite;
  final  bool isManual;
  bool   isAiPatched;

  VpnConfig({
    required this.name,
    required this.link,
    String?  originalLink,
    this.customName   = '',
    this.groupName    = 'Manual',
    this.sourceUrl    = 'manual',
    this.ping         = '---',
    this.pingMs       = 9999,
    this.isManual     = false,
    this.isAiPatched  = false,
    this.isFavourite  = false,
  }) : originalLink = originalLink ?? link;

  // Сбросить к оригинальному ключу провайдера
  void resetToOriginal() {
    link        = originalLink;
    isAiPatched = false;
  }
  bool get isModified => link != originalLink;

  String get displayName => customName.isNotEmpty ? customName : name;

  Map<String, dynamic> toMap() => {
    'name': name, 'customName': customName, 'link': link,
    'originalLink': originalLink,
    'groupName': groupName, 'sourceUrl': sourceUrl,
    'ping': ping, 'pingMs': pingMs,
    'isManual': isManual, 'isAiPatched': isAiPatched, 'isFavourite': isFavourite,
  };

  factory VpnConfig.fromMap(Map<String, dynamic> m) {
    final link = m['link'] as String? ?? '';
    if (link.isEmpty) throw const FormatException('Empty link');
    final origLink = m['originalLink'] as String? ?? link;
    return VpnConfig(
      name: m['name'] ?? 'Node', customName: m['customName'] ?? '',
      link: link, originalLink: origLink,
      groupName: m['groupName'] ?? 'Manual',
      sourceUrl: m['sourceUrl'] ?? 'manual',
      ping: m['ping'] ?? '---', pingMs: m['pingMs'] ?? 9999,
      isManual: m['isManual'] ?? false, isAiPatched: m['isAiPatched'] ?? false,
      isFavourite: m['isFavourite'] ?? false,
    );
  }

  String get protocol {
    final s = link.toLowerCase();
    if (s.startsWith('vless'))                       return 'VLESS';
    if (s.startsWith('vmess'))                       return 'VMESS';
    if (s.startsWith('trojan'))                      return 'TROJAN';
    if (s.startsWith('ssr'))                         return 'SSR';
    if (s.startsWith('ss://'))                       return 'SS';
    if (s.startsWith('hysteria2') || s.startsWith('hy2')) return 'HY2';
    if (s.startsWith('hysteria'))                    return 'HY';
    if (s.startsWith('wireguard'))                   return 'WG';
    return link.split('://').first.toUpperCase();
  }

  Color get pingColor {
    if (pingMs <= 0 || pingMs >= 9999) return Colors.white30;
    if (pingMs < 150) return Colors.greenAccent;
    if (pingMs < 400) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }

  // ── TCP+TLS Ping: измеряем реальную доступность, не просто TCP ──────────────
  // OPTIMIZED: TCP ping с уменьшенными таймаутами и параллельным TLS
  // OPTIMIZED: TCP ping с уменьшенными таймаутами и параллельным TLS
  // FIX v3.0: TCP ping показывал "живую" ноду которая реально заблокирована по TLS
  // Теперь: быстрый TCP, потом TLS — если TLS падает → 9999 (заблокировано)
  static Future<int> tcpPing(String link) async {
    String host = ''; int port = 443;
    try {
      final raw = link.contains('@')
          ? 'dummy://${link.split('@').last.split('#').first}' : link;
      final uri = Uri.parse(raw);
      host = uri.host; port = uri.port > 0 ? uri.port : 443;
    } catch (_) { return 9999; }
    if (host.isEmpty) return 9999;

    // OPTIMIZATION: TCP + TLS параллельно — TLS timeout меньше
    // Экономим до 3 сек на каждой проверке
    final tcpFuture = () async {
      final sw = Stopwatch()..start();
      try {
        final s = await Socket.connect(host, port,
            timeout: const Duration(milliseconds: 1500)); // было 3000ms
        sw.stop();
        await s.close();
        return sw.elapsedMilliseconds;
      } catch (_) { return 9999; }
    }();

    final tlsFuture = () async {
      try {
        final s = await SecureSocket.connect(
          host, port,
          timeout: const Duration(milliseconds: 2000), // было 3000ms
          onBadCertificate: (_) => true,
        );
        await s.close();
        return true;
      } catch (_) { return false; }
    }();

    final results = await Future.wait([tcpFuture, tlsFuture]);
    final tcpMs = results[0] as int;
    final tlsOk = results[1] as bool;

    return tlsOk ? tcpMs : 9999;
  }
}

// ═══════════════════════════════════════════════════════════════
//  CONNECTION HISTORY  (v4.0)
// ═══════════════════════════════════════════════════════════════

class ConnectionRecord {
  final String serverName;
  final String protocol;
  final DateTime startedAt;
  final Duration duration;
  final int uploadBytes;
  final int downloadBytes;

  ConnectionRecord({
    required this.serverName,
    required this.protocol,
    required this.startedAt,
    required this.duration,
    required this.uploadBytes,
    required this.downloadBytes,
  });

  Map<String, dynamic> toJson() => {
    'serverName':    serverName,
    'protocol':      protocol,
    'startedAt':     startedAt.millisecondsSinceEpoch,
    'durationSec':   duration.inSeconds,
    'uploadBytes':   uploadBytes,
    'downloadBytes': downloadBytes,
  };

  factory ConnectionRecord.fromJson(Map<String, dynamic> j) => ConnectionRecord(
    serverName:    j['serverName']    ?? '',
    protocol:      j['protocol']      ?? '',
    startedAt:     DateTime.fromMillisecondsSinceEpoch(j['startedAt'] ?? 0),
    duration:      Duration(seconds: j['durationSec'] ?? 0),
    uploadBytes:   j['uploadBytes']   ?? 0,
    downloadBytes: j['downloadBytes'] ?? 0,
  );

  String get durationStr {
    final s   = duration.inSeconds;
    final h   = s ~/ 3600;
    final min = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${min.toString().padLeft(2,'0')}m';
    return '${min.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }

  String get trafficStr {
    // ignore: unused_element
    String fmt(int b) {
      if (b > 1024 * 1024 * 1024) return '\${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
      if (b > 1024 * 1024) return '\${(b / 1024 / 1024).toStringAsFixed(1)} MB';
      if (b > 1024) return '\${(b / 1024).toStringAsFixed(0)} KB';
      return '\$b B';
    }
    return '↑\${fmt(uploadBytes)}  ↓\${fmt(downloadBytes)}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  VPN PROVIDER  (v4.0 — история, реальный трафик, уведомления)
// ═══════════════════════════════════════════════════════════════
