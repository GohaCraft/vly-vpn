// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unused_local_variable, dead_code, avoid_print, unused_field, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, always_use_package_imports
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PER-APP / PER-SERVICE BYPASS  (июнь 2026)
//
//  «В каком ты приложении» на xray определяется по ДОМЕНАМ/IP назначения:
//  YouTube → googlevideo.com, Telegram → 149.154.x, TikTok → byteoversea.com.
//  Для каждого сервиса — свой профиль обхода (транспорт/фрагментация/SNI).
//
//  ВАЖНО про форки: AyuGram, ExtraGram, Nicegram, Swiftgram, Telegram X — это
//  клиенты Telegram, они ходят на ТЕ ЖЕ серверы Telegram (DC), поэтому
//  покрываются доменами/IP профиля telegram автоматически — отдельных правил
//  не нужно.
//
//  Статус (июнь 2026): YouTube и WhatsApp заблокированы полностью (11.02.2026),
//  Telegram душат (возможен полный бан), TikTok/Instagram/Twitter — заблокированы.
// ═══════════════════════════════════════════════════════════════════════════

class ServiceBypassProfile {
  final String        id;
  final String        name;
  final IconData      icon;
  final List<String>  domains;   // домены сервиса (+ поддомены)
  final List<String>  ips;       // CIDR диапазоны (нужно для Telegram)
  final String        strategy;  // рекомендуемый тип обхода (тюнинг/ИИ)
  final String        note;

  const ServiceBypassProfile({
    required this.id,
    required this.name,
    required this.icon,
    required this.domains,
    this.ips      = const [],
    required this.strategy,
    this.note     = '',
  });
}

class ServiceBypassProfiles {
  // Telegram + все форки (один профиль — серверы общие)
  static const telegram = ServiceBypassProfile(
    id: 'telegram', name: 'Telegram', icon: Icons.send_rounded,
    domains: [
      'telegram.org', 't.me', 'telegram.me', 'telegra.ph', 'telesco.pe',
      'tdesktop.com', 'cdn-telegram.org', 'comments.app', 'contest.com',
    ],
    ips: [
      '149.154.160.0/20', '91.108.4.0/22', '91.108.8.0/22', '91.108.12.0/22',
      '91.108.16.0/22', '91.108.56.0/22', '95.161.64.0/20',
      '2001:b28:f23d::/48', '2001:67c:4e8::/48', '2001:b28:f23f::/48',
    ],
    strategy: 'reality_fragment',
    note: 'Форки AyuGram/ExtraGram/Nicegram/Swiftgram/Telegram X — те же серверы, покрыты.');

  static const youtube = ServiceBypassProfile(
    id: 'youtube', name: 'YouTube', icon: Icons.play_circle_fill_rounded,
    domains: [
      'youtube.com', 'youtu.be', 'youtubei.googleapis.com', 'youtube-nocookie.com',
      'googlevideo.com', 'ytimg.com', 'yt3.ggpht.com', 'ggpht.com', 'i.ytimg.com',
    ],
    // YouTube — QUIC/UDP-тяжёлый; заблокирован полностью с 11.02.2026.
    strategy: 'quic_fragment');

  static const tiktok = ServiceBypassProfile(
    id: 'tiktok', name: 'TikTok', icon: Icons.music_note_rounded,
    domains: [
      'tiktok.com', 'tiktokv.com', 'tiktokcdn.com', 'tiktokcdn-us.com',
      'byteoversea.com', 'ibyteimg.com', 'muscdn.com', 'ttwstatic.com', 'tiktokw.us',
    ],
    strategy: 'reality_vk_sni');

  static const instagram = ServiceBypassProfile(
    id: 'instagram', name: 'Instagram', icon: Icons.camera_alt_rounded,
    domains: ['instagram.com', 'cdninstagram.com', 'ig.me', 'instagr.am'],
    strategy: 'reality_fragment');

  static const whatsapp = ServiceBypassProfile(
    id: 'whatsapp', name: 'WhatsApp', icon: Icons.chat_rounded,
    domains: ['whatsapp.com', 'whatsapp.net', 'wa.me'],
    // Заблокирован полностью с 11.02.2026.
    strategy: 'reality_fragment');

  static const discord = ServiceBypassProfile(
    id: 'discord', name: 'Discord', icon: Icons.forum_rounded,
    domains: ['discord.com', 'discord.gg', 'discordapp.com', 'discordapp.net',
              'discord.media', 'discordcdn.com'],
    strategy: 'reality_ws');

  static const twitterX = ServiceBypassProfile(
    id: 'x', name: 'X (Twitter)', icon: Icons.tag_rounded,
    domains: ['twitter.com', 'x.com', 't.co', 'twimg.com', 'twitter.co'],
    strategy: 'reality_fragment');

  static const meta = ServiceBypassProfile(
    id: 'meta', name: 'Facebook', icon: Icons.facebook_rounded,
    domains: ['facebook.com', 'fb.com', 'fbcdn.net', 'fb.me', 'messenger.com'],
    strategy: 'reality_fragment');

  static const all = [
    telegram, youtube, tiktok, instagram, whatsapp, discord, twitterX, meta,
  ];

  // Определить сервис по хосту (для UI/диагностики/ИИ).
  static ServiceBypassProfile? detect(String host) {
    final h = host.toLowerCase();
    for (final p in all) {
      if (p.domains.any((d) => h == d || h.endsWith('.$d'))) return p;
    }
    return null;
  }

  // Точные xray-routing правила: каждый сервис → через VPN (proxy).
  // Точнее geosite (включает CDN, IP Telegram, форки) → ровно нужный трафик.
  static List<Map<String, dynamic>> buildRoutingRules() {
    final rules = <Map<String, dynamic>>[];
    for (final p in all) {
      if (p.domains.isNotEmpty) {
        rules.add({
          'type': 'field',
          'domain': p.domains.map((d) => 'domain:$d').toList(),
          'outboundTag': 'proxy',
        });
      }
      if (p.ips.isNotEmpty) {
        rules.add({'type': 'field', 'ip': p.ips, 'outboundTag': 'proxy'});
      }
    }
    return rules;
  }
}
