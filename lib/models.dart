// ignore_for_file: unused_import, unused_element
part of 'main.dart';

class VpnConfig {
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

    // Шаг 1: TCP latency (быстро)
    int tcpMs = 9999;
    try {
      final sw = Stopwatch()..start();
      final s  = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      sw.stop(); tcpMs = sw.elapsedMilliseconds;
      await s.close();
    } catch (_) { return 9999; }

    // Шаг 2: TLS handshake — если РКН режет на TLS уровне, TCP проходит а TLS нет
    try {
      final s = await SecureSocket.connect(
        host, port,
        timeout: const Duration(seconds: 3),
        onBadCertificate: (_) => true,
      );
      await s.close();
      return tcpMs; // TLS прошёл — нода реально живая
    } catch (_) {
      return 9999; // TLS упал — нода заблокирована по fingerprint
    }
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

