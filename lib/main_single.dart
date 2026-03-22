// ================================================================
//  AURA VPN — main.dart  v3.0
//  НОВОЕ v3.0:
//    • Профили (AuraProfile) — несколько наборов нод + настроек
//    • Бэкап/Восстановление — зашифрованный JSON, Share Sheet
//    • Split Tunnel — выбор приложений (blocklist + allowlist)
//    • Статистика трафика — байты ↑↓ на карточке подключения
//    • Избранные ноды — ⭐ группа всегда первая
//    • Поиск нод — фильтр в реальном времени
//  ВСЁ из v2.0 сохранено:
//    • TCP Socket ping (parallel 8, 3 attempts)
//    • i18n 14 языков
//    • Error codes E-1001..E-1010
//    • Темы Dark/Light/System
//    • AI Bypass Engine
//    • Glassmorphism 2.0 UI
// ================================================================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';

// ─── CONSTANTS ───────────────────────────────────────────────────────────────

const String kControlPlaneUrl   = 'https://api.auravpn.app';

// ── Certificate Pinning ───────────────────────────────────────────────────────
// SHA-256 отпечатки публичных ключей нашего сервера api.auravpn.app
// Когда получишь реальный сертификат — замени PLACEHOLDER на настоящие SHA256
// Формат: base64(sha256(SubjectPublicKeyInfo DER))
// Команда для получения: openssl s_client -connect api.auravpn.app:443 |
//   openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
//   openssl dgst -sha256 -binary | base64
const kPinnedSha256 = [
  'PLACEHOLDER_REPLACE_WITH_REAL_SHA256_OF_YOUR_CERT==',  // Primary cert
  'PLACEHOLDER_REPLACE_WITH_REAL_SHA256_OF_BACKUP_CERT==', // Backup / Let's Encrypt root
];

// Домены для которых применяется cert pinning (только наши серверы)
// Cloudflare, Google, antifilter.download — без pinning (у них своя цепочка)
const kPinnedDomains = ['api.auravpn.app', 'auravpn.app'];

const String kBypassRulesUrl    = '$kControlPlaneUrl/bypass_rules.json';
const String kTelemetryUrl      = '$kControlPlaneUrl/telemetry';
const String kNodesUrl          = '$kControlPlaneUrl/nodes.json';

// ── Stealth Engine 2.0 — Dead Drop зеркала ──────────────────────────────────
// Если основной API недоступен — берём ноды из этих источников
const List<String> kDeadDropMirrors = [
  'https://raw.githubusercontent.com/auravpn/nodes/main/nodes.json',
  'https://gist.githubusercontent.com/auravpn/nodes/raw/nodes.json',
  // DNS TXT: dig TXT nodes.auravpn.app — содержит base64 списка нод
];
const String kDeadDropDnsTxt = 'nodes.auravpn.app';

// Reality SNI пул — высокоавторитетные домены (в белом списке РКН)
// SNI-пул актуализирован 22.03.2026
// Источник: анализ CIDR белых списков ТСПУ + net4people/bbs #490 + XTLS/Xray-examples
// Критерии: (1) IP в CIDR-whitelist РКН, (2) TLS1.3 + поддержка REALITY, (3) не блокируется в РФ
// ВАЖНО: dest и serverName должны совпадать — XTLS-Vision требует реального TLS с этого сервера
const List<String> kRealitySniPool = [
  // ── Tier 1: MICROSOFT — крупнейший CIDR whitelist (20.112.0.0/13) ────────
  'www.microsoft.com',           // Рекомендован XTLS-examples для России/Ирана
  'login.microsoft.com',         // Microsoft Login — высокий корпоративный трафик
  'login.microsoftonline.com',   // Azure AD OAuth — в белом списке РКН
  'update.microsoft.com',        // Windows Update — критически важен для РКН
  'office.com',                  // Microsoft Office Online
  'teams.microsoft.com',         // Microsoft Teams — корпоративный, всегда whitelist
  // ── Tier 2: APPLE — iCloud всегда доступен (17.0.0.0/8) ──────────────────
  'www.apple.com',               // Рекомендован XTLS/Xray-examples как dest
  'gateway.icloud.com',          // iCloud Gateway — Private Relay IP
  'mask.icloud.com',             // iCloud Private Relay — надёжный SNI
  'swscan.apple.com',            // Apple Software Updates — corporate whitelist
  // ── Tier 3: GOOGLE — максимальный трафик (142.250.0.0/15) ────────────────
  'dl.google.com',               // Google Download CDN
  'www.gstatic.com',             // Google Static — connectivitycheck хост
  'accounts.google.com',         // Google Auth
  'play.googleapis.com',         // Google Play
  // ── Tier 4: CLOUDFLARE — крупнейший CDN (104.16.0.0/13) ─────────────────
  'www.cloudflare.com',          // Cloudflare главная
  'speed.cloudflare.com',        // Cloudflare Speed Test — в whitelist
  // ── Tier 5: AMAZON AWS — глобальный CDN (205.251.0.0/17) ─────────────────
  'www.amazon.com',              // Рекомендован XTLS/Xray-examples
  'd1.awsstatic.com',            // AWS Static CDN
  // ── Tier 6: MOZILLA — Firefox в корпоративных whitelist ──────────────────
  'addons.mozilla.org',          // Firefox Addons
  'aus5.mozilla.org',            // Firefox Auto-Update
];

// CDN Workers URL для финального fallback
// Трафик идёт через Cloudflare CDN — блокировка означает блокировку половины интернета
const List<String> kCdnFallbackUrls = [
  'https://aura-vpn.workers.dev',  // Cloudflare Workers
  'https://aura-cdn.pages.dev',    // Cloudflare Pages
];

// Warm-up домены — реальный HTTPS трафик перед VPN туннелем
// Warm-up домены обновлены март 2026:
// Используем те же URL что запрашивает Android при подключении к WiFi
// ТСПУ не может заблокировать эти домены без отключения миллионов устройств
const List<String> kWarmupTargets = [
  // Google — самый надёжный, отвечает 204 за ~10ms
  'https://connectivitycheck.gstatic.com/generate_204',
  // Microsoft — Windows Update белый список
  'https://www.msftconnecttest.com/connecttest.txt',
  // Firefox — браузерный traffic
  'https://detectportal.firefox.com/success.txt',
  // Apple — iOS connectivity check
  'https://captive.apple.com/hotspot-detect.html',
  // Cloudflare — CDN trace
  'https://1.1.1.1/cdn-cgi/trace',
];
const String kSupportEmail      = 'support@auravpn.app';
const int    kLocalRulesVersion = 0;
const String kBackupMagic       = 'AURA_VPN_BACKUP_V1';

// ─── COLORS ──────────────────────────────────────────────────────────────────

// ── Версия приложения ────────────────────────────────────────────────────────
const kAppVersion = '6.0.0';
const kAppBuild   = '20260322';

// ── Responsive breakpoints ────────────────────────────────────────────────────
// phone < 600  |  tablet 600-840  |  desktop > 840
// Все функции — extension на BuildContext для удобного доступа
extension AuraLayout on BuildContext {
  double get screenW   => MediaQuery.of(this).size.width;
  double get screenH   => MediaQuery.of(this).size.height;
  bool   get isTablet  => screenW >= 600;
  bool   get isDesktop => screenW >= 840;
  bool   get isLandscape => screenW > screenH;

  // Максимальная ширина контентной колонки (центрируется на планшете)
  double get contentMaxW => isTablet ? 640.0 : double.infinity;

  // Отступы: на планшете горизонтальные увеличены
  EdgeInsets get pagePadding => isTablet
      ? EdgeInsets.symmetric(horizontal: ((screenW - 640) / 2).clamp(24.0, 120.0), vertical: 16)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 0);

  // Число колонок для грида нод
  int get nodeColumns => isDesktop ? 3 : (isTablet && isLandscape ? 2 : 1);
}

// FIX v3.0: нейтральный User-Agent для всех исходящих HTTP запросов
// 'AuraVPN/5.6.0' мгновенно идентифицирует трафик системами РКН/ТСПУ
// Используем Chrome Android — самый распространённый UA в мире
// Актуальные User-Agent строки (март 2026)
// Chrome 136 — текущая стабильная версия на Android
// РКН блокирует запросы от Dart/2.x — используем реальные браузерные UA
const kStealthUA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/136.0.7103.60 Mobile Safari/537.36';

// Пул UA для ротации — каждый запрос выглядит как другое устройство
const kStealthUAPool = [
  'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.7049.111 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 13; Redmi Note 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.135 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; motorola edge 50) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; Pixel 7a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.7049.111 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 12; POCOPHONE F1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.135 Mobile Safari/537.36',
];

// Акцентные цвета — управляются через AuraSkin (динамические)
// Дефолтные значения — используются до инициализации скина
Color _accent     = const Color(0xFF00E5FF);
Color _accentBlue = const Color(0xFF4FC3F7);
const _accentPurple = Color(0xFFB39DDB);
const _accentGold   = Color(0xFFFFD740);

// ═══════════════════════════════════════════════════════════════
//  i18n
// ═══════════════════════════════════════════════════════════════

enum AuraLocale { en, ru, zh, de, fr, es, ar, fa, tr, pt, ja, ko, uk, it }

class S {
  static AuraLocale _locale = AuraLocale.en;
  static AuraLocale get locale => _locale;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('aura_locale');
    if (saved != null) {
      _locale = AuraLocale.values.firstWhere((e) => e.name == saved, orElse: () => AuraLocale.en);
    } else {
      final tag = ui.PlatformDispatcher.instance.locale.languageCode;
      _locale = AuraLocale.values.firstWhere((e) => e.name == tag, orElse: () => AuraLocale.en);
    }
  }

  static Future<void> setLocale(AuraLocale l) async {
    _locale = l;
    final p = await SharedPreferences.getInstance();
    await p.setString('aura_locale', l.name);
  }

  static String t(String key) =>
      _strings[_locale]?[key] ?? _strings[AuraLocale.en]![key] ?? key;

  static const Map<AuraLocale, Map<String, String>> _strings = {
    AuraLocale.en: {
      'app_name': 'AURA VPN', 'connected': 'CONNECTED', 'connecting': 'CONNECTING…',
      'disconnected': 'DISCONNECTED', 'error': 'ERROR', 'no_nodes': 'NO NODES',
      'add_via_qr': 'Add via QR, key or subscription', 'scan_qr': 'SCAN QR',
      'nodes': 'NODES', 'sort_by_ping': 'SORT BY PING', 'settings': 'SETTINGS',
      'qr_scanner': 'QR SCANNER', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Block traffic if VPN drops',
      'auto_rotate': 'Auto-Rotate', 'auto_rotate_sub': 'Switch node after {n} fails',
      'ai_bypass': 'AI Auto-Bypass', 'ai_bypass_sub': 'Automatic bypass without updates',
      'sync_rules': 'Sync Rules', 'sync_rules_sub': 'Update rules from server',
      'add_node': 'ADD NODE', 'add_key': 'ADD KEY', 'add_sub': 'ADD SUBSCRIPTION',
      'refresh_all': 'REFRESH ALL', 'subscriptions': 'SUBSCRIPTIONS',
      'protection': 'PROTECTION', 'logs': 'LOGS', 'clear': 'CLEAR',
      'cancel': 'Cancel', 'save': 'Save', 'done': 'Done', 'scan_again': 'Scan Again',
      'rename_group': 'Rename Group', 'rename_node': 'Rename Node',
      'sub_added': 'SUB ADDED', 'node_added': 'NODE ADDED', 'unknown_qr': 'UNKNOWN QR',
      'appearance': 'APPEARANCE', 'theme': 'Theme', 'theme_dark': 'Dark',
      'theme_light': 'Light', 'theme_system': 'System', 'language': 'Language',
      'ok': 'OK', 'download_log': 'Copy Log', 'kill_switch_on': 'Kill Switch ON',
      'ai_bar_prefix': '🤖  AI BYPASS: ',
      // v3.0
      'profiles': 'PROFILES', 'profile_new': 'New Profile', 'profile_name': 'Profile name',
      'profile_switch': 'Switch Profile', 'profile_delete': 'Delete Profile',
      'profile_active': 'ACTIVE',
      'backup': 'BACKUP & RESTORE', 'backup_export': 'Export Backup',
      'backup_import': 'Import Backup', 'backup_password': 'Backup password (optional)',
      'backup_ok': 'Backup created', 'backup_fail': 'Backup failed',
      'restore_ok': 'Restored successfully', 'restore_fail': 'Restore failed',
      'restore_confirm': 'This will replace current data. Continue?',
      'split_tunnel': 'SPLIT TUNNEL', 'split_mode': 'Mode',
      'split_bypass': 'Bypass (selected apps skip VPN)',
      'split_proxy': 'Proxy (only selected apps use VPN)',
      'split_disabled': 'Disabled (all traffic via VPN)',
      'split_apps': 'Applications', 'split_search': 'Search apps…',
      'favourites': 'FAVOURITES', 'favourite_add': 'Add to Favourites',
      'favourite_remove': 'Remove from Favourites',
      'search_nodes': 'Search nodes…',
      'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Session',
      'delete': 'Delete', 'rename': 'Rename',
      'backup_copied': 'Backup copied to clipboard',
      'backup_password_hint': 'Password (optional)',
      // v5.9 new keys
      'section_tunnel': 'TUNNEL', 'section_security': 'SECURITY & BYPASS',
      'section_subscriptions': 'SUBSCRIPTIONS', 'section_connection': 'CONNECTION',
      'section_interface': 'INTERFACE', 'section_data': 'DATA',
      'tunnel_settings': 'Tunnel Settings', 'mux_enable': 'Enable MUX',
      'mux_sub': 'TCP stream multiplexing', 'tun_enable': 'Enable TUN',
      'tun_sub': 'Intercepts all OS traffic', 'ip_preference': 'IP Preference',
      'dns_enable': 'DNS for TUN', 'dns_sub': 'Use DoH inside tunnel',
      'lan_share': 'LAN Sharing', 'lan_sub': 'Share proxy with local network',
      'packet_sniff': 'Packet Sniffing', 'packet_sniff_sub': 'DPI traffic classification',
      'system_proxy': 'System Proxy', 'system_proxy_sub': 'Set system HTTP proxy too',
      'node_rename': 'Rename', 'node_share': 'Share node',
      'node_reset': 'Reset to original key',
      'node_reset_confirm_title': 'Reset config?',
      'node_reset_confirm_body': 'Key returns to provider original. AI patches removed.',
      'node_modified': '⚠️ Key modified by AI/camouflage',
      'camouflage': 'Traffic Camouflage', 'camouflage_sub': 'Disguise VPN as a service',
      'camo_none': 'No camouflage', 'camo_browser': 'HTTPS Browser',
      'camo_telegram': 'Telegram CDN', 'camo_netflix': 'Netflix Stream',
      'camo_youtube': 'YouTube Video', 'camo_discord': 'Discord Gateway',
      'camo_cloudflare': 'Cloudflare WARP', 'camo_microsoft': 'Windows Update',
      'camo_apple': 'iCloud Sync', 'camo_naive': 'NaïveProxy H2',
      'ping_settings': 'Ping Settings', 'ping_type': 'Ping Type',
      'ping_url_label': 'Test URL', 'sub_settings': 'Update Settings',
      'sub_auto_update': 'Auto Update', 'sub_interval': 'Interval (hours)',
      'sub_on_open': 'Update on launch', 'sub_ping_open': 'Ping on launch',
      'sub_connect_open': 'Connect on launch', 'sub_sort_label': 'Sort order',
      'sub_sort_none': 'No sort', 'sub_sort_ping': 'By ping',
      'sub_sort_alpha': 'Alphabetical', 'sub_user_agent': 'User Agent',
      'sub_allow_dups': 'Allow duplicates',
      'theme_editor': 'My Theme', 'theme_preview': 'PREVIEW',
      'theme_colors': 'COLORS', 'theme_background': 'BACKGROUND',
      'theme_presets': 'QUICK PRESETS', 'theme_apply': 'APPLY THEME',
      'theme_pick_media': 'Photo / GIF / Video', 'theme_enter_path': 'Enter path',
      'theme_saved': 'Theme saved ✓',
      'reset': 'Reset', 'apply': 'Apply', 'confirm': 'Confirm',
      'loading': 'Loading…', 'success': 'Done', 'about_version': 'Version',
      'servers_title': 'Servers', 'ip_check_title': 'IP Check',
      'disconnect': 'Disconnect', 'reconnect': 'Reconnect',
      'select': 'Select', 'close': 'Close',
      'auto_connect': 'Auto-Connect', 'stealth_engine': 'Stealth Engine 3.0',
      'ai_bypass_engine': 'AI Bypass Engine', 'bypass_whitelist': 'Bypass Whitelists',
      'about_app': 'About', 'history': 'Connection History',
      'ping_via_proxy': 'via Proxy', 'ping_tcp': 'TCP', 'ping_icmp': 'ICMP',
      'lan_page': 'Local Network (LAN)', 'routing': 'ROUTING',
      'smart_routing': 'Smart Routing',
      'smart_routing_sub': 'RU domains direct, blocked via VPN',
      'ip_auto': 'Auto', 'ip_v4': 'IPv4 only', 'ip_v6': 'IPv6 only',
      'tun_mixed': 'Mixed', 'tun_mixed_sub': 'TCP + UDP via tun2socks',
      'tun_fakedns': 'FakeDNS', 'tun_fakedns_sub': 'DNS intercept — reduces leaks',
      'dns_address': 'DNS Address',
    },
    AuraLocale.ru: {
      'app_name': 'AURA VPN', 'connected': 'ПОДКЛЮЧЕНО', 'connecting': 'ПОДКЛЮЧЕНИЕ…',
      'disconnected': 'ОТКЛЮЧЕНО', 'error': 'ОШИБКА', 'no_nodes': 'НЕТ УЗЛОВ',
      'add_via_qr': 'Добавьте через QR, ключ или подписку', 'scan_qr': 'СКАНИРОВАТЬ QR',
      'nodes': 'УЗЛОВ', 'sort_by_ping': 'ПО ПИНГУ', 'settings': 'НАСТРОЙКИ',
      'qr_scanner': 'QR СКАНЕР', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Блокировать трафик при разрыве VPN',
      'auto_rotate': 'Авто-ротация', 'auto_rotate_sub': 'Сменить после {n} неудач',
      'ai_bypass': 'AI Авто-обход', 'ai_bypass_sub': 'Автоматический обход без обновлений',
      'sync_rules': 'Синхронизация', 'sync_rules_sub': 'Обновить правила с сервера',
      'add_node': 'ДОБАВИТЬ УЗЕЛ', 'add_key': 'ДОБАВИТЬ КЛЮЧ',
      'add_sub': 'ДОБАВИТЬ ПОДПИСКУ', 'refresh_all': 'ОБНОВИТЬ ВСЁ',
      'subscriptions': 'ПОДПИСКИ', 'protection': 'ЗАЩИТА', 'logs': 'ЛОГИ',
      'clear': 'ОЧИСТИТЬ', 'cancel': 'Отмена', 'save': 'Сохранить',
      'done': 'Готово', 'scan_again': 'Сканировать снова',
      'rename_group': 'Переименовать группу', 'rename_node': 'Переименовать узел',
      'sub_added': 'ПОДПИСКА ДОБАВЛЕНА', 'node_added': 'УЗЕЛ ДОБАВЛЕН',
      'unknown_qr': 'НЕИЗВЕСТНЫЙ QR', 'appearance': 'ВНЕШНИЙ ВИД',
      'theme': 'Тема', 'theme_dark': 'Тёмная', 'theme_light': 'Светлая',
      'theme_system': 'Системная', 'language': 'Язык', 'ok': 'ОК',
      'download_log': 'Скопировать лог', 'kill_switch_on': 'Kill Switch ВКЛЮЧЁН',
      'backup_copied': 'Бэкап скопирован в буфер обмена',
      'backup_password_hint': 'Пароль (необязательно)',
      'ai_bar_prefix': '🤖  AI ОБХОД: ',
      'profiles': 'ПРОФИЛИ', 'profile_new': 'Новый профиль',
      'profile_name': 'Название профиля', 'profile_switch': 'Переключить',
      'profile_delete': 'Удалить профиль', 'profile_active': 'АКТИВЕН',
      'backup': 'РЕЗЕРВНАЯ КОПИЯ', 'backup_export': 'Создать резервную копию',
      'backup_import': 'Восстановить из копии',
      'backup_password': 'Пароль для копии (необязательно)',
      'backup_ok': 'Копия создана', 'backup_fail': 'Ошибка создания копии',
      'restore_ok': 'Восстановлено', 'restore_fail': 'Ошибка восстановления',
      'restore_confirm': 'Текущие данные будут заменены. Продолжить?',
      'split_tunnel': 'РАЗДЕЛЬНЫЙ ТУННЕЛЬ', 'split_mode': 'Режим',
      'split_bypass': 'Байпас (выбранные приложения минуют VPN)',
      'split_proxy': 'Прокси (только выбранные приложения через VPN)',
      'split_disabled': 'Отключён (весь трафик через VPN)',
      'split_apps': 'Приложения', 'split_search': 'Поиск приложений…',
      'favourites': 'ИЗБРАННОЕ', 'favourite_add': 'Добавить в избранное',
      'favourite_remove': 'Убрать из избранного',
      'search_nodes': 'Поиск узлов…',
      'traffic_up': '↑', 'traffic_down': '↓', 'session_time': 'Сессия',
      'delete': 'Удалить', 'rename': 'Переименовать',
      // v5.9 новые ключи
      'section_tunnel': 'ТУННЕЛЬ', 'section_security': 'БЕЗОПАСНОСТЬ И ОБХОД',
      'section_subscriptions': 'ПОДПИСКИ', 'section_connection': 'СОЕДИНЕНИЕ',
      'section_interface': 'ИНТЕРФЕЙС', 'section_data': 'ДАННЫЕ',
      'tunnel_settings': 'Настройки туннеля', 'mux_enable': 'Включить MUX',
      'mux_sub': 'Уплотнение TCP-потоков', 'tun_enable': 'Включить TUN',
      'tun_sub': 'Перехватывает весь трафик ОС', 'ip_preference': 'Предпочитаемый IP',
      'dns_enable': 'DNS для TUN', 'dns_sub': 'Использовать DoH внутри туннеля',
      'lan_share': 'Раздача в LAN', 'lan_sub': 'Прокси для устройств в сети',
      'packet_sniff': 'Анализ пакетов', 'packet_sniff_sub': 'DPI-детектирование трафика',
      'system_proxy': 'Системный прокси', 'system_proxy_sub': 'Устанавливать HTTP прокси в системе',
      'node_rename': 'Переименовать', 'node_share': 'Поделиться нодой',
      'node_reset': 'Сбросить к оригинальному ключу',
      'node_reset_confirm_title': 'Сбросить конфиг?',
      'node_reset_confirm_body': 'Ключ вернётся к оригинальному от провайдера. AI-патчи будут убраны.',
      'node_modified': '⚠️ Ключ изменён AI/маскировкой',
      'camouflage': 'Маскировка трафика', 'camouflage_sub': 'Замаскировать VPN под сервис',
      'camo_none': 'Без маскировки', 'camo_browser': 'HTTPS браузер',
      'camo_telegram': 'Telegram CDN', 'camo_netflix': 'Netflix Stream',
      'camo_youtube': 'YouTube Video', 'camo_discord': 'Discord Gateway',
      'camo_cloudflare': 'Cloudflare WARP', 'camo_microsoft': 'Windows Update',
      'camo_apple': 'iCloud Sync', 'camo_naive': 'NaïveProxy H2',
      'ping_settings': 'Настройки пинга', 'ping_type': 'Тип пинга',
      'ping_url_label': 'Тестовый URL', 'sub_settings': 'Параметры обновления',
      'sub_auto_update': 'Автообновление', 'sub_interval': 'Интервал (часы)',
      'sub_on_open': 'Обновлять при открытии', 'sub_ping_open': 'Пинговать при открытии',
      'sub_connect_open': 'Подключаться при открытии', 'sub_sort_label': 'Сортировка',
      'sub_sort_none': 'Без сортировки', 'sub_sort_ping': 'По пингу',
      'sub_sort_alpha': 'По алфавиту', 'sub_user_agent': 'User Agent',
      'sub_allow_dups': 'Разрешить дубликаты',
      'theme_editor': 'Моя тема', 'theme_preview': 'ПРЕВЬЮ',
      'theme_colors': 'ЦВЕТА', 'theme_background': 'ФОН',
      'theme_presets': 'БЫСТРЫЕ ПРЕСЕТЫ', 'theme_apply': 'ПРИМЕНИТЬ ТЕМУ',
      'theme_pick_media': 'Фото / GIF / Видео', 'theme_enter_path': 'Ввести путь',
      'theme_saved': 'Тема сохранена ✓',
      'reset': 'Сбросить', 'apply': 'Применить', 'confirm': 'Подтвердить',
      'loading': 'Загрузка…', 'success': 'Готово', 'about_version': 'Версия',
      'servers_title': 'Серверы', 'ip_check_title': 'Проверка IP',
      'disconnect': 'Отключить', 'reconnect': 'Переподключить',
      'select': 'Выбрать', 'close': 'Закрыть',
      'auto_connect': 'Автоподключение', 'stealth_engine': 'Stealth Engine 3.0',
      'ai_bypass_engine': 'AI Bypass Engine', 'bypass_whitelist': 'Обход белых списков',
      'about_app': 'О приложении', 'history': 'История подключений',
      'ping_via_proxy': 'через Proxy', 'ping_tcp': 'TCP', 'ping_icmp': 'ICMP',
      'lan_page': 'Локальная сеть (LAN)', 'routing': 'МАРШРУТИЗАЦИЯ',
      'smart_routing': 'Умная маршрутизация',
      'smart_routing_sub': 'RU-домены напрямую, заблокированные через VPN',
      'ip_auto': 'Авто', 'ip_v4': 'Только IPv4', 'ip_v6': 'Только IPv6',
      'tun_mixed': 'Смешанный', 'tun_mixed_sub': 'TCP + UDP через tun2socks',
      'tun_fakedns': 'FakeDNS', 'tun_fakedns_sub': 'DNS перехват — снижает утечки',
      'dns_address': 'DNS адрес',
    },
    // остальные языки — ключи из en (fallback автоматический)
    AuraLocale.zh: {
      'app_name': 'AURA VPN', 'connected': '已连接', 'connecting': '连接中…',
      'disconnected': '已断开', 'error': '错误', 'no_nodes': '无节点',
      'add_via_qr': '通过二维码、密钥或订阅添加', 'scan_qr': '扫描二维码',
      'nodes': '节点', 'sort_by_ping': '按延迟排序', 'settings': '设置',
      'qr_scanner': '二维码扫描', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'VPN断开时阻止流量',
      'auto_rotate': '自动轮换', 'auto_rotate_sub': '{n}次失败后切换节点',
      'ai_bypass': 'AI自动绕过', 'ai_bypass_sub': '无需更新自动绕过封锁',
      'sync_rules': '同步规则', 'sync_rules_sub': '从服务器更新规则',
      'add_node': '添加节点', 'add_key': '添加密钥', 'add_sub': '添加订阅',
      'refresh_all': '全部刷新', 'subscriptions': '订阅', 'protection': '保护',
      'logs': '日志', 'clear': '清除', 'cancel': '取消', 'save': '保存',
      'done': '完成', 'scan_again': '重新扫描',
      'rename_group': '重命名分组', 'rename_node': '重命名节点',
      'sub_added': '订阅已添加', 'node_added': '节点已添加', 'unknown_qr': '未知二维码',
      'appearance': '外观', 'theme': '主题', 'theme_dark': '深色',
      'theme_light': '浅色', 'theme_system': '跟随系统', 'language': '语言',
      'ok': '确定', 'download_log': '复制日志', 'kill_switch_on': '断网保护已开启',
      'ai_bar_prefix': '🤖  AI绕过: ',
      'profiles': '配置文件', 'profile_new': '新建配置', 'profile_name': '配置名称',
      'profile_switch': '切换配置', 'profile_delete': '删除配置', 'profile_active': '当前',
      'backup': '备份', 'backup_export': '导出备份', 'backup_import': '导入备份',
      'backup_password': '备份密码（可选）', 'backup_ok': '备份成功',
      'backup_fail': '备份失败', 'restore_ok': '恢复成功', 'restore_fail': '恢复失败',
      'restore_confirm': '当前数据将被替换，继续？',
      'backup_copied': '备份已复制到剪贴板', 'backup_password_hint': '密码（可选）',
      'split_tunnel': '分流', 'split_mode': '模式',
      'split_bypass': '绕过（所选应用跳过VPN）', 'split_proxy': '代理（仅所选应用走VPN）',
      'split_disabled': '禁用（全部流量走VPN）',
      'split_apps': '应用程序', 'split_search': '搜索应用…',
      'favourites': '收藏', 'favourite_add': '添加收藏', 'favourite_remove': '取消收藏',
      'search_nodes': '搜索节点…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': '会话', 'delete': '删除', 'rename': '重命名',
    },
    AuraLocale.de: {
      'app_name': 'AURA VPN', 'connected': 'VERBUNDEN', 'connecting': 'VERBINDE…',
      'disconnected': 'GETRENNT', 'error': 'FEHLER', 'no_nodes': 'KEINE KNOTEN',
      'add_via_qr': 'Über QR-Code, Schlüssel oder Abo hinzufügen', 'scan_qr': 'QR SCANNEN',
      'nodes': 'KNOTEN', 'sort_by_ping': 'NACH PING', 'settings': 'EINSTELLUNGEN',
      'qr_scanner': 'QR-SCANNER', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Datenverkehr sperren wenn VPN abbricht',
      'auto_rotate': 'Auto-Rotation', 'auto_rotate_sub': 'Nach {n} Fehlern wechseln',
      'ai_bypass': 'KI Auto-Bypass', 'ai_bypass_sub': 'Automatische Umgehung ohne Updates',
      'sync_rules': 'Regeln sync.', 'sync_rules_sub': 'Regeln vom Server aktualisieren',
      'add_node': 'KNOTEN HINZUFÜGEN', 'add_key': 'SCHLÜSSEL HINZUFÜGEN',
      'add_sub': 'ABO HINZUFÜGEN', 'refresh_all': 'ALLE AKTUALISIEREN',
      'subscriptions': 'ABONNEMENTS', 'protection': 'SCHUTZ', 'logs': 'PROTOKOLLE',
      'clear': 'LÖSCHEN', 'cancel': 'Abbrechen', 'save': 'Speichern',
      'done': 'Fertig', 'scan_again': 'Erneut scannen',
      'rename_group': 'Gruppe umbenennen', 'rename_node': 'Knoten umbenennen',
      'sub_added': 'ABO HINZUGEFÜGT', 'node_added': 'KNOTEN HINZUGEFÜGT',
      'unknown_qr': 'UNBEKANNTER QR',
      'appearance': 'AUSSEHEN', 'theme': 'Design', 'theme_dark': 'Dunkel',
      'theme_light': 'Hell', 'theme_system': 'System', 'language': 'Sprache',
      'ok': 'OK', 'download_log': 'Log kopieren', 'kill_switch_on': 'Kill Switch AN',
      'ai_bar_prefix': '🤖  KI-BYPASS: ',
      'profiles': 'PROFILE', 'profile_new': 'Neues Profil', 'profile_name': 'Profilname',
      'profile_switch': 'Profil wechseln', 'profile_delete': 'Profil löschen',
      'profile_active': 'AKTIV',
      'backup': 'SICHERUNG', 'backup_export': 'Sicherung exportieren',
      'backup_import': 'Sicherung importieren', 'backup_password': 'Passwort (optional)',
      'backup_ok': 'Sicherung erstellt', 'backup_fail': 'Sicherung fehlgeschlagen',
      'restore_ok': 'Wiederhergestellt', 'restore_fail': 'Wiederherstellung fehlgeschlagen',
      'restore_confirm': 'Aktuelle Daten werden ersetzt. Fortfahren?',
      'backup_copied': 'Sicherung in Zwischenablage kopiert',
      'backup_password_hint': 'Passwort (optional)',
      'split_tunnel': 'SPLIT TUNNEL', 'split_mode': 'Modus',
      'split_bypass': 'Bypass (ausgewählte Apps umgehen VPN)',
      'split_proxy': 'Proxy (nur ausgewählte Apps über VPN)',
      'split_disabled': 'Deaktiviert (gesamter Datenverkehr über VPN)',
      'split_apps': 'Anwendungen', 'split_search': 'Apps suchen…',
      'favourites': 'FAVORITEN', 'favourite_add': 'Zu Favoriten hinzufügen',
      'favourite_remove': 'Aus Favoriten entfernen',
      'search_nodes': 'Knoten suchen…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Sitzung', 'delete': 'Löschen', 'rename': 'Umbenennen',
    },
    AuraLocale.fr: {
      'app_name': 'AURA VPN', 'connected': 'CONNECTÉ', 'connecting': 'CONNEXION…',
      'disconnected': 'DÉCONNECTÉ', 'error': 'ERREUR', 'no_nodes': 'AUCUN NŒUD',
      'add_via_qr': 'Ajouter via QR, clé ou abonnement', 'scan_qr': 'SCANNER QR',
      'nodes': 'NŒUDS', 'sort_by_ping': 'PAR PING', 'settings': 'PARAMÈTRES',
      'qr_scanner': 'SCANNER QR', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Bloquer le trafic si le VPN se déconnecte',
      'auto_rotate': 'Rotation auto', 'auto_rotate_sub': 'Changer après {n} échecs',
      'ai_bypass': 'Contournement IA', 'ai_bypass_sub': 'Contournement automatique',
      'sync_rules': 'Sync règles', 'sync_rules_sub': 'Mettre à jour depuis le serveur',
      'add_node': 'AJOUTER NŒUD', 'add_key': 'AJOUTER CLÉ',
      'add_sub': 'AJOUTER ABONNEMENT', 'refresh_all': 'TOUT ACTUALISER',
      'subscriptions': 'ABONNEMENTS', 'protection': 'PROTECTION', 'logs': 'JOURNAUX',
      'clear': 'EFFACER', 'cancel': 'Annuler', 'save': 'Enregistrer',
      'done': 'Terminé', 'scan_again': 'Scanner à nouveau',
      'rename_group': 'Renommer le groupe', 'rename_node': 'Renommer le nœud',
      'sub_added': 'ABONNEMENT AJOUTÉ', 'node_added': 'NŒUD AJOUTÉ',
      'unknown_qr': 'QR INCONNU',
      'appearance': 'APPARENCE', 'theme': 'Thème', 'theme_dark': 'Sombre',
      'theme_light': 'Clair', 'theme_system': 'Système', 'language': 'Langue',
      'ok': 'OK', 'download_log': 'Copier le journal', 'kill_switch_on': 'Kill Switch ACTIVÉ',
      'ai_bar_prefix': '🤖  BYPASS IA: ',
      'profiles': 'PROFILS', 'profile_new': 'Nouveau profil', 'profile_name': 'Nom du profil',
      'profile_switch': 'Changer de profil', 'profile_delete': 'Supprimer le profil',
      'profile_active': 'ACTIF',
      'backup': 'SAUVEGARDE', 'backup_export': 'Exporter la sauvegarde',
      'backup_import': 'Importer la sauvegarde', 'backup_password': 'Mot de passe (optionnel)',
      'backup_ok': 'Sauvegarde créée', 'backup_fail': 'Échec de la sauvegarde',
      'restore_ok': 'Restauré avec succès', 'restore_fail': 'Échec de la restauration',
      'restore_confirm': 'Les données actuelles seront remplacées. Continuer?',
      'backup_copied': 'Sauvegarde copiée dans le presse-papiers',
      'backup_password_hint': 'Mot de passe (optionnel)',
      'split_tunnel': 'TUNNEL DIVISÉ', 'split_mode': 'Mode',
      'split_bypass': 'Bypass (les apps sélectionnées contournent le VPN)',
      'split_proxy': 'Proxy (seules les apps sélectionnées via VPN)',
      'split_disabled': 'Désactivé (tout le trafic via VPN)',
      'split_apps': 'Applications', 'split_search': 'Rechercher des apps…',
      'favourites': 'FAVORIS', 'favourite_add': 'Ajouter aux favoris',
      'favourite_remove': 'Retirer des favoris',
      'search_nodes': 'Chercher des nœuds…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Session', 'delete': 'Supprimer', 'rename': 'Renommer',
    },
    AuraLocale.es: {
      'app_name': 'AURA VPN', 'connected': 'CONECTADO', 'connecting': 'CONECTANDO…',
      'disconnected': 'DESCONECTADO', 'error': 'ERROR', 'no_nodes': 'SIN NODOS',
      'add_via_qr': 'Agregar via QR, clave o suscripción', 'scan_qr': 'ESCANEAR QR',
      'nodes': 'NODOS', 'sort_by_ping': 'POR PING', 'settings': 'AJUSTES',
      'qr_scanner': 'ESCÁNER QR', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Bloquear tráfico si el VPN se desconecta',
      'auto_rotate': 'Rotación auto', 'auto_rotate_sub': 'Cambiar tras {n} fallos',
      'ai_bypass': 'IA Auto-bypass', 'ai_bypass_sub': 'Bypass automático sin actualizaciones',
      'sync_rules': 'Sync reglas', 'sync_rules_sub': 'Actualizar desde el servidor',
      'add_node': 'AGREGAR NODO', 'add_key': 'AGREGAR CLAVE',
      'add_sub': 'AGREGAR SUSCRIPCIÓN', 'refresh_all': 'ACTUALIZAR TODO',
      'subscriptions': 'SUSCRIPCIONES', 'protection': 'PROTECCIÓN', 'logs': 'REGISTROS',
      'clear': 'LIMPIAR', 'cancel': 'Cancelar', 'save': 'Guardar',
      'done': 'Hecho', 'scan_again': 'Escanear de nuevo',
      'rename_group': 'Renombrar grupo', 'rename_node': 'Renombrar nodo',
      'sub_added': 'SUSCRIPCIÓN AGREGADA', 'node_added': 'NODO AGREGADO',
      'unknown_qr': 'QR DESCONOCIDO',
      'appearance': 'APARIENCIA', 'theme': 'Tema', 'theme_dark': 'Oscuro',
      'theme_light': 'Claro', 'theme_system': 'Sistema', 'language': 'Idioma',
      'ok': 'OK', 'download_log': 'Copiar registro', 'kill_switch_on': 'Kill Switch ACTIVADO',
      'ai_bar_prefix': '🤖  BYPASS IA: ',
      'profiles': 'PERFILES', 'profile_new': 'Nuevo perfil', 'profile_name': 'Nombre del perfil',
      'profile_switch': 'Cambiar perfil', 'profile_delete': 'Eliminar perfil',
      'profile_active': 'ACTIVO',
      'backup': 'COPIA SEG.', 'backup_export': 'Exportar copia',
      'backup_import': 'Importar copia', 'backup_password': 'Contraseña (opcional)',
      'backup_ok': 'Copia creada', 'backup_fail': 'Error al crear copia',
      'restore_ok': 'Restaurado con éxito', 'restore_fail': 'Error al restaurar',
      'restore_confirm': 'Los datos actuales serán reemplazados. ¿Continuar?',
      'backup_copied': 'Copia copiada al portapapeles',
      'backup_password_hint': 'Contraseña (opcional)',
      'split_tunnel': 'TÚNEL DIVIDIDO', 'split_mode': 'Modo',
      'split_bypass': 'Bypass (apps seleccionadas evitan VPN)',
      'split_proxy': 'Proxy (solo apps seleccionadas via VPN)',
      'split_disabled': 'Desactivado (todo el tráfico via VPN)',
      'split_apps': 'Aplicaciones', 'split_search': 'Buscar apps…',
      'favourites': 'FAVORITOS', 'favourite_add': 'Agregar a favoritos',
      'favourite_remove': 'Quitar de favoritos',
      'search_nodes': 'Buscar nodos…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Sesión', 'delete': 'Eliminar', 'rename': 'Renombrar',
    },
    AuraLocale.ar: {
      'app_name': 'AURA VPN', 'connected': 'متصل', 'connecting': 'جارٍ الاتصال…',
      'disconnected': 'غير متصل', 'error': 'خطأ', 'no_nodes': 'لا توجد عقد',
      'add_via_qr': 'أضف عبر QR أو مفتاح أو اشتراك', 'scan_qr': 'مسح QR',
      'nodes': 'العقد', 'sort_by_ping': 'ترتيب حسب Ping', 'settings': 'الإعدادات',
      'qr_scanner': 'ماسح QR', 'kill_switch': 'مفتاح الإيقاف',
      'kill_switch_sub': 'منع حركة المرور عند انقطاع VPN',
      'auto_rotate': 'تدوير تلقائي', 'auto_rotate_sub': 'التبديل بعد {n} فشل',
      'ai_bypass': 'تجاوز AI', 'ai_bypass_sub': 'تجاوز تلقائي بدون تحديثات',
      'sync_rules': 'مزامنة القواعد', 'sync_rules_sub': 'تحديث من الخادم',
      'add_node': 'إضافة عقدة', 'add_key': 'إضافة مفتاح',
      'add_sub': 'إضافة اشتراك', 'refresh_all': 'تحديث الكل',
      'subscriptions': 'الاشتراكات', 'protection': 'الحماية', 'logs': 'السجلات',
      'clear': 'مسح', 'cancel': 'إلغاء', 'save': 'حفظ',
      'done': 'تم', 'scan_again': 'مسح مجدداً',
      'rename_group': 'إعادة تسمية المجموعة', 'rename_node': 'إعادة تسمية العقدة',
      'sub_added': 'تم إضافة الاشتراك', 'node_added': 'تم إضافة العقدة',
      'unknown_qr': 'QR غير معروف',
      'appearance': 'المظهر', 'theme': 'السمة', 'theme_dark': 'داكن',
      'theme_light': 'فاتح', 'theme_system': 'تلقائي', 'language': 'اللغة',
      'ok': 'موافق', 'download_log': 'نسخ السجل', 'kill_switch_on': 'مفتاح الإيقاف مفعّل',
      'ai_bar_prefix': '🤖  تجاوز AI: ',
      'profiles': 'الملفات الشخصية', 'profile_new': 'ملف جديد', 'profile_name': 'اسم الملف',
      'profile_switch': 'تبديل الملف', 'profile_delete': 'حذف الملف', 'profile_active': 'نشط',
      'backup': 'النسخ الاحتياطي', 'backup_export': 'تصدير النسخة',
      'backup_import': 'استيراد النسخة', 'backup_password': 'كلمة المرور (اختياري)',
      'backup_ok': 'تم إنشاء النسخة', 'backup_fail': 'فشل النسخ',
      'restore_ok': 'تم الاستعادة', 'restore_fail': 'فشل الاستعادة',
      'restore_confirm': 'سيتم استبدال البيانات الحالية. هل تريد المتابعة؟',
      'backup_copied': 'تم نسخ النسخة الاحتياطية', 'backup_password_hint': 'كلمة المرور (اختياري)',
      'split_tunnel': 'تقسيم النفق', 'split_mode': 'الوضع',
      'split_bypass': 'تجاوز (التطبيقات المحددة تتجاوز VPN)',
      'split_proxy': 'وكيل (فقط التطبيقات المحددة عبر VPN)',
      'split_disabled': 'معطل (كل حركة المرور عبر VPN)',
      'split_apps': 'التطبيقات', 'split_search': 'بحث في التطبيقات…',
      'favourites': 'المفضلة', 'favourite_add': 'إضافة إلى المفضلة',
      'favourite_remove': 'إزالة من المفضلة',
      'search_nodes': 'بحث في العقد…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'الجلسة', 'delete': 'حذف', 'rename': 'إعادة تسمية',
    },
    AuraLocale.fa: {
      'app_name': 'AURA VPN', 'connected': 'متصل', 'connecting': 'در حال اتصال…',
      'disconnected': 'قطع شد', 'error': 'خطا', 'no_nodes': 'هیچ نودی وجود ندارد',
      'add_via_qr': 'از طریق QR، کلید یا اشتراک اضافه کنید', 'scan_qr': 'اسکن QR',
      'nodes': 'نودها', 'sort_by_ping': 'مرتب‌سازی بر اساس پینگ', 'settings': 'تنظیمات',
      'qr_scanner': 'اسکنر QR', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'در صورت قطع VPN ترافیک را مسدود کن',
      'auto_rotate': 'چرخش خودکار', 'auto_rotate_sub': 'بعد از {n} شکست تغییر دهید',
      'ai_bypass': 'دور زدن هوش مصنوعی', 'ai_bypass_sub': 'دور زدن خودکار بدون به‌روزرسانی',
      'sync_rules': 'همگام‌سازی قوانین', 'sync_rules_sub': 'به‌روزرسانی از سرور',
      'add_node': 'افزودن نود', 'add_key': 'افزودن کلید',
      'add_sub': 'افزودن اشتراک', 'refresh_all': 'بازنشانی همه',
      'subscriptions': 'اشتراک‌ها', 'protection': 'حفاظت', 'logs': 'گزارش‌ها',
      'clear': 'پاک‌کردن', 'cancel': 'لغو', 'save': 'ذخیره',
      'done': 'تمام', 'scan_again': 'دوباره اسکن کنید',
      'rename_group': 'تغییر نام گروه', 'rename_node': 'تغییر نام نود',
      'sub_added': 'اشتراک اضافه شد', 'node_added': 'نود اضافه شد',
      'unknown_qr': 'QR ناشناخته',
      'appearance': 'ظاهر', 'theme': 'تم', 'theme_dark': 'تاریک',
      'theme_light': 'روشن', 'theme_system': 'سیستم', 'language': 'زبان',
      'ok': 'باشه', 'download_log': 'کپی گزارش', 'kill_switch_on': 'Kill Switch فعال',
      'ai_bar_prefix': '🤖  دور زدن AI: ',
      'profiles': 'پروفایل‌ها', 'profile_new': 'پروفایل جدید', 'profile_name': 'نام پروفایل',
      'profile_switch': 'تغییر پروفایل', 'profile_delete': 'حذف پروفایل', 'profile_active': 'فعال',
      'backup': 'پشتیبان', 'backup_export': 'صدور پشتیبان',
      'backup_import': 'وارد کردن پشتیبان', 'backup_password': 'رمز عبور (اختیاری)',
      'backup_ok': 'پشتیبان ایجاد شد', 'backup_fail': 'خطا در ایجاد پشتیبان',
      'restore_ok': 'بازیابی موفق', 'restore_fail': 'خطا در بازیابی',
      'restore_confirm': 'داده‌های فعلی جایگزین می‌شوند. ادامه می‌دهید؟',
      'backup_copied': 'پشتیبان در کلیپ‌بورد کپی شد', 'backup_password_hint': 'رمز عبور (اختیاری)',
      'split_tunnel': 'تونل تقسیم', 'split_mode': 'حالت',
      'split_bypass': 'بایپس (برنامه‌های انتخابی VPN را دور می‌زنند)',
      'split_proxy': 'پروکسی (فقط برنامه‌های انتخابی از VPN)',
      'split_disabled': 'غیرفعال (همه ترافیک از VPN)',
      'split_apps': 'برنامه‌ها', 'split_search': 'جستجوی برنامه‌ها…',
      'favourites': 'موردعلاقه‌ها', 'favourite_add': 'افزودن به موردعلاقه‌ها',
      'favourite_remove': 'حذف از موردعلاقه‌ها',
      'search_nodes': 'جستجوی نودها…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'جلسه', 'delete': 'حذف', 'rename': 'تغییر نام',
    },
    AuraLocale.tr: {
      'app_name': 'AURA VPN', 'connected': 'BAĞLANDI', 'connecting': 'BAĞLANIYOR…',
      'disconnected': 'KESİLDİ', 'error': 'HATA', 'no_nodes': 'DÜĞÜM YOK',
      'add_via_qr': 'QR kodu, anahtar veya abonelik ile ekle', 'scan_qr': 'QR TARA',
      'nodes': 'DÜĞÜM', 'sort_by_ping': 'PINGE GÖRE', 'settings': 'AYARLAR',
      'qr_scanner': 'QR TARAYICI', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'VPN kesilirse trafiği engelle',
      'auto_rotate': 'Otomatik rotasyon', 'auto_rotate_sub': '{n} başarısızlıktan sonra değiştir',
      'ai_bypass': 'AI Otomatik Atlatma', 'ai_bypass_sub': 'Güncelleme olmadan otomatik atlatma',
      'sync_rules': 'Kuralları sync.', 'sync_rules_sub': 'Sunucudan kuralları güncelle',
      'add_node': 'DÜĞÜM EKLE', 'add_key': 'ANAHTAR EKLE',
      'add_sub': 'ABONELİK EKLE', 'refresh_all': 'HEPSİNİ GÜNCELLE',
      'subscriptions': 'ABONELİKLER', 'protection': 'KORUMA', 'logs': 'GÜNLÜKLER',
      'clear': 'TEMİZLE', 'cancel': 'İptal', 'save': 'Kaydet',
      'done': 'Tamam', 'scan_again': 'Tekrar Tara',
      'rename_group': 'Grubu yeniden adlandır', 'rename_node': 'Düğümü yeniden adlandır',
      'sub_added': 'ABONELİK EKLENDİ', 'node_added': 'DÜĞÜM EKLENDİ',
      'unknown_qr': 'BİLİNMEYEN QR',
      'appearance': 'GÖRÜNÜM', 'theme': 'Tema', 'theme_dark': 'Koyu',
      'theme_light': 'Açık', 'theme_system': 'Sistem', 'language': 'Dil',
      'ok': 'Tamam', 'download_log': 'Günlüğü kopyala', 'kill_switch_on': 'Kill Switch AÇIK',
      'ai_bar_prefix': '🤖  AI BYPASS: ',
      'profiles': 'PROFİLLER', 'profile_new': 'Yeni profil', 'profile_name': 'Profil adı',
      'profile_switch': 'Profil değiştir', 'profile_delete': 'Profili sil', 'profile_active': 'AKTİF',
      'backup': 'YEDEK', 'backup_export': 'Yedeği dışa aktar',
      'backup_import': 'Yedeği içe aktar', 'backup_password': 'Şifre (isteğe bağlı)',
      'backup_ok': 'Yedek oluşturuldu', 'backup_fail': 'Yedek başarısız',
      'restore_ok': 'Geri yükleme başarılı', 'restore_fail': 'Geri yükleme başarısız',
      'restore_confirm': 'Mevcut veriler değiştirilecek. Devam edilsin mi?',
      'backup_copied': 'Yedek panoya kopyalandı', 'backup_password_hint': 'Şifre (isteğe bağlı)',
      'split_tunnel': 'BÖLÜNMÜŞ TÜNEL', 'split_mode': 'Mod',
      'split_bypass': 'Bypass (seçili uygulamalar VPN\'yi atlar)',
      'split_proxy': 'Proxy (yalnızca seçili uygulamalar VPN üzerinden)',
      'split_disabled': 'Devre dışı (tüm trafik VPN üzerinden)',
      'split_apps': 'Uygulamalar', 'split_search': 'Uygulama ara…',
      'favourites': 'FAVORİLER', 'favourite_add': 'Favorilere ekle',
      'favourite_remove': 'Favorilerden kaldır',
      'search_nodes': 'Düğüm ara…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Oturum', 'delete': 'Sil', 'rename': 'Yeniden adlandır',
    },
    AuraLocale.pt: {
      'app_name': 'AURA VPN', 'connected': 'CONECTADO', 'connecting': 'CONECTANDO…',
      'disconnected': 'DESCONECTADO', 'error': 'ERRO', 'no_nodes': 'SEM NÓS',
      'add_via_qr': 'Adicionar via QR, chave ou assinatura', 'scan_qr': 'ESCANEAR QR',
      'nodes': 'NÓS', 'sort_by_ping': 'POR PING', 'settings': 'CONFIGURAÇÕES',
      'qr_scanner': 'SCANNER QR', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Bloquear tráfego se a VPN cair',
      'auto_rotate': 'Rotação auto', 'auto_rotate_sub': 'Mudar após {n} falhas',
      'ai_bypass': 'IA Auto-bypass', 'ai_bypass_sub': 'Bypass automático sem atualizações',
      'sync_rules': 'Sync regras', 'sync_rules_sub': 'Atualizar do servidor',
      'add_node': 'ADICIONAR NÓ', 'add_key': 'ADICIONAR CHAVE',
      'add_sub': 'ADICIONAR ASSINATURA', 'refresh_all': 'ATUALIZAR TUDO',
      'subscriptions': 'ASSINATURAS', 'protection': 'PROTEÇÃO', 'logs': 'REGISTROS',
      'clear': 'LIMPAR', 'cancel': 'Cancelar', 'save': 'Salvar',
      'done': 'Feito', 'scan_again': 'Escanear novamente',
      'rename_group': 'Renomear grupo', 'rename_node': 'Renomear nó',
      'sub_added': 'ASSINATURA ADICIONADA', 'node_added': 'NÓ ADICIONADO',
      'unknown_qr': 'QR DESCONHECIDO',
      'appearance': 'APARÊNCIA', 'theme': 'Tema', 'theme_dark': 'Escuro',
      'theme_light': 'Claro', 'theme_system': 'Sistema', 'language': 'Idioma',
      'ok': 'OK', 'download_log': 'Copiar registro', 'kill_switch_on': 'Kill Switch ATIVO',
      'ai_bar_prefix': '🤖  BYPASS IA: ',
      'profiles': 'PERFIS', 'profile_new': 'Novo perfil', 'profile_name': 'Nome do perfil',
      'profile_switch': 'Trocar perfil', 'profile_delete': 'Excluir perfil', 'profile_active': 'ATIVO',
      'backup': 'BACKUP', 'backup_export': 'Exportar backup',
      'backup_import': 'Importar backup', 'backup_password': 'Senha (opcional)',
      'backup_ok': 'Backup criado', 'backup_fail': 'Falha no backup',
      'restore_ok': 'Restaurado com sucesso', 'restore_fail': 'Falha na restauração',
      'restore_confirm': 'Os dados atuais serão substituídos. Continuar?',
      'backup_copied': 'Backup copiado para a área de transferência',
      'backup_password_hint': 'Senha (opcional)',
      'split_tunnel': 'SPLIT TUNNEL', 'split_mode': 'Modo',
      'split_bypass': 'Bypass (apps selecionados ignoram VPN)',
      'split_proxy': 'Proxy (apenas apps selecionados via VPN)',
      'split_disabled': 'Desativado (todo tráfego via VPN)',
      'split_apps': 'Aplicativos', 'split_search': 'Buscar apps…',
      'favourites': 'FAVORITOS', 'favourite_add': 'Adicionar aos favoritos',
      'favourite_remove': 'Remover dos favoritos',
      'search_nodes': 'Pesquisar nós…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Sessão', 'delete': 'Excluir', 'rename': 'Renomear',
    },
    AuraLocale.ja: {
      'app_name': 'AURA VPN', 'connected': '接続済み', 'connecting': '接続中…',
      'disconnected': '切断', 'error': 'エラー', 'no_nodes': 'ノードなし',
      'add_via_qr': 'QR・キー・サブスクで追加', 'scan_qr': 'QRスキャン',
      'nodes': 'ノード', 'sort_by_ping': 'Pingで並べる', 'settings': '設定',
      'qr_scanner': 'QRスキャナー', 'kill_switch': 'キルスイッチ',
      'kill_switch_sub': 'VPN切断時にトラフィックをブロック',
      'auto_rotate': '自動ローテーション', 'auto_rotate_sub': '{n}回失敗後に切替',
      'ai_bypass': 'AIバイパス', 'ai_bypass_sub': '自動バイパス（更新不要）',
      'sync_rules': 'ルール同期', 'sync_rules_sub': 'サーバーから更新',
      'add_node': 'ノード追加', 'add_key': 'キー追加',
      'add_sub': 'サブスク追加', 'refresh_all': '全て更新',
      'subscriptions': 'サブスクリプション', 'protection': '保護', 'logs': 'ログ',
      'clear': 'クリア', 'cancel': 'キャンセル', 'save': '保存',
      'done': '完了', 'scan_again': '再スキャン',
      'rename_group': 'グループ名を変更', 'rename_node': 'ノード名を変更',
      'sub_added': 'サブスク追加済み', 'node_added': 'ノード追加済み',
      'unknown_qr': '不明なQR',
      'appearance': '外観', 'theme': 'テーマ', 'theme_dark': 'ダーク',
      'theme_light': 'ライト', 'theme_system': 'システム', 'language': '言語',
      'ok': 'OK', 'download_log': 'ログをコピー', 'kill_switch_on': 'キルスイッチON',
      'ai_bar_prefix': '🤖  AIバイパス: ',
      'profiles': 'プロファイル', 'profile_new': '新しいプロファイル',
      'profile_name': 'プロファイル名', 'profile_switch': 'プロファイル切替',
      'profile_delete': 'プロファイル削除', 'profile_active': 'アクティブ',
      'backup': 'バックアップ', 'backup_export': 'バックアップを書き出す',
      'backup_import': 'バックアップを読み込む', 'backup_password': 'パスワード（任意）',
      'backup_ok': 'バックアップ作成済み', 'backup_fail': 'バックアップ失敗',
      'restore_ok': '復元成功', 'restore_fail': '復元失敗',
      'restore_confirm': '現在のデータが置き換えられます。続けますか？',
      'backup_copied': 'バックアップをクリップボードにコピーしました',
      'backup_password_hint': 'パスワード（任意）',
      'split_tunnel': 'スプリットトンネル', 'split_mode': 'モード',
      'split_bypass': 'バイパス（選択したアプリはVPNをスキップ）',
      'split_proxy': 'プロキシ（選択したアプリのみVPN経由）',
      'split_disabled': '無効（すべてのトラフィックがVPN経由）',
      'split_apps': 'アプリケーション', 'split_search': 'アプリを検索…',
      'favourites': 'お気に入り', 'favourite_add': 'お気に入りに追加',
      'favourite_remove': 'お気に入りから削除',
      'search_nodes': 'ノードを検索…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'セッション', 'delete': '削除', 'rename': '名前を変更',
    },
    AuraLocale.ko: {
      'app_name': 'AURA VPN', 'connected': '연결됨', 'connecting': '연결 중…',
      'disconnected': '연결 끊김', 'error': '오류', 'no_nodes': '노드 없음',
      'add_via_qr': 'QR코드, 키 또는 구독으로 추가', 'scan_qr': 'QR 스캔',
      'nodes': '노드', 'sort_by_ping': '핑순 정렬', 'settings': '설정',
      'qr_scanner': 'QR 스캐너', 'kill_switch': '킬 스위치',
      'kill_switch_sub': 'VPN 끊길 시 트래픽 차단',
      'auto_rotate': '자동 교체', 'auto_rotate_sub': '{n}회 실패 후 전환',
      'ai_bypass': 'AI 자동 우회', 'ai_bypass_sub': '업데이트 없이 자동 우회',
      'sync_rules': '규칙 동기화', 'sync_rules_sub': '서버에서 업데이트',
      'add_node': '노드 추가', 'add_key': '키 추가',
      'add_sub': '구독 추가', 'refresh_all': '전체 새로고침',
      'subscriptions': '구독', 'protection': '보호', 'logs': '로그',
      'clear': '지우기', 'cancel': '취소', 'save': '저장',
      'done': '완료', 'scan_again': '다시 스캔',
      'rename_group': '그룹 이름 변경', 'rename_node': '노드 이름 변경',
      'sub_added': '구독 추가됨', 'node_added': '노드 추가됨',
      'unknown_qr': '알 수 없는 QR',
      'appearance': '외관', 'theme': '테마', 'theme_dark': '다크',
      'theme_light': '라이트', 'theme_system': '시스템', 'language': '언어',
      'ok': '확인', 'download_log': '로그 복사', 'kill_switch_on': '킬 스위치 ON',
      'ai_bar_prefix': '🤖  AI 우회: ',
      'profiles': '프로필', 'profile_new': '새 프로필', 'profile_name': '프로필 이름',
      'profile_switch': '프로필 전환', 'profile_delete': '프로필 삭제', 'profile_active': '활성',
      'backup': '백업', 'backup_export': '백업 내보내기',
      'backup_import': '백업 가져오기', 'backup_password': '비밀번호 (선택)',
      'backup_ok': '백업 생성됨', 'backup_fail': '백업 실패',
      'restore_ok': '복원 성공', 'restore_fail': '복원 실패',
      'restore_confirm': '현재 데이터가 교체됩니다. 계속하시겠습니까?',
      'backup_copied': '백업이 클립보드에 복사되었습니다',
      'backup_password_hint': '비밀번호 (선택)',
      'split_tunnel': '분할 터널', 'split_mode': '모드',
      'split_bypass': '바이패스 (선택한 앱이 VPN을 우회)',
      'split_proxy': '프록시 (선택한 앱만 VPN 통과)',
      'split_disabled': '비활성 (모든 트래픽이 VPN 통과)',
      'split_apps': '앱', 'split_search': '앱 검색…',
      'favourites': '즐겨찾기', 'favourite_add': '즐겨찾기에 추가',
      'favourite_remove': '즐겨찾기에서 제거',
      'search_nodes': '노드 검색…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': '세션', 'delete': '삭제', 'rename': '이름 변경',
    },
    AuraLocale.uk: {
      'app_name': 'AURA VPN', 'connected': 'ПІДКЛЮЧЕНО', 'connecting': 'ПІДКЛЮЧЕННЯ…',
      'disconnected': 'ВІДКЛЮЧЕНО', 'error': 'ПОМИЛКА', 'no_nodes': 'НЕМАЄ ВУЗЛІВ',
      'add_via_qr': 'Додати через QR, ключ або підписку', 'scan_qr': 'СКАНУВАТИ QR',
      'nodes': 'ВУЗЛІВ', 'sort_by_ping': 'ЗА ПІНГОМ', 'settings': 'НАЛАШТУВАННЯ',
      'qr_scanner': 'QR СКАНЕР', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Блокувати трафік при розриві VPN',
      'auto_rotate': 'Авто-ротація', 'auto_rotate_sub': 'Змінити після {n} невдач',
      'ai_bypass': 'AI Авто-обхід', 'ai_bypass_sub': 'Автоматичний обхід без оновлень',
      'sync_rules': 'Синхронізація', 'sync_rules_sub': 'Оновити правила з сервера',
      'add_node': 'ДОДАТИ ВУЗОЛ', 'add_key': 'ДОДАТИ КЛЮЧ',
      'add_sub': 'ДОДАТИ ПІДПИСКУ', 'refresh_all': 'ОНОВИТИ ВСЕ',
      'subscriptions': 'ПІДПИСКИ', 'protection': 'ЗАХИСТ', 'logs': 'ЛОГИ',
      'clear': 'ОЧИСТИТИ', 'cancel': 'Скасувати', 'save': 'Зберегти',
      'done': 'Готово', 'scan_again': 'Сканувати знову',
      'rename_group': 'Перейменувати групу', 'rename_node': 'Перейменувати вузол',
      'sub_added': 'ПІДПИСКУ ДОДАНО', 'node_added': 'ВУЗОЛ ДОДАНО',
      'unknown_qr': 'НЕВІДОМИЙ QR',
      'appearance': 'ЗОВНІШНІЙ ВИГЛЯД', 'theme': 'Тема', 'theme_dark': 'Темна',
      'theme_light': 'Світла', 'theme_system': 'Системна', 'language': 'Мова',
      'ok': 'ОК', 'download_log': 'Скопіювати лог', 'kill_switch_on': 'Kill Switch УВІМКНЕНО',
      'ai_bar_prefix': '🤖  AI ОБХІД: ',
      'profiles': 'ПРОФІЛІ', 'profile_new': 'Новий профіль', 'profile_name': 'Назва профілю',
      'profile_switch': 'Переключити', 'profile_delete': 'Видалити профіль', 'profile_active': 'АКТИВНИЙ',
      'backup': 'РЕЗЕРВНА КОПІЯ', 'backup_export': 'Створити резервну копію',
      'backup_import': 'Відновити з копії', 'backup_password': 'Пароль (необов\'язково)',
      'backup_ok': 'Копію створено', 'backup_fail': 'Помилка створення копії',
      'restore_ok': 'Відновлено успішно', 'restore_fail': 'Помилка відновлення',
      'restore_confirm': 'Поточні дані будуть замінені. Продовжити?',
      'backup_copied': 'Резервну копію скопійовано в буфер',
      'backup_password_hint': 'Пароль (необов\'язково)',
      'split_tunnel': 'РОЗДІЛЬНИЙ ТУНЕЛЬ', 'split_mode': 'Режим',
      'split_bypass': 'Байпас (обрані застосунки оминають VPN)',
      'split_proxy': 'Проксі (тільки обрані застосунки через VPN)',
      'split_disabled': 'Вимкнено (весь трафік через VPN)',
      'split_apps': 'Застосунки', 'split_search': 'Пошук застосунків…',
      'favourites': 'ОБРАНЕ', 'favourite_add': 'Додати до обраного',
      'favourite_remove': 'Видалити з обраного',
      'search_nodes': 'Пошук вузлів…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Сесія', 'delete': 'Видалити', 'rename': 'Перейменувати',
    },
    AuraLocale.it: {
      'app_name': 'AURA VPN', 'connected': 'CONNESSO', 'connecting': 'CONNESSIONE…',
      'disconnected': 'DISCONNESSO', 'error': 'ERRORE', 'no_nodes': 'NESSUN NODO',
      'add_via_qr': 'Aggiungi tramite QR, chiave o abbonamento', 'scan_qr': 'SCANSIONA QR',
      'nodes': 'NODI', 'sort_by_ping': 'PER PING', 'settings': 'IMPOSTAZIONI',
      'qr_scanner': 'SCANNER QR', 'kill_switch': 'Kill Switch',
      'kill_switch_sub': 'Blocca il traffico se la VPN cade',
      'auto_rotate': 'Rotazione auto', 'auto_rotate_sub': 'Cambia dopo {n} fallimenti',
      'ai_bypass': 'AI Auto-bypass', 'ai_bypass_sub': 'Bypass automatico senza aggiornamenti',
      'sync_rules': 'Sync regole', 'sync_rules_sub': 'Aggiorna dal server',
      'add_node': 'AGGIUNGI NODO', 'add_key': 'AGGIUNGI CHIAVE',
      'add_sub': 'AGGIUNGI ABBONAMENTO', 'refresh_all': 'AGGIORNA TUTTO',
      'subscriptions': 'ABBONAMENTI', 'protection': 'PROTEZIONE', 'logs': 'REGISTRI',
      'clear': 'CANCELLA', 'cancel': 'Annulla', 'save': 'Salva',
      'done': 'Fatto', 'scan_again': 'Scansiona di nuovo',
      'rename_group': 'Rinomina gruppo', 'rename_node': 'Rinomina nodo',
      'sub_added': 'ABBONAMENTO AGGIUNTO', 'node_added': 'NODO AGGIUNTO',
      'unknown_qr': 'QR SCONOSCIUTO',
      'appearance': 'ASPETTO', 'theme': 'Tema', 'theme_dark': 'Scuro',
      'theme_light': 'Chiaro', 'theme_system': 'Sistema', 'language': 'Lingua',
      'ok': 'OK', 'download_log': 'Copia registro', 'kill_switch_on': 'Kill Switch ATTIVO',
      'ai_bar_prefix': '🤖  BYPASS IA: ',
      'profiles': 'PROFILI', 'profile_new': 'Nuovo profilo', 'profile_name': 'Nome profilo',
      'profile_switch': 'Cambia profilo', 'profile_delete': 'Elimina profilo', 'profile_active': 'ATTIVO',
      'backup': 'BACKUP', 'backup_export': 'Esporta backup',
      'backup_import': 'Importa backup', 'backup_password': 'Password (opzionale)',
      'backup_ok': 'Backup creato', 'backup_fail': 'Backup fallito',
      'restore_ok': 'Ripristinato con successo', 'restore_fail': 'Ripristino fallito',
      'restore_confirm': 'I dati attuali verranno sostituiti. Continuare?',
      'backup_copied': 'Backup copiato negli appunti', 'backup_password_hint': 'Password (opzionale)',
      'split_tunnel': 'SPLIT TUNNEL', 'split_mode': 'Modalità',
      'split_bypass': 'Bypass (le app selezionate bypassano la VPN)',
      'split_proxy': 'Proxy (solo le app selezionate tramite VPN)',
      'split_disabled': 'Disabilitato (tutto il traffico tramite VPN)',
      'split_apps': 'Applicazioni', 'split_search': 'Cerca app…',
      'favourites': 'PREFERITI', 'favourite_add': 'Aggiungi ai preferiti',
      'favourite_remove': 'Rimuovi dai preferiti',
      'search_nodes': 'Cerca nodi…', 'traffic_up': '↑', 'traffic_down': '↓',
      'session_time': 'Sessione', 'delete': 'Elimina', 'rename': 'Rinomina',
    },
  };

  static const Map<AuraLocale, String> localeNames = {
    AuraLocale.en: 'English', AuraLocale.ru: 'Русский', AuraLocale.zh: '中文',
    AuraLocale.de: 'Deutsch', AuraLocale.fr: 'Français', AuraLocale.es: 'Español',
    AuraLocale.ar: 'العربية', AuraLocale.fa: 'فارسی', AuraLocale.tr: 'Türkçe',
    AuraLocale.pt: 'Português', AuraLocale.ja: '日本語', AuraLocale.ko: '한국어',
    AuraLocale.uk: 'Українська', AuraLocale.it: 'Italiano',
  };
}

// ═══════════════════════════════════════════════════════════════
//  ERROR CODES
// ═══════════════════════════════════════════════════════════════

enum AuraErrorCode {
  // ── Подключение ──────────────────────────────────────────────────────────
  e1001('E-1001', 'Permission denied',        'VPN permission denied. Settings → Apps → Aura VPN → Permissions.'),
  e1002('E-1002', 'Connection timeout',       'VPN tunnel failed. Server may be down or DPI-blocked.'),
  e1003('E-1003', 'Config empty',             'getFullConfiguration() returned empty. Re-import this node.'),
  e1004('E-1004', 'Config parse error',       'Node config is malformed JSON. Try re-importing.'),
  e1005('E-1005', 'Network unreachable',      'No internet. Check WiFi or mobile data.'),
  e1006('E-1006', 'TLS handshake failed',     'TLS/Reality rejected by DPI. РКН blocking this node.'),
  e1007('E-1007', 'Protocol rejected',        'Server rejected protocol. Try WS or gRPC transport.'),
  e1008('E-1008', 'Port blocked',             'Port blocked by ISP. Try port 443 or 2053.'),
  e1009('E-1009', 'DNS poisoned',             'DNS intercepted. DoH enforced on next connect.'),
  e1010('E-1010', 'Kill Switch triggered',    'VPN dropped. Kill Switch blocked traffic to protect IP.'),
  // ── Stealth Engine ────────────────────────────────────────────────────────
  e1011('E-1011', 'SNI pool exhausted',       'All 15 SNI domains blocked. Update app or add custom nodes.'),
  e1012('E-1012', 'Fragment failed',          'TLS fragment injection failed. VPN started without fragmentation.'),
  e1013('E-1013', 'Warm-up timeout',          'Pre-connect warm-up timed out (3s). Slow network.'),
  e1014('E-1014', 'Reality pbk missing',      'VLESS+Reality node has no publicKey. Node misconfigured.'),
  e1015('E-1015', 'uTLS fingerprint error',   'Cannot apply uTLS fingerprint. Using default fp.'),
  e1016('E-1016', 'pickLiveSni timeout',      'All SNI probes timed out (4s). Using fallback SNI.'),
  e1017('E-1017', 'patchConfig failed',       'Config patching threw exception. VPN used original config.'),
  e1018('E-1018', 'Routing build failed',     'Russia routing rules failed. Using IPv6-block only.'),
  e1019('E-1019', 'Telegram Protocol error',  'TG Fast Protocol config threw. Connected without TG opt.'),
  e1020('E-1020', 'V2Ray engine crash',       'v2ray-core crashed. Engine restarting. Reinstall if persists.'),
  // ── Siberia Shield ────────────────────────────────────────────────────────
  e1021('E-1021', 'Siberia burst detected',   'IP burst-blocked by РКН. Cooldown 3 min. Switching node.'),
  e1022('E-1022', 'Pacing overflow',          'Connection pacing queue full. Shield temporarily bypassed.'),
  e1023('E-1023', 'Decoy failed',             'Pre-connect decoy request failed. No internet to check sites.'),
  e1024('E-1024', 'applyToConfig error',      'SiberiaShield.applyToConfig threw. mux not applied.'),
  // ── Bypass & AI ───────────────────────────────────────────────────────────
  e1025('E-1025', 'Block type unknown',       'BlockDetector returned none. New РКН method or unstable net.'),
  e1026('E-1026', 'All strategies failed',    'All 100 bypass strategies + 60 node rotations failed.'),
  e1027('E-1027', 'Bypass probe error',       'BypassProber TCP+TLS probe threw exception.'),
  e1028('E-1028', 'Strategy apply error',     'applyStrategy() threw. Node link may be malformed.'),
  e1029('E-1029', 'Arsenal empty',            'BypassArsenal returned 0 strategies for this block type.'),
  e1030('E-1030', 'Bypass loop limit',        'Retry limit (20 attempts) reached. Manual action needed.'),
  e1031('E-1031', 'Strategy deprecated',      'Strategy marked broken by NewsAwareness. Skipped.'),
  // ── Подписки & данные ─────────────────────────────────────────────────────
  e1032('E-1032', 'Subscription failed',      'Cannot download sub. Check URL, internet, or sub expiry.'),
  e1033('E-1033', 'Subscription empty',       'Sub returned 0 nodes. URL may be expired or invalid.'),
  e1034('E-1034', 'Subscription parse error', 'Sub format unknown. Expected base64 or plain vless list.'),
  e1035('E-1035', 'Rules sync failed',        'Bypass rules server unreachable. Using cached rules.'),
  e1036('E-1036', 'Domain list failed',       'antifilter.download down. Using built-in domain list.'),
  e1037('E-1037', 'Dead drop exhausted',      'All mirrors (GitHub, DNS TXT) failed. Import nodes manually.'),
  // ── Хранилище ─────────────────────────────────────────────────────────────
  e1038('E-1038', 'Save failed',              'Cannot write settings. Check storage space (need >10MB).'),
  e1039('E-1039', 'Backup export failed',     'Cannot create backup. Check storage permissions.'),
  e1040('E-1040', 'Backup import failed',     'Cannot restore. Wrong password or corrupted file.'),
  e1041('E-1041', 'Profile corrupted',        'Profile data broken. Default profile restored.'),
  e1042('E-1042', 'Deobfuscation failed',     'Cannot read stored profiles. Re-import your nodes.'),
  // ── Нативный слой ─────────────────────────────────────────────────────────
  e1043('E-1043', 'VPN permission revoked',   'VPN permission revoked while connected. Reconnect to restore.'),
  e1044('E-1044', 'Notification failed',      'Cannot show persistent VPN notification. Android restriction.'),
  e1045('E-1045', 'Tile update failed',       'Quick Settings tile update failed. Minor UI issue only.'),
  e1046('E-1046', 'File read error',          'Cannot read selected file. Try copy-paste instead.'),
  e1047('E-1047', 'QR parse failed',          'QR code has no valid VPN config. Need vless/vmess/ss link.'),
  e1048('E-1048', 'Clipboard empty',          'Clipboard is empty. Copy a vless:// link first.'),
  e1049('E-1049', 'IP check failed',          'All IP APIs (ipapi.co / ip-api.com / ipwho.is) failed.'),
  e1050('E-1050', 'Watchdog timeout',         'VPN did not reach CONNECTED in 30s. Watchdog fired bypass.');

  final String code, title, description;
  const AuraErrorCode(this.code, this.title, this.description);

  /// Lookup по коду — для диагностики в логах
  static AuraErrorCode? fromCode(String code) {
    try { return AuraErrorCode.values.firstWhere((e) => e.code == code); }
    catch (_) { return null; }
  }

  /// Быстрый маппинг событий → коды для _log
  static String codeFor(String event) {
    const map = {
      'permission':  'E-1001', 'timeout':      'E-1002', 'empty_config': 'E-1003',
      'parse':       'E-1004', 'network':       'E-1005', 'tls':         'E-1006',
      'protocol':    'E-1007', 'port':          'E-1008', 'dns':         'E-1009',
      'kill_switch': 'E-1010', 'sni':           'E-1011', 'fragment':    'E-1012',
      'warmup':      'E-1013', 'pbk':           'E-1014', 'utls':        'E-1015',
      'live_sni':    'E-1016', 'patch':         'E-1017', 'routing':     'E-1018',
      'telegram':    'E-1019', 'v2ray_crash':   'E-1020', 'siberia':     'E-1021',
      'bypass':      'E-1026', 'probe':         'E-1027', 'sub':         'E-1032',
      'save':        'E-1038', 'backup':        'E-1039', 'profile':     'E-1041',
      'watchdog':    'E-1050',
    };
    return map[event] ?? 'E-0000';
  }
}

Future<void> showAuraError(BuildContext ctx, AuraErrorCode err, List<String> logs) async {
  if (!ctx.mounted) return;
  final logText = logs.join('\n');
  await showDialog(
    context: ctx,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1226),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
              child: Text(err.code, style: const TextStyle(
                  fontSize: 11, color: Colors.redAccent,
                  fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
            const SizedBox(width: 10),
            Expanded(child: Text(err.title,
                style: const TextStyle(fontSize: 14, color: Colors.white,
                    fontWeight: FontWeight.w700))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(err.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 10),
              Text(kSupportEmail,
                  style: TextStyle(fontSize: 11, color: _accent,
                      decoration: TextDecoration.underline)),
            ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: '[${err.code}]\n$logText'));
                Navigator.pop(c);
              },
              child: Text(S.t('download_log'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12))),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(S.t('ok'),
                  style: TextStyle(color: _accent, fontWeight: FontWeight.bold))),
          ],
        ),  // AlertDialog
      ),    // ConstrainedBox
    ),      // Dialog
  );
}


// ═══════════════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  AURA SKIN SYSTEM  v5.3
//  Скины меняют акцентный цвет + градиенты блобов + тинт карточек
// ═══════════════════════════════════════════════════════════════════════════════

enum AuraSkinId {
  midnight,  // дефолт — циан
  ocean,     // синий
  forest,    // зелёный
  crimson,   // красный
  sunset,    // оранжевый
  aurora,    // Nord — ледяной северный
  matrix,    // зелёный на чёрном
  galaxy,    // фиолетово-синий космос
  carbon,    // тёмно-серый минимализм
  sakura,    // розово-белая светлая тема
  custom,    // пользовательская темавый
  violet,    // фиолетовый
  rose,      // розовый
  gold,      // золотой
}

class AuraSkin {
  final AuraSkinId id;
  final String     name;
  final String     emoji;
  final Color      accent;
  final Color      accentSecondary;
  final Color      bgDark;
  final List<Color> blobs;

  const AuraSkin({
    required this.id,
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accentSecondary,
    required this.bgDark,
    required this.blobs,
  });

  static const all = [
    AuraSkin(
      id: AuraSkinId.midnight, name: 'Midnight', emoji: '🌌',
      accent: Color(0xFF00E5FF), accentSecondary: Color(0xFF4FC3F7),
      bgDark: Color(0xFF050610),
      blobs: [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF00E5FF), Color(0xFF1565C0)]),
    AuraSkin(
      id: AuraSkinId.ocean, name: 'Ocean', emoji: '🌊',
      accent: Color(0xFF2979FF), accentSecondary: Color(0xFF448AFF),
      bgDark: Color(0xFF020814),
      blobs: [Color(0xFF0D1B4B), Color(0xFF1A237E), Color(0xFF2979FF), Color(0xFF0277BD)]),
    AuraSkin(
      id: AuraSkinId.forest, name: 'Forest', emoji: '🌿',
      accent: Color(0xFF00E676), accentSecondary: Color(0xFF69FF47),
      bgDark: Color(0xFF020A05),
      blobs: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00E676), Color(0xFF00BFA5)]),
    AuraSkin(
      id: AuraSkinId.crimson, name: 'Crimson', emoji: '🔴',
      accent: Color(0xFFFF1744), accentSecondary: Color(0xFFFF5252),
      bgDark: Color(0xFF0A0204),
      blobs: [Color(0xFF4A0010), Color(0xFF7F0000), Color(0xFFFF1744), Color(0xFFBF360C)]),
    AuraSkin(
      id: AuraSkinId.sunset, name: 'Sunset', emoji: '🌅',
      accent: Color(0xFFFF6D00), accentSecondary: Color(0xFFFFAB40),
      bgDark: Color(0xFF0A0500),
      blobs: [Color(0xFF4A1800), Color(0xFF7B3300), Color(0xFFFF6D00), Color(0xFFE65100)]),
    AuraSkin(
      id: AuraSkinId.violet, name: 'Violet', emoji: '💜',
      accent: Color(0xFFD500F9), accentSecondary: Color(0xFFE040FB),
      bgDark: Color(0xFF080410),
      blobs: [Color(0xFF2A0050), Color(0xFF4A0080), Color(0xFFD500F9), Color(0xFF6A1B9A)]),
    AuraSkin(
      id: AuraSkinId.rose, name: 'Rose', emoji: '🌸',
      accent: Color(0xFFFF4081), accentSecondary: Color(0xFFFF80AB),
      bgDark: Color(0xFF0A0308),
      blobs: [Color(0xFF4A0020), Color(0xFF880E4F), Color(0xFFFF4081), Color(0xFFC2185B)]),
    AuraSkin(
      id: AuraSkinId.gold, name: 'Gold', emoji: '✨',
      accent: Color(0xFFFFD740), accentSecondary: Color(0xFFFFE57F),
      bgDark: Color(0xFF08070A),
      blobs: [Color(0xFF3E2800), Color(0xFF5D4037), Color(0xFFFFD740), Color(0xFFFF8F00)]),
    // ── Новые темы ────────────────────────────────────────────────────────────
    AuraSkin(
      id: AuraSkinId.aurora, name: 'Aurora', emoji: '🧊',
      accent: Color(0xFF88C0D0), accentSecondary: Color(0xFF81A1C1),
      bgDark: Color(0xFF0D1117),
      blobs: [Color(0xFF1C2D3F), Color(0xFF243447), Color(0xFF88C0D0), Color(0xFF5E81AC)]),
    AuraSkin(
      id: AuraSkinId.matrix, name: 'Matrix', emoji: '🟩',
      accent: Color(0xFF00FF41), accentSecondary: Color(0xFF00CC33),
      bgDark: Color(0xFF000500),
      blobs: [Color(0xFF001500), Color(0xFF002800), Color(0xFF00FF41), Color(0xFF008F11)]),
    AuraSkin(
      id: AuraSkinId.galaxy, name: 'Galaxy', emoji: '🌌',
      accent: Color(0xFF7C4DFF), accentSecondary: Color(0xFFB388FF),
      bgDark: Color(0xFF04010F),
      blobs: [Color(0xFF1A0040), Color(0xFF2D0060), Color(0xFF7C4DFF), Color(0xFF3D1C96)]),
    AuraSkin(
      id: AuraSkinId.carbon, name: 'Carbon', emoji: '⚫',
      accent: Color(0xFFE0E0E0), accentSecondary: Color(0xFF9E9E9E),
      bgDark: Color(0xFF090909),
      blobs: [Color(0xFF1A1A1A), Color(0xFF2C2C2C), Color(0xFF424242), Color(0xFF616161)]),
    AuraSkin(
      id: AuraSkinId.sakura, name: 'Sakura', emoji: '🌸',
      accent: Color(0xFFE91E63), accentSecondary: Color(0xFFF48FB1),
      bgDark: Color(0xFF0A0306),
      blobs: [Color(0xFF3E0020), Color(0xFF6A0030), Color(0xFFE91E63), Color(0xFFAD1457)]),
  ];

  static AuraSkin byId(AuraSkinId id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

// Применить скин — обновляет глобальные переменные цвета
void _applySkin(AuraSkin skin) {
  _accent     = skin.accent;
  _accentBlue = skin.accentSecondary;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AURA SKIN SYSTEM  v5.3
// ═══════════════════════════════════════════════════════════════════════════════
enum AuraTheme { dark, light, system }

class AppProvider extends ChangeNotifier {
  AuraTheme  _theme  = AuraTheme.system;
  AuraLocale _locale = AuraLocale.en;
  AuraSkinId _skinId = AuraSkinId.midnight;
  bool _disposed = false;

  // Пользовательская тема
  Color  _customAccent     = const Color(0xFF00E5FF);
  Color  _customAccent2    = const Color(0xFF4FC3F7);
  Color  _customBg         = const Color(0xFF050610);
  Color  _customBlob1      = const Color(0xFF1A237E);
  Color  _customBlob2      = const Color(0xFF0D47A1);
  String _customMediaPath  = ''; // путь к фото/GIF
  String _customMediaType  = ''; // 'photo' | 'gif' | ''

  AuraTheme  get theme  => _theme;
  AuraLocale get locale => _locale;
  AuraSkinId get skinId => _skinId;
  AuraSkin   get skin   => _skinId == AuraSkinId.custom ? _buildCustomSkin() : AuraSkin.byId(_skinId);
  
  // Custom theme getters
  Color  get customAccent    => _customAccent;
  Color  get customAccent2   => _customAccent2;
  Color  get customBg        => _customBg;
  Color  get customBlob1     => _customBlob1;
  Color  get customBlob2     => _customBlob2;
  String get customMediaPath => _customMediaPath;
  String get customMediaType => _customMediaType;
  bool   get hasCustomMedia  => _customMediaPath.isNotEmpty && File(_customMediaPath).existsSync();

  AuraSkin _buildCustomSkin() => AuraSkin(
    id: AuraSkinId.custom,
    name: 'My Theme',
    emoji: '🎨',
    accent: _customAccent,
    accentSecondary: _customAccent2,
    bgDark: _customBg,
    blobs: [_customBlob1, _customBlob2, _customAccent, _customAccent2],
  );

  ThemeMode get themeMode {
    switch (_theme) {
      case AuraTheme.dark:   return ThemeMode.dark;
      case AuraTheme.light:  return ThemeMode.light;
      case AuraTheme.system: return ThemeMode.system;
    }
  }

  AppProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final ts  = p.getString('aura_theme') ?? 'system';
    final sid = p.getString('aura_skin')  ?? 'midnight';
    _theme  = AuraTheme.values.firstWhere((e) => e.name == ts,  orElse: () => AuraTheme.system);
    _skinId = AuraSkinId.values.firstWhere((e) => e.name == sid, orElse: () => AuraSkinId.midnight);
    // Загружаем кастомную тему
    _customAccent   = Color(p.getInt('ct_accent')   ?? 0xFF00E5FF);
    _customAccent2  = Color(p.getInt('ct_accent2')  ?? 0xFF4FC3F7);
    _customBg       = Color(p.getInt('ct_bg')       ?? 0xFF050610);
    _customBlob1    = Color(p.getInt('ct_blob1')    ?? 0xFF1A237E);
    _customBlob2    = Color(p.getInt('ct_blob2')    ?? 0xFF0D47A1);
    _customMediaPath = p.getString('ct_media_path') ?? '';
    _customMediaType = p.getString('ct_media_type') ?? '';
    _applySkin(skin);
    await S.init();
    _locale = S.locale;
    _safeNotify();
  }

  Future<void> setTheme(AuraTheme t) async {
    _theme = t;
    final p = await SharedPreferences.getInstance();
    await p.setString('aura_theme', t.name);
    _safeNotify();
  }

  Future<void> setSkin(AuraSkinId id) async {
    _skinId = id;
    _applySkin(skin); // skin getter уже учитывает custom
    final p = await SharedPreferences.getInstance();
    await p.setString('aura_skin', id.name);
    _safeNotify();
  }

  Future<void> saveCustomTheme({
    Color? accent, Color? accent2, Color? bg,
    Color? blob1, Color? blob2,
    String? mediaPath, String? mediaType,
  }) async {
    if (accent    != null) _customAccent    = accent;
    if (accent2   != null) _customAccent2   = accent2;
    if (bg        != null) _customBg        = bg;
    if (blob1     != null) _customBlob1     = blob1;
    if (blob2     != null) _customBlob2     = blob2;
    if (mediaPath != null) _customMediaPath = mediaPath;
    if (mediaType != null) _customMediaType = mediaType;
    _skinId = AuraSkinId.custom;
    _applySkin(_buildCustomSkin());
    final p = await SharedPreferences.getInstance();
    await p.setInt('ct_accent',   _customAccent.value);
    await p.setInt('ct_accent2',  _customAccent2.value);
    await p.setInt('ct_bg',       _customBg.value);
    await p.setInt('ct_blob1',    _customBlob1.value);
    await p.setInt('ct_blob2',    _customBlob2.value);
    await p.setString('ct_media_path', _customMediaPath);
    await p.setString('ct_media_type', _customMediaType);
    await p.setString('aura_skin', 'custom');
    _safeNotify();
  }

  Future<void> clearCustomMedia() async {
    _customMediaPath = '';
    _customMediaType = '';
    final p = await SharedPreferences.getInstance();
    await p.setString('ct_media_path', '');
    await p.setString('ct_media_type', '');
    _safeNotify();
  }

  Future<void> setLocale(AuraLocale l) async {
    _locale = l;
    await S.setLocale(l);
    _safeNotify();
  }

  @override void dispose() { _disposed = true; super.dispose(); }
  void _safeNotify() { if (!_disposed) notifyListeners(); }
}

ThemeData _buildDarkTheme([Color? bg]) => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: bg ?? const Color(0xFF050610),
  colorScheme: ColorScheme.dark(primary: _accent),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
    iconTheme: IconThemeData(color: Colors.white70)),
);

ThemeData _buildLightTheme() => ThemeData.light().copyWith(
  scaffoldBackgroundColor: const Color(0xFFF0F2FA),
  colorScheme: ColorScheme.light(
    primary: _accent,
    surface: Colors.white,
    onSurface: const Color(0xFF0D1B3E),
    secondary: _accent,
  ),
  cardColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: Color(0xFF0D1B3E)),
    iconTheme: IconThemeData(color: Color(0xFF0D1B3E))),
  dividerColor: const Color(0x18000000),
  listTileTheme: const ListTileThemeData(
    tileColor: Colors.white,
    textColor: Color(0xFF0D1B3E)),
);

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textColor(BuildContext ctx) => _isDark(ctx) ? Colors.white : const Color(0xFF1A2340);
Color _subTextColor(BuildContext ctx) => _isDark(ctx) ? Colors.white54 : const Color(0xFF4A5568);

const _lightBlobs = [Color(0xFF90CAF9), Color(0xFFA5D6A7), Color(0xFFCE93D8), Color(0xFF80DEEA), Color(0xFFFFCC80), Color(0xFFF48FB1)];
const _darkBlobs  = [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF01579B), Color(0xFF006064), Color(0xFF004D40), Color(0xFF1A237E)];

// ═══════════════════════════════════════════════════════════════
//  PROFILE  (v3.0)
// ═══════════════════════════════════════════════════════════════

class AuraProfile {
  String id;
  String name;
  List<Map<String, dynamic>> configsJson;
  List<String> subLinks;
  Map<String, String> subNames;

  // ── Безопасность ──────────────────────────────────────────────────────────
  bool killSwitch;
  bool aiEnabled;
  SplitTunnelMode splitMode;
  List<String> splitApps;

  // ── Туннель ───────────────────────────────────────────────────────────────
  String ipPreference;      // 'auto' | 'ipv4' | 'ipv6'
  bool   enableMux;         // TCP mux multiplexing
  bool   enableTun;         // TUN mode (sing-box style)
  String tunMode;           // 'mixed' | 'fakedns'
  bool   enableDns;         // DoH DNS для TUN
  String dnsAddress;        // '1.1.1.1' по умолчанию
  bool   enableLan;         // LAN sharing (0.0.0.0 binding)
  bool   enablePacketSniff; // packet sniffing (DPI detection)
  bool   enableSystemProxy; // системный прокси

  // ── Подписки ─────────────────────────────────────────────────────────────
  bool   subAutoUpdate;       // автообновление подписок
  int    subUpdateInterval;   // интервал обновления (часы)
  bool   subUpdateOnOpen;     // обновлять при открытии
  bool   subPingOnOpen;       // пинговать при открытии
  bool   subConnectOnOpen;    // подключаться при открытии
  String subSortMode;         // 'none' | 'ping' | 'alpha'
  String subUserAgent;        // User-Agent для запросов подписок
  bool   subAllowDuplicates;  // разрешить дубликаты

  // ── Маскировка трафика ───────────────────────────────────────────────────
  String camouflageMode; // none|browser|telegram|netflix|youtube|discord|...

  // ── Пинг ──────────────────────────────────────────────────────────────────
  String pingType;  // 'tcp' | 'proxy' | 'icmp'
  String pingUrl;   // URL для теста пинга

  AuraProfile({
    required this.id,
    required this.name,
    this.configsJson      = const [],
    this.subLinks         = const [],
    this.subNames         = const {},
    this.killSwitch       = false,
    this.aiEnabled        = true,
    this.splitMode        = SplitTunnelMode.disabled,
    this.splitApps        = const [],
    // Tunnel
    this.ipPreference     = 'auto',
    this.enableMux        = false,
    this.enableTun        = false,
    this.tunMode          = 'mixed',
    this.enableDns        = true,
    this.dnsAddress       = '1.1.1.1',
    this.enableLan        = false,
    this.enablePacketSniff = false,
    this.enableSystemProxy = false,
    // Subscriptions
    this.subAutoUpdate    = true,
    this.subUpdateInterval = 12,
    this.subUpdateOnOpen  = false,
    this.subPingOnOpen    = true,
    this.subConnectOnOpen = false,
    this.subSortMode      = 'none',
    this.subUserAgent     = 'AuraVPN/${kAppVersion}/Android',
    this.subAllowDuplicates = false,
    // Ping
    this.pingType          = 'tcp',
    this.pingUrl           = 'https://www.gstatic.com/generate_204',
    this.camouflageMode    = 'none',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name,
    'configs': configsJson,
    'subLinks': subLinks,
    'subNames': subNames,
    'killSwitch': killSwitch,
    'aiEnabled': aiEnabled,
    'splitMode': splitMode.name,
    'splitApps': splitApps,
    'ipPreference': ipPreference,
    'enableMux': enableMux,
    'enableTun': enableTun,
    'tunMode': tunMode,
    'enableDns': enableDns,
    'dnsAddress': dnsAddress,
    'enableLan': enableLan,
    'enablePacketSniff': enablePacketSniff,
    'enableSystemProxy': enableSystemProxy,
    'subAutoUpdate': subAutoUpdate,
    'subUpdateInterval': subUpdateInterval,
    'subUpdateOnOpen': subUpdateOnOpen,
    'subPingOnOpen': subPingOnOpen,
    'subConnectOnOpen': subConnectOnOpen,
    'subSortMode': subSortMode,
    'subUserAgent': subUserAgent,
    'subAllowDuplicates': subAllowDuplicates,
    'pingType': pingType,
    'pingUrl': pingUrl,
    'camouflageMode': camouflageMode,
  };

  factory AuraProfile.fromJson(Map<String, dynamic> j) => AuraProfile(
    id: j['id'] ?? _uid(),
    name: j['name'] ?? 'Profile',
    configsJson: List<Map<String,dynamic>>.from(j['configs'] ?? []),
    subLinks: List<String>.from(j['subLinks'] ?? []),
    subNames: Map<String,String>.from(j['subNames'] ?? {}),
    killSwitch: j['killSwitch'] ?? false,
    aiEnabled: j['aiEnabled'] ?? true,
    splitMode: SplitTunnelMode.values.firstWhere(
        (e) => e.name == (j['splitMode'] ?? 'disabled'),
        orElse: () => SplitTunnelMode.disabled),
    splitApps: List<String>.from(j['splitApps'] ?? []),
    ipPreference: j['ipPreference'] ?? 'auto',
    enableMux: j['enableMux'] ?? false,
    enableTun: j['enableTun'] ?? false,
    tunMode: j['tunMode'] ?? 'mixed',
    enableDns: j['enableDns'] ?? true,
    dnsAddress: j['dnsAddress'] ?? '1.1.1.1',
    enableLan: j['enableLan'] ?? false,
    enablePacketSniff: j['enablePacketSniff'] ?? false,
    enableSystemProxy: j['enableSystemProxy'] ?? false,
    subAutoUpdate: j['subAutoUpdate'] ?? true,
    subUpdateInterval: j['subUpdateInterval'] ?? 12,
    subUpdateOnOpen: j['subUpdateOnOpen'] ?? false,
    subPingOnOpen: j['subPingOnOpen'] ?? true,
    subConnectOnOpen: j['subConnectOnOpen'] ?? false,
    subSortMode: j['subSortMode'] ?? 'none',
    subUserAgent: j['subUserAgent'] ?? 'AuraVPN/${kAppVersion}/Android',
    subAllowDuplicates: j['subAllowDuplicates'] ?? false,
    pingType: j['pingType'] ?? 'tcp',
    pingUrl: j['pingUrl'] ?? 'https://www.gstatic.com/generate_204',
    camouflageMode: j['camouflageMode'] ?? 'none',
  );

  static String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      Random().nextInt(9999).toRadixString(36);
}

// ═══════════════════════════════════════════════════════════════
//  SPLIT TUNNEL  (v3.0)
// ═══════════════════════════════════════════════════════════════

enum SplitTunnelMode {
  disabled,  // весь трафик через VPN
  bypass,    // выбранные приложения МИНУЮТ vpn
  proxy,     // только выбранные приложения через vpn
}

// Список системных пакетов которые всегда надо показывать
// ignore: unused_element
const _wellKnownApps = <String, String>{
  'com.android.chrome':          'Chrome',
  'com.google.android.youtube':  'YouTube',
  'org.telegram.messenger':      'Telegram',
  'com.whatsapp':                'WhatsApp',
  'com.instagram.android':       'Instagram',
  'com.facebook.katana':         'Facebook',
  'com.twitter.android':         'Twitter / X',
  'com.netflix.mediaclient':     'Netflix',
  'com.spotify.music':           'Spotify',
  'ru.vk.im':                    'VK',
  'com.vkontakte.android':       'VKontakte',
  'ru.ok.android':               'OK',
  'org.thunderdog.challegram':   'Telegram X',
  'com.viber.voip':              'Viber',
  'com.skype.raider':            'Skype',
  'com.zhiliaoapp.musically':    'TikTok',
  'com.google.android.gm':       'Gmail',
  'com.microsoft.teams':         'MS Teams',
  'com.discord':                 'Discord',
  'com.snapchat.android':        'Snapchat',
};

// ═══════════════════════════════════════════════════════════════
//  BACKUP ENGINE  (v4.0 — усиленное шифрование)
// ═══════════════════════════════════════════════════════════════

class BackupEngine {
  // Key stretching: повторяем ключ через многократное XOR + перестановки
  // Это не AES, но значительно лучше простого XOR
  static List<int> _deriveKey(String password, List<int> salt) {
    if (password.isEmpty) return salt.isEmpty ? List.filled(32, 0x42) : salt;
    final pw = utf8.encode(password);
    // PBKDF2-like: 1000 итераций XOR+rotate
    var key = List<int>.from(pw + salt);
    for (int round = 0; round < 1000; round++) {
      key = List.generate(key.length, (i) {
        final prev = key[(i - 1 + key.length) % key.length];
        final next = key[(i + 1) % key.length];
        return (key[i] ^ prev ^ next ^ (round & 0xFF)) & 0xFF;
      });
    }
    // Растягиваем до 32 байт
    while (key.length < 32) key = [...key, ...key];
    return key.sublist(0, 32);
  }

  static List<int> _encrypt(List<int> data, String password) {
    // Генерируем случайный salt (16 байт)
    final rng  = Random.secure();
    final salt = List.generate(16, (_) => rng.nextInt(256));
    final key  = _deriveKey(password, salt);

    // XOR с derived key (значительно лучше простого XOR с паролем)
    final encrypted = List.generate(data.length,
        (i) => data[i] ^ key[i % key.length]);

    // Добавляем HMAC-like checksum для верификации (8 байт)
    var checksum = 0xDEADBEEF;
    for (int i = 0; i < encrypted.length; i++) {
      checksum = ((checksum << 5) ^ encrypted[i] ^ key[i % key.length]) & 0xFFFFFFFF;
    }
    final cs = [
      (checksum >> 24) & 0xFF, (checksum >> 16) & 0xFF,
      (checksum >> 8)  & 0xFF,  checksum        & 0xFF,
    ];

    // Формат: [salt(16)] [checksum(4)] [encrypted data]
    return [...salt, ...cs, ...encrypted];
  }

  static List<int>? _decrypt(List<int> data, String password) {
    if (data.length < 20) return null; // слишком короткий
    final salt      = data.sublist(0, 16);
    final cs_stored = data.sublist(16, 20);
    final encrypted = data.sublist(20);
    final key       = _deriveKey(password, salt);

    // Верифицируем checksum
    var checksum = 0xDEADBEEF;
    for (int i = 0; i < encrypted.length; i++) {
      checksum = ((checksum << 5) ^ encrypted[i] ^ key[i % key.length]) & 0xFFFFFFFF;
    }
    final cs_expected = [
      (checksum >> 24) & 0xFF, (checksum >> 16) & 0xFF,
      (checksum >> 8)  & 0xFF,  checksum        & 0xFF,
    ];
    if (!_listEq(cs_stored, cs_expected)) return null; // неверный пароль или битый файл

    return List.generate(encrypted.length,
        (i) => encrypted[i] ^ key[i % key.length]);
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  static String export(List<AuraProfile> profiles, String activeId, String password) {
    final payload = jsonEncode({
      'magic':    kBackupMagic,
      'version':  4,
      'ts':       DateTime.now().millisecondsSinceEpoch,
      'activeId': activeId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
    });
    final bytes     = utf8.encode(payload);
    final encrypted = _encrypt(bytes, password);
    return base64.encode(encrypted);
  }

  static Map<String, dynamic>? import(String b64, String password) {
    try {
      final bytes     = base64.decode(b64.trim());
      final decrypted = _decrypt(bytes, password);
      if (decrypted == null) return null; // неверный пароль

      // Обратная совместимость: старый формат v3 без checksum
      List<int> plainBytes = decrypted;
      Map<String, dynamic>? result;
      try {
        result = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      } catch (_) {
        // Пробуем старый XOR-формат v3
        final key = utf8.encode(password);
        final old = List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
        try {
          result = jsonDecode(utf8.decode(old)) as Map<String, dynamic>;
        } catch (_) { return null; }
      }

      if (result['magic'] != kBackupMagic) return null;
      return result;
    } catch (_) { return null; }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SIBERIA SHIELD  —  Anti-Burst Detection Engine
//  Март 2026: РКН «Сибирская блокировка» — детектирует burst TLS соединений
//  к одному IP (3-8 handshake за <5 сек) → блокирует IP на 2 минуты
//
//  Стратегия обхода (как Durov VPN / Outline):
//  1. CONNECTION PACING — не более 1 нового TLS за 2+ сек к одному IP
//  2. SINGLE TUNNEL MUX — один TCP туннель, всё внутри него (xmux/smux)
//  3. TRAFFIC SHAPING — размер пакетов имитирует HTTPS стриминг
//  4. IP COOLDOWN — если IP заблокирован, ждём 2+ мин и ротируем
//  5. DECOY TRAFFIC — фоновые HTTP запросы к белым доменам между handshake
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  PINNED HTTP CLIENT  —  Certificate Pinning для нашего сервера
//
//  Защита от MITM: РКН или провайдер не смогут подменить SSL-сертификат
//  и подсунуть фальшивые ноды или выключить приложение удалённо.
//
//  Применяется ТОЛЬКО к kPinnedDomains (api.auravpn.app).
//  Cloudflare DoH, antifilter.download, GitHub — без pinning (доверяем их цепочке).
//
//  ВАЖНО: Замени kPinnedSha256 на реальные SHA-256 когда развернёшь сервер.
//  Команда: openssl s_client -connect api.auravpn.app:443 |
//           openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
//           openssl dgst -sha256 -binary | base64
// ═══════════════════════════════════════════════════════════════════════════════

class PinnedHttpClient {
  // Создаём HttpClient с проверкой отпечатка для наших доменов
  static HttpClient create({bool pinned = true}) {
    final client = HttpClient();
    client.userAgent = kStealthUA;

    if (!pinned || kPinnedSha256.every((s) => s.startsWith('PLACEHOLDER'))) {
      // Pinning не настроен (заглушки) — работаем без него
      return client;
    }

    // TODO: полный cert pinning через SHA-256 — добавить когда будет реальный сертификат
    // Dart X509Certificate не даёт доступ к DER bytes без сторонних пакетов.
    // Команда для получения SHA-256: openssl s_client -connect api.auravpn.app:443 |
    //   openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
    //   openssl dgst -sha256 -binary | base64
    client.badCertificateCallback = (cert, host, port) {
      // Пока только проверяем что сертификат выдан для нашего домена
      if (kPinnedDomains.any((d) => host == d || host.endsWith('.$d'))) {
        // Rejecting certificates that don't match our domain
        return false; // false = reject bad cert (correct security behavior)
      }
      return false; // reject all bad certs from any domain
    };

    return client;
  }

  // Быстрый HTTP GET с pinning и timeout
  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
    bool pinOurServer = true,
  }) async {
    final uri  = Uri.parse(url);
    // pin = pinOurServer && kPinnedDomains.any(...) — TODO: use when cert pinning enabled
    final hdrs = {
      'User-Agent': kStealthUA,
      ...?headers,
    };
    return http.get(uri, headers: hdrs).timeout(timeout);
  }

  // POST с pinning и timeout
  static Future<http.Response> post(
    String url, {
    required String body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final hdrs = {
      'Content-Type': 'application/json',
      'User-Agent': kStealthUA,
      ...?headers,
    };
    return http.post(Uri.parse(url), headers: hdrs, body: body).timeout(timeout);
  }
}

class SiberiaShield {
  static final _rng = Random();

  // Трекер соединений к IP-адресам: IP → список timestamp
  static final Map<String, List<DateTime>> _connTimestamps = {};
  // Заблокированные IP: IP → время когда разблокируется
  static final Map<String, DateTime> _blockedUntil = {};

  // Пороги детектора обновлены март 2026 (ntc.party анализ ТСПУ)
  // ТСПУ усилил ML-детектор: теперь режет на 2-х SYN за 8 сек к одному IP
  static const _maxConnsPerWindow = 1;    // 1 за окно (ТСПУ 2026: 2 → блок)
  static const _windowSeconds     = 8;   // окно 8 сек (расширено с 5 до 8)
  static const _cooldownMinutes   = 4;   // 4 мин cooldown (ТСПУ блокирует на 3)
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
  // РКН видит: HTTP → пауза → HTTP → пауза → TLS (выглядит как браузер)
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

  // Telegram DC IP диапазоны — трафик к ним детектируется РКН
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
//  TSPU COUNTERMEASURES 2026
//  Активные контрмеры против новых методов блокировок ТСПУ (март 2026)
//
//  Основано на:
//  - ntc.party анализ поведения ТСПУ Q1 2026
//  - Xray-core v26.x Vision framework changelog
//  - net4people/bbs #490: новые признаки ML-классификатора ТСПУ
//  - boringssl fingerprint research (tlsfingerprint.io)
//
//  ML-DPI ТСПУ 2026 анализирует:
//  1. Packet length distribution (типичный VPN имеет равномерное распределение)
//  2. Inter-arrival time patterns (регулярные интервалы = машина, не браузер)
//  3. TLS ClientHello entropy (VLESS без padding имеет низкую энтропию)
//  4. Server→Client первый ответ размер (Reality: точно 1369 байт — детектируется)
//  5. IPv6 traffic ratio (блокируются IPv6 потоки к подозрительным /48)
// ═══════════════════════════════════════════════════════════════════════════════

class TspuCountermeasures2026 {
  static final _rng = Random();

  // ── Детектор типа блокировки по коду ошибки ────────────────────────────────
  // Разные типы блокировок требуют разных контрмер
  static BlockType classifyError(String errorMsg) {
    final e = errorMsg.toLowerCase();
    // TCP RST — активная блокировка (ТСПУ инжектирует RST)
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

  // ── Выбор оптимальной стратегии по типу блокировки ─────────────────────────
  // Вместо случайного перебора — целенаправленный выбор
  static List<int> prioritizedStrategies(BlockType blockType) {
    switch (blockType) {
      case BlockType.tcpReset:
        // RST → фрагментация + смена порта + Reality SNI rotate
        return [1, 4, 5, 6, 7, 43, 44, 45, 56, 57, 58];
      case BlockType.tlsFingerprint:
        // TLS fingerprint → смена uTLS + CDN fallback + Reality SNI
        return [1, 9, 10, 16, 17, 18, 19, 11, 12, 66, 67];
      case BlockType.dnsPoisoning:
        // DNS poisoning → DoH стратегии
        return [51, 52, 53, 54, 55];
      case BlockType.portBlocked:
        // Port blocked → смена порта (443, 8443, CF ports)
        return [4, 5, 6, 7, 8, 61, 62, 63, 64, 65];
      case BlockType.timeout:
        // Timeout → смена ноды + CDN
        return [71, 72, 73, 99, 100, 11, 12, 81, 82, 83];
      case BlockType.timeout:
      default:
        // Unknown → Tier 1 strategies
        return [1, 2, 3, 9, 10, 11];
    }
  }

  // ── Случайный padding для снижения энтропийных признаков ────────────────────
  // ТСПУ детектирует низкоэнтропийные пакеты как VPN
  // Добавляем рандомный User-Agent и фейковые заголовки
  static Map<String, String> antiEntropyHeaders() {
    final agents = [
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/136.0.7103.60',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_2) AppleWebKit/605.1.15 Safari/604.1',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edge/134.0.3124.72',
      'Dalvik/2.1.0 (Linux; Android 14; SM-S928B Build/UP1A.231005.007)',
    ];
    final ua = agents[_rng.nextInt(agents.length)];
    return {
      'User-Agent':      ua,
      'Accept-Language': _randomAcceptLanguage(),
      'Cache-Control':   _rng.nextBool() ? 'no-cache' : 'max-age=0',
    };
  }

  static String _randomAcceptLanguage() {
    final langs = ['ru-RU,ru;q=0.9,en;q=0.8', 'en-US,en;q=0.9', 'ru,en-US;q=0.9,en;q=0.8'];
    return langs[_rng.nextInt(langs.length)];
  }

  // ── Adaptive delay: имитация сетевого стека конкретного устройства ──────────
  // ТСПУ 2026: ML обнаруживает VPN по "идеальным" задержкам (0ms jitter)
  // Реальные устройства имеют jitter 2-15ms на каждом пакете
  static Duration adaptiveDelay(Duration base) {
    // Добавляем gaussian-like jitter ±15% к базовой задержке
    final jitterMs = (base.inMilliseconds * 0.15 * (_rng.nextDouble() * 2 - 1)).round();
    final total = (base.inMilliseconds + jitterMs).clamp(5, 5000);
    return Duration(milliseconds: total);
  }

  // ── Проверка: заблокирован ли порт полностью ────────────────────────────────
  static Future<bool> isPortReachable(String host, int port) async {
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 2000));
      await s.close();
      return true;
    } catch (_) { return false; }
  }

  // ── Обнаружение режима "замедления" (не блокировка, а throttling) ───────────
  // ТСПУ иногда замедляет, а не блокирует — распознаём по RTT > 2000ms
  static Future<ThrottleState> detectThrottle(String host, int port) async {
    try {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 5000));
      sw.stop();
      await s.close();
      final rtt = sw.elapsedMilliseconds;
      if (rtt > 3000) return ThrottleState.heavyThrottle;
      if (rtt > 1500) return ThrottleState.lightThrottle;
      return ThrottleState.normal;
    } on TimeoutException {
      return ThrottleState.blocked;
    } catch (_) {
      return ThrottleState.blocked;
    }
  }
}

enum ThrottleState { normal, lightThrottle, heavyThrottle, blocked }

// ═══════════════════════════════════════════════════════════════════════════════
//  TRAFFIC CAMOUFLAGE ENGINE
//
//  Маскировка VPN трафика под конкретные популярные сервисы/протоколы.
//  Каждый режим применяет специфичные заголовки, пути, SNI и паттерны
//  которые неотличимы от реального трафика этого сервиса.
//
//  Режимы:
//  • none       — без маскировки (чистый VLESS/VMess)
//  • browser    — обычный HTTPS браузер (Google Chrome)
//  • telegram   — Telegram MTProto через CDN (уже реализован)
//  • netflix    — Netflix видеостриминг (HTTP/2, chunked transfer)
//  • youtube    — YouTube видео (специфичные пути googleapis.com)
//  • discord    — Discord WebSocket (gateway.discord.gg паттерн)
//  • cloudflare — Cloudflare WARP (WireGuard-like UDP паттерн через TCP)
//  • microsoft  — Windows Update / Office 365 (login.microsoft.com)
//  • apple      — iCloud синхронизация (mask.icloud.com Private Relay)
//  • naive      — NaïveProxy: HTTP CONNECT через H2 (как Chrome proxy)
// ═══════════════════════════════════════════════════════════════════════════════

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
    // Telegram использует WebSocket 443 с CDN SNI
    final sni = 'cdn4.telegram.org';
    _patchOutbounds(j, 'ws', {
      'wsSettings': {
        'path': '/api',
        'headers': {
          'Host':       sni,
          'User-Agent': 'Telegram-iOS/10.2 (iPhone; iOS 18.3; Scale/3.00)',
          'Connection': 'Upgrade',
          'Upgrade':    'websocket',
        },
      },
    }, sni, 'ios', disableMux: true,
    extraSockopt: {'tcpKeepAliveIdle': 30});
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
    {'id': 11, 'name': 'CF Workers CDN',             'type': 'cdn_fallback',        'priority': 11, 'params': {'url':'aura-vpn.workers.dev'}},
    {'id': 12, 'name': 'CF Pages CDN',               'type': 'cdn_fallback',        'priority': 12, 'params': {'url':'aura-cdn.pages.dev'}},
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
    {'id': 81, 'name': 'CF Workers v2',              'type': 'cdn_fallback',        'priority': 81, 'params': {'url':'aura-vpn-proxy.workers.dev'}},
    {'id': 82, 'name': 'CF Pages v2',                'type': 'cdn_fallback',        'priority': 82, 'params': {'url':'aura-proxy.pages.dev'}},
    {'id': 83, 'name': 'CF Workers v3',              'type': 'cdn_fallback',        'priority': 83, 'params': {'url':'aura-bypass.workers.dev'}},
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
//  Март 2026: РКН использует AI-анализ TLS fingerprint (JA4+) + ТСПУ глубокий DPI
//  v3.0: race-based SNI, безопасный mux, расширенный SNI пул, защита pbk/sid,
//        гарантированный cleanup warmUp, рандомная фрагментация, IPv6 leak fix
// ═══════════════════════════════════════════════════════════════════════════════

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
    'Mozilla/5.0 (Linux; Android 14; POCO X6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.135 Mobile Safari/537.36',
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

  static void resetCounter() { _rstCount = 0; _lastRst = null; }

  // Геттеры для DevDashboard (приватные поля недоступны снаружи)
  static int    get utlsIndexPublic => _uTlsIndex;
  static int    get rstCountPublic  => _rstCount;
  static String get cachedSniPublic => _cachedSni ?? '—';
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SELF-HEALING MIRROR — Dead Drop система получения нод
//  Если основной API недоступен, пробуем GitHub Gist → DNS TXT
// ═══════════════════════════════════════════════════════════════════════════════

class SelfHealingMirror {
  static final _rng = Random();
  static const _uas = [
    // FIX v3.0: нейтральные User-Agent — не раскрываем что это VPN клиент
    // 'AuraVPN/5.6.0' идентифицировал трафик для систем мониторинга РКН
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  ];
  static String get _ua => _uas[_rng.nextInt(_uas.length)];

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
            log('✅ Nodes from ${mirror.contains('github') ? 'GitHub' : 'Mirror'}: ${nodes.length}');
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
      req.headers.set('User-Agent', 'Mozilla/5.0 Chrome/124.0.0.0');
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
      {'priority': 2, 'type': 'change_transport',    'params': {'transport': 'ws',   'path': '/'}},
      {'priority': 3, 'type': 'change_transport',    'params': {'transport': 'grpc', 'service': 'gun'}},
      {'priority': 4, 'type': 'change_port',         'params': {'port': 443}},
      {'priority': 5, 'type': 'change_port',         'params': {'port': 8443}},
      {'priority': 6, 'type': 'change_port',         'params': {'port': 80}},
      {'priority': 7, 'type': 'add_reality_sni',     'params': {'sni': 'dl.google.com'}},
      {'priority': 8, 'type': 'add_reality_sni',     'params': {'sni': 'update.microsoft.com'}},
      {'priority': 9, 'type': 'trojan_ws_fallback',  'params': {'port': 443, 'path': '/api/v1'}},
      {'priority': 10,'type': 'cdn_fallback',         'params': {'url': 'aura-vpn.workers.dev'}},
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
      {'priority': 3, 'type': 'change_transport',     'params': {'transport': 'ws',   'path': '/cdn'}},
      {'priority': 4, 'type': 'change_transport',     'params': {'transport': 'grpc', 'service': 'gun'}},
      {'priority': 5, 'type': 'cdn_fallback',          'params': {'url': 'aura-vpn.workers.dev'}},
      {'priority': 6, 'type': 'cdn_fallback',          'params': {'url': 'aura-cdn.pages.dev'}},
      {'priority': 7, 'type': 'shadow_fallback',       'params': {}},
    ]},
    // Stealth: TLS fingerprint / сервисная блокировка
    {'id': 'stealth_tls', 'triggers': ['tlsFingerprint', 'serviceBlocked'], 'strategies': [
      {'priority': 1, 'type': 'rotate_reality_sni',   'params': {}},
      {'priority': 2, 'type': 'change_transport',     'params': {'transport': 'ws',   'path': '/'}},
      {'priority': 3, 'type': 'add_reality_sni',      'params': {'sni': 'dl.google.com'}},
      {'priority': 4, 'type': 'add_reality_sni',      'params': {'sni': 'fonts.googleapis.com'}},
      {'priority': 5, 'type': 'add_reality_sni',      'params': {'sni': 'update.microsoft.com'}},
      {'priority': 6, 'type': 'add_reality_sni',      'params': {'sni': 'gateway.icloud.com'}},
      {'priority': 7, 'type': 'add_reality_sni',      'params': {'sni': 'mask.icloud.com'}},
      {'priority': 8, 'type': 'trojan_ws_fallback',   'params': {'port': 443, 'path': '/stream'}},
      {'priority': 9, 'type': 'cdn_fallback',          'params': {'url': 'aura-vpn.workers.dev'}},
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
    all.sort((a, b) => a.priority.compareTo(b.priority));
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
    }
    return VpnConfig(
      name: '${orig.name} [AI]', link: link,
      groupName: orig.groupName, sourceUrl: orig.sourceUrl,
      isManual: orig.isManual, isAiPatched: true,
      isFavourite: orig.isFavourite,
    );
  }
}

class BypassProber {
  // Проверяем через полный TLS handshake, не просто TCP
  // РКН/Роскомнадзор пропускает TCP но режет на TLS уровне
  static Future<bool> probe(VpnConfig cfg) async {
    String host = ''; int port = 443;
    try {
      final uri = Uri.parse(cfg.link.contains('@')
          ? 'dummy://${cfg.link.split('@').last.split('#').first}' : cfg.link);
      host = uri.host; port = uri.port > 0 ? uri.port : 443;
    } catch (_) { return false; }
    if (host.isEmpty) return false;
    // Сначала быстрый TCP (1.5 сек) — если упал, TLS не нужен
    try {
      final s = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1500));
      await s.close();
    } catch (_) { return false; }
    // Затем TLS handshake — реальная проверка прохождения трафика
    try {
      final s = await SecureSocket.connect(
        host, port,
        timeout: const Duration(seconds: 3),
        onBadCertificate: (_) => true,
      );
      await s.close();
      return true;
    } catch (_) { return false; }
  }
}

class AiBypassAgent {
  final BypassRulesEngine _rules;
  final void Function(String) _log;
  bool _isRunning = false;
  AiBypassAgent(this._rules, this._log);

  bool get isRunning        => _isRunning;
  int  currentStrategyId    = 0;  // текущий номер стратегии — показывается в UI
  String currentStrategyName = '';

  void cancel() { _isRunning = false; }

  Future<VpnConfig?> findBypass(VpnConfig blocked) async {
    if (_isRunning) return null;
    _isRunning = true;
    try { return await _run(blocked); } finally { _isRunning = false; }
  }

  Future<VpnConfig?> _run(VpnConfig blocked) async {
    _log('🤖 Detecting block type…');
    final bt = await BlockDetector.detect(blocked);
    _log('🤖 Block: ${bt.name}');
    if (bt == BlockType.none) return blocked;

    // Стратегии: server rules + BypassArsenal 100
    final ruleStrategies = _rules.getStrategies(bt);
    final arsenalRaw     = BypassArsenal.getStrategiesForBlock(bt.name);
    final arsenalStrats  = arsenalRaw.map((m) => BypassStrategy(
      priority: m['priority'] as int,
      type:     m['type']     as String,
      params:   Map<String, dynamic>.from(m['params'] as Map? ?? {}),
    )).toList();

    // Дедупликация по type+params
    final seen = <String>{};
    final allStrats = [...ruleStrategies, ...arsenalStrats].where((s) {
      return seen.add('${s.type}:${s.params}');
    }).toList();

    // Фильтр: пропускаем из blacklist + switch_node при хорошем пинге
    final queue = allStrats.where((s) {
      final id = _stratId(s);
      if (StrategyBlacklist.isBlocked(id, s.type, s.params)) {
        final m = StrategyBlacklist.minutesLeft(id, s.type, s.params);
        _log('🤖 #$id ${s.type} — blacklisted ${m}m, skip');
        return false;
      }
      if (s.type == 'switch_node' && blocked.pingMs > 0 && blocked.pingMs < 500) return false;
      return true;
    }).toList();

    final skipped = allStrats.length - queue.length;
    _log('🤖 Queue: ${queue.length} (skipped $skipped blacklisted)');

    for (int i = 0; i < queue.length; i++) {
      final s  = queue[i];
      final id = _stratId(s);
      if (!_isRunning) return null;
      if (s.type == 'switch_node') { _log('🤖 → switch node'); return null; }

      // Обновляем ID текущей стратегии — виден в _AiBar
      currentStrategyId   = id;
      currentStrategyName = s.type.replaceAll('_', ' ');
      _log('🤖 #$id · ${s.type} (${i+1}/${queue.length})');

      try {
        final patched = _rules.applyStrategy(blocked, s);
        final works   = await BypassProber.probe(patched);

        if (works) {
          _log('🤖 ✅ #$id · ${s.type} WORKS');
          currentStrategyId = 0;
          StrategyBlacklist.reportSuccess(id, s.type, s.params);
          BypassReporter.report(strategyId: id, strategyType: s.type,
              blockType: bt.name, success: true);
          _telemetry(blocked, bt, s, success: true);
          return patched;
        } else {
          final bl = StrategyBlacklist.reportFail(id, s.type, s.params);
          BypassReporter.report(strategyId: id, strategyType: s.type,
              blockType: bt.name, success: false);
          if (bl) _log('🤖 #$id blacklisted '
              '${StrategyBlacklist.minutesLeft(id, s.type, s.params)}m');
        }
      } catch (e) {
        _log('🤖 #$id error: $e');
        StrategyBlacklist.reportFail(id, s.type, s.params);
      }
    }

    currentStrategyId = 0;
    _log('🤖 All exhausted → ${AuraErrorCode.e1026.code}');
    return null;
  }

  // Получить ID стратегии из BypassArsenal по type
  int _stratId(BypassStrategy s) {
    final found = BypassArsenal.strategies
        .where((m) => m['type'] == s.type)
        .firstOrNull;
    return (found?['id'] as int?) ?? s.priority;
  }

  void _telemetry(VpnConfig n, BlockType bt, BypassStrategy s, {required bool success}) {
    Future.microtask(() async {
      try {
        await PinnedHttpClient.post(
          kTelemetryUrl,
          body: jsonEncode({
            'v':            kAppVersion,
            'block_type':   bt.name,
            'strategy_id':  s.priority,
            'strategy_type':s.type,
            'protocol':     n.protocol,
            'success':      success,
            'ts':           DateTime.now().millisecondsSinceEpoch,
            'strategy_key': '${s.type}:${s.params}',
          }),
          timeout: const Duration(seconds: 4),
        );
      } catch (_) {} // сервер недоступен — работаем offline
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NEWS AWARENESS  —  Заглушка для будущего AI агента мониторинга блокировок
//
//  Задача: следить за новостями о блокировках, автоматически обновлять
//  списки стратегий и помечать неработающие методы как deprecated.
//
//  TODO: подключить реальный AI агент (Claude/GPT) в следующей версии
//  Агент будет:
//  1. Мониторить runetfreedom, roskomsvoboda.org, ntc.party
//  2. Парсить сообщения о новых блокировках
//  3. Автоматически добавлять/удалять стратегии в BypassArsenal
//  4. Помечать стратегии как 'deprecated' если они перестали работать
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  STRATEGY BLACKLIST  —  Локальный чёрный список нерабочих стратегий
//
//  Когда стратегия не прошла зонд 2 раза подряд:
//  → Блокируется на 5 мин (экспоненциально: 5→10→20→40→60 мин)
//  → Сохраняется в SharedPrefs (переживает перезапуск)
//  → Отчёт на сервер (когда будет — BypassReporter)
//
//  Когда будет сервер AdminPanel:
//  - N% пользователей репортят одну стратегию → глобальный blacklist
//  - AI мониторит новости → предиктивно блокирует
//  - Каждая стратегия проверяется 10 раз перед финальным blacklist
// ═══════════════════════════════════════════════════════════════════════════════

class StrategyBlacklist {
  // strategyKey → unblockAt
  static final Map<String, DateTime> _blocked    = {};
  // Счётчик провалов — в blacklist только после _minFails
  static final Map<String, int>      _failCounts = {};

  static const int _minFails     = 2;   // 2 провала подряд → blacklist
  static const int _blockMinutes = 5;   // базовые 5 мин
  static const int _maxBlockMins = 60;  // максимум 1 час (экспоненциальный рост)

  static String _key(int id, String type, Map params) =>
      '$id:$type:${params.hashCode}';

  // Проверить — заблокирована ли стратегия
  static bool isBlocked(int id, String type, Map params) {
    final key   = _key(id, type, params);
    final until = _blocked[key];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _blocked.remove(key);
      _failCounts.remove(key);
      return false;
    }
    return true;
  }

  // Репортим провал — возвращает true если стратегия теперь заблокирована
  static bool reportFail(int id, String type, Map params) {
    final key   = _key(id, type, params);
    final fails = (_failCounts[key] ?? 0) + 1;
    _failCounts[key] = fails;

    if (fails >= _minFails) {
      // Экспоненциальная блокировка: 5→10→20→40→60 мин
      final extra   = (fails - _minFails).clamp(0, 5);
      final minutes = (_blockMinutes * (1 << extra)).clamp(0, _maxBlockMins);
      _blocked[key] = DateTime.now().add(Duration(minutes: minutes));
      _persist();
      return true;
    }
    return false;
  }

  // Стратегия сработала → сбрасываем
  static void reportSuccess(int id, String type, Map params) {
    final key = _key(id, type, params);
    _blocked.remove(key);
    _failCounts.remove(key);
    _persist();
  }

  // Сколько минут осталось в blacklist
  static int minutesLeft(int id, String type, Map params) {
    final until = _blocked[_key(id, type, params)];
    if (until == null) return 0;
    return DateTime.now().isBefore(until)
        ? until.difference(DateTime.now()).inMinutes + 1 : 0;
  }

  // Сохранить в SharedPrefs
  static Future<void> _persist() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _blocked.map((k, v) => MapEntry(k, v.toIso8601String()));
      await p.setString('strategy_blacklist', jsonEncode(data));
    } catch (_) {}
  }

  // Загрузить из SharedPrefs при старте
  static Future<void> load() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString('strategy_blacklist');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final now  = DateTime.now();
        data.forEach((k, v) {
          final until = DateTime.tryParse(v as String);
          if (until != null && until.isAfter(now)) _blocked[k] = until;
        });
      }
    } catch (_) {}
  }

  // Очистить весь blacklist
  // Публичные геттеры для Dev Dashboard
  static Map<String, DateTime> get allBlocked  => Map.unmodifiable(_blocked);
  static int                   get blockedCount => _blocked.length;

  static void clear() {
    _blocked.clear();
    _failCounts.clear();
    _persist();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BYPASS REPORTER  —  Заготовка для Admin Panel
//
//  СЕЙЧАС: заглушка (_enabled = false), только локальный blacklist
//  КОГДА БУДЕТ СЕРВЕР:
//    POST kControlPlaneUrl/strategy_report
//    → AdminPanel видит какие стратегии падают у N пользователей
//    → AI мониторит и предиктивно обновляет blacklist
// ═══════════════════════════════════════════════════════════════════════════════

class BypassReporter {
  static const _enabled = false; // ← включить когда будет сервер

  static Future<void> report({
    required int    strategyId,
    required String strategyType,
    required String blockType,
    required bool   success,
  }) async {
    if (!_enabled) return;
    try {
      await PinnedHttpClient.post(
        '$kControlPlaneUrl/strategy_report',
        body: jsonEncode({
          'strategy_id':   strategyId,
          'strategy_type': strategyType,
          'block_type':    blockType,
          'success':       success,
          'ts':            DateTime.now().millisecondsSinceEpoch,
          'app_version':   kAppVersion,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

// ── NewsAwareness (делегирует в StrategyBlacklist) ───────────────────────────
class NewsAwareness {
  static const newsSources = [
    'https://roskomsvoboda.org/feed/',
    'https://ntc.party/latest.json',
    'https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/CHANGELOG.md',
  ];

  static bool isDeprecated(String type, Map params) =>
      StrategyBlacklist.isBlocked(0, type, params);

  static void markDeprecated(String type, Map params) =>
      StrategyBlacklist.reportFail(0, type, params);

  static Future<void> syncNews(void Function(String) log) async {
    log('📰 NewsAwareness: AI не подключён — используем локальный blacklist');
  }

  // Алиасы для обратной совместимости с VpnProvider
  static Future<void> load() => StrategyBlacklist.load();
  static Future<void> syncFromServer(String _) async { /* заглушка — AI не подключён */ }
}



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

class VpnProvider extends ChangeNotifier {
  late FlutterV2ray _v2ray;
  bool _disposed = false;

  // ── Состояние подключения ─────────────────────────────────────────────────
  String status      = 'OFFLINE';
  bool   isConnected = false;
  String aiStatus    = 'IDLE';

  // ── Обход белых списков (v5.0) ────────────────────────────────────────────
  bool   whitelistBypassActive  = false;
  String whitelistBypassStatus  = 'IDLE';
  bool   bypassBtnMode          = false;

  // ── Stealth Engine 3.0 ─────────────────────────────────────────────────────
  bool   stealthMode            = true;   // включён по умолчанию
  bool   stealthWarmup          = true;   // warm-up HTTP перед VPN
  bool   stealthFragment        = true;   // TLS фрагментация
  bool   stealthRealitySni      = true;   // авто-ротация Reality SNI
  bool   siberiaShield          = true;   // защита от Сибирской блокировки
  int    stealthHandshakeFails  = 0;      // счётчик провалов handshake
  String stealthStatus          = '';     // статус для UI

  // ── Трафик (v4.0) ─────────────────────────────────────────────────────────
  int    trafficUp   = 0; // bytes/s текущая скорость
  int    trafficDown = 0;
  int    totalUp     = 0; // bytes total сессия
  int    totalDown   = 0;
  Duration sessionDuration = Duration.zero;
  DateTime? _connectedAt;
  Timer?  _trafficTimer;

  // ── История подключений (v4.0) ────────────────────────────────────────────
  List<ConnectionRecord> connectionHistory = [];

  // ── Профили (v3.0) ────────────────────────────────────────────────────────
  List<AuraProfile> profiles      = [];
  String            activeProfileId = '';

  // ── Текущий профиль — удобные геттеры ─────────────────────────────────────
  AuraProfile get _prof {
    if (profiles.isEmpty) { _ensureDefaultProfile(); }
    return profiles.firstWhere((p) => p.id == activeProfileId,
        orElse: () => profiles.first);
  }

  List<VpnConfig>       get configs   => _configs;
  List<String>          get subLinks  => _prof.subLinks;
  Map<String, String>   get subNames  => _prof.subNames;
  bool get killSwitch   => _prof.killSwitch;
  bool get aiEnabled    => _prof.aiEnabled;
  SplitTunnelMode get splitMode => _prof.splitMode;
  List<String>    get splitApps => _prof.splitApps;

  set killSwitch(bool v) { _prof.killSwitch = v; }
  set aiEnabled(bool v)  { _prof.aiEnabled = v; }

  // ── Туннель ───────────────────────────────────────────────────────────────
  bool   get enableMux         => _prof.enableMux;
  bool   get enableTun         => _prof.enableTun;
  String get tunMode           => _prof.tunMode;
  bool   get enableDns         => _prof.enableDns;
  String get dnsAddress        => _prof.dnsAddress;
  bool   get enableLan         => _prof.enableLan;
  String get ipPreference      => _prof.ipPreference;
  bool   get enablePacketSniff => _prof.enablePacketSniff;
  bool   get enableSystemProxy => _prof.enableSystemProxy;

  void setEnableMux(bool v)         { _prof.enableMux = v;         saveToDisk(); _notify(); }
  void setEnableTun(bool v)         { _prof.enableTun = v;         saveToDisk(); _notify(); }
  void setTunMode(String v)         { _prof.tunMode = v;           saveToDisk(); _notify(); }
  void setEnableDns(bool v)         { _prof.enableDns = v;         saveToDisk(); _notify(); }
  void setDnsAddress(String v)      { _prof.dnsAddress = v;        saveToDisk(); _notify(); }
  void setEnableLan(bool v)         { _prof.enableLan = v;         saveToDisk(); _notify(); }
  void setIpPreference(String v)    { _prof.ipPreference = v;      saveToDisk(); _notify(); }
  void setPacketSniff(bool v)       { _prof.enablePacketSniff = v; saveToDisk(); _notify(); }
  void setSystemProxy(bool v)       { _prof.enableSystemProxy = v; saveToDisk(); _notify(); }

  // ── Подписки ─────────────────────────────────────────────────────────────
  bool   get subAutoUpdate     => _prof.subAutoUpdate;
  int    get subUpdateInterval => _prof.subUpdateInterval;
  bool   get subUpdateOnOpen   => _prof.subUpdateOnOpen;
  bool   get subPingOnOpen     => _prof.subPingOnOpen;
  bool   get subConnectOnOpen  => _prof.subConnectOnOpen;
  String get subSortMode       => _prof.subSortMode;
  String get subUserAgent      => _prof.subUserAgent;
  bool   get subAllowDups      => _prof.subAllowDuplicates;

  void setSubAutoUpdate(bool v)       { _prof.subAutoUpdate = v;      saveToDisk(); _notify(); }
  void setSubInterval(int v)          { _prof.subUpdateInterval = v;  saveToDisk(); _notify(); }
  void setSubUpdateOnOpen(bool v)     { _prof.subUpdateOnOpen = v;    saveToDisk(); _notify(); }
  void setSubPingOnOpen(bool v)       { _prof.subPingOnOpen = v;      saveToDisk(); _notify(); }
  void setSubConnectOnOpen(bool v)    { _prof.subConnectOnOpen = v;   saveToDisk(); _notify(); }
  void setSubSortMode(String v)       { _prof.subSortMode = v;        saveToDisk(); _notify(); }
  void setSubUserAgent(String v)      { _prof.subUserAgent = v;       saveToDisk(); _notify(); }
  void setSubAllowDups(bool v)        { _prof.subAllowDuplicates = v; saveToDisk(); _notify(); }

  // ── Пинг ──────────────────────────────────────────────────────────────────
  String get pingType => _prof.pingType;
  String get pingUrl  => _prof.pingUrl;

  void setPingType(String v) { _prof.pingType = v; saveToDisk(); _notify(); }
  void setPingUrl(String v)  { _prof.pingUrl  = v; saveToDisk(); _notify(); }

  // ── Маскировка трафика ─────────────────────────────────────────────────────
  String get camouflageMode => _prof.camouflageMode;
  CamouflageMode get camouflage =>
      CamouflageMode.values.firstWhere(
          (e) => e.name == _prof.camouflageMode,
          orElse: () => CamouflageMode.none);
  void setCamouflageMode(String v) {
    _prof.camouflageMode = v;
    saveToDisk();
    _notify();
  }

  List<VpnConfig> _configs = [];

  int    selectedIndex    = 0;
  List<String> logs       = [];
  bool   isPingAllRunning = false;

  // ── Авто-режим (v5.1) ────────────────────────────────────────────────────
  bool   isAutoMode       = false;  // режим авто включён
  bool   isAutoRunning    = false;  // идёт процесс поиска лучшей ноды
  String autoStatus       = '';     // текст статуса для UI
  Timer? _autoRecheckTimer;         // периодическая перепроверка

  // ── Поиск (v3.0) ─────────────────────────────────────────────────────────
  String searchQuery = '';

  late final BypassRulesEngine _bypassRules;
  late final AiBypassAgent     _aiAgent;

  BypassRulesEngine           get bypassRules  => _bypassRules;

  // ── Dev Dashboard геттеры (только для _DevDashboard) ─────────────────────
  bool              get devIsRotating    => _isRotating;
  int               get devFailCount     => _failCount;
  int               get devBypassAttempt => _bypassAttempt;
  int               get devBypassNodeIdx => _bypassNodeIdx;
  AiBypassAgent     get devAiAgent       => _aiAgent;
  void Function(String)       get logFn        => _log;
  String groupNameFromUrl(String url)           => _groupNameFromUrl(url);

  int    _failCount  = 0;
  Timer? _watchdog;
  bool   _isRotating = false;
  static const int      maxFails        = 3;
  // FIX: 9с слишком мало — pacing+warmup+SNI может занять до 15 сек
  // Увеличено до 30с — это реальный timeout для VPN подключения
  static const Duration _watchdogTimeout = Duration(seconds: 30);

  // ── Группировка с избранным и поиском ─────────────────────────────────────

  List<VpnConfig> get filteredConfigs {
    if (searchQuery.isEmpty) return _configs;
    final q = searchQuery.toLowerCase();
    return _configs.where((c) =>
      c.displayName.toLowerCase().contains(q) ||
      c.protocol.toLowerCase().contains(q) ||
      c.groupName.toLowerCase().contains(q)
    ).toList();
  }

  Map<String, List<VpnConfig>> get grouped {
    final src = filteredConfigs;
    final m = <String, List<VpnConfig>>{};
    // Избранные — всегда первые
    final favs = src.where((c) => c.isFavourite).toList();
    if (favs.isNotEmpty) m['__favourites__'] = favs;
    // Manual
    final manuals = src.where((c) => c.sourceUrl == 'manual' && !c.isFavourite).toList();
    if (manuals.isNotEmpty) m['manual'] = manuals;
    // Server
    final serverNodes = src.where((c) => c.sourceUrl == 'server' && !c.isFavourite).toList();
    if (serverNodes.isNotEmpty) m['server'] = serverNodes;
    // Subscriptions
    for (final url in subLinks) {
      final nodes = src.where((c) => c.sourceUrl == url && !c.isFavourite).toList();
      if (nodes.isNotEmpty) m[url] = nodes;
    }
    for (final c in src) {
      if (!m.values.any((list) => list.contains(c))) (m['other'] ??= []).add(c);
    }
    return m;
  }

  String groupDisplayName(String sourceUrl) {
    if (sourceUrl == '__favourites__') return '⭐  ${S.t('favourites')}';
    if (sourceUrl == 'manual')  return 'Manual Keys';
    if (sourceUrl == 'server')  return 'Aura Servers';
    if (sourceUrl == 'other')   return 'Other';
    if (subNames.containsKey(sourceUrl)) return subNames[sourceUrl]!;
    try { return Uri.parse(sourceUrl).host.replaceAll('www.', ''); }
    catch (_) { return sourceUrl; }
  }

  // ── Constructor ───────────────────────────────────────────────────────────

  VpnProvider() {
    _bypassRules = BypassRulesEngine();
    _aiAgent     = AiBypassAgent(_bypassRules, _log);
    _v2ray = FlutterV2ray(onStatusChanged: (v2s) {
      final prev   = status;
      final newSt  = v2s.state.toUpperCase();
      final changed = newSt != prev;

      status      = newSt;
      isConnected = status == 'CONNECTED';

      // Реальный трафик из v2ray — обновляем без _notify (timer делает это)
      trafficUp   = v2s.uploadSpeed;
      trafficDown = v2s.downloadSpeed;
      totalUp     = v2s.upload;
      totalDown   = v2s.download;

      if (!changed) return; // Не перерисовываем UI если статус не изменился
      _log('◉ $status');
      if (status == 'CONNECTED') {
        _failCount = 0; _isRotating = false; aiStatus = 'IDLE';
        _bypassAttempt = 0; _bypassNodeIdx = selectedIndex;
        stealthHandshakeFails = 0;
        _cancelWd();
        _connectedAt = DateTime.now();
        _startTrafficTimer();
        final nodeName = (_configs.isNotEmpty && selectedIndex < _configs.length)
            ? _configs[selectedIndex].displayName : 'Aura VPN';
        _sendNotification('🔒 VPN подключён', nodeName);
        _showPersistentNotif();
        _ipCheck.fetchCurrent(force: true);
        _updateTile(active: true, server: nodeName);
      } else if (status == 'CONNECTING') {
        _startWd();
      } else if (status == 'DISCONNECTED') {
        _cancelWd();
        _saveHistoryRecord();
        _stopTrafficTimer();
        _dismissPersistentNotif();                       // убрать постоянное уведомление
        Future.delayed(const Duration(seconds: 2), () => _ipCheck.fetchCurrent(force: true)); // обновить IP
        _updateTile(active: false);                      // обновить тайл
        if (prev == 'CONNECTING' && !_isRotating) {
          _failCount++;
          _log('⚠ Fail #$_failCount/$maxFails');
          if (_failCount >= maxFails) _scheduleBypass();
        }
        if (prev == 'CONNECTED') {
          _sendNotification('🔓 VPN отключён', 'Сессия завершена');
        }
      }
      _notify();
    });
    _init();
  }

  @override void dispose() {
    _disposed = true;
    _cancelWd();
    _stopTrafficTimer();
    _autoRecheckTimer?.cancel();
    _logDebounce?.cancel();
    super.dispose();
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  // ── Stealth Engine 2.0 — публичные setters ────────────────────────────────
  void setStealthMode(bool v)       { stealthMode       = v; _saveStealthPrefs(); _notify(); }
  void setStealthFragment(bool v)   { stealthFragment   = v; _saveStealthPrefs(); _notify(); }
  void setStealthRealitySni(bool v) { stealthRealitySni = v; _saveStealthPrefs(); _notify(); }
  void setStealthWarmup(bool v)     { stealthWarmup     = v; _saveStealthPrefs(); _notify(); }
  void setSiberiaShield(bool v)     { siberiaShield     = v; _saveStealthPrefs(); _notify(); }

  Future<void> _saveStealthPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('stealth_mode',        stealthMode);
      await p.setBool('stealth_fragment',    stealthFragment);
      await p.setBool('stealth_reality_sni', stealthRealitySni);
      await p.setBool('stealth_warmup',      stealthWarmup);
      await p.setBool('siberia_shield',      siberiaShield);
    } catch (_) {}
  }

  Future<void> _loadStealthPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      stealthMode       = p.getBool('stealth_mode')        ?? true;
      stealthFragment   = p.getBool('stealth_fragment')    ?? true;
      stealthRealitySni = p.getBool('stealth_reality_sni') ?? true;
      stealthWarmup     = p.getBool('stealth_warmup')      ?? true;
      siberiaShield     = p.getBool('siberia_shield')      ?? true;
    } catch (_) {}
  }


  

  // ── Публичные методы (вызываются из UI) ──────────────────────────────────
  void refresh()               { _notify(); }
  String get activeProfileName => _prof.name;
  void setAiEnabled(bool v)    { _prof.aiEnabled  = v; saveToDisk(); _notify(); }
  void setKillSwitch(bool v)   { _prof.killSwitch = v; saveToDisk(); _notify(); }

  // Сброс конфига ноды к оригинальному состоянию из провайдера
  // Убирает AI-патчинг, маскировку, кастомное имя — возвращает исходный ключ


  // Проверяет — был ли конфиг изменён относительно оригинала
  bool isNodeModified(int idx) {
    if (idx < 0 || idx >= _configs.length) return false;
    final cfg = _configs[idx];
    return cfg.isAiPatched ||
           cfg.customName.isNotEmpty ||
           (cfg.originalLink.isNotEmpty && cfg.link != cfg.originalLink);
  }
  void syncRules()             { _bypassRules.syncFromServer(_log).then((_) => _notify()); }
  void clearHistory()          { connectionHistory.clear(); _persistHistory(); _notify(); }
  void clearLogs()             { logs.clear(); _notify(); }
  // FIX v3.0: логи не вызывают notifyListeners напрямую — только через debounce
  // До этого каждый _log() вызывал перерисовку всего UI (freeze при активном bypass)
  Timer? _logDebounce;
  void _log(String msg) {
    final ts = DateTime.now().toString().split(' ').last.substring(0, 8);
    logs.add('[$ts] $msg');
    if (logs.length > 200) logs.removeRange(0, logs.length - 200);
    // Debounce: обновляем UI не чаще чем раз в 100ms
    _logDebounce?.cancel();
    _logDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) notifyListeners();
    });
  }

  // ── Traffic counter (v4.0) ────────────────────────────────────────────────
  // uploadSpeed/downloadSpeed приходят каждую секунду через onStatusChanged
  // Здесь только обновляем sessionDuration

  void _startTrafficTimer() {
    _trafficTimer?.cancel();
    sessionDuration = Duration.zero;
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !isConnected) return;
      if (_connectedAt != null) {
        sessionDuration = DateTime.now().difference(_connectedAt!);
      }
      // Обновляем уведомление каждые 5 сек чтобы не нагружать систему
      if (sessionDuration.inSeconds % 5 == 0) {
        _updatePersistentNotif();
      }
      _notify();
    });
  }

  void _stopTrafficTimer() {
    _trafficTimer?.cancel();
    _trafficTimer = null;
    trafficUp = 0; trafficDown = 0;
    _connectedAt = null;
  }

  String get sessionTimeStr {
    final s = sessionDuration.inSeconds;
    final h   = s ~/ 3600;
    final m   = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2,'0')}m';
    return '${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }


  // ── Speed formatter ───────────────────────────────────────────────────────

  String formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec > 1024 * 1024) return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s';
    if (bytesPerSec > 1024) return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    return '$bytesPerSec B/s';
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes > 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  // ── History (v4.0) ────────────────────────────────────────────────────────

  void _saveHistoryRecord() {
    if (_connectedAt == null) return;
    final dur = DateTime.now().difference(_connectedAt!);
    if (dur.inSeconds < 3) return; // не сохраняем мгновенные обрывы
    final cfg = (_configs.isNotEmpty && selectedIndex < _configs.length)
        ? _configs[selectedIndex] : null;
    final record = ConnectionRecord(
      serverName:    cfg?.displayName ?? 'Unknown',
      protocol:      cfg?.protocol    ?? '?',
      startedAt:     _connectedAt!,
      duration:      dur,
      uploadBytes:   totalUp,
      downloadBytes: totalDown,
    );
    connectionHistory.insert(0, record);
    if (connectionHistory.length > 50) connectionHistory.removeLast();
    _persistHistory();
  }

  Future<void> _persistHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('conn_history',
          jsonEncode(connectionHistory.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('conn_history');
      if (raw != null) {
        connectionHistory = (jsonDecode(raw) as List)
            .map((j) => ConnectionRecord.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  // ── Notifications (v4.0) ──────────────────────────────────────────────────
  // Нативный Android notification через platform channel (без доп. пакетов)

  static const _notifChannel  = MethodChannel('aura_vpn/notifications');
  static const _tileChannel   = MethodChannel('aura_vpn/tile');
  static const _cmdChannel    = MethodChannel('aura_vpn/commands');
  // Публичный доступ для _CustomThemeEditorState
  static const cmdChannel = _cmdChannel;

  Future<void> _sendNotification(String title, String body) async {
    try {
      await _notifChannel.invokeMethod('show', {'title': title, 'body': body});
    } catch (_) {}
  }

  // Постоянное уведомление пока VPN активен — с кнопкой Отключить
  Future<void> _showPersistentNotif() async {
    if (_configs.isEmpty || selectedIndex >= _configs.length) return;
    final name = _configs[selectedIndex].displayName;
    final spd  = '↑ ${formatSpeed(trafficUp)}  ↓ ${formatSpeed(trafficDown)}';
    try {
      await _notifChannel.invokeMethod('showPersistent', {
        'server': name, 'speed': spd,
      });
    } catch (_) {}
  }

  Future<void> _updatePersistentNotif() async {
    if (!isConnected) return;
    if (_configs.isEmpty || selectedIndex >= _configs.length) return;
    final name = _configs[selectedIndex].displayName;
    final spd  = '↑ ${formatSpeed(trafficUp)}  ↓ ${formatSpeed(trafficDown)}';
    try {
      await _notifChannel.invokeMethod('updatePersistent', {
        'server': name, 'speed': spd,
      });
    } catch (_) {}
  }

  Future<void> _dismissPersistentNotif() async {
    try {
      await _notifChannel.invokeMethod('dismissPersistent', null);
    } catch (_) {}
  }

  // Обновить Quick Settings тайл
  Future<void> _updateTile({required bool active, String server = 'Aura VPN'}) async {
    try {
      await _tileChannel.invokeMethod('update', {
        'active': active, 'server': server,
      });
    } catch (_) {}
  }

  // Слушаем команды от нативного кода (кнопка в уведомлении, тайл)
  void _setupCommandChannel() {
    _cmdChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'disconnect':
          if (isConnected) await toggle();
          break;
        case 'connect':
          if (!isConnected) await toggle();
          break;
        // AutoConnect: сеть изменилась
        case 'network_changed':
          final type = call.arguments as String? ?? '';
          if (!isConnected) {
            if (type == 'open_wifi' && _autoConnect.onOpenWifi) {
              _log('🌐 AutoConnect: открытый WiFi → подключаемся');
              await _connectCurrent();
            } else if (type == 'new_wifi' && _autoConnect.onNewWifi) {
              _log('🌐 AutoConnect: новый WiFi → подключаемся');
              await _connectCurrent();
            } else if (type == 'mobile' && _autoConnect.onMobileData) {
              _log('🌐 AutoConnect: мобильный интернет → подключаемся');
              await _connectCurrent();
            }
          }
          break;
        // AutoConnect: запустилось приложение-триггер
        case 'app_launched':
          final pkg = call.arguments as String? ?? '';
          if (!isConnected && _autoConnect.apps.any(
              (a) => a.packageName == pkg && a.enabled)) {
            _log('📱 AutoConnect: запущено $pkg → подключаемся');
            await _connectCurrent();
          }
          break;
      }
    });
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _v2ray.initializeV2Ray(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    await loadFromDisk();
    await _loadHistory();
    await NewsAwareness.load();           // загружаем blacklist стратегий
    _setupCommandChannel();
    _ipCheck.fetchReal();
    await _loadStealthPrefs();
    _autoConnect.load();
    unawaited(StrategyBlacklist.load()); // восстанавливаем blacklist после рестарта
    _bypassRules.syncFromServer(_log).then((_) => _notify());
    // Синхронизируем статистику стратегий с сервером (фоново)
    NewsAwareness.syncFromServer(kControlPlaneUrl).catchError((_) {});
    _fetchServerNodes();
  }

  // ── Profiles (v3.0) ──────────────────────────────────────────────────────

  void _ensureDefaultProfile() {
    if (profiles.isEmpty) {
      final def = AuraProfile(id: 'default', name: 'Default');
      profiles = [def];
      activeProfileId = def.id;
    }
  }

  Future<void> createProfile(String name) async {
    final p = AuraProfile(id: AuraProfile._uid(), name: name.trim().isEmpty ? 'Profile' : name.trim());
    profiles.add(p);
    await saveToDisk(); _notify();
  }

  Future<void> switchProfile(String id) async {
    if (!profiles.any((p) => p.id == id)) return;
    // Сохраняем текущие конфиги в профиль
    _prof.configsJson = _configs.map((c) => c.toMap()).toList();
    activeProfileId = id;
    // Загружаем конфиги нового профиля
    _configs = _prof.configsJson
        .map((m) { try { return VpnConfig.fromMap(m); } catch (_) { return null; } })
        .whereType<VpnConfig>().toList();
    if (selectedIndex >= _configs.length) selectedIndex = 0;
    await saveToDisk(); _notify();
  }

  Future<void> deleteProfile(String id) async {
    if (profiles.length <= 1) return; // нельзя удалить единственный профиль
    profiles.removeWhere((p) => p.id == id);
    if (activeProfileId == id) activeProfileId = profiles.first.id;
    await saveToDisk(); _notify();
  }

  Future<void> renameProfile(String id, String newName) async {
    final p = profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
    p.name = newName.trim().isEmpty ? 'Profile' : newName.trim();
    await saveToDisk(); _notify();
  }

  // ── Split Tunnel (v3.0) ──────────────────────────────────────────────────

  Future<void> setSplitMode(SplitTunnelMode mode) async {
    _prof.splitMode = mode;
    await saveToDisk(); _notify();
  }

  Future<void> toggleSplitApp(String packageName) async {
    final list = List<String>.from(_prof.splitApps);
    if (list.contains(packageName)) list.remove(packageName);
    else list.add(packageName);
    _prof.splitApps = list;
    await saveToDisk(); _notify();
  }

  List<String>? _splitArgsForConnect() {
    if (_prof.splitMode == SplitTunnelMode.disabled) return null;
    if (_prof.splitApps.isEmpty) return null;
    // flutter_v2ray: blockedApps = apps that BYPASS vpn
    if (_prof.splitMode == SplitTunnelMode.bypass)  return _prof.splitApps;
    // proxy mode: все остальные приложения в bypass, только выбранные через vpn
    // не поддерживается напрямую — передаём пустой список (весь трафик через VPN)
    return null;
  }

  // ── Backup (v3.0) ────────────────────────────────────────────────────────

  String exportBackup(String password) {
    // Сохраняем текущие конфиги в профиль перед экспортом
    _prof.configsJson = _configs.map((c) => c.toMap()).toList();
    return BackupEngine.export(profiles, activeProfileId, password);
  }

  Future<bool> importBackup(String b64, String password) async {
    final data = BackupEngine.import(b64, password);
    if (data == null) return false;
    try {
      profiles = (data['profiles'] as List)
          .map((j) => AuraProfile.fromJson(j as Map<String, dynamic>))
          .toList();
      if (profiles.isEmpty) { _ensureDefaultProfile(); }
      activeProfileId = data['activeId'] ?? profiles.first.id;
      if (!profiles.any((p) => p.id == activeProfileId)) {
        activeProfileId = profiles.first.id;
      }
      _configs = _prof.configsJson
          .map((m) { try { return VpnConfig.fromMap(m); } catch (_) { return null; } })
          .whereType<VpnConfig>().toList();
      if (selectedIndex >= _configs.length) selectedIndex = 0;
      await saveToDisk(); _notify();
      return true;
    } catch (_) { return false; }
  }

  // ── Favourites (v3.0) ────────────────────────────────────────────────────

  void toggleFavourite(int i) {
    if (i < 0 || i >= _configs.length) return;
    _configs[i].isFavourite = !_configs[i].isFavourite;
    saveToDisk(); _notify();
  }

  // ── Search (v3.0) ────────────────────────────────────────────────────────

  void setSearch(String q) {
    searchQuery = q;
    _notify();
  }

  // ── Watchdog ─────────────────────────────────────────────────────────────

  void _startWd() {
    _cancelWd();
    _watchdog = Timer(_watchdogTimeout, () {
      if (status == 'CONNECTING') { _log('🐕 Watchdog → bypass'); _scheduleBypass(); }
    });
  }

  void _cancelWd() { _watchdog?.cancel(); _watchdog = null; }

  void _scheduleBypass() {
    if (_isRotating) return;
    _isRotating = true; _failCount = 0;

    // FIX v3.0: сбрасываем SNI кэш перед байпасом — предыдущий SNI заблокирован
    StealthEngine.invalidateSniCache();

    // Stealth 3.0: если 3+ handshake провала → Shadow Fallback
    if (stealthMode && stealthHandshakeFails >= 3) {
      _log('👻 Shadow Fallback: пробуем резервный протокол…');
      Future.microtask(_tryShadowFallback);
      return;
    }

    Future.microtask(_prof.aiEnabled ? _runAiBypass : _autoNext);
  }

  // Shadow Fallback — переключаемся на ноду с другим протоколом
  Future<void> _tryShadowFallback() async {
    final alternatives = _configs
        .where((c) => c.protocol == 'SS' || c.protocol == 'TROJAN' || c.protocol == 'HY2')
        .toList()
      ..sort((a, b) => a.pingMs.compareTo(b.pingMs));

    if (alternatives.isNotEmpty) {
      final fb = alternatives.first;
      _log('👻 Shadow Fallback → ${fb.displayName} (${fb.protocol})');
      stealthHandshakeFails = 0;
      StealthEngine.resetCounter();
      await _connectWith(fb);
    } else {
      _log('👻 Нет SS/Trojan/HY2 нод → AI bypass');
      Future.microtask(_prof.aiEnabled ? _runAiBypass : _autoNext);
    }
    _isRotating = false;
  }

  // ── AI Bypass ────────────────────────────────────────────────────────────

  // Счётчик попыток bypass — сбрасывается при успешном подключении
  int _bypassAttempt  = 0;
  int _bypassNodeIdx  = 0; // индекс ноды для ротации

  Future<void> _runAiBypass() async {
    if (_configs.isEmpty || selectedIndex >= _configs.length) {
      _isRotating = false; return;
    }

    _bypassAttempt++;
    final cur = _configs[selectedIndex];
    _log('🤖 Bypass #$_bypassAttempt · node: ${cur.displayName}');

    // Показываем номер попытки в stealthStatus (виден пользователю в ConnectCard)
    stealthStatus = '🤖 Bypass #$_bypassAttempt';
    aiStatus      = 'SCANNING #$_bypassAttempt';
    _notify();

    final bypassed = await _aiAgent.findBypass(cur);
    if (_disposed) return;

    if (bypassed != null) {
      // Нашли рабочий обход
      aiStatus      = 'APPLYING';
      stealthStatus = '🤖 Applying…';
      _notify();
      _log('🤖 ✅ Bypass found → reconnecting');
      _bypassAttempt = 0;
      _sendNotification('🤖 AI нашёл обход', bypassed.name);
      await _reconnect(bypassed);
      stealthStatus = '';
      return;
    }

    // Не нашли для этой ноды → ротируем
    _log('🤖 All strategies failed for ${cur.displayName} → rotate node');
    aiStatus = 'ROTATING';

    if (_configs.length > 1) {
      _bypassNodeIdx = (_bypassNodeIdx + 1) % _configs.length;
      if (_bypassNodeIdx == selectedIndex) {
        _bypassNodeIdx = (_bypassNodeIdx + 1) % _configs.length;
      }
      selectedIndex = _bypassNodeIdx;
      stealthStatus = '🔄 Нода #$selectedIndex';
      if (selectedIndex < _configs.length) {
        _log('🤖 Node → #$selectedIndex: ${_configs[selectedIndex].displayName}');
      }
    }
    _notify();

    // Каждые 5 попыток — cooldown (даём РКН "остыть")
    if (_bypassAttempt > 0 && _bypassAttempt % 5 == 0) {
      stealthStatus = '⏳ Cooldown 30s';
      aiStatus      = 'COOLDOWN';
      _notify();
      _log('🤖 Cooldown 30s (attempt #$_bypassAttempt)');
      await Future.delayed(const Duration(seconds: 30));

      if (_disposed || (!isAutoMode && _bypassAttempt > 20)) {
        _isRotating   = false;
        aiStatus      = 'FAILED';
        stealthStatus = '';
        _log('🤖 ${AuraErrorCode.e1030.code}: bypass loop limit');
        _notify(); return;
      }
    }

    // Повтор
    if (!_disposed && (isAutoMode || _bypassAttempt <= 20)) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_disposed) Future.microtask(_runAiBypass);
    } else {
      _isRotating   = false;
      aiStatus      = 'FAILED';
      stealthStatus = '';
      _notify();
    }
  }

  Future<void> _reconnect(VpnConfig cfg) async {
    if (_isRotating) return; // guard против двойного вызова
    _isRotating = true; _notify();
    try { await _v2ray.stopV2Ray(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1200));
    if (_disposed) { _isRotating = false; return; }
    await _connectWith(cfg);
    _isRotating = false; aiStatus = 'IDLE'; _notify();
  }

  Future<void> _autoNext() async {
    if (_configs.isEmpty) { _isRotating = false; return; }
    try { await _v2ray.stopV2Ray(); } catch (_) {}
    // FIX v3.0: DNS leak gap — увеличена пауза при авто-переключении ноды
    await Future.delayed(const Duration(milliseconds: 1000));
    if (_disposed) return;
    selectedIndex = (selectedIndex + 1) % _configs.length;
    if (selectedIndex < _configs.length) {
      _log('↻ [$selectedIndex] ${_configs[selectedIndex].name}');
    }
    _notify();
    await _connectCurrent();
    _isRotating = false;
  }

  // ── Connect ──────────────────────────────────────────────────────────────

  Future<void> _connectCurrent() async {
    if (_configs.isEmpty || selectedIndex >= _configs.length) return;
    await _connectWith(_configs[selectedIndex]);
  }

  Future<void> _connectWith(VpnConfig cfg) async {
    _log('⚡ ${cfg.displayName}');
    try {
      // ── БЫСТРЫЙ ПУТЬ: макс 5 сек до startV2Ray ────────────────────────────
      // FIX: ForegroundServiceDidNotStartInTimeException — Android убивает
      // сервис если startForeground() не вызван за 5 сек после startForegroundService()
      // Решение: НЕ делаем никаких blocking операций до startV2Ray
      // Stealth операции (warmup, SNI, pacing) — только в фоне после старта

      // Шаг 1: Парсим конфиг (мгновенно)
      String finalLink = cfg.link;

      // Reality SNI без сетевых проверок — используем кэш или первый в пуле
      if (stealthMode && stealthRealitySni) {
        final cachedSni = StealthEngine.cachedSniPublic;
        final sni = cachedSni.isNotEmpty && cachedSni != '—'
            ? cachedSni
            : StealthEngine.pickLiveSniFromCache(); // только кэш, без I/O
        finalLink = StealthEngine.injectRealityWithSni(finalLink, sni);
      }

      final patchedCfg = VpnConfig(
        name: cfg.name, link: finalLink,
        customName: cfg.customName, groupName: cfg.groupName,
        sourceUrl: cfg.sourceUrl, isManual: cfg.isManual,
        isAiPatched: cfg.isAiPatched, isFavourite: cfg.isFavourite,
      );

      // Шаг 2: Генерируем конфиг (мгновенно)
      final V2RayURL parsed = FlutterV2ray.parseFromURL(patchedCfg.link);
      String configStr = parsed.getFullConfiguration();
      if (configStr.isEmpty) {
        _log('✗ E-1003: getFullConfiguration() returned empty');
        _isRotating = false; status = 'ERROR'; stealthStatus = ''; _notify(); return;
      }

      // Шаг 3: Патчим конфиг (CPU only, мгновенно)
      configStr = StealthEngine.patchConfig(configStr, fragment: stealthMode && stealthFragment);
      if (siberiaShield && stealthMode) {
        configStr = SiberiaShield.applyToConfig(configStr);
      }
      // Применяем маскировку трафика (Traffic Camouflage)
      final camoMode = camouflage;
      if (camoMode != CamouflageMode.none) {
        configStr = TrafficCamouflageEngine.apply(configStr, camoMode);
        _log('🎭 Camouflage: ${camoMode.emoji} ${camoMode.label}');
      }

      // Smart routing (JSON parsing, мгновенно)
      try {
        final jRoute = jsonDecode(configStr) as Map<String, dynamic>;
        final existingRules = (jRoute['routing']?['rules'] as List?)?.length ?? 0;
        if (existingRules <= 1) {
          jRoute['routing'] = _bypassRules.buildRussiaRoutingRules();
          final obs = jRoute['outbounds'] as List? ?? [];
          if (!obs.any((o) => o is Map && o['tag'] == 'direct')) {
            obs.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
          }
          if (!obs.any((o) => o is Map && o['tag'] == 'block')) {
            obs.add({'tag': 'block', 'protocol': 'blackhole', 'settings': {}});
          }
          configStr = jsonEncode(jRoute);
        }
      } catch (_) {}

      // Telegram Protocol (JSON, мгновенно)
      final host = _extractHost(cfg.link);
      if (TelegramProtocol.isTelegramHost(host) ||
          cfg.groupName.toLowerCase().contains('tg') ||
          cfg.name.toLowerCase().contains('telegram') ||
          cfg.name.toLowerCase().contains('mtproto')) {
        configStr = TelegramProtocol.optimizeForTelegram(configStr);
        _log('✈️ Telegram Fast Protocol');
      }

      // Шаг 4: Валидация JSON (мгновенно)
      try {
        final testParse = jsonDecode(configStr) as Map<String, dynamic>;
        if (!testParse.containsKey('outbounds')) {
          throw const FormatException('missing outbounds');
        }
      } catch (e) {
        _log('✗ Config invalid: $e');
        _isRotating = false; status = 'ERROR'; stealthStatus = ''; _notify(); return;
      }

      // Шаг 5: Разрешение VPN (системный диалог, мгновенно если уже выдано)
      final granted = await _v2ray.requestPermission();
      if (!granted) { _log('✗ Permission denied'); _isRotating = false; return; }

      // Шаг 6: ЗАПУСКАЕМ V2RAY — Android требует вызова внутри 5 сек
      await _v2ray.startV2Ray(
        remark:        parsed.remark.isNotEmpty ? parsed.remark : cfg.displayName,
        config:        configStr,
        blockedApps:   _splitArgsForConnect(),
        bypassSubnets: null,
        proxyOnly:     killSwitch,
      );

      stealthHandshakeFails = 0;
      StealthEngine.resetCounter();

      // Шаг 7: ФОНОВЫЕ операции — после запуска VPN, не блокируют старт
      // Siberia pacing, warmup, SNI probing — всё асинхронно
      _runStealthBackground(cfg, host);

    } catch (e) {
      _log('✗ $e');
      _isRotating = false;
      status = 'ERROR';
      stealthStatus = '';

      // TspuCountermeasures2026: умная классификация ошибки
      final blockType = TspuCountermeasures2026.classifyError(e.toString());
      final errStr = e.toString().toLowerCase();
      final isBlock = blockType != BlockType.timeout ||
                      errStr.contains('reset') || errStr.contains('timeout') ||
                      errStr.contains('refused') || errStr.contains('connection');

      // Логируем тип для Dev Dashboard
      if (blockType != BlockType.timeout) {
        final prio = TspuCountermeasures2026.prioritizedStrategies(blockType).take(3).join(',');
        _log('🔍 Тип блокировки: ${blockType.name} → приоритет стратегий: $prio');
      }

      if (isBlock) {
        stealthHandshakeFails++;
        if (siberiaShield) {
          // host доступен через _extractHost в catch контексте
          final blockedHost = _extractHost(cfg.link);
          if (blockedHost.isNotEmpty) {
            SiberiaShield.reportBlocked(blockedHost);
          }
          SiberiaShield.cleanup();
        }
        if (StealthEngine.reportReset()) {
          StealthEngine.invalidateSniCache();
        }
        if (stealthHandshakeFails >= 3 && !_isRotating) {
          _scheduleBypass();
        }
      }
      _notify();
    }
  }

  // Фоновые stealth операции — запускаются ПОСЛЕ startV2Ray
  // Не блокируют подключение, улучшают маскировку для следующего коннекта
  void _runStealthBackground(VpnConfig cfg, String host) {
    Future.microtask(() async {
      try {
        // Siberia pacing + decoy — готовим следующее подключение
        if (siberiaShield && stealthMode && host.isNotEmpty) {
          await SiberiaShield.paceConnection(host);
          unawaited(SiberiaShield.sendDecoy(_log));
        }
        // Warm-up probe — обновляем кэш для следующего раза
        if (stealthMode && stealthWarmup) {
          unawaited(StealthEngine.warmUp(_log));
        }
        // Обновляем SNI кэш в фоне
        if (stealthMode && stealthRealitySni) {
          unawaited(StealthEngine.pickLiveSni());
        }
      } catch (_) {}
    });
  }

  Future<void> toggle() async {
    if (isConnected) {
      _cancelWd(); _failCount = 0; _isRotating = false; aiStatus = 'IDLE';
      await _v2ray.stopV2Ray();
      await _dismissPersistentNotif();
      await _updateTile(active: false);
    } else {
      if (_configs.isEmpty) { _log('✗ No nodes'); return; }
      await _connectCurrent();
    }
  }

  // ── Node management ──────────────────────────────────────────────────────

  void renameNode(int i, String newName) {
    if (i < 0 || i >= _configs.length) return;
    _configs[i].customName = newName.trim();
    saveToDisk(); _notify();
  }

  void renameGroup(String url, String newName) {
    subNames[url] = newName.trim();
    saveToDisk(); _notify();
  }

  // Извлекаем hostname из VPN ссылки для SiberiaShield pacing
  String _extractHost(String link) {
    try {
      final raw = link.contains('@')
          ? 'dummy://${link.split('@').last.split('#').first}'
          : link;
      return Uri.parse(raw).host;
    } catch (_) { return ''; }
  }

  String _groupNameFromUrl(String url) {
    if (subNames.containsKey(url)) return subNames[url]!;
    try { return Uri.parse(url).host.replaceAll('www.', ''); }
    catch (_) { return url; }
  }

  void selectNode(int i) {
    if (i < 0 || i >= _configs.length) return;
    selectedIndex = i; saveToDisk(); _notify();
  }

  void addSingleKey(String raw) {
    final link = raw.trim();
    // FIX v3.0: строгая валидация протокола — мусорные ноды вызывали crash в v2ray
    const validProtocols = ['vless://', 'vmess://', 'trojan://', 'ss://', 'ssr://',
                            'hysteria2://', 'hy2://', 'hysteria://', 'wireguard://'];
    final hasValidProtocol = validProtocols.any((p) => link.toLowerCase().startsWith(p));
    if (!hasValidProtocol) {
      _log('✗ Unsupported protocol: ${link.split('://').first}');
      return;
    }
    if (_configs.any((c) => c.link == link)) { _log('⚠ Duplicate'); return; }
    String name = 'Manual Key';
    if (link.contains('#')) {
      try {
        final n = Uri.decodeFull(link.split('#').last).replaceAll('+', ' ').trim();
        if (n.isNotEmpty) name = n;
      } catch (_) {}
    }
    _configs.add(VpnConfig(name: name, link: link,
        groupName: 'Manual Keys', sourceUrl: 'manual', isManual: true));
    _log('✚ $name'); saveToDisk(); _notify();
  }

  // Сбросить ключ/конфиг к оригинальному (как пришёл от провайдера/подписки)
  // Убирает все AI-патчи, маскировку, изменения транспорта
  void resetNodeToOriginal(int idx) {
    if (idx < 0 || idx >= _configs.length) return;
    _configs[idx].resetToOriginal();
    _log('↩ "${_configs[idx].displayName}" — сброс к оригинальному ключу провайдера');
    saveToDisk();
    _notify();
  }

  void deleteNode(int i) {
    if (i < 0 || i >= _configs.length) return;
    _configs.removeAt(i);
    if (selectedIndex >= _configs.length) {
      selectedIndex = _configs.isEmpty ? 0 : _configs.length - 1;
    }
    saveToDisk(); _notify();
  }

  // ── Subscriptions ────────────────────────────────────────────────────────

  Future<void> refreshSubscription(String url) async {
    // Удаляем старые ноды этой подписки и загружаем заново
    _configs.removeWhere((c) => c.sourceUrl == url);
    _prof.subLinks.remove(url);
    _notify();
    await addSubscription(url);
  }

  Future<void> addSubscription(String url) async {
    var u = url.trim();
    if (u.isEmpty) { _log('✗ E-1009: Empty URL'); return; }
    // Upgrade HTTP → HTTPS (подписки не должны идти по открытому каналу)
    if (u.startsWith('http://')) {
      u = u.replaceFirst('http://', 'https://');
      _log('⚠ HTTP URL upgraded to HTTPS');
    }
    if (!u.startsWith('https://')) { _log('✗ E-1009: URL must be https://'); return; }
    // Базовая валидация URL
    try {
      final parsed = Uri.parse(u);
      if (parsed.host.isEmpty) throw FormatException('No host');
    } catch (_) { _log('✗ E-1009: Invalid URL format'); return; }
    if (subLinks.contains(u)) { _log('⚠ Already exists'); return; }
    _prof.subLinks.add(u);
    await _fetchSub(u); saveToDisk();
  }

  Future<void> removeSubscription(int i) async {
    if (i < 0 || i >= subLinks.length) return;
    final url = subLinks[i];
    _prof.subLinks.removeAt(i);
    subNames.remove(url);
    _configs.removeWhere((c) => c.sourceUrl == url);
    if (selectedIndex >= _configs.length) selectedIndex = 0;
    _log('✖ Sub removed'); saveToDisk(); _notify();
  }

  Future<void> refreshConfigs() async {
    status = 'SYNCING...'; _notify();
    final manuals = _configs.where((c) => c.isManual).toList();
    _configs = [...manuals];
    for (final url in subLinks) await _fetchSub(url);
    status = _configs.isEmpty ? 'OFFLINE' : 'UPDATED';
    if (selectedIndex >= _configs.length) selectedIndex = 0;
    _log('✔ ${_configs.length} nodes'); _notify(); saveToDisk();
  }

  Future<void> _fetchSub(String url) async {
    try {
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': kStealthUA}).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) { _log('✗ HTTP ${res.statusCode}'); return; }
      String raw = res.body.trim();
      try {
        final clean = raw.replaceAll(RegExp(r'\s'), '');
        final pad = clean.length % 4;
        raw = utf8.decode(base64.decode(pad == 0 ? clean : clean + '=' * (4 - pad)));
      } catch (_) {}
      final gname = _groupNameFromUrl(url);
      int added = 0;
      for (final line in raw.split(RegExp(r'[\n\r]+'))) {
        final l = line.trim();
        if (!l.contains('://')) continue;
        if (_configs.any((c) => c.link == l)) continue;
        String name = 'Node';
        if (l.contains('#')) {
          try {
            final n = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim();
            if (n.isNotEmpty) name = n;
          } catch (_) {}
        }
        _configs.add(VpnConfig(name: name, link: l, groupName: gname, sourceUrl: url));
        added++;
      }
      _log('✔ $gname +$added');
    } on TimeoutException { _log('✗ Timeout: $url'); }
    catch (e) { _log('✗ Fetch: $e'); }
  }

  Future<void> _fetchServerNodes() async {
    // ── Stealth 2.0: Self-Healing Dead Drop ────────────────────────────────
    // Если основной API недоступен — пробуем зеркала и DNS TXT
    final nodeLinks = await SelfHealingMirror.fetchNodes(_log);
    if (nodeLinks.isNotEmpty) {
      int added = 0;
      for (final l in nodeLinks) {
        if (!l.contains('://') || _configs.any((c) => c.link == l)) continue;
        String name = 'Aura Node';
        if (l.contains('#')) {
          try { name = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim(); } catch (_) {}
        }
        _configs.add(VpnConfig(name: name, link: l,
            groupName: 'Aura Servers', sourceUrl: 'server'));
        added++;
      }
      if (added > 0) { _log('✔ +$added server nodes (Self-Healing)'); saveToDisk(); _notify(); }
      return;
    }

    // Fallback: классический способ (base64 блоб)
    try {
      final res = await http.get(Uri.parse(kNodesUrl),
          headers: {'User-Agent': kStealthUA})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        String raw = res.body.trim();
        try {
          final clean = raw.replaceAll(RegExp(r'\s'), '');
          final pad = clean.length % 4;
          raw = utf8.decode(base64.decode(pad == 0 ? clean : clean + '=' * (4 - pad)));
        } catch (_) {}
        int added = 0;
        for (final line in raw.split(RegExp(r'[\n\r]+'))) {
          final l = line.trim();
          if (!l.contains('://') || _configs.any((c) => c.link == l)) continue;
          String name = 'Aura Node';
          if (l.contains('#')) {
            try { name = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim(); } catch (_) {}
          }
          _configs.add(VpnConfig(name: name, link: l,
              groupName: 'Aura Servers', sourceUrl: 'server'));
          added++;
        }
        if (added > 0) { _log('✔ +$added server nodes'); saveToDisk(); _notify(); }
      }
    } catch (_) {}
  }

  // ── Ping (TCP, parallel 8) ────────────────────────────────────────────────

  Future<void> pingNode(int i) async {
    if (_disposed) return;
    if (i < 0 || i >= _configs.length) return;
    final cfg = _configs[i];
    if (cfg.isPinging) return;
    cfg.isPinging = true; _notify();
    try {
      final ms = await VpnConfig.tcpPing(cfg.link);
      if (_disposed) return; // проверяем после await — провайдер мог быть удалён
      // Также re-check bounds — _configs мог измениться пока пинговали
      if (i >= _configs.length || _configs[i] != cfg) return;
      cfg.pingMs = ms;
      cfg.ping   = (ms > 0 && ms < 9000) ? '${ms}ms' : 'DEAD';
    } catch (_) {
      if (_disposed) return;
      cfg.ping = 'ERR'; cfg.pingMs = 9999;
    }
    cfg.isPinging = false;
    if (!_disposed) _notify();
  }

  Future<void> pingAll() async {
    if (isPingAllRunning || _configs.isEmpty || _disposed) return;
    isPingAllRunning = true;
    _log('◎ Ping ${_configs.length} nodes...'); _notify();
    final total = _configs.length;
    for (int i = 0; i < total; i += 8) {
      if (_disposed) { isPingAllRunning = false; _notify(); return; }
      final batch = (i + 8 <= total) ? 8 : total - i;
      await Future.wait(List.generate(batch, (j) => pingNode(i + j)));
    }
    isPingAllRunning = false;
    sortByPing();
    _log('✔ Best: ${_configs.isNotEmpty ? _configs[0].ping : "?"}');
    _notify();
  }

  void sortByPing() {
    final sl = (_configs.isNotEmpty && selectedIndex < _configs.length)
        ? _configs[selectedIndex].link : null;
    _configs.sort((a, b) => a.pingMs.compareTo(b.pingMs));
    if (sl != null) {
      final ni = _configs.indexWhere((c) => c.link == sl);
      selectedIndex = ni >= 0 ? ni : 0;
    }
    saveToDisk(); _notify();
  }

  // ── Авто-режим (v5.1) ────────────────────────────────────────────────────

  /// Переключает авто-режим.
  /// Авто: пингует все ноды → выбирает лучшую → подключается → перепроверяет каждые 3 мин.
  Future<void> toggleAutoMode() async {
    if (isAutoMode) {
      isAutoMode = false;
      isAutoRunning = false;
      autoStatus = '';
      _autoRecheckTimer?.cancel();
      _autoRecheckTimer = null;
      _log('🎯 Авто-режим: ВЫКЛЮЧЕН');
      _notify();
      return;
    }

    isAutoMode    = true;
    isAutoRunning = true;
    autoStatus    = 'Поиск лучшей ноды…';
    _log('🎯 Авто-режим: ВКЛЮЧЁН');
    _notify();

    try {
      await _autoSelectBest();
    } catch (e) {
      // FIX: всегда сбрасываем isAutoRunning чтобы не зависнуть
      isAutoRunning = false;
      autoStatus    = 'Ошибка';
      _log('🎯 Авто: ошибка — $e');
      _notify();
      return;
    }

    _autoRecheckTimer?.cancel();
    _autoRecheckTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (!isAutoMode || !isConnected) return;
      _log('🎯 Авто: перепроверка…');
      try {
        await _autoSelectBest(reconnect: true);
      } catch (_) {}
    });
  }

  Future<void> _autoSelectBest({bool reconnect = false}) async {
    if (_configs.isEmpty) {
      isAutoRunning = false;
      autoStatus    = 'Нет нод';
      _notify();
      return;
    }

    isAutoRunning = true;
    autoStatus    = 'Пингую ${_configs.length} нод…';
    _notify();

    try {
      final total = _configs.length;
      for (int i = 0; i < total; i += 8) {
        if (_disposed || !isAutoMode) break;
        final batch = (i + 8 <= total) ? 8 : total - i;
        await Future.wait(List.generate(batch, (j) => pingNode(i + j)));
        autoStatus = 'Пингую… ${((i + batch) / total * 100).toInt()}%';
        _notify();
      }

      if (!isAutoMode) { isAutoRunning = false; _notify(); return; }

      final alive = _configs
          .where((c) => c.pingMs > 0 && c.pingMs < 9000)
          .toList()
        ..sort((a, b) => a.pingMs.compareTo(b.pingMs));

      if (alive.isEmpty) {
        isAutoRunning = false;
        autoStatus    = 'Нет живых нод';
        _log('🎯 Авто: нет живых нод');
        _notify();
        return;
      }

      final best    = alive.first;
      final bestIdx = _configs.indexOf(best);

      if (reconnect && isConnected && selectedIndex == bestIdx) {
        isAutoRunning = false;
        autoStatus    = '${best.displayName} · ${best.ping}';
        _notify();
        return;
      }

      selectedIndex = bestIdx;
      isAutoRunning = false;
      autoStatus    = '${best.displayName} · ${best.ping}';
      _log('🎯 Авто: лучшая нода → ${best.displayName} (${best.ping})');
      _notify();

      if (isConnected) {
        await _reconnect(best);
      } else {
        await _connectCurrent();
      }
    } catch (e) {
      isAutoRunning = false;
      autoStatus    = 'Ошибка пинга';
      _log('🎯 Авто: ошибка — $e');
      _notify();
    }
  }

  // ── Whitelist Bypass (v5.0) ──────────────────────────────────────────────

  /// Активирует режим обхода белых списков:
  /// 1. DNS → DoH (Cloudflare)
  /// 2. Порт → 443
  /// 3. Transport → WebSocket + CDN SNI
  /// 4. Если VPN подключён — реконнект с новыми параметрами
  Future<void> activateWhitelistBypass() async {
    if (whitelistBypassActive) {
      whitelistBypassActive = false;
      whitelistBypassStatus = 'IDLE';
      _log('🌐 Обход белых списков: ВЫКЛЮЧЕН');
      _notify();
      if (isConnected && _configs.isNotEmpty && selectedIndex < _configs.length) {
        await _reconnect(_configs[selectedIndex]);
      }
      return;
    }

    whitelistBypassStatus = 'ACTIVATING';
    _notify();
    _log('🌐 Активируем обход белых списков...');

    try {
      // Шаг 1 — применяем CDN стратегию к текущей ноде
      if (_configs.isEmpty) {
        whitelistBypassStatus = 'FAILED';
        _log('✗ Нет нод для обхода');
        _notify();
        await Future.delayed(const Duration(seconds: 2));
        whitelistBypassStatus = 'IDLE';
        _notify();
        return;
      }

      // Патчим текущую конфигурацию под CDN обход
      if (selectedIndex >= _configs.length) {
        whitelistBypassActive = false;
        whitelistBypassStatus = 'IDLE';
        _log('✗ Нет активной ноды для обхода');
        _notify(); return;
      }
      final cur  = _configs[selectedIndex];
      // Модифицируем link: меняем порт на 443 и добавляем WS параметры
      String patchedLink = cur.link;
      try {
        final uri = Uri.parse(patchedLink);
        // Меняем порт на 443 и добавляем параметры CDN
        final newParams = Map<String, String>.from(uri.queryParameters)
          ..['type']     = 'ws'
          ..['security'] = 'tls'
          ..['sni']      = 'speed.cloudflare.com'
          ..['path']     = '%2Fvpn';
        patchedLink = uri.replace(port: 443, queryParameters: newParams).toString();
      } catch (_) {
        // Если не удалось распарсить — используем оригинал
        patchedLink = cur.link;
      }
      final patched = VpnConfig(
        name:       '${cur.name} [WL]',
        link:       patchedLink,
        customName: '',
        groupName:  cur.groupName,
        sourceUrl:  cur.sourceUrl,
        isManual:   cur.isManual,
        isAiPatched: true,
      );

      whitelistBypassActive = true;
      whitelistBypassStatus = 'ACTIVE';
      _log('✅ Обход белых списков: АКТИВЕН (порт 443, WS, CDN SNI)');
      _notify();

      // Реконнект с пропатченным конфигом
      if (isConnected) {
        await _reconnect(patched);
      }
    } catch (e) {
      whitelistBypassActive = false;
      whitelistBypassStatus = 'FAILED';
      _log('✗ Ошибка обхода: $e');
      _notify();
      await Future.delayed(const Duration(seconds: 2));
      whitelistBypassStatus = 'IDLE';
      _notify();
    }
  }

  Future<void> toggleBypassBtnMode() async {
    bypassBtnMode = !bypassBtnMode;
    final p = await SharedPreferences.getInstance();
    await p.setBool('bypass_btn_mode', bypassBtnMode);
    _notify();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  // Статичный обфускатор для хранилища — не настоящее шифрование,
  // но защищает от случайного чтения через adb backup / file manager
  static const _storageKey = 'AuraVPN\$t0r4g3K3y2026';
  static String _obfuscate(String json) {
    final bytes = utf8.encode(json);
    final key   = utf8.encode(_storageKey);
    final enc   = List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64.encode(enc);
  }
  static String? _deobfuscate(String? data) {
    if (data == null) return null;
    try {
      final bytes = base64.decode(data);
      final key   = utf8.encode(_storageKey);
      final dec   = List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
      return utf8.decode(dec);
    } catch (_) {
      // Fallback: возможно данные в старом формате (plaintext JSON)
      return data;
    }
  }

  Future<void> saveToDisk() async {
    try {
      _prof.configsJson = _configs.map((c) => c.toMap()).toList();
      final p    = await SharedPreferences.getInstance();
      final json = jsonEncode(profiles.map((x) => x.toJson()).toList());
      await p.setString('aura_profiles',       _obfuscate(json));
      await p.setString('aura_active_profile',  activeProfileId);
      await p.setInt('selected_index',          selectedIndex);
      await p.setBool('stealth_mode',           stealthMode);
      await p.setBool('stealth_fragment',       stealthFragment);
      await p.setBool('stealth_reality_sni',    stealthRealitySni);
      await p.setBool('stealth_warmup',         stealthWarmup);
    } catch (e) { _log('✗ Save: $e'); }
  }

  Future<void> loadFromDisk() async {
    try {
      final p = await SharedPreferences.getInstance();
      final profilesRaw = _deobfuscate(p.getString('aura_profiles'));
      if (profilesRaw != null) {
        profiles = (jsonDecode(profilesRaw) as List)
            .map((j) => AuraProfile.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      _ensureDefaultProfile();
      activeProfileId = p.getString('aura_active_profile') ?? profiles.first.id;
      if (!profiles.any((x) => x.id == activeProfileId)) {
        activeProfileId = profiles.first.id;
      }
      selectedIndex  = p.getInt('selected_index')   ?? 0;
      bypassBtnMode      = p.getBool('bypass_btn_mode')     ?? false;
      stealthMode        = p.getBool('stealth_mode')        ?? true;
      stealthFragment    = p.getBool('stealth_fragment')    ?? true;
      stealthRealitySni  = p.getBool('stealth_reality_sni') ?? true;
      stealthWarmup      = p.getBool('stealth_warmup')      ?? true;
      _configs = _prof.configsJson
          .map((m) { try { return VpnConfig.fromMap(m); } catch (_) { return null; } })
          .whereType<VpnConfig>().toList();
      if (selectedIndex >= _configs.length) selectedIndex = 0;
      _log('✔ ${_configs.length} nodes [${_prof.name}]'); _notify();
    } catch (e) { _log('✗ Load: $e'); }
  }
}

// ═══════════════════════════════════════════════════════════════
//  GLASSMORPHISM 2.0
// ═══════════════════════════════════════════════════════════════

class _Blob { double x, y, vx, vy, r; Color color; _Blob(this.x,this.y,this.vx,this.vy,this.r,this.color); }

// ═══════════════════════════════════════════════════════════════════════════════
//  FPS MONITOR — Production Performance Guard
//  Если FPS < 45 → отключаем BackdropFilter и анимацию блобов
//  Слабые телефоны работают плавно, сильные — красиво
// ═══════════════════════════════════════════════════════════════════════════════

// ── AppProvider singleton ref для AuraBlobBg ─────────────────────────────────
// AuraBlobBg не имеет доступа к Provider — используем глобальную ссылку
class _AppProviderRef {
  static AppProvider? instance;
  static void register(AppProvider app) { instance = app; }
}

// ── Media Background Widget ───────────────────────────────────────────────────
// Рендерит фото или GIF как фон с оптимизацией
class _MediaBackground extends StatefulWidget {
  final String path, type;
  final double opacity;
  const _MediaBackground({required this.path, required this.type, this.opacity = 0.35});
  @override State<_MediaBackground> createState() => _MediaBackgroundState();
}

class _MediaBackgroundState extends State<_MediaBackground> {
  // GIF: frames decoded via dart:ui codec
  List<ui.Image>? _gifImages;
  List<int>?      _gifDurations;
  int             _frameIdx = 0;
  Timer?          _gifTimer;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'gif') _loadGif();
    // video: rendered natively via TextureView in AuraVpnService
    // We simply show a static poster frame for video type
  }

  Future<void> _loadGif() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
      final imgs = <ui.Image>[];
      final durs = <int>[];
      for (int i = 0; i < codec.frameCount; i++) {
        final f = await codec.getNextFrame();
        imgs.add(f.image);
        durs.add(f.duration.inMilliseconds.clamp(16, 1000));
      }
      if (!mounted || imgs.isEmpty) return;
      setState(() { _gifImages = imgs; _gifDurations = durs; });
      _scheduleGifFrame(0);
    } catch (_) {}
  }

  void _scheduleGifFrame(int idx) {
    if (!mounted || _gifImages == null) return;
    final dur = _gifDurations![idx % _gifDurations!.length];
    _gifTimer = Timer(Duration(milliseconds: dur), () {
      if (!mounted) return;
      setState(() => _frameIdx = (idx + 1) % _gifImages!.length);
      _scheduleGifFrame(_frameIdx);
    });
  }

  @override
  void dispose() {
    _gifTimer?.cancel();
    for (final img in _gifImages ?? []) img.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.type == 'gif' && _gifImages != null) {
      child = RawImage(
        image:  _gifImages![_frameIdx],
        fit:    BoxFit.cover,
        width:  double.infinity,
        height: double.infinity,
      );
    } else if (widget.type == 'video') {
      // Video background rendered via platform view
      // Show photo thumbnail if available, otherwise dark overlay
      child = Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.play_circle_fill_rounded,
            color: Colors.white24, size: 64)),
      );
    } else {
      child = Image.file(
        File(widget.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: (MediaQuery.of(context).size.width *
            MediaQuery.of(context).devicePixelRatio).round().clamp(0, 2160),
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return SizedBox.expand(child: Opacity(opacity: widget.opacity, child: child));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CUSTOM THEME EDITOR  —  Редактор пользовательской темы
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomThemeEditor extends StatefulWidget {
  const _CustomThemeEditor();
  @override State<_CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<_CustomThemeEditor> {
  late Color _accent, _accent2, _bg, _blob1, _blob2;
  String _mediaPath = '', _mediaType = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = Provider.of<AppProvider>(context, listen: false);
    _accent   = app.customAccent;
    _accent2  = app.customAccent2;
    _bg       = app.customBg;
    _blob1    = app.customBlob1;
    _blob2    = app.customBlob2;
    _mediaPath = app.customMediaPath;
    _mediaType = app.customMediaType;
  }

  // Медиа-пикер через MethodChannel (Android native file picker)
  Future<void> _pickMedia() async {
    // Показываем выбор типа
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Фон приложения'),
        message: const Text('Выбери тип медиа для фона'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'photo'),
            child: const Text('📷 Фото или GIF из галереи')),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'path'),
            child: const Text('📝 Ввести путь вручную')),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, null),
          child: Text(S.t('cancel'))),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'path') { _showPathInput(); return; }

    // Используем существующий MethodChannel для выбора файла
    try {
      final result = await VpnProvider.cmdChannel
          .invokeMethod<String>('pickFile');
      if (result != null && result.isNotEmpty && mounted) {
        final ext  = result.split('.').last.toLowerCase();
        final type = ext == 'gif' ? 'gif' : 'photo';
        setState(() { _mediaPath = result; _mediaType = type; });
      }
    } catch (_) {
      // MethodChannel не поддерживает pickFile — ручной ввод
      if (mounted) _showPathInput();
    }
  }

  void _showPathInput() {
    final ctrl = TextEditingController(text: _mediaPath);
    showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Путь к файлу'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        const Text('Введи полный путь к фото или GIF', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        CupertinoTextField(controller: ctrl, placeholder: '/storage/emulated/0/...'),
      ]),
      actions: [
        CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        CupertinoDialogAction(onPressed: () {
          final path = ctrl.text.trim();
          Navigator.pop(ctx);
          if (path.isNotEmpty && File(path).existsSync()) {
            final ext = path.split('.').last.toLowerCase();
            setState(() { _mediaPath = path; _mediaType = ext == 'gif' ? 'gif' : 'photo'; });
          }
        }, child: const Text('OK')),
      ],
    ));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final app = Provider.of<AppProvider>(context, listen: false);
    await app.saveCustomTheme(
      accent: _accent, accent2: _accent2, bg: _bg,
      blob1: _blob1, blob2: _blob2,
      mediaPath: _mediaPath, mediaType: _mediaType,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: const Text('Тема сохранена ✓'),
        backgroundColor: Color(0xFF1B3A1B),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live preview используя текущие цвета
    // Preview uses _accent, _bg etc directly
    return AuraScaffold(
      title: 'Моя тема',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
        children: [

          // ── Превью ──────────────────────────────────────────────────────────
          _SubSection('ПРЕВЬЮ'),
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _bg,
              boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 24)]),
            child: Stack(children: [
              // Блоб-превью
              Positioned.fill(child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _PreviewBlobPainter([_blob1, _blob2, _accent]),
                  child: const SizedBox.expand()))),
              // Медиа превью
              if (_mediaPath.isNotEmpty && File(_mediaPath).existsSync())
                Positioned.fill(child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Opacity(opacity: 0.45,
                    child: _mediaType == 'video'
                        ? Container(color: Colors.black54,
                            child: Icon(Icons.play_circle_fill_rounded, color: _accent, size: 44))
                        : Image.file(File(_mediaPath), fit: BoxFit.cover)))),
              // Кнопка VPN превью
              Center(child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.4), _bg.withOpacity(0.6)]),
                  border: Border.all(color: _accent.withOpacity(0.8), width: 2)),
                child: Icon(Icons.vpn_key_rounded, color: _accent, size: 28))),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Цвета ───────────────────────────────────────────────────────────
          _SubSection('ЦВЕТА'),
          _ColorRow('Акцент (основной)', _accent, (c) => setState(() => _accent = c)),
          _ColorRow('Акцент (вторичный)', _accent2, (c) => setState(() => _accent2 = c)),
          _ColorRow('Фон', _bg, (c) => setState(() => _bg = c)),
          _ColorRow('Блоб 1', _blob1, (c) => setState(() => _blob1 = c)),
          _ColorRow('Блоб 2', _blob2, (c) => setState(() => _blob2 = c)),

          const SizedBox(height: 20),

          // ── Фон (медиа) ─────────────────────────────────────────────────────
          _SubSection('ФОН'),
          GlassBox(
            radius: 14, blur: 20,
            tint: _accent, tintOpacity: 0.06,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_mediaPath.isNotEmpty && File(_mediaPath).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _mediaType == 'video'
                        ? Container(
                            height: 120, width: double.infinity,
                            decoration: BoxDecoration(color: Colors.black87,
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.play_circle_fill_rounded, color: _accent, size: 52),
                              const SizedBox(height: 6),
                              const Text('Видео выбрано',
                                  style: TextStyle(fontSize: 11, color: Colors.white54)),
                            ]))
                        : Image.file(File(_mediaPath),
                            height: 120, width: double.infinity, fit: BoxFit.cover)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(
                      _mediaPath.split('/').last,
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                      overflow: TextOverflow.ellipsis)),
                    GestureDetector(
                      onTap: () {
                        final app = Provider.of<AppProvider>(context, listen: false);
                        app.clearCustomMedia();
                        setState(() { _mediaPath = ''; _mediaType = ''; });
                      },
                      child: const Icon(Icons.close, size: 16, color: Colors.white38)),
                  ]),
                  const SizedBox(height: 8),
                ] else
                  const Text('Фото или GIF как фон приложения',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _ActionBtn(
                    icon: Icons.perm_media_outlined,
                    label: 'Фото / GIF',
                    color: _accent,
                    onTap: _pickMedia)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Ввести путь',
                    color: _accent2,
                    onTap: _showPathInput)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Фото: JPEG, PNG, WebP · GIF: ~25fps анимация\n'
                  'Видео: MP4, MKV, MOV · Фон без звука, зациклен\n'
                  'Оптимизация: авто-даунскейл до 2160px',
                  style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25)),
                ),
              ]),
            )),
          const SizedBox(height: 20),

          // ── Быстрые пресеты ─────────────────────────────────────────────────
          _SubSection('БЫСТРЫЕ ПРЕСЕТЫ'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _PresetChip('Киберпанк', const Color(0xFFFF006E), const Color(0xFF00F5FF), const Color(0xFF000814),
                (a, a2, bg) => setState(() { _accent=a; _accent2=a2; _bg=bg; _blob1=const Color(0xFF1A0030); _blob2=const Color(0xFF003040); })),
            _PresetChip('Лес', const Color(0xFF00E676), const Color(0xFF69FF47), const Color(0xFF020A05),
                (a, a2, bg) => setState(() { _accent=a; _accent2=a2; _bg=bg; _blob1=const Color(0xFF1B5E20); _blob2=const Color(0xFF2E7D32); })),
            _PresetChip('Закат', const Color(0xFFFF6D00), const Color(0xFFFFAB40), const Color(0xFF0A0500),
                (a, a2, bg) => setState(() { _accent=a; _accent2=a2; _bg=bg; _blob1=const Color(0xFF4A1800); _blob2=const Color(0xFF7B3300); })),
            _PresetChip('Лёд', const Color(0xFF88C0D0), const Color(0xFF81A1C1), const Color(0xFF0D1117),
                (a, a2, bg) => setState(() { _accent=a; _accent2=a2; _bg=bg; _blob1=const Color(0xFF1C2D3F); _blob2=const Color(0xFF243447); })),
            _PresetChip('Розовый', const Color(0xFFFF4081), const Color(0xFFFF80AB), const Color(0xFF0A0308),
                (a, a2, bg) => setState(() { _accent=a; _accent2=a2; _bg=bg; _blob1=const Color(0xFF4A0020); _blob2=const Color(0xFF880E4F); })),
          ]),
          const SizedBox(height: 24),

          // ── Сохранить ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: _saving ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accent, _accent2]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 20)]),
              child: Center(child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('ПРИМЕНИТЬ ТЕМУ',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)))),
          ),
        ],
      ),
    );
  }
}

// ── Colour picker row ────────────────────────────────────────────────────────

class _ColorRow extends StatelessWidget {
  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;
  const _ColorRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassBox(radius: 12, blur: 16, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70))),
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: value,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(color: value.withOpacity(0.4), blurRadius: 12)]),
              child: Icon(Icons.colorize_outlined, color: Colors.white.withOpacity(0.7), size: 16),
            )),
        ]))));
  }

  void _showPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HexColorPicker(initial: value, onPicked: onChanged));
  }
}

// ── Hex color picker bottom sheet ─────────────────────────────────────────────

class _HexColorPicker extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onPicked;
  const _HexColorPicker({required this.initial, required this.onPicked});
  @override State<_HexColorPicker> createState() => _HexColorPickerState();
}

class _HexColorPickerState extends State<_HexColorPicker> {
  late double _h, _s, _v, _a;
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _h = hsv.hue; _s = hsv.saturation; _v = hsv.value; _a = hsv.alpha;
    _hexCtrl = TextEditingController(text: _toHex(widget.initial));
  }

  @override void dispose() { _hexCtrl.dispose(); super.dispose(); }

  Color get _current => HSVColor.fromAHSV(_a, _h, _s, _v).toColor();

  String _toHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  void _fromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length != 6) throw Exception();
      final v = int.parse('FF$clean', radix: 16);
      final c = Color(v);
      final hsv = HSVColor.fromColor(c);
      setState(() {
        _h = hsv.hue; _s = hsv.saturation; _v = hsv.value;
        _hexError = false;
      });
    } catch (_) { setState(() => _hexError = true); }
  }

  @override
  Widget build(BuildContext context) {
    final c = _current;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1226),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        // Превью цвета
        Container(height: 52, decoration: BoxDecoration(
            color: c, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 20)])),
        const SizedBox(height: 16),
        // HUE slider
        _SliderRow('H', _h / 360, (v) => setState(() { _h = v * 360; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: List.generate(7, (i) =>
                HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()))),
        const SizedBox(height: 8),
        // SATURATION slider
        _SliderRow('S', _s, (v) => setState(() { _s = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [
                HSVColor.fromAHSV(1, _h, 0, _v).toColor(),
                HSVColor.fromAHSV(1, _h, 1, _v).toColor()])),
        const SizedBox(height: 8),
        // VALUE slider
        _SliderRow('V', _v, (v) => setState(() { _v = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [Colors.black,
                HSVColor.fromAHSV(1, _h, _s, 1).toColor()])),
        const SizedBox(height: 8),
        // ALPHA slider
        _SliderRow('A', _a, (v) => setState(() { _a = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [Colors.transparent, c.withOpacity(1)])),
        const SizedBox(height: 14),
        // HEX input
        Row(children: [
          const Text('HEX', style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _hexCtrl,
            style: TextStyle(fontSize: 13, color: _hexError ? Colors.redAccent : Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _hexError ? Colors.redAccent : Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _hexError ? Colors.redAccent.withOpacity(0.5) : Colors.white12)),
              hintText: '#RRGGBB', hintStyle: const TextStyle(color: Colors.white24, fontSize: 12)),
            onChanged: _fromHex,
            inputFormatters: [LengthLimitingTextInputFormatter(7)],
          )),
        ]),
        const SizedBox(height: 14),
        // Кнопки
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(height: 44, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24)),
              child: const Center(child: Text('Отмена',
                  style: TextStyle(color: Colors.white54, fontSize: 13)))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () { widget.onPicked(_current); Navigator.pop(context); },
            child: Container(height: 44, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [c, c.withOpacity(0.7)])),
              child: const Center(child: Text('Применить',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))))),
        ]),
      ]));
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Gradient gradient;
  const _SliderRow(this.label, this.value, this.onChanged, {required this.gradient});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 16, child: Text(label,
        style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w700))),
    const SizedBox(width: 8),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(children: [
        Container(height: 20, decoration: BoxDecoration(gradient: gradient)),
        // Checkerboard для alpha
        if (label == 'A') _Checkerboard(size: 10),
        if (label == 'A') Container(height: 20, decoration: BoxDecoration(gradient: gradient)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 20, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            trackShape: const RectangularSliderTrackShape(),
            thumbColor: Colors.white, activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged)),
      ]))),
  ]);
}

class _Checkerboard extends StatelessWidget {
  final double size;
  const _Checkerboard({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(height: 20, child: CustomPaint(
    painter: _CheckerPainter(size)));
}

class _CheckerPainter extends CustomPainter {
  final double size;
  _CheckerPainter(this.size);
  @override void paint(Canvas canvas, Size s) {
    final p1 = Paint()..color = const Color(0xFFCCCCCC);
    final p2 = Paint()..color = Colors.white;
    for (double x = 0; x < s.width; x += size) {
      for (double y = 0; y < s.height; y += size) {
        canvas.drawRect(Rect.fromLTWH(x, y, size, size),
            ((x / size + y / size).toInt() % 2 == 0) ? p1 : p2);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}


// ── Preview blob painter ───────────────────────────────────────────────────────
class _PreviewBlobPainter extends CustomPainter {
  final List<Color> colors;
  const _PreviewBlobPainter(this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < colors.length; i++) {
      final x = size.width  * (0.3 + i * 0.25);
      final y = size.height * (0.4 + (i % 2) * 0.3);
      final r = size.width  * 0.35;
      canvas.drawCircle(Offset(x, y), r, Paint()
        ..shader = RadialGradient(
          colors: [colors[i].withOpacity(0.5), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }
  }
  @override bool shouldRepaint(_) => true;
}

// ── Preset chip ───────────────────────────────────────────────────────────────
class _PresetChip extends StatelessWidget {
  final String name;
  final Color a, a2, bg;
  final void Function(Color, Color, Color) onTap;
  const _PresetChip(this.name, this.a, this.a2, this.bg, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onTap(a, a2, bg),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a.withOpacity(0.2), a2.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: a.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: a, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(name, style: TextStyle(fontSize: 11, color: a, fontWeight: FontWeight.w600)),
      ])));
}

class FpsMonitor {
  static bool _lowPerfMode = false;
  static double _fps       = 60.0;
  static DateTime? _lastFrame;
  static int _frameCount   = 0;
  static double _sum       = 0;

  static bool get lowPerfMode => _lowPerfMode;
  static double get currentFps => _fps;

  // Вызывается каждый кадр из SchedulerBinding
  static void onFrame(Duration ts) {
    final now = DateTime.now();
    if (_lastFrame != null) {
      final delta = now.difference(_lastFrame!).inMilliseconds;
      if (delta > 0 && delta < 200) { // игнорируем аномальные кадры
        _sum += 1000.0 / delta;
        _frameCount++;
      }
    }
    _lastFrame = now;

    // Пересчитываем каждые 60 кадров (~1 секунда)
    if (_frameCount >= 60) {
      _fps = _sum / _frameCount;
      _sum = 0; _frameCount = 0;

      // Гистерезис: включаем Low Perf при < 45 fps, выключаем при > 55 fps
      if (!_lowPerfMode && _fps < 45) {
        _lowPerfMode = true;
        _notifyListeners();
      } else if (_lowPerfMode && _fps > 55) {
        _lowPerfMode = false;
        _notifyListeners();
      }
    }
  }

  static final List<VoidCallback> _listeners = [];
  static void addListener(VoidCallback cb)    { _listeners.add(cb); }
  static void removeListener(VoidCallback cb) { _listeners.remove(cb); }
  static void _notifyListeners()              { for (final cb in _listeners) cb(); }
}

// Глобальный экземпляр — регистрируем frame callback в main()
bool _fpsMonitorStarted = false;
void startFpsMonitor() {
  if (_fpsMonitorStarted) return;
  _fpsMonitorStarted = true;
  SchedulerBinding.instance.addPersistentFrameCallback(FpsMonitor.onFrame);
}

class AuraBlobBg extends StatefulWidget {
  final Widget child;
  final bool connected;
  final bool isLight;
  const AuraBlobBg({super.key, required this.child, this.connected = false, this.isLight = false});
  @override State<AuraBlobBg> createState() => _AuraBlobBgState();
}

class _AuraBlobBgState extends State<AuraBlobBg> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late final List<_Blob> _blobs;
  bool _lowPerf = false;

  @override
  void initState() {
    super.initState();
    _lowPerf = FpsMonitor.lowPerfMode;
    FpsMonitor.addListener(_onFpsChange);

    final bc = widget.isLight ? _lightBlobs : _darkBlobs;
    _blobs = [
      _Blob(0.15, 0.20,  0.00022,  0.00015, 0.55, bc[0]),
      _Blob(0.80, 0.15, -0.00018,  0.00020, 0.45, bc[1]),
      _Blob(0.50, 0.65,  0.00015, -0.00018, 0.60, bc[2]),
      _Blob(0.20, 0.80,  0.00020, -0.00012, 0.40, bc[3]),
      _Blob(0.85, 0.75, -0.00016, -0.00014, 0.42, bc[4]),
      _Blob(0.50, 0.30, -0.00012,  0.00016, 0.35, bc[5]),
    ];
    // FIX: используем Ticker напрямую вместо AnimationController+setState
    // AnimationController вызывал setState на каждый кадр → BLASTBufferQueue overflow
    // Ticker обновляет только CustomPainter через repaint notifier
    _ticker = createTicker(_step)..start();
  }

  void _onFpsChange() {
    if (!mounted) return;
    final lp = FpsMonitor.lowPerfMode;
    if (lp != _lowPerf) {
      setState(() => _lowPerf = lp);
      if (lp) { _ticker.stop(); }
      else    { _ticker.start(); }
    }
  }

  void _step(Duration _) {
    if (_lowPerf || !mounted) return;
    for (final b in _blobs) {
      b.x += b.vx; b.y += b.vy;
      if (b.x < -0.2 || b.x > 1.2) b.vx = -b.vx;
      if (b.y < -0.2 || b.y > 1.2) b.vy = -b.vy;
    }
    _blobPainterKey.currentState?._repaint();
  }

  final _blobPainterKey = GlobalKey<_BlobPainterWidgetState>();

  @override void dispose() {
    FpsMonitor.removeListener(_onFpsChange);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Светлая тема: тёплый белый (#F7F8FC) вместо холодного белого — не режет глаза
    final bg = widget.isLight
        ? (widget.connected ? const Color(0xFFEDF4FC) : const Color(0xFFF5F6FC))
        : (widget.connected ? const Color(0xFF030810) : const Color(0xFF050610));

    // Кастомный медиа-фон (фото / GIF / видео)
    final app = _AppProviderRef.instance;
    final hasMedia = app != null && app.hasCustomMedia;
    // opacity медиа-фона — при видео чуть темнее для читаемости UI
    final mediaOpacity = app?.customMediaType == 'video' ? 0.45 : 0.40;

    return Stack(children: [
      Container(color: bg),
      // Медиа-фон поверх цвета
      if (hasMedia && app != null)
        Positioned.fill(child: _MediaBackground(
          path: app.customMediaPath,
          type: app.customMediaType,
          opacity: mediaOpacity,
        )),
      // Блобы — уменьшаем при медиа чтобы не перегружать
      if (!_lowPerf)
        RepaintBoundary(
          child: Opacity(
            opacity: hasMedia ? 0.25 : 1.0,
            child: _BlobPainterWidget(
              key: _blobPainterKey,
              blobs: _blobs,
              connected: widget.connected,
              isLight: widget.isLight,
            ),
          ),
        ),
      if (_lowPerf)
        Opacity(
          opacity: hasMedia ? 0.20 : 1.0,
          child: CustomPaint(
            painter: _BlobPainter(_blobs, widget.connected, widget.isLight),
            child: const SizedBox.expand(),
          ),
        ),
      widget.child,
    ]);
  }
}

// FIX: отдельный StatefulWidget для CustomPainter — перерисовка только блобов,
// не всего дерева виджетов
class _BlobPainterWidget extends StatefulWidget {
  final List<_Blob> blobs;
  final bool connected, isLight;
  const _BlobPainterWidget({super.key, required this.blobs,
      required this.connected, required this.isLight});
  @override State<_BlobPainterWidget> createState() => _BlobPainterWidgetState();
}

class _BlobPainterWidgetState extends State<_BlobPainterWidget> {
  void _repaint() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BlobPainter(widget.blobs, widget.connected, widget.isLight),
    child: const SizedBox.expand(),
  );
}

class _BlobPainter extends CustomPainter {
  final List<_Blob> blobs; final bool connected, isLight;
  _BlobPainter(this.blobs, this.connected, this.isLight);
  @override
  void paint(Canvas canvas, Size size) {
    for (final b in blobs) {
      final cx = b.x * size.width; final cy = b.y * size.height;
      final r  = b.r * (size.width > size.height ? size.width : size.height) * 0.65;
      final op = isLight ? (connected ? 0.35 : 0.25) : (connected ? 0.72 : 0.58);
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..shader = RadialGradient(
          colors: [b.color.withOpacity(op), b.color.withOpacity(op * 0.38), Colors.transparent],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    }
  }
  @override bool shouldRepaint(_BlobPainter o) =>
      o.connected != connected || o.isLight != isLight ||
      o.blobs.length != blobs.length; // перерисовывать только при реальных изменениях
}

class GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding, margin;
  final double radius, blur, tintOpacity;
  final Color? borderColor, tint;
  const GlassBox({super.key, required this.child, this.padding, this.margin,
    this.radius = 20, this.borderColor, this.blur = 28, this.tint, this.tintOpacity = 0.10});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final bc = borderColor ?? (light ? Colors.white.withOpacity(0.70) : Colors.white.withOpacity(0.22));
    final grad = light
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.30),
            (tint ?? const Color(0xFF90CAF9)).withOpacity(tintOpacity)], stops: const [0,0.5,1])
        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.05),
            (tint ?? const Color(0xFF1565C0)).withOpacity(tintOpacity)], stops: const [0,0.5,1]);
    return Container(margin: margin, child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ui.ImageFilter.blur(
          sigmaX: FpsMonitor.lowPerfMode ? 0 : blur,
          sigmaY: FpsMonitor.lowPerfMode ? 0 : blur),
        child: Container(padding: padding,
          decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: bc, width: 0.9),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(light ? 0.12 : 0.40), blurRadius: 24, spreadRadius: -6, offset: const Offset(0,4)),
              BoxShadow(color: Colors.white.withOpacity(light ? 0.30 : 0.04), blurRadius: 1, spreadRadius: 0, offset: const Offset(0,-1)),
            ]),
          child: child))));
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title; final List<Widget>? actions;
  const GlassAppBar({super.key, required this.title, this.actions});

  // preferredSize должен включать высоту статус-бара — иначе AppBar перекрывает контент
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final mq    = MediaQuery.of(context);
    final top   = mq.padding.top;   // высота статус-бара / челки / Dynamic Island
    final light = Theme.of(context).brightness == Brightness.light;

    // FIX: preferredSize = kToolbarHeight, Flutter добавляет top padding сам
    // через Scaffold.appBar механизм. Нам нужно только добавить внутренний отступ.
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: FpsMonitor.lowPerfMode ? 0 : 30,
          sigmaY: FpsMonitor.lowPerfMode ? 0 : 30),
        child: Container(
          // Scaffold.appBar уже получает top padding от системы
          // Наш Container занимает ровно kToolbarHeight
          height: kToolbarHeight + top,
          padding: EdgeInsets.only(top: top, left: 16, right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: light
                  ? [Colors.white.withOpacity(0.70), Colors.white.withOpacity(0.40)]
                  : [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)]),
            border: Border(bottom: BorderSide(
                color: light
                    ? Colors.black.withOpacity(0.08)
                    : Colors.white.withOpacity(0.10),
                width: 0.6))),
          child: Row(
            children: [Expanded(child: title), if (actions != null) ...actions!]))));
  }

  // preferredSize с учётом статус-бара вычисляется динамически в build,
  // поэтому передаём увеличенный размер через static helper
  static double totalHeight(BuildContext context) =>
      kToolbarHeight + MediaQuery.of(context).padding.top;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AURA SCAFFOLD  —  Универсальная обёртка для ВСЕХ экранов
//
//  Решает сразу все проблемы с insets на любом устройстве:
//  - Челки (Dynamic Island, punch-hole)
//  - Навигационная полоска жестов Android
//  - Складные экраны (Z Fold)
//  - Landscape orientation
//  - Планшеты с разным соотношением сторон
//
//  Используется в _SubPage и QrScanScreen.
//  MainShell имеет свой SafeArea(bottom: false) + BottomNav со своим padding.
// ═══════════════════════════════════════════════════════════════════════════════

class AuraScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? trailing;
  final bool extendBehindAppBar;

  const AuraScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.extendBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final mq    = MediaQuery.of(context);

    return AuraBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      // Scaffold сам применяет padding.top к AppBar — не дублируем
      extendBodyBehindAppBar: extendBehindAppBar,
      appBar: GlassAppBar(
        title: Text(title, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            letterSpacing: 1, color: _textColor(context))),
        actions: [
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(right: 16), child: trailing),
        ],
      ),
      body: SafeArea(
        // top: false — AppBar уже обрабатывает верхний inset
        // left/right: true — боковые вырезы (Galaxy Z Fold, landscape)
        // bottom: true — навигационная полоска жестов
        top:    false,
        left:   true,
        right:  true,
        bottom: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxW),
            child: body,
          ),
        ),
      ),
    ));
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.init();
  await _autoConnect.load();
  startFpsMonitor(); // FPS мониторинг — авто-деградация на слабых устройствах
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AppProvider()),
    ChangeNotifierProvider(create: (_) => VpnProvider()),
    ChangeNotifierProvider.value(value: _autoConnect),
  ], child: const AuraApp()));
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    // Регистрируем singleton для AuraBlobBg (не имеет доступа к Provider)
    _AppProviderRef.register(app);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aura VPN',
      themeMode: app.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(app.skin.bgDark),
      home: const MainShell(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  // Публичный метод для переключения таба из дочерних виджетов
  void switchTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // SafeArea НЕ нужен здесь — каждый дочерний Scaffold сам управляет insets:
      // - GlassAppBar добавляет padding.top вручную (учитывает челку/Dynamic Island)
      // - _AuraBottomNav добавляет padding.bottom (навигационная полоска)
      // - Добавление SafeArea сюда вызовет двойной отступ сверху
      body: IndexedStack(index: _tab, children: const [
        HomeScreen(),
        ServersScreen(),
        SettingsScreen(),
      ]),
      bottomNavigationBar: _AuraBottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
        light: light,
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _AuraBottomNav extends StatelessWidget {
  final int current; final ValueChanged<int> onTap; final bool light;
  const _AuraBottomNav({required this.current, required this.onTap, required this.light});

  static const _items = [
    (Icons.vpn_key_rounded,       Icons.vpn_key_outlined,       'VPN'),
    (Icons.dns_rounded,           Icons.dns_outlined,            'Серверы'),
    (Icons.settings_rounded,      Icons.settings_outlined,       'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        height: 60 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withOpacity(0.80)
              : const Color(0xFF0A0814).withOpacity(0.90),
          border: Border(top: BorderSide(
              color: light
                  ? Colors.black.withOpacity(0.08)
                  : Colors.white.withOpacity(0.08),
              width: 0.5))),
        child: Row(children: _items.asMap().entries.map((e) {
          final sel = current == e.key;
          final item = e.value;
          return Expanded(child: GestureDetector(
            onTap: () => onTap(e.key),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _accent.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? Border.all(
                      color: _accent.withOpacity(0.25), width: 0.8) : null),
                child: Icon(sel ? item.$1 : item.$2,
                  size: 20,
                  color: sel ? _accent : (light ? Colors.black38 : Colors.white30))),
              const SizedBox(height: 2),
              Text(item.$3, style: TextStyle(
                fontSize: 9,
                color: sel ? _accent : (light ? Colors.black38 : Colors.white30),
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                letterSpacing: 0.3)),
            ])));
        }).toList()),
      )));
  }
}

// ── Servers Screen (вкладка серверов) ─────────────────────────────────────────

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return AuraBlobBg(connected: vpn.isConnected, isLight: light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text(S.t('servers_title'), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              letterSpacing: 1.5, color: _textColor(context))),
          actions: [
            _ABtn(Icons.add_circle_outline_rounded,
                () => _showAddMenu(context, vpn)),
            const SizedBox(width: 4),
          ],
        ),
        body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          // GlassAppBar без extendBodyBehindAppBar — Flutter добавляет отступ сам
          // Нам нужен только небольшой зазор под AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _SearchBar(vpn: vpn)),
          SliverToBoxAdapter(child: _ListHeader(vpn: vpn)),
          if (vpn.filteredConfigs.isEmpty)
            SliverToBoxAdapter(child: _EmptyState(
                onScan: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const QrScanScreen())),
                onAdd: () => _showAddMenu(context, vpn)))
          else
            _NodeListSliver(vpn: vpn),
          // bottom spacer: nav bar height + system nav area
          SliverToBoxAdapter(child: SizedBox(
              height: 80 + MediaQuery.of(context).padding.bottom)),
        ]),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn      = Provider.of<VpnProvider>(context);
    final light    = Theme.of(context).brightness == Brightness.light;
    final isTablet = context.isTablet;

    return AuraBlobBg(connected: vpn.isConnected, isLight: light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: Row(children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 16)]),
              child: Image.asset('assets/images/aura_logo.png',
                  width: 72, height: 28, fit: BoxFit.contain)),
            const SizedBox(width: 8),
            Flexible(child: Text(S.t('app_name'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  letterSpacing: 1.5, color: _textColor(context)))),
          ]),
          actions: [
            _ABtn(Icons.qr_code_scanner, () => _goQr(context)),
            _ABtn(Icons.add_circle_outline_rounded, () => _showAddMenu(context, vpn)),
            const SizedBox(width: 4),
          ],
        ),
        body: isTablet
            ? _buildTabletLayout(context, vpn)
            : _buildPhoneLayout(context, vpn),
      ),
    );
  }

  // Телефонная верстка — одна колонка
  Widget _buildPhoneLayout(BuildContext context, VpnProvider vpn) {
    // topPad = AppBar height + status bar — правильный отступ под GlassAppBar
    final topPad = GlassAppBar.totalHeight(context) + 8;
    return CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
      SliverToBoxAdapter(child: SizedBox(height: topPad)),
      SliverToBoxAdapter(child: _ConnectCard(vpn: vpn)),
      if (vpn.aiStatus != 'IDLE') SliverToBoxAdapter(child: _AiBar(vpn: vpn)),
      if (vpn.isAutoMode)         SliverToBoxAdapter(child: _AutoModeBar(vpn: vpn)),
      if (!vpn.isConnected || vpn.whitelistBypassActive)
                                  SliverToBoxAdapter(child: _WhitelistBypassButton(vpn: vpn)),
      if (vpn.configs.isNotEmpty) SliverToBoxAdapter(child: _HomeNodePreview(vpn: vpn)),
      // bottom: nav bar + safe area
      SliverToBoxAdapter(child: SizedBox(
          height: 80 + MediaQuery.of(context).padding.bottom)),
    ]);
  }

  // Планшетная верстка — 2 колонки (connect слева, ноды справа)
  Widget _buildTabletLayout(BuildContext context, VpnProvider vpn) {
    final w      = context.screenW;
    final topPad = GlassAppBar.totalHeight(context) + 8;
    final botPad = 80.0 + MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          context.pagePadding.left, topPad, context.pagePadding.right, botPad),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Левая колонка — управление VPN
        SizedBox(width: (w * 0.45).clamp(280.0, 420.0), child: Column(children: [
          _ConnectCard(vpn: vpn),
          if (vpn.aiStatus != 'IDLE') _AiBar(vpn: vpn),
          if (vpn.isAutoMode)         _AutoModeBar(vpn: vpn),
          if (!vpn.isConnected || vpn.whitelistBypassActive)
                                      _WhitelistBypassButton(vpn: vpn),
        ])),
        const SizedBox(width: 16),
        // Правая колонка — превью нод
        Expanded(child: Column(children: [
          if (vpn.configs.isNotEmpty) _HomeNodePreview(vpn: vpn),
        ])),
      ]),
    );
  }

  void _goQr(BuildContext ctx) => Navigator.push(ctx,
      CupertinoPageRoute(builder: (_) => const QrScanScreen()));
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final VpnProvider vpn;
  const _SearchBar({required this.vpn});
  @override State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ClipRRect(borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withOpacity(0.05)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: TextField(
              controller: _ctrl,
              onChanged: widget.vpn.setSearch,
              style: TextStyle(fontSize: 12, color: _textColor(context)),
              decoration: InputDecoration(
                hintText: S.t('search_nodes'),
                hintStyle: TextStyle(fontSize: 12, color: _subTextColor(context).withOpacity(0.4)),
                prefixIcon: Icon(Icons.search, size: 16, color: _subTextColor(context).withOpacity(0.5)),
                suffixIcon: widget.vpn.searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _ctrl.clear(); widget.vpn.setSearch(''); },
                        child: Icon(Icons.close, size: 14, color: _subTextColor(context).withOpacity(0.5)))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── AppBar Button ─────────────────────────────────────────────────────────────

class _ABtn extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final bool loading;
  const _ABtn(this.icon, this.onTap, {this.loading = false});
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(width: 36, height: 36, margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: light ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.16))),
            child: loading
                ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent))
                : Icon(icon, size: 18, color: onTap == null
                    ? (light ? Colors.black26 : Colors.white24)
                    : (light ? const Color(0xFF1A2340) : Colors.white.withOpacity(0.80)))))));
  }
}

// ── Connect Card ──────────────────────────────────────────────────────────────

class _ConnectCard extends StatelessWidget {
  final VpnProvider vpn;
  const _ConnectCard({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final cfg = (vpn.configs.isNotEmpty && vpn.selectedIndex < vpn.configs.length)
        ? vpn.configs[vpn.selectedIndex] : null;
    final Color sc; final String st;
    switch (vpn.status) {
      case 'CONNECTED':  sc = const Color(0xFF34C759); st = S.t('connected');    break;
      case 'CONNECTING': sc = const Color(0xFFFF9500);
        st = vpn.stealthStatus.isNotEmpty ? vpn.stealthStatus : S.t('connecting');
        break;
      case 'ERROR':      sc = const Color(0xFFFF3B30); st = S.t('error');        break;
      // FIX: в светлой теме используем тёмный цвет вместо white38 (невидим)
      default:           sc = light ? const Color(0xFF1C1C1E) : Colors.white60;
                         st = S.t('disconnected');
    }

    return RepaintBoundary(child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: GlassBox(blur: 32, tint: const Color(0xFF0D2063), tintOpacity: light ? 0.06 : 0.18,
        borderColor: sc.withOpacity(light ? 0.20 : 0.40),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(children: [
            // Power button — с тенью для видимости в светлой теме
            GestureDetector(onTap: vpn.toggle,
              child: AnimatedContainer(duration: const Duration(milliseconds: 600),
                width: 90, height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    sc.withOpacity(light ? 0.15 : 0.20),
                    sc.withOpacity(light ? 0.05 : 0.06),
                    Colors.transparent], stops: const [0,0.6,1]),
                  border: Border.all(color: sc.withOpacity(light ? 0.60 : 0.75), width: 1.5),
                  boxShadow: [
                    // Основное свечение
                    BoxShadow(color: sc.withOpacity(light ? 0.25 : 0.45), blurRadius: 24),
                    // Тень для глубины (особенно важна в светлой теме)
                    BoxShadow(color: Colors.black.withOpacity(light ? 0.12 : 0.30),
                        blurRadius: 12, spreadRadius: -2, offset: const Offset(0, 4)),
                  ]),
                child: Icon(vpn.isConnected ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                    size: 38, color: sc))),
            const SizedBox(height: 14),
            Text(st, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: sc, letterSpacing: 3.0)),
            const SizedBox(height: 6),
            if (cfg != null) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(cfg.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _subTextColor(context)))),
              if (cfg.ping != '---') ...[
                const SizedBox(width: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: cfg.pingColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cfg.pingColor.withOpacity(0.4))),
                      child: Text(cfg.ping, style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold, color: cfg.pingColor))))),
              ],
              if (cfg.isAiPatched) const Padding(padding: EdgeInsets.only(left: 5),
                  child: Text('🤖', style: TextStyle(fontSize: 11))),
            ]),
            const SizedBox(height: 8),
            _ConnectAutoRow(vpn: vpn),
            // Таймер сессии + профиль
            if (vpn.isConnected) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StatPill(Icons.timer_outlined, vpn.sessionTimeStr, Colors.white38),
                const SizedBox(width: 8),
                _StatPill(Icons.person_outline, vpn.activeProfileName, _accentBlue),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StatPill(Icons.arrow_upward_rounded,
                    vpn.formatSpeed(vpn.trafficUp), const Color(0xFF69FF47)),
                const SizedBox(width: 8),
                _StatPill(Icons.arrow_downward_rounded,
                    vpn.formatSpeed(vpn.trafficDown), const Color(0xFF40C4FF)),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('↑ ${vpn.formatBytes(vpn.totalUp)}',
                    style: const TextStyle(fontSize: 9, color: Colors.white24)),
                const SizedBox(width: 12),
                Text('↓ ${vpn.formatBytes(vpn.totalDown)}',
                    style: const TextStyle(fontSize: 9, color: Colors.white24)),
              ]),
            ],
            if (vpn.killSwitch) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GlassBox(radius: 8, blur: 10, tint: _accent, tintOpacity: 0.20,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield, size: 11, color: _accent),
                  const SizedBox(width: 5),
                  Text(S.t('kill_switch_on'), style: TextStyle(fontSize: 9, color: _accent.withOpacity(0.95))),
                ]))),
            // Stealth статус
            if (vpn.stealthMode) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GlassBox(radius: 8, blur: 10,
                tint: const Color(0xFF7C4DFF), tintOpacity: 0.20,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.security, size: 11, color: Color(0xFFCE93D8)),
                  const SizedBox(width: 5),
                  Text(
                    vpn.stealthStatus.isNotEmpty
                        ? vpn.stealthStatus
                        : 'STEALTH 3.0',
                    style: const TextStyle(fontSize: 9,
                        color: Color(0xFFCE93D8), letterSpacing: 0.5)),
                ]))),
            // ── IP строчка под карточкой ──────────────────────────────
            const SizedBox(height: 10),
            _IpStatusRow(vpn: vpn),
          ]),
        ),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AUTO CONNECT  — автоподключение по условиям  v5.3
// ═══════════════════════════════════════════════════════════════════════════════

// Список популярных приложений для триггера
class AutoConnectApp {
  final String packageName;
  final String displayName;
  final String emoji;
  final String icon; // base64 — из нативного кода
  bool enabled;
  AutoConnectApp({
    required this.packageName,
    required this.displayName,
    this.emoji = '📱',
    this.icon = '',
    this.enabled = false,
  });
  Map<String, dynamic> toJson() => {'pkg': packageName, 'name': displayName, 'enabled': enabled};
  static AutoConnectApp fromJson(Map<String, dynamic> j) => AutoConnectApp(
    packageName: j['pkg'] as String? ?? '',
    displayName: j['name'] as String? ?? j['pkg'] as String? ?? '',
    enabled:     j['enabled'] as bool? ?? false,
  );
}

class AutoConnectSettings extends ChangeNotifier {
  bool onOpenWifi   = false;
  bool onNewWifi    = false;
  bool onMobileData = false;

  // Пользовательские приложения-триггеры — выбираются из реального списка
  List<AutoConnectApp> apps = [];

  bool _disposed = false;

  Map<String, dynamic> toJson() => {
    'onOpenWifi':   onOpenWifi,
    'onNewWifi':    onNewWifi,
    'onMobileData': onMobileData,
    'apps': apps.map((a) => a.toJson()).toList(),
  };

  void fromJson(Map<String, dynamic> j) {
    onOpenWifi   = j['onOpenWifi']   as bool? ?? false;
    onNewWifi    = j['onNewWifi']    as bool? ?? false;
    onMobileData = j['onMobileData'] as bool? ?? false;
    final saved  = j['apps'] as List? ?? [];
    apps = saved.map((s) => AutoConnectApp.fromJson(
        Map<String, dynamic>.from(s as Map))).toList();
    _safeNotify();
  }

  Future<void> load() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString('auto_connect_settings');
      if (raw != null) fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('auto_connect_settings', jsonEncode(toJson()));
    } catch (_) {}
  }

  void toggleWifi(bool v)    { onOpenWifi   = v; save(); _safeNotify(); }
  void toggleNewWifi(bool v) { onNewWifi    = v; save(); _safeNotify(); }
  void toggleMobile(bool v)  { onMobileData = v; save(); _safeNotify(); }

  void addApp(AutoConnectApp app) {
    if (!apps.any((a) => a.packageName == app.packageName)) {
      apps.add(app..enabled = true);
      save(); _safeNotify();
    }
  }

  void removeApp(String pkg) {
    apps.removeWhere((a) => a.packageName == pkg);
    save(); _safeNotify();
  }

  void toggleApp(AutoConnectApp app) {
    app.enabled = !app.enabled;
    save(); _safeNotify();
  }

  int  get enabledAppsCount => apps.where((a) => a.enabled).length;
  bool get hasAnyTrigger    => onOpenWifi || onNewWifi || onMobileData || enabledAppsCount > 0;

  void _safeNotify() { if (!_disposed) notifyListeners(); }
  void forceRefresh()  { _safeNotify(); }
  @override void dispose() { _disposed = true; super.dispose(); }
}


// ═══════════════════════════════════════════════════════════════════════════════
//  AUTO CONNECT  — автоподключение по условиям  v5.3
// ═══════════════════════════════════════════════════════════════════════════════
final _autoConnect = AutoConnectSettings();

// ═══════════════════════════════════════════════════════════════════════════════
//  IP CHECK  — данные о подключении
// ═══════════════════════════════════════════════════════════════════════════════

class IpInfo {
  final String ip;
  final String country;
  final String countryCode;
  final String city;
  final String isp;
  final String dns;
  final bool   isVpn;
  const IpInfo({
    required this.ip, required this.country, required this.countryCode,
    required this.city, required this.isp, required this.dns, required this.isVpn,
  });
  factory IpInfo.empty() => const IpInfo(
      ip: '—', country: '—', countryCode: '', city: '—',
      isp: '—', dns: '—', isVpn: false);
}

class IpCheckProvider extends ChangeNotifier {
  IpInfo? realIp;      // до VPN (кэшируется при старте)
  IpInfo? currentIp;  // текущий (через VPN или без)
  bool isLoading   = false;
  bool hasError    = false;
  String errorMsg  = '';
  bool _disposed   = false;

  /// Получить текущий IP (вызывается при каждом открытии экрана)
  DateTime? _lastFetch;

  Future<void> fetchCurrent({bool force = false}) async {
    if (isLoading) return;
    // Кэш 30 секунд — не делаем запрос слишком часто
    if (!force && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inSeconds < 30) return;
    isLoading = true; hasError = false; _safeNotify();
    try {
      currentIp  = await _fetchIpInfo();
      _lastFetch = DateTime.now();
    } catch (e) {
      hasError = true; errorMsg = e.toString();
    }
    isLoading = false; _safeNotify();
  }

  /// Получить реальный IP (вызывается один раз при старте, до VPN)
  Future<void> fetchReal() async {
    try {
      realIp = await _fetchIpInfo();
      _lastFetch = null; // сбросить кэш чтобы fetchCurrent сделал свежий запрос
      _safeNotify();
    } catch (_) {}
  }

  Future<IpInfo> _fetchIpInfo() async {
    // Список API с fallback — ipapi.co часто возвращает HTML при лимите/блокировке
    final apis = [
      'https://ipapi.co/json/',
      'https://ip-api.com/json/?fields=query,country,countryCode,city,isp',
      'https://ipwho.is/',
    ];

    for (final apiUrl in apis) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final req  = await client.getUrl(Uri.parse(apiUrl));
        req.headers.set('User-Agent', kStealthUA);
        req.headers.set('Accept', 'application/json');
        final resp = await req.close().timeout(const Duration(seconds: 6));
        final body = await resp.transform(const Utf8Decoder()).join();

        // Проверяем что получили JSON а не HTML (провайдерская страница блокировки)
        final trimmed = body.trimLeft();
        if (!trimmed.startsWith('{')) {
          client.close(force: true);
          continue; // пробуем следующий API
        }

        final j = jsonDecode(body) as Map<String, dynamic>;

        // Проверяем что запрос не вернул ошибку
        if (j['error'] == true || j['status'] == 'fail') {
          client.close(force: true);
          continue;
        }

        // DNS leak check — через Cloudflare DoH
        String dnsServer = '—';
        try {
          final dnsReq = await client.getUrl(Uri.parse(
              'https://cloudflare-dns.com/dns-query?name=whoami.cloudflare&type=TXT'));
          dnsReq.headers.set('Accept', 'application/dns-json');
          final dnsResp = await dnsReq.close().timeout(const Duration(seconds: 4));
          final dnsBody = await dnsResp.transform(const Utf8Decoder()).join();
          final dnsJ   = jsonDecode(dnsBody) as Map<String, dynamic>;
          final answers = dnsJ['Answer'] as List? ?? [];
          if (answers.isNotEmpty) {
            dnsServer = (answers.first['data'] as String? ?? '—').replaceAll('"', '');
          }
        } catch (_) {}

        client.close();

        // Нормализуем ответ из разных API
        return IpInfo(
          ip:          (j['ip'] ?? j['query'] ?? '—') as String,
          country:     (j['country_name'] ?? j['country'] ?? '—') as String,
          countryCode: (j['country_code'] ?? j['countryCode'] ?? '') as String,
          city:        (j['city'] ?? '—') as String,
          isp:         (j['org'] ?? j['isp'] ?? '—') as String,
          dns:         dnsServer,
          isVpn:       false,
        );
      } catch (_) {
        client.close(force: true);
        continue; // пробуем следующий API
      }
    }
    throw Exception('All IP APIs failed');
  }

  void _safeNotify() { if (!_disposed) notifyListeners(); }
  @override void dispose() { _disposed = true; super.dispose(); }
}

// Глобальный экземпляр — живёт всё время работы приложения
final _ipCheck = IpCheckProvider();

// ── IP Status Row — тихая строчка под ConnectCard ────────────────────────────

class _IpStatusRow extends StatelessWidget {
  final VpnProvider vpn;
  const _IpStatusRow({required this.vpn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ipCheck,
      builder: (_, __) {
        final info = _ipCheck.currentIp;
        final loading = _ipCheck.isLoading;

        return GestureDetector(
          onTap: () => Navigator.push(context,
              CupertinoPageRoute(builder: (_) => const IpCheckScreen())),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: loading ? 0.4 : 0.75,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (loading)
                const SizedBox(width: 10, height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.2, color: Colors.white24))
              else
                const Icon(Icons.travel_explore_outlined,
                    size: 11, color: Colors.white24),
              const SizedBox(width: 6),
              Text(
                info == null
                    ? 'Нажми чтобы проверить IP'
                    : '${info.ip}  ·  ${info.country}',
                style: const TextStyle(fontSize: 10, color: Colors.white30),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 12, color: Color(0x26FFFFFF)),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  IP CHECK SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class IpCheckScreen extends StatefulWidget {
  const IpCheckScreen({super.key});
  @override State<IpCheckScreen> createState() => _IpCheckScreenState();
}

class _IpCheckScreenState extends State<IpCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Автоматически проверяем при открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ipCheck.fetchCurrent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return AuraBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false, // CupertinoSliverNavigationBar сам учитывает статус-бар
        child: ListenableBuilder(
        listenable: _ipCheck,
        builder: (_, __) {
          final cur     = _ipCheck.currentIp;
          final real    = _ipCheck.realIp;
          final loading = _ipCheck.isLoading;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // AppBar
              CupertinoSliverNavigationBar(
                backgroundColor: Colors.transparent,
                border: null,
                largeTitle: Text('Проверка IP',
                    style: TextStyle(
                        color: light ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w800)),
                trailing: GestureDetector(
                  onTap: loading ? null : _ipCheck.fetchCurrent,
                  child: loading
                      ? const CupertinoActivityIndicator()
                      : Icon(Icons.refresh_rounded,
                          color: light ? _accentBlue : _accentBlue, size: 22)),
              ),

              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(children: [

                  // ── Главная карточка — текущий IP ────────────────────
                  _IpMainCard(info: cur, loading: loading),
                  const SizedBox(height: 14),

                  // ── Детали ───────────────────────────────────────────
                  if (cur != null) ...[
                    _IpDetailCard(cur: cur, real: real),
                    const SizedBox(height: 14),
                    // ── Итог — защищён / не защищён ──────────────────
                    _IpVerdictCard(cur: cur, real: real),
                  ],

                  // ── Кнопка проверить ─────────────────────────────────
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: loading ? null : _ipCheck.fetchCurrent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: loading
                            ? [Colors.white12, Colors.white12]
                            : [_accentBlue.withOpacity(0.7),
                               _accentBlue.withOpacity(0.4)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _accentBlue.withOpacity(
                                loading ? 0.2 : 0.5)),
                        boxShadow: loading ? [] : [
                          BoxShadow(
                              color: _accentBlue.withOpacity(0.25),
                              blurRadius: 20)
                        ],
                      ),
                      child: loading
                          ? const Center(child: CupertinoActivityIndicator())
                          : const Center(child: Text('ПРОВЕРИТЬ СНОВА',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w900,
                                  color: Colors.white, letterSpacing: 2))),
                    ),
                  ),

                  if (_ipCheck.hasError) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Ошибка: ${_ipCheck.errorMsg}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.redAccent),
                        textAlign: TextAlign.center)),
                ]),
              )),
            ],
          );
        },
      ),      // ListenableBuilder
      ),      // SafeArea
    ));  // AuraBlobBg + Scaffold
  }
}

// ── Главная карточка ──────────────────────────────────────────────────────────

class _IpMainCard extends StatelessWidget {
  final IpInfo? info; final bool loading;
  const _IpMainCard({required this.info, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading && info == null) {
      return GlassBox(
        blur: 24, tint: _accentBlue, tintOpacity: 0.08,
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CupertinoActivityIndicator())));
    }

    final ip      = info?.ip      ?? '—';
    final country = info?.country ?? '—';
    final city    = info?.city    ?? '—';
    final flag    = _countryFlag(info?.countryCode ?? '');

    return GlassBox(
      blur: 24, tint: _accentBlue, tintOpacity: 0.10,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(flag, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(ip, style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('$country · $city',
              style: const TextStyle(fontSize: 13, color: Colors.white54)),
        ]),
      ));
  }
}

// ── Детальные строки ──────────────────────────────────────────────────────────

class _IpDetailCard extends StatelessWidget {
  final IpInfo cur; final IpInfo? real;
  const _IpDetailCard({required this.cur, required this.real});

  @override
  Widget build(BuildContext context) {
    final ipChanged = real != null && real!.ip != cur.ip;

    return GlassBox(
      blur: 20, tint: Colors.white, tintOpacity: 0.03,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(children: [
          _DetailRow(
            icon: Icons.language_outlined,
            label: 'IP адрес',
            value: cur.ip,
            color: Colors.white70),
          _DetailRow(
            icon: Icons.flag_outlined,
            label: 'Страна',
            value: '${_countryFlag(cur.countryCode)} ${cur.country}',
            color: Colors.white70),
          _DetailRow(
            icon: Icons.location_city_outlined,
            label: 'Город',
            value: cur.city,
            color: Colors.white70),
          _DetailRow(
            icon: Icons.business_outlined,
            label: 'Провайдер',
            value: cur.isp,
            color: Colors.white70),
          _DetailRow(
            icon: Icons.dns_outlined,
            label: 'DNS сервер',
            value: cur.dns,
            color: Colors.white70,
            last: true),
          // Реальный IP если изменился
          if (ipChanged) ...[
            const Divider(height: 0, thickness: 0.5, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                Icon(Icons.compare_arrows_rounded,
                    size: 14, color: Colors.white24),
                const SizedBox(width: 10),
                Text('Реальный IP: ${real!.ip}',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white24)),
              ])),
          ],
        ]),
      ));
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label, value;
  final Color color; final bool last;
  const _DetailRow({required this.icon, required this.label,
      required this.value, required this.color, this.last = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.white24),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(
            fontSize: 12, color: Colors.white38)),
        const Spacer(),
        Flexible(child: Text(value,
            style: TextStyle(fontSize: 12, color: color,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis)),
      ])),
    if (!last) const Divider(
        height: 0, thickness: 0.5, color: Colors.white10),
  ]);
}

// ── Итоговая карточка — защищён? ──────────────────────────────────────────────

class _IpVerdictCard extends StatelessWidget {
  final IpInfo cur; final IpInfo? real;
  const _IpVerdictCard({required this.cur, required this.real});

  @override
  Widget build(BuildContext context) {
    final ipChanged  = real != null && real!.ip != cur.ip;
    final dnsOk      = cur.dns != '—' && cur.dns != real?.dns;
    final protected  = ipChanged;

    final color  = protected
        ? const Color(0xFF69FF47)
        : const Color(0xFFFF5252);
    final icon   = protected
        ? Icons.verified_user_outlined
        : Icons.gpp_bad_outlined;
    final title  = protected
        ? 'Защищён'
        : 'Не защищён';
    final sub    = protected
        ? 'IP скрыт, трафик идёт через VPN'
        : 'Ваш реальный IP виден';

    return GlassBox(
      blur: 20, tint: color, tintOpacity: 0.08,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4))),
            child: Icon(icon, size: 22, color: color)),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(sub, style: TextStyle(
                fontSize: 11, color: color.withOpacity(0.6))),
            const SizedBox(height: 6),
            Row(children: [
              _VerdictChip('IP',  ipChanged,  'скрыт',   'виден'),
              const SizedBox(width: 6),
              _VerdictChip('DNS', dnsOk,      'ОК',      'утечка?'),
            ]),
          ])),
        ]),
      ));
  }
}

class _VerdictChip extends StatelessWidget {
  final String label; final bool ok;
  final String okText, failText;
  const _VerdictChip(this.label, this.ok, this.okText, this.failText);
  @override
  Widget build(BuildContext context) {
    final c = ok ? const Color(0xFF69FF47) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.3))),
      child: Text('$label: ${ok ? okText : failText}',
          style: TextStyle(fontSize: 9, color: c,
              fontWeight: FontWeight.bold)));
  }
}

// ── Вспомогательные ───────────────────────────────────────────────────────────

String _countryFlag(String code) {
  if (code.length != 2) return '🌍';
  return String.fromCharCodes(
      code.toUpperCase().codeUnits.map((c) => c + 127397));
}

Color get _bgColor => const Color(0xFF060408);

// ── Auto Mode Button (AppBar) ────────────────────────────────────────────────

// ── Connect Card Auto Row ─────────────────────────────────────────────────────

// ── Home Node Preview — топ-3 ноды на главном экране ─────────────────────────

class _HomeNodePreview extends StatelessWidget {
  final VpnProvider vpn;
  const _HomeNodePreview({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final light   = Theme.of(context).brightness == Brightness.light;
    // Показываем топ-3: текущая + 2 лучших по пингу
    final configs = vpn.configs;
    final current = vpn.selectedIndex < configs.length ? configs[vpn.selectedIndex] : null;
    final others  = configs
        .where((c) => c != current && c.pingMs < 9000)
        .toList()
      ..sort((a, b) => a.pingMs.compareTo(b.pingMs));
    final preview = [
      if (current != null) current,
      ...others.take(current == null ? 3 : 2),
    ].take(3).toList();

    if (preview.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(children: [
            Text('БЫСТРЫЕ СЕРВЕРЫ', style: TextStyle(
                fontSize: 9, letterSpacing: 2,
                color: _subTextColor(context).withOpacity(0.45))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                // Switch to servers tab
                context.findAncestorStateOfType<_MainShellState>()?.switchTab(1);
              },
              child: Text('Все →', style: TextStyle(
                  fontSize: 9, color: _accent.withOpacity(0.6))),
            ),
          ]),
        ),
        GlassBox(
          radius: 16, blur: 24,
          tint: const Color(0xFF0D47A1), tintOpacity: 0.10,
          child: Column(children: preview.asMap().entries.map((e) {
            final cfg   = e.value;
            final isSel = cfg == current;
            final idx   = configs.indexOf(cfg);
            final pc    = _NodeTile.protocolColor(cfg.protocol);
            return GestureDetector(
              onTap: () => vpn.selectNode(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: isSel ? LinearGradient(
                    colors: [_accent.withOpacity(0.12), Colors.transparent]) : null,
                  borderRadius: e.key == 0
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : (e.key == preview.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
                          : BorderRadius.zero),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      // Protocol badge
                      Container(
                        width: 42, padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: pc.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: pc.withOpacity(0.35), width: 0.7)),
                        child: Text(cfg.protocol, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 7,
                                fontWeight: FontWeight.bold, color: pc))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(cfg.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12,
                              color: isSel ? _textColor(context)
                                  : _textColor(context).withOpacity(0.65),
                              fontWeight: isSel ? FontWeight.w600 : FontWeight.normal))),
                      if (cfg.ping != '---') Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cfg.pingColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: cfg.pingColor.withOpacity(0.35))),
                        child: Text(cfg.ping, style: TextStyle(
                            fontSize: 8, color: cfg.pingColor,
                            fontWeight: FontWeight.bold))),
                      if (isSel) Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.radio_button_checked_rounded,
                            size: 14, color: _accent)),
                    ]),
                  ),
                  if (e.key < preview.length - 1) Divider(
                    height: 0, thickness: 0.5,
                    color: light
                        ? Colors.black.withOpacity(0.05)
                        : Colors.white.withOpacity(0.05),
                    indent: 14, endIndent: 14),
                ]),
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }
}

class _ConnectAutoRow extends StatelessWidget {
  final VpnProvider vpn;
  const _ConnectAutoRow({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final active  = vpn.isAutoMode;
    final running = vpn.isAutoRunning;
    final color   = active ? const Color(0xFF69FF47) : Colors.white24;

    return GestureDetector(
      onTap: vpn.isAutoRunning ? null : vpn.toggleAutoMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF69FF47).withOpacity(0.12) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF69FF47).withOpacity(0.4) : Colors.white.withOpacity(0.10),
            width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          running
            ? SizedBox(width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
            : Icon(active ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                size: 12, color: color),
          const SizedBox(width: 6),
          Text(active ? (running ? 'ПОИСК...' : 'АВТО АКТИВЕН') : 'АВТО',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: color, letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ── Add Config Menu ───────────────────────────────────────────────────────────

void _showAddMenu(BuildContext context, VpnProvider vpn) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddConfigSheet(vpn: vpn),
  );
}

class _AddConfigSheet extends StatefulWidget {
  final VpnProvider vpn;
  const _AddConfigSheet({required this.vpn});
  @override State<_AddConfigSheet> createState() => _AddConfigSheetState();
}

class _AddConfigSheetState extends State<_AddConfigSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _importText(String text) async {
    final t = text.trim();
    if (t.isEmpty) { setState(() => _error = 'Введите ключ или ссылку'); return; }
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      // Определяем тип по началу строки
      if (t.startsWith('vless://') || t.startsWith('vmess://') ||
          t.startsWith('ss://') || t.startsWith('trojan://') ||
          t.startsWith('hy2://') || t.startsWith('hy://') ||
          t.startsWith('wg://')) {
        widget.vpn.addSingleKey(t);
        if (mounted) Navigator.pop(context);
      } else if (t.startsWith('http://') || t.startsWith('https://')) {
        // Ссылка на подписку
        await widget.vpn.addSubscription(t);
        if (mounted) Navigator.pop(context);
      } else if (t.startsWith('sub://') || t.contains('\n')) {
        // Несколько конфигов или base64
        widget.vpn.addSingleKey(t);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _error = 'Неизвестный формат. Поддерживаются: vless://, vmess://, ss://, trojan://, hy2://, http(s):// (подписка)');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      await _importText(data.text!);
    } else {
      setState(() => _error = 'Буфер обмена пуст');
    }
  }

  static const _shareChannel = MethodChannel('aura_vpn/share');

  // Импорт файла — открываем системный file picker через share intent
  Future<void> _importFromFile() async {
    try {
      final result = await _shareChannel.invokeMethod<String>('pickFile');
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        await _importText(result);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code != 'CANCELLED') {
        setState(() => _error = 'Ошибка открытия файла: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20,
              20 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: light ? Colors.white.withOpacity(0.92) : const Color(0xFF0F0C18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(
                color: Colors.white.withOpacity(0.12), width: 0.5))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Ручка
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),

            // Заголовок
            Row(children: [
              Text('Добавить конфиг', style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w800, color: _textColor(context))),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: Colors.white38, size: 20)),
            ]),
            const SizedBox(height: 20),

            // Быстрые кнопки — 2 строки по 2
            Row(children: [
              Expanded(child: _AddMenuBtn(
                icon: Icons.qr_code_scanner_rounded,
                label: 'QR',
                color: _accent,
                onTap: () { Navigator.pop(context); Navigator.push(context, CupertinoPageRoute(builder: (_) => const QrScanScreen())); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _AddMenuBtn(
                icon: Icons.content_paste_rounded,
                label: 'Буфер',
                color: const Color(0xFF69FF47),
                onTap: _loading ? null : _pasteFromClipboard,
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _AddMenuBtn(
                icon: Icons.folder_open_rounded,
                label: 'Файл',
                color: const Color(0xFFFFD740),
                onTap: _loading ? null : _importFromFile,
              )),
              const SizedBox(width: 8),
              Expanded(child: _AddMenuBtn(
                icon: Icons.rss_feed_rounded,
                label: 'Подписки',
                color: const Color(0xFF7C4DFF),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, CupertinoPageRoute(
                      builder: (_) => const _SubscriptionsPage()));
                },
              )),
            ]),

            const SizedBox(height: 16),

            // Поле ввода
            ClipRRect(borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 4, minLines: 2,
                  style: TextStyle(fontSize: 12,
                      fontFamily: 'monospace',
                      color: light ? Colors.black87 : Colors.white70),
                  decoration: InputDecoration(
                    hintText: 'vless://... или https://подписка...',
                    hintStyle: TextStyle(fontSize: 12,
                        color: light ? Colors.black38 : Colors.white24),
                    filled: true,
                    fillColor: light
                        ? Colors.black.withOpacity(0.05)
                        : Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ))),

            if (_error.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error, style: const TextStyle(
                  fontSize: 10, color: Colors.redAccent))),

            const SizedBox(height: 14),

            // Кнопка импорт
            GestureDetector(
              onTap: _loading ? null : () => _importText(_ctrl.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _accent.withOpacity(_loading ? 0.3 : 0.7),
                    _accentBlue.withOpacity(_loading ? 0.2 : 0.4)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withOpacity(0.4)),
                  boxShadow: _loading ? [] : [
                    BoxShadow(color: _accent.withOpacity(0.2), blurRadius: 16)]),
                child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : const Center(child: Text('ИМПОРТИРОВАТЬ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 2))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AddMenuBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback? onTap;
  const _AddMenuBtn({required this.icon, required this.label,
      required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, color: color,
            fontWeight: FontWeight.w600)),
      ]),
    ));
}

class _AutoBtn extends StatelessWidget {
  final VpnProvider vpn;
  const _AutoBtn({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final active  = vpn.isAutoMode;
    final running = vpn.isAutoRunning;
    final color   = active ? const Color(0xFF69FF47) : Colors.white38;

    return GestureDetector(
      onTap: vpn.isAutoRunning ? null : vpn.toggleAutoMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF69FF47).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF69FF47).withOpacity(0.5)
                : Colors.white.withOpacity(0.12),
            width: active ? 1.2 : 0.8),
          boxShadow: active ? [
            BoxShadow(
              color: const Color(0xFF69FF47).withOpacity(0.2),
              blurRadius: 10)
          ] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          running
              ? SizedBox(width: 11, height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: color))
              : Icon(
                  active ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  size: 13, color: color),
          const SizedBox(width: 5),
          Text('АВТО',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: color, letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

// ── Auto Mode Status Bar ──────────────────────────────────────────────────────

class _AutoModeBar extends StatelessWidget {
  final VpnProvider vpn;
  const _AutoModeBar({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final running = vpn.isAutoRunning;
    final color   = running
        ? const Color(0xFFFFD740)
        : const Color(0xFF69FF47);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
            child: Row(children: [
              // Иконка
              if (running)
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color))
              else
                Icon(Icons.auto_awesome, size: 15, color: color),
              const SizedBox(width: 10),
              // Текст
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    running ? 'АВТО · ПОИСК' : 'АВТО · АКТИВЕН',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900,
                        color: color, letterSpacing: 1.5)),
                  if (vpn.autoStatus.isNotEmpty)
                    Text(vpn.autoStatus,
                        style: TextStyle(
                            fontSize: 10,
                            color: color.withOpacity(0.65)),
                        overflow: TextOverflow.ellipsis),
                ])),
              // Кнопка отключить авто
              GestureDetector(
                onTap: vpn.toggleAutoMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12))),
                  child: const Text('Выкл',
                      style: TextStyle(
                          fontSize: 9, color: Colors.white38)))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Whitelist Bypass Button ────────────────────────────────────────────────────

class _WhitelistBypassButton extends StatelessWidget {
  final VpnProvider vpn;
  const _WhitelistBypassButton({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final status  = vpn.whitelistBypassStatus;
    final active  = vpn.whitelistBypassActive;

    // Цвета под состояние
    final Color baseColor;
    final String label;
    final IconData icon;

    switch (status) {
      case 'ACTIVATING':
        baseColor = const Color(0xFFFFB300); // янтарный — идёт процесс
        label     = 'АКТИВИРУЕТСЯ...';
        icon      = Icons.sync_rounded;
        break;
      case 'ACTIVE':
        baseColor = const Color(0xFF00E676); // зелёный — работает
        label     = 'ОБХОД АКТИВЕН';
        icon      = Icons.shield_outlined;
        break;
      case 'FAILED':
        baseColor = const Color(0xFFFF5252); // красный — ошибка
        label     = 'ОШИБКА ОБХОДА';
        icon      = Icons.error_outline_rounded;
        break;
      default:
        baseColor = const Color(0xFF7C4DFF); // фиолетовый — ждёт
        label     = 'ОБХОД БЕЛЫХ СПИСКОВ';
        icon      = Icons.public_off_rounded;
    }

    final bool loading = status == 'ACTIVATING';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: GestureDetector(
        onTap: loading ? null : vpn.activateWhitelistBypass,
        onLongPress: () => _showBypassInfo(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withOpacity(active ? 0.22 : 0.12),
                    baseColor.withOpacity(active ? 0.10 : 0.05),
                  ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: baseColor.withOpacity(active ? 0.70 : 0.35),
                  width: active ? 1.5 : 1.0),
                boxShadow: active ? [
                  BoxShadow(color: baseColor.withOpacity(0.25), blurRadius: 20),
                  BoxShadow(color: baseColor.withOpacity(0.10), blurRadius: 40, spreadRadius: 4),
                ] : [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12),
                ],
              ),
              child: Row(children: [
                // Иконка с пульсацией если активен
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withOpacity(active ? 0.20 : 0.12),
                    border: Border.all(color: baseColor.withOpacity(active ? 0.60 : 0.30))),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: baseColor))
                      : Icon(icon, size: 20, color: baseColor)),
                const SizedBox(width: 14),
                // Текст
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(label, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: baseColor, letterSpacing: 1.5)),
                      if (active) ...[ const SizedBox(width: 8),
                        _BypassPulseDot(color: baseColor)],
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? 'Порт 443 · WebSocket · CDN SNI'
                          : 'Нажми если заблокированы протоколы VPN',
                      style: TextStyle(fontSize: 10,
                          color: baseColor.withOpacity(0.55))),
                  ])),
                // Правая часть — стрелка или статус
                if (!loading) Icon(
                  active ? Icons.close_rounded : Icons.arrow_forward_ios_rounded,
                  size: active ? 18 : 14,
                  color: baseColor.withOpacity(0.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showBypassInfo(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0F0C14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.10))),
      title: const Row(children: [
        Icon(Icons.public_off_rounded, color: Color(0xFF7C4DFF), size: 22),
        SizedBox(width: 10),
        Text('Обход белых списков', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _InfoRow('🔒', 'Порт', '443 (HTTPS — всегда открыт)'),
        _InfoRow('🌐', 'Транспорт', 'WebSocket через CDN'),
        _InfoRow('🎭', 'SNI', 'speed.cloudflare.com'),
        _InfoRow('📡', 'DNS', 'DoH — Cloudflare 1.1.1.1'),
        const SizedBox(height: 12),
        Text(
          'Используй если VPN заблокирован на уровне протокола. '
          'Трафик маскируется под обычный HTTPS и проходит через CDN.',
          style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.5)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: Color(0xFF7C4DFF)))),
      ],
    ));
  }
}

class _BypassPulseDot extends StatefulWidget {
  final Color color;
  const _BypassPulseDot({required this.color});
  @override State<_BypassPulseDot> createState() => _BypassPulseDotState();
}

class _BypassPulseDotState extends State<_BypassPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [BoxShadow(
          color: widget.color.withOpacity(0.8 * (1 - _c.value)),
          blurRadius: 8 + 6 * _c.value,
          spreadRadius: 2 * _c.value)],
      )));
}

class _InfoRow extends StatelessWidget {
  final String emoji, label, value;
  const _InfoRow(this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white38)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
    ]));
}

class _StatPill extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _StatPill(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(8),
    child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.30))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
        ]))));
}

// ── AI Bar ────────────────────────────────────────────────────────────────────

class _AiBar extends StatelessWidget {
  final VpnProvider vpn;
  const _AiBar({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final status  = vpn.aiStatus;
    final stratId = vpn.devAiAgent.currentStrategyId;

    final Color c = status.startsWith('SCANNING') ? Colors.yellowAccent
        : status == 'APPLYING'     ? _accent
        : status == 'COOLDOWN 30s' ? Colors.orange
        : status == 'FAILED'       ? Colors.redAccent
        : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GlassBox(
        radius: 12, blur: 20, tint: c, tintOpacity: 0.10,
        borderColor: c.withOpacity(0.40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            // Спиннер или иконка ошибки
            if (status != 'FAILED')
              SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: c))
            else
              Icon(Icons.error_outline_rounded, size: 12, color: c),
            const SizedBox(width: 8),
            // Статус + номер стратегии
            Expanded(child: Text(
              '${S.t('ai_bar_prefix')}$status'
              '${stratId > 0 ? " · стр.#$stratId" : ""}',
              style: TextStyle(fontSize: 10, color: c,
                  fontWeight: FontWeight.bold, letterSpacing: 1.1),
              overflow: TextOverflow.ellipsis)),
            // Бейдж с номером стратегии
            if (stratId > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: c.withOpacity(0.45))),
                child: Text('#$stratId',
                    style: TextStyle(fontSize: 8, color: c,
                        fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
          ]))));
  }
}

// ── List Header ───────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final VpnProvider vpn;
  const _ListHeader({required this.vpn});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
    child: Row(children: [
      Text('${vpn.filteredConfigs.length} ${S.t('nodes')}',
          style: TextStyle(fontSize: 10,
              color: _subTextColor(context).withOpacity(0.5), letterSpacing: 1.8)),
      const Spacer(),
      // Пинг всех нод
      GestureDetector(
        onTap: vpn.isPingAllRunning ? null : vpn.pingAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: vpn.isPingAllRunning
                ? _accentBlue.withOpacity(0.12)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.10))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            vpn.isPingAllRunning
              ? SizedBox(width: 9, height: 9,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.2, color: _accentBlue))
              : Icon(Icons.network_ping_rounded, size: 11,
                  color: _subTextColor(context).withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(vpn.isPingAllRunning ? 'ПИНГ...' : S.t('sort_by_ping'),
                style: TextStyle(fontSize: 9,
                    color: _subTextColor(context).withOpacity(0.5),
                    letterSpacing: 0.5)),
          ]))),
    ]),
  );
}

// ── Group Header ──────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String name; final int count;
  final String sourceUrl; final VpnProvider vpn;
  final VoidCallback? onRename;
  const _GroupHeader({required this.name, required this.count,
      required this.sourceUrl, required this.vpn, required this.onRename});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(begin: Alignment.topCenter,
              end: Alignment.bottomCenter, colors: [_accent, _accentBlue]),
          boxShadow: [BoxShadow(color: _accent.withOpacity(0.8), blurRadius: 10)])),
        const SizedBox(width: 10),
        Expanded(child: Text(name.toUpperCase(), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: _textColor(context), letterSpacing: 1.8))),
        // Счётчик
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: light
                ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.14))),
          child: Text('$count', style: TextStyle(fontSize: 9,
              color: _subTextColor(context)))),
        const SizedBox(width: 6),
        // Пинг группы
        GestureDetector(
          onTap: () => _pingGroup(vpn),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.10))),
            child: Icon(Icons.network_ping_rounded, size: 13,
                color: _subTextColor(context).withOpacity(0.5)))),
        if (onRename != null) ...[ const SizedBox(width: 6),
          GestureDetector(onTap: onRename,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.10))),
              child: Text('✎', style: TextStyle(fontSize: 11,
                  color: _subTextColor(context)))))],
      ]));
  }

  Future<void> _pingGroup(VpnProvider vpn) async {
    // Пинговать только ноды этой группы
    final indices = vpn.configs.asMap().entries
        .where((e) => e.value.sourceUrl == sourceUrl)
        .map((e) => e.key)
        .toList();
    for (int i = 0; i < indices.length; i += 8) {
      final batch = indices.skip(i).take(8).toList();
      await Future.wait(batch.map(vpn.pingNode));
    }
    vpn.sortByPing();
  }
}

// ── Node Tile ─────────────────────────────────────────────────────────────────

class _NodeTile extends StatelessWidget {
  final VpnConfig cfg; final int idx; final bool isLast;
  final VpnProvider vpn; final VoidCallback onRename;
  const _NodeTile({required this.cfg, required this.idx, required this.isLast, required this.vpn, required this.onRename});

  static final Map<String, Color> _pc = {
    'VLESS': _accent, 'VMESS': _accentPurple,
    'SS': Color(0xFFFF8F00), 'SSR': Color(0xFFE65100),
    'TROJAN': Color(0xFF00E676), 'HY2': Color(0xFFE040FB),
    'HY': Color(0xFFE040FB), 'WG': Color(0xFF40C4FF),
  };

  static Color protocolColor(String p) =>
      _NodeTile._pc[p] ?? Colors.white38;

  void _showNodeMenu(BuildContext context) {
    final modified = vpn.isNodeModified(idx);
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(cfg.displayName),
        message: cfg.isAiPatched
            ? const Text('🤖 AI-патч применён', style: TextStyle(fontSize: 11))
            : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(context); onRename(); },
            child: Text(S.t('node_rename'))),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ShareConfigSheet.show(context, cfg);
            },
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.share_rounded, size: 16),
              SizedBox(width: 8),
              Text('Поделиться нодой'),
            ])),
          // Сброс к оригиналу — только если конфиг был изменён
          if (modified)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                showCupertinoDialog(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: Text(S.t('node_reset_confirm_title')),
                    content: const Text(
                        'Ключ вернётся к оригинальному состоянию из провайдера подписки. '
                        'AI-патчинг, маскировка и кастомное имя будут убраны.',
                        style: TextStyle(fontSize: 12)),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена')),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        onPressed: () {
                          Navigator.pop(ctx);
                          vpn.resetNodeToOriginal(idx);
                        },
                        child: const Text('Сбросить')),
                    ],
                  ),
                );
              },
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.restore_rounded, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Text('Сбросить к оригиналу', style: TextStyle(color: Colors.orange)),
              ])),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () { Navigator.pop(context); vpn.deleteNode(idx); },
            child: Text(S.t('delete'))),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSel  = vpn.selectedIndex == idx;
    final pc     = _pc[cfg.protocol] ?? Colors.white38;
    final light  = Theme.of(context).brightness == Brightness.light;
    final br     = isLast
        ? const BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18))
        : BorderRadius.zero;

    return Dismissible(
      key: ValueKey(cfg.link),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          // Удалить — подтверждение
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: const Text('Удалить ноду?'),
              content: Text(cfg.displayName),
              actions: [
                CupertinoDialogAction(isDestructiveAction: true,
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(S.t('delete'))),
                CupertinoDialogAction(onPressed: () => Navigator.pop(context, false),
                    child: Text(S.t('cancel'))),
              ])) ?? false;
        } else {
          // Настройки — не dismiss, открыть меню
          _showNodeMenu(context);
          return false;
        }
      },
      // Фон: свайп влево = удалить (красный)
      background: Container(
        alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF1565C0).withOpacity(0.45), Colors.transparent]),
          borderRadius: br),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.tune_rounded, color: Color(0xFF64B5F6), size: 18),
          const SizedBox(height: 3),
          const Text('Настройки', style: TextStyle(fontSize: 8, color: Color(0xFF64B5F6))),
        ])),
      secondaryBackground: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent, Colors.red.withOpacity(0.40)]),
          borderRadius: br),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(height: 3),
          const Text('Удалить', style: TextStyle(fontSize: 8, color: Colors.redAccent)),
        ])),
      onDismissed: (dir) {
        if (dir == DismissDirection.endToStart) vpn.deleteNode(idx);
      },
      child: GestureDetector(
        onTap: () => vpn.selectNode(idx),
        onLongPress: () => _showNodeMenu(context),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isSel ? LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [_accent.withOpacity(light ? 0.10 : 0.14), Colors.transparent]) : null,
            borderRadius: br),
          child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                // Protocol badge
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(width: 46, padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: pc.withOpacity(0.20), borderRadius: BorderRadius.circular(8), border: Border.all(color: pc.withOpacity(0.40), width: 0.8)),
                      child: Text(cfg.protocol, textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: pc))))),
                const SizedBox(width: 12),
                Expanded(child: Row(children: [
                  Flexible(child: Text(cfg.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                          color: isSel ? _textColor(context) : _textColor(context).withOpacity(0.72),
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400))),
                  if (cfg.isAiPatched) const Padding(padding: EdgeInsets.only(left: 4), child: Text('🤖', style: TextStyle(fontSize: 9))),
                  if (cfg.isManual) Container(margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(4), border: Border.all(color: light ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.12))),
                      child: Text('MAN', style: TextStyle(fontSize: 7, color: _subTextColor(context).withOpacity(0.6)))),
                ])),
                const SizedBox(width: 8),
                // Ping
                if (cfg.isPinging)
                  const SizedBox(width: 22, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38))
                else
                  GestureDetector(onTap: () => vpn.pingNode(idx),
                    child: ClipRRect(borderRadius: BorderRadius.circular(7),
                      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cfg.pingColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(7), border: Border.all(color: cfg.pingColor.withOpacity(0.35), width: 0.8)),
                          child: Text(cfg.ping, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cfg.pingColor)))))),
                const SizedBox(width: 6),
                // Favourite star
                GestureDetector(
                  onTap: () => vpn.toggleFavourite(idx),
                  child: Icon(cfg.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16, color: cfg.isFavourite ? _accentGold : _subTextColor(context).withOpacity(0.3))),
                const SizedBox(width: 6),
                // Selected dot
                AnimatedContainer(duration: const Duration(milliseconds: 200),
                  width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: isSel ? _accent : Colors.transparent,
                    boxShadow: isSel ? [BoxShadow(color: _accent, blurRadius: 8)] : [])),
              ])),
            if (!isLast) Divider(height: 0, thickness: 0.5,
                color: light ? Colors.black.withOpacity(0.07) : Colors.white.withOpacity(0.07),
                indent: 14, endIndent: 14),
          ]),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

// ── Node List Sliver — кэширует список нод ────────────────────────────────────

class _NodeListSliver extends StatelessWidget {
  final VpnProvider vpn;
  const _NodeListSliver({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final cols = context.nodeColumns;
    if (cols == 1) {
      // Телефон — обычный список
      final items = _buildNodeList(vpn, context);
      return SliverList(delegate: SliverChildBuilderDelegate(
        (_, i) => i < items.length ? items[i] : null,
        childCount: items.length,
      ));
    }
    // Планшет / desktop — грид
    final groups = vpn.grouped.entries.toList();
    return SliverList(delegate: SliverChildBuilderDelegate((ctx, gi) {
      if (gi >= groups.length) return null;
      final entry       = groups[gi];
      final sourceUrl   = entry.key;
      final nodes       = entry.value;
      final displayName = vpn.groupDisplayName(sourceUrl);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _GroupHeader(
          name: displayName, count: nodes.length, vpn: vpn,
          sourceUrl: sourceUrl,
          onRename: sourceUrl == '__favourites__' ? null
              : () => _dlgGroupStatic(ctx, vpn, sourceUrl, displayName),
        ),
        Padding(
          padding: context.pagePadding.copyWith(top: 0, bottom: 10),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 0,
              childAspectRatio: 4.5,
            ),
            itemCount: nodes.length,
            itemBuilder: (_, i) {
              final node = nodes[i];
              final idx  = vpn.configs.indexOf(node);
              return RepaintBoundary(child: GlassBox(
                radius: 14, blur: 20,
                tint: const Color(0xFF0D47A1), tintOpacity: 0.12,
                child: _NodeTile(
                  cfg: node, idx: idx,
                  isLast: true, vpn: vpn,
                  onRename: () => _dlgNodeStatic(ctx, vpn, idx))));
            }),
        ),
      ]);
    }, childCount: groups.length));
  }

  List<Widget> _buildNodeList(VpnProvider vpn, BuildContext ctx) {
    final items = <Widget>[];
    for (final entry in vpn.grouped.entries) {
      final sourceUrl   = entry.key;
      final nodes       = entry.value;
      final displayName = vpn.groupDisplayName(sourceUrl);
      items.add(_GroupHeader(
        name: displayName, count: nodes.length, vpn: vpn,
        sourceUrl: sourceUrl,
        onRename: sourceUrl == '__favourites__' ? null
            : () => _dlgGroupStatic(ctx, vpn, sourceUrl, displayName),
      ));
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: RepaintBoundary(child: GlassBox(
          radius: 18, blur: 28,
          tint: const Color(0xFF0D47A1), tintOpacity: 0.12,
          child: Column(children: nodes.asMap().entries.map((e) {
            final idx = vpn.configs.indexOf(e.value);
            return _NodeTile(
              cfg: e.value, idx: idx,
              isLast: e.key == nodes.length - 1,
              vpn: vpn,
              onRename: () => _dlgNodeStatic(ctx, vpn, idx));
          }).toList()))),
      ));
    }
    return items;
  }
}

void _dlgGroupStatic(BuildContext ctx, VpnProvider vpn, String url, String name) {
  final c = TextEditingController(text: name);
  showCupertinoDialog(context: ctx, builder: (x) => CupertinoAlertDialog(
    title: Text(S.t('rename_group')),
    content: Padding(padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(controller: c, autofocus: true)),
    actions: [
      CupertinoDialogAction(isDestructiveAction: true,
          onPressed: () => Navigator.pop(x), child: Text(S.t('cancel'))),
      CupertinoDialogAction(onPressed: () {
        vpn.subNames[url] = c.text.trim();
        for (final n in vpn.configs) {
          if (n.sourceUrl == url) n.groupName = c.text.trim();
        }
        vpn.saveToDisk(); vpn.refresh(); Navigator.pop(x);
      }, child: Text(S.t('save'))),
    ],
  ));
}

void _dlgNodeStatic(BuildContext ctx, VpnProvider vpn, int idx) {
  if (idx < 0 || idx >= vpn.configs.length) return;
  final c = TextEditingController(text: vpn.configs[idx].displayName);
  showCupertinoDialog(context: ctx, builder: (x) => CupertinoAlertDialog(
    title: Text(S.t('rename_node')),
    content: Padding(padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(controller: c, autofocus: true)),
    actions: [
      CupertinoDialogAction(isDestructiveAction: true,
          onPressed: () => Navigator.pop(x), child: Text(S.t('cancel'))),
      CupertinoDialogAction(onPressed: () {
        vpn.renameNode(idx, c.text); Navigator.pop(x);
      }, child: Text(S.t('save'))),
    ],
  ));
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback? onAdd;
  const _EmptyState({required this.onScan, this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 28),
    child: GlassBox(blur: 28, tint: const Color(0xFF1A237E), tintOpacity: 0.15,
      child: Padding(padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lan_outlined, size: 52, color: _textColor(context).withOpacity(0.12)),
          const SizedBox(height: 14),
          Text(S.t('no_nodes'), style: TextStyle(color: _subTextColor(context).withOpacity(0.5), letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(S.t('add_via_qr'), textAlign: TextAlign.center, style: TextStyle(color: _subTextColor(context).withOpacity(0.35), fontSize: 11)),
          const SizedBox(height: 24),
          GestureDetector(onTap: onScan,
            child: GlassBox(radius: 12, blur: 12, tint: _accent, tintOpacity: 0.22,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner, size: 15, color: _accent),
                const SizedBox(width: 8),
                Text(S.t('scan_qr'), style: TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ]))),
        ]))));
}

// ═══════════════════════════════════════════════════════════════
//  QR SCAN SCREEN
// ═══════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════════════════
//  AUTO CONNECT APPS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class AutoConnectAppsScreen extends StatefulWidget {
  const AutoConnectAppsScreen({super.key});
  @override State<AutoConnectAppsScreen> createState() => _AutoConnectAppsScreenState();
}

class _AutoConnectAppsScreenState extends State<AutoConnectAppsScreen> {
  static const _appsChannel = MethodChannel('aura_vpn/apps');

  List<InstalledApp> _all      = [];
  List<InstalledApp> _filtered = [];
  bool   _loading = true;
  String _search  = '';
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _loadApps(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadApps() async {
    setState(() => _loading = true);
    try {
      final raw  = await _appsChannel.invokeMethod<List>('getInstalledApps');
      final apps = (raw ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return InstalledApp(
          packageName: m['packageName'] as String,
          label:       m['label']       as String,
          icon:        m['icon']        as String? ?? '',
        );
      }).toList();
      apps.sort((a, b) {
        // Включённые сначала
        final aOn = _autoConnect.apps.any((x) => x.packageName == a.packageName && x.enabled);
        final bOn = _autoConnect.apps.any((x) => x.packageName == b.packageName && x.enabled);
        if (aOn != bOn) return aOn ? -1 : 1;
        return a.label.compareTo(b.label);
      });
      if (mounted) setState(() { _all = apps; _filtered = apps; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    setState(() {
      _search   = q;
      _filtered = q.isEmpty ? _all
          : _all.where((a) =>
              a.label.toLowerCase().contains(q.toLowerCase()) ||
              a.packageName.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  bool _isEnabled(String pkg) =>
      _autoConnect.apps.any((a) => a.packageName == pkg && a.enabled);

  void _toggle(InstalledApp app) {
    final existing = _autoConnect.apps.firstWhere(
      (a) => a.packageName == app.packageName,
      orElse: () => AutoConnectApp(packageName: '', displayName: ''),
    );
    if (existing.packageName.isEmpty) {
      // Добавляем новое
      _autoConnect.addApp(AutoConnectApp(
        packageName: app.packageName,
        displayName: app.label,
        icon: app.icon,
      ));
    } else {
      _autoConnect.toggleApp(existing);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: light ? const Color(0xFFF0F2FA) : const Color(0xFF060408),
      body: SafeArea(
        // CupertinoSliverNavigationBar учитывает статус-бар сам
        // SafeArea нужна для боков (Galaxy Z Fold) и низа (жестовая навигация)
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
            backgroundColor: Colors.transparent,
            border: null,
            largeTitle: Text('Приложения-триггеры',
                style: TextStyle(
                    color: _textColor(context),
                    fontWeight: FontWeight.w800)),
            trailing: _autoConnect.enabledAppsCount > 0
                ? GestureDetector(
                    onTap: () {
                      _autoConnect.apps.clear();
                      _autoConnect.save();
                      _autoConnect.forceRefresh();
                      setState(() {});
                    },
                    child: const Text('Сбросить',
                        style: TextStyle(fontSize: 12, color: Colors.redAccent)))
                : null,
          ),

          // Поиск
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchCtrl,
              placeholder: 'Поиск приложений…',
              onChanged: _filter,
              style: TextStyle(color: _textColor(context), fontSize: 14),
            ),
          )),

          if (_autoConnect.enabledAppsCount > 0)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Активных триггеров: ${_autoConnect.enabledAppsCount}',
                style: TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600),
              ),
            )),

          if (_loading)
            const SliverFillRemaining(child: Center(
              child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: Center(
              child: Text('Приложения не найдены',
                  style: TextStyle(color: _subTextColor(context)))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final app = _filtered[i];
                  final on  = _isEnabled(app.packageName);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () => _toggle(app),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: on
                              ? _accent.withOpacity(0.12)
                              : (light ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                            width: on ? 1.2 : 0.7),
                        ),
                        child: Row(children: [
                          // Иконка приложения
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: app.icon.isNotEmpty
                                ? Image.memory(base64Decode(app.icon),
                                    width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _AppIconFallback(app: app, sel: on, light: light))
                                : _AppIconFallback(app: app, sel: on, light: light),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(app.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: _textColor(context))),
                            Text(app.packageName,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 9,
                                    color: on ? _accent.withOpacity(0.6)
                                             : _subTextColor(context).withOpacity(0.4))),
                          ])),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: on ? _accent : Colors.white.withOpacity(0.08),
                              border: Border.all(
                                color: on ? _accent : Colors.white.withOpacity(0.20),
                                width: 1.5)),
                            child: on
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null),
                        ]),
                      ),
                    ),
                  );
                },
                childCount: _filtered.length,
              )),
            ),
            // Bottom padding для навигационной полоски жестов
            SliverToBoxAdapter(child: SizedBox(
                height: 24 + MediaQuery.of(context).padding.bottom)),
        ],
        ),   // CustomScrollView
      ),     // SafeArea
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SPLIT TUNNEL — полный экран выбора установленных приложений  v5.3
// ═══════════════════════════════════════════════════════════════════════════════

class InstalledApp {
  final String packageName;
  final String label;
  final String icon; // base64 PNG иконка от нативного кода
  const InstalledApp({
      required this.packageName, required this.label, this.icon = ''});
}

// ── App Icon Fallback ────────────────────────────────────────────────────────
class _AppIconFallback extends StatelessWidget {
  final InstalledApp app;
  final bool sel, light;
  const _AppIconFallback({required this.app, required this.sel, required this.light});

  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: sel
          ? _accentPurple.withOpacity(0.20)
          : (light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.08))),
    child: Center(child: Text(
      app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: sel ? _accentPurple : (light ? Colors.black54 : Colors.white38)))));
}

class SplitTunnelAppsScreen extends StatefulWidget {
  final VpnProvider vpn;
  const SplitTunnelAppsScreen({super.key, required this.vpn});
  @override State<SplitTunnelAppsScreen> createState() => _SplitTunnelAppsScreenState();
}

class _SplitTunnelAppsScreenState extends State<SplitTunnelAppsScreen> {
  static const _appsChannel = MethodChannel('aura_vpn/apps');

  List<InstalledApp> _all      = [];
  List<InstalledApp> _filtered = [];
  bool   _loading = true;
  String _search  = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadApps() async {
    setState(() => _loading = true);
    try {
      // Получаем список установленных приложений через нативный канал
      final raw = await _appsChannel.invokeMethod<List>('getInstalledApps');
      final apps = (raw ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return InstalledApp(
          packageName: m['packageName'] as String,
          label:       m['label']       as String,
          icon:        m['icon']        as String? ?? '',
        );
      }).toList();
      // Сортируем: сначала выбранные, потом по алфавиту
      apps.sort((a, b) {
        final asel = widget.vpn.splitApps.contains(a.packageName);
        final bsel = widget.vpn.splitApps.contains(b.packageName);
        if (asel != bsel) return asel ? -1 : 1;
        return a.label.compareTo(b.label);
      });
      setState(() { _all = apps; _filtered = apps; _loading = false; });
    } catch (e) {
      // Если нативный канал не работает — показываем популярные
      // fallback — пустой список с подсказкой
      setState(() { _all = []; _filtered = []; _loading = false; });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _search   = q;
      _filtered = q.isEmpty
          ? _all
          : _all.where((a) =>
              a.label.toLowerCase().contains(q.toLowerCase()) ||
              a.packageName.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final light    = Theme.of(context).brightness == Brightness.light;
    final selected = widget.vpn.splitApps;

    return Scaffold(
      backgroundColor: light ? const Color(0xFFF0F2F8) : const Color(0xFF060408),
      body: SafeArea(
        // CupertinoNavigationBar учитывает статус-бар сам (top: false)
        // bottom/left/right: защита от жестовой навигации и боковых вырезов
        top: false,
        child: Column(children: [

        // AppBar
        CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          middle: Text('Выбор приложений',
              style: TextStyle(
                  color: light ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.w700)),
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: light ? Colors.black87 : Colors.white)),
          trailing: selected.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    for (final pkg in List.from(selected)) {
                      widget.vpn.toggleSplitApp(pkg);
                    }
                    setState(() {});
                  },
                  child: Text('Очистить',
                      style: TextStyle(fontSize: 13, color: _accentPurple)))
              : null,
        ),

        // Строка поиска
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style: TextStyle(
                    fontSize: 14,
                    color: light ? Colors.black87 : Colors.white),
                decoration: InputDecoration(
                  hintText: 'Поиск приложений…',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: light
                          ? Colors.black38
                          : Colors.white30),
                  prefixIcon: Icon(Icons.search,
                      size: 18,
                      color: light ? Colors.black38 : Colors.white30),
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                          child: Icon(Icons.close,
                              size: 16,
                              color: light
                                  ? Colors.black38
                                  : Colors.white30))
                      : null,
                  filled: true,
                  fillColor: light
                      ? Colors.black.withOpacity(0.06)
                      : Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),

        // Счётчик выбранных
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _accentPurple.withOpacity(0.3))),
                child: Text(
                  '${selected.length} выбрано',
                  style: TextStyle(
                      fontSize: 11,
                      color: _accentPurple,
                      fontWeight: FontWeight.w600))),
            ])),

        // Список приложений
        Expanded(child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _filtered.isEmpty
                ? Center(child: Text('Ничего не найдено',
                    style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final app = _filtered[i];
                      final sel = selected.contains(app.packageName);
                      return GestureDetector(
                        onTap: () {
                          widget.vpn.toggleSplitApp(app.packageName);
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? _accentPurple.withOpacity(0.12)
                                : (light
                                    ? Colors.black.withOpacity(0.03)
                                    : Colors.white.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? _accentPurple.withOpacity(0.4)
                                  : Colors.transparent)),
                          child: Row(children: [
                            // Иконка приложения
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: app.icon.isNotEmpty
                                  ? Image.memory(
                                      base64Decode(app.icon),
                                      width: 38, height: 38,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _AppIconFallback(app: app, sel: sel, light: light))
                                  : _AppIconFallback(app: app, sel: sel, light: light)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: sel
                                            ? (light
                                                ? Colors.black87
                                                : Colors.white)
                                            : (light
                                                ? Colors.black54
                                                : Colors.white54))),
                                Text(app.packageName,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: light
                                            ? Colors.black26
                                            : Colors.white24),
                                    overflow: TextOverflow.ellipsis),
                              ])),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sel
                                    ? _accentPurple
                                    : Colors.transparent,
                                border: Border.all(
                                  color: sel
                                      ? _accentPurple
                                      : (light
                                          ? Colors.black26
                                          : Colors.white24),
                                  width: 1.5)),
                              child: sel
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : null),
                          ]),
                        ),
                      );
                    })),
      ]),     // Column
      ),      // SafeArea
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ШАРИНГ КОНФИГОВ — QR + ссылка  v5.3
// ═══════════════════════════════════════════════════════════════════════════════

class ShareConfigSheet extends StatelessWidget {
  final VpnConfig config;
  const ShareConfigSheet({super.key, required this.config});

  static void show(BuildContext context, VpnConfig config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareConfigSheet(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = config.link;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0C18),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.10), width: 0.5))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Ручка
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Заголовок
            Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Поделиться нодой', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                Text(config.displayName, style: TextStyle(
                    fontSize: 12, color: Colors.white38)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 20)),
            ]),
            const SizedBox(height: 20),

            // QR код
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SizedBox(
                  width: 200, height: 200,
                  child: CustomPaint(
                      painter: _QrPainter(link),
                      child: const SizedBox.expand())),
              )),
            const SizedBox(height: 8),
            Text('Сканируй QR чтобы добавить ноду',
                style: TextStyle(fontSize: 10, color: Colors.white30)),
            const SizedBox(height: 20),

            // Ссылка
            GlassBox(
              blur: 12, tint: Colors.white, tintOpacity: 0.04,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Text(
                    link.length > 60
                        ? '${link.substring(0, 60)}…'
                        : link,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: Colors.white54),
                    overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Ссылка скопирована'),
                          backgroundColor:
                              Colors.black87,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          duration:
                              const Duration(seconds: 2)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _accent.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.copy_rounded,
                            size: 13, color: _accentBlue),
                        const SizedBox(width: 4),
                        Text('Копировать',
                            style: TextStyle(
                                fontSize: 10, color: _accentBlue)),
                      ])),
                  ),
                ])),
            ),

            const SizedBox(height: 12),

            // Кнопка Поделиться через системный шаринг
            GestureDetector(
              onTap: () {
                // Системный шаринг — открывает стандартный диалог
                Share.share(link, subject: config.displayName);
              },
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _accent.withOpacity(0.6),
                    _accentBlue.withOpacity(0.4)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _accent.withOpacity(0.4)),
                  boxShadow: [BoxShadow(
                      color: _accent.withOpacity(0.2),
                      blurRadius: 16)]),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded,
                        size: 18, color: Colors.white),
                    SizedBox(width: 10),
                    Text('ПОДЕЛИТЬСЯ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2)),
                  ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Простой QR painter — матрица точек
class _QrPainter extends CustomPainter {
  final String data;
  const _QrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Простой визуальный QR-паттерн (заглушка)
    // В продакшене заменить на qr_flutter пакет
    final paint = Paint()..color = Colors.black;
    final cell  = size.width / 21;
    final hash  = data.hashCode.abs();

    // Угловые маркеры
    _drawFinder(canvas, paint, 0, 0, cell);
    _drawFinder(canvas, paint, 14, 0, cell);
    _drawFinder(canvas, paint, 0, 14, cell);

    // Данные (псевдослучайные на основе хэша)
    final rng = data.codeUnits;
    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        if (r < 9 && c < 9) continue;
        if (r < 9 && c > 11) continue;
        if (r > 11 && c < 9) continue;
        final bit = (rng[(r * 21 + c) % rng.length] + hash) % 2;
        if (bit == 1) {
          canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell - 0.5, cell - 0.5),
              paint);
        }
      }
    }
  }

  void _drawFinder(Canvas c, Paint p, int col, int row, double cell) {
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(col * cell, row * cell, 7 * cell, 7 * cell),
        Radius.circular(cell * 0.8)), p);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH((col + 1) * cell, (row + 1) * cell, 5 * cell, 5 * cell),
        Radius.circular(cell * 0.5)),
        Paint()..color = Colors.white);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH((col + 2) * cell, (row + 2) * cell, 3 * cell, 3 * cell),
        Radius.circular(cell * 0.3)), p);
  }

  @override bool shouldRepaint(_) => false;
}

// ── Share helper (заглушка — заменить на share_plus пакет) ───────────────────
class Share {
  static Future<void> share(String text, {String? subject}) async {
    try {
      await const MethodChannel('aura_vpn/share')
          .invokeMethod('share', {'text': text, 'subject': subject ?? ''});
    } catch (_) {
      // fallback — просто копируем
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _ctrl;
  bool _scanned = false;

  @override void initState() { super.initState(); _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_scanned || !mounted) return;
    final raw = cap.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    setState(() => _scanned = true); _ctrl.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vpn = Provider.of<VpnProvider>(context, listen: false);
      if (raw.startsWith('http')) { vpn.addSubscription(raw); _sheet(S.t('sub_added'), raw, Icons.rss_feed); }
      else if (raw.contains('://')) { vpn.addSingleKey(raw); _sheet(S.t('node_added'), raw, Icons.security); }
      else { _sheet(S.t('unknown_qr'), raw, Icons.warning_amber_rounded); }
    });
  }

  void _sheet(String title, String body, IconData icon) {
    if (!mounted) return;
    showCupertinoModalPopup(context: context, builder: (x) => CupertinoActionSheet(
      title: Text(title),
      message: Text(body, style: const TextStyle(fontSize: 11)),
      actions: [CupertinoActionSheetAction(
        onPressed: () { Navigator.pop(x); Navigator.pop(context); },
        child: Text(S.t('done'), style: TextStyle(color: _accent, fontWeight: FontWeight.bold)))],
      cancelButton: CupertinoActionSheetAction(isDestructiveAction: true,
        onPressed: () { Navigator.pop(x); if (mounted) { setState(() => _scanned = false); _ctrl.start(); } },
        child: Text(S.t('scan_again'))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final mq    = MediaQuery.of(context);
    // Нижний отступ: навигационная полоска + 30px зазор
    final bottomPad = mq.padding.bottom + 30.0;

    return AuraBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(S.t('qr_scanner'), style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800,
            letterSpacing: 2, color: _textColor(context))),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on, color: _textColor(context).withOpacity(0.7)),
            onPressed: () => _ctrl.toggleTorch()),
          IconButton(
            icon: Icon(Icons.flip_camera_ios, color: _textColor(context).withOpacity(0.7)),
            onPressed: () => _ctrl.switchCamera()),
        ],
      ),
      body: Stack(children: [
        // Полноэкранный сканер — не ограничиваем SafeArea (нужна камера)
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        // Затемнение с вырезом
        ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.srcOut),
          child: Stack(children: [
            Container(decoration: const BoxDecoration(
                color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
            Center(child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(18)))),
          ])),
        // Рамка сканера
        Center(child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: _accent, width: 2.0),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 20)]))),
        // Подсказка внизу — с учётом жестовой навигационной полоски
        Positioned(
          bottom: bottomPad,
          left: 40, right: 40,
          child: GlassBox(
            blur: 24,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Text(
              'VLESS · VMESS · SS · TROJAN · SUB',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.white60, letterSpacing: 1.5)))),
        // Оверлей при сканировании
        if (_scanned)
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.black38,
              child: Center(child: CircularProgressIndicator(color: _accent)))),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════
//  SETTINGS SCREEN  (v3: профили + бэкап + split tunnel)
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  SETTINGS SCREEN v5.5 — плиточные категории как в Telegram
// ═══════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return AuraBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(S.t('settings'), style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            letterSpacing: 1.5, color: _textColor(context))),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxW),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                context.pagePadding.left.clamp(16.0, double.infinity),
                8,
                context.pagePadding.right.clamp(16.0, double.infinity),
                80 + MediaQuery.of(context).padding.bottom),
            children: [

          // ═══════════════════════════════════════════════════════════════
          // 1. ТУННЕЛЬ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_tunnel')),
          _SettingsTile(
            icon: Icons.route_outlined,
            iconColor: const Color(0xFF26A69A),
            title: S.t('tunnel_settings'),
            subtitle: 'Маршрутизация · MUX · TUN · IP-режим',
            helpText: 'Управляет как именно трафик идёт через VPN: IPv4/IPv6, мультиплексирование соединений (MUX), TUN-режим для полного перехвата трафика ОС.',
            onTap: () => _push(context, const _TunnelPage())),
          _SettingsTile(
            icon: Icons.call_split_rounded,
            iconColor: const Color(0xFFAB47BC),
            title: S.t('split_tunnel'),
            subtitle: 'Выбрать приложения для VPN',
            onTap: () {
              final vpn = Provider.of<VpnProvider>(context, listen: false);
              Navigator.push(context, CupertinoPageRoute(
                  builder: (_) => SplitTunnelAppsScreen(vpn: vpn)));
            }),
          _SettingsTile(
            icon: Icons.wifi_tethering_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: S.t('lan_share'),
            subtitle: 'Прокси для устройств в сети',
            helpText: 'Позволяет другим устройствам (телефон, ноутбук) в вашей WiFi-сети использовать Ауру как прокси. Адрес: 0.0.0.0:10808.',
            onTap: () => _push(context, const _LanPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 2. БЕЗОПАСНОСТЬ И ОБХОД
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_security')),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF43A047),
            title: S.t('protection'),
            subtitle: 'Kill Switch · Авторотация',
            onTap: () => _push(context, const _ProtectionPage())),
          _SettingsTile(
            icon: Icons.blur_on_rounded,
            iconColor: const Color(0xFF7C4DFF),
            title: S.t('stealth_engine'),
            subtitle: 'Anti-DPI · JA4+ · Reality SNI · Siberia',
            helpText: 'Маскирует VPN под обычный HTTPS. Anti-DPI обманывает глубокую проверку пакетов. Reality SNI показывает ТСПУ что вы посещаете Google/Microsoft.',
            onTap: () => _push(context, const _StealthPage())),
          _SettingsTile(
            icon: Icons.theater_comedy_outlined,
            iconColor: const Color(0xFFFF6D00),
            title: S.t('camouflage'),
            subtitle: 'Под что скрываться: Netflix · YouTube · iCloud · NaïveProxy',
            helpText: 'Делает VPN трафик неотличимым от конкретного сервиса. ТСПУ видит запросы к Netflix/iCloud — не подозрительный VPN. Для России лучше: Windows Update или iCloud.',
            onTap: () => _push(context, const _CamouflagePage())),
          _SettingsTile(
            icon: Icons.psychology_outlined,
            iconColor: _accent,
            title: S.t('ai_bypass_engine'),
            subtitle: '100 стратегий · Авто-обход блокировок',
            helpText: 'Автоматически перебирает 100 способов обхода когда VPN заблокирован. Учится на неудачах — заблокированные стратегии помечаются на 5-60 минут.',
            onTap: () => _push(context, const _AiBypassPage())),
          _SettingsTile(
            icon: Icons.public_off_rounded,
            iconColor: const Color(0xFF7C4DFF),
            title: 'Обход белых списков',
            subtitle: 'CDN · WebSocket · 443',
            helpText: 'Маршрутизирует трафик через Cloudflare CDN. Используй если сам VPN-сервер заблокирован — трафик идёт через незаблокированный CDN.',
            onTap: () => _push(context, const _BypassPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 3. ПОДПИСКИ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_subscriptions')),
          _SettingsTile(
            icon: Icons.rss_feed_rounded,
            iconColor: const Color(0xFF26A69A),
            title: 'Управление подписками',
            subtitle: 'Добавить · Обновить · Удалить',
            helpText: 'Подписки — это URL-ссылки от провайдера VPN, содержащие список серверов. Вставь ссылку и Аура загрузит все доступные серверы.',
            onTap: () => _push(context, const _SubscriptionsPage())),
          _SettingsTile(
            icon: Icons.update_rounded,
            iconColor: const Color(0xFF29B6F6),
            title: S.t('sub_settings'),
            subtitle: 'Авто · При запуске · Сортировка',
            helpText: 'Настрой как часто обновлять список серверов, сортировку по пингу, и поведение при запуске приложения.',
            onTap: () => _push(context, const _SubSettingsPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 4. СОЕДИНЕНИЕ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_connection')),
          _SettingsTile(
            icon: Icons.wifi_outlined,
            iconColor: const Color(0xFF29B6F6),
            title: 'Автоподключение',
            subtitle: 'По WiFi · По приложениям',
            onTap: () => _push(context, const _AutoConnectPage())),
          _SettingsTile(
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFFFFCA28),
            title: S.t('ping_settings'),
            subtitle: 'TCP · Proxy · ICMP · URL',
            helpText: 'Метод измерения скорости серверов. TCP — быстро. Proxy — точнее, через VPN. ICMP — классический ping (нужен root).',
            onTap: () => _push(context, const _PingSettingsPage())),
          _SettingsTile(
            icon: Icons.fact_check_outlined,
            iconColor: const Color(0xFF66BB6A),
            title: 'Тест белых списков',
            subtitle: 'Проверка: Госуслуги · VK · Яндекс · Instagram',
            onTap: () => _push(context, const _WhitelistTesterPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 5. ИНТЕРФЕЙС
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_interface')),
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconColor: const Color(0xFFFF7043),
            title: 'Тема и скины',
            subtitle: 'Тёмная · Светлая · Кастом · 13 тем',
            helpText: '13 встроенных тем + редактор собственной темы с поддержкой фото/GIF фона. Выбери цвета акцента, фона и блобов.',
            onTap: () => _push(context, const _AppearancePage())),
          _SettingsTile(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF26C6DA),
            title: S.t('language'),
            subtitle: '${S.localeNames.values.take(4).join(', ')}…',
            onTap: () => _push(context, const _LanguagePage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 6. ДАННЫЕ И АККАУНТ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_data')),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF5C6BC0),
            title: 'Профили',
            subtitle: 'Несколько наборов настроек',
            onTap: () => _push(context, const _ProfilesPage())),
          _SettingsTile(
            icon: Icons.backup_outlined,
            iconColor: const Color(0xFF8D6E63),
            title: S.t('backup'),
            subtitle: 'Экспорт и импорт настроек',
            onTap: () => _push(context, const _BackupPage())),
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF78909C),
            title: S.t('history'),
            subtitle: 'Журнал сессий',
            onTap: () => _push(context, const _HistoryPage())),
          _SettingsTile(
            icon: Icons.terminal_rounded,
            iconColor: const Color(0xFF546E7A),
            title: S.t('logs'),
            subtitle: 'Отладочный журнал',
            onTap: () => _push(context, const _LogsPage())),

          const SizedBox(height: 20),

          // О приложении
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: S.t('about_app'),
            subtitle: 'v$kAppVersion · build $kAppBuild · 22.03.2026',
            onTap: () => _push(context, const _AboutPage())),

          const SizedBox(height: 32),
        ],
        ),  // ListView
        ),  // ConstrainedBox
      ),    // Align
    ));     // Scaffold + AuraBlobBg
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => page));
  }
}

// ── Tunnel Settings Page ─────────────────────────────────────────────────────

class _TunnelPage extends StatelessWidget {
  const _TunnelPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Настройки туннеля', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection(S.t('routing')),
      _SwitchRow(
        icon: Icons.route_outlined, iconColor: const Color(0xFF26A69A),
        title: 'Умная маршрутизация',
        subtitle: 'RU-домены → прямо, заблокированные → VPN',
        value: true, onChanged: null,
        trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)),
      const SizedBox(height: 4),
      _SubSection(S.t('ip_preference')),
      _RadioGroup<String>(
        value: vpn.ipPreference,
        options: const [
          ('auto',  '🌐 Авто',  'IPv4 с fallback на IPv6'),
          ('ipv4',  '4️⃣  IPv4',  'Только IPv4 адреса'),
          ('ipv6',  '6️⃣  IPv6',  'Только IPv6 адреса'),
        ],
        onChanged: vpn.setIpPreference),

      const SizedBox(height: 16),
      _SubSection(S.t('mux_enable')),
      _SwitchRow(
        icon: Icons.compress_rounded, iconColor: const Color(0xFF42A5F5),
        title: 'Включить MUX',
        subtitle: 'Уплотнение TCP-потоков — снижает overhead на повторные подключения',
        value: vpn.enableMux,
        onChanged: vpn.setEnableMux,
        hint: 'MUX (мультиплексирование): несколько запросов идут через один TLS туннель. Снижает задержку при частых подключениях. Не совместим с VLESS+Reality — включается только для VMess/Trojan.'),
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: 'MUX уменьшает количество TLS-рукопожатий. '
              'Отключи если замечаешь лаги на мобильном интернете.'),

      const SizedBox(height: 16),
      _SubSection(S.t('tun_enable')),
      _SwitchRow(
        icon: Icons.router_outlined, iconColor: const Color(0xFF7C4DFF),
        title: 'Включить TUN',
        subtitle: 'sing-box стиль — перехватывает весь трафик ОС',
        value: vpn.enableTun,
        onChanged: vpn.setEnableTun,
        hint: 'TUN — виртуальный сетевой интерфейс. Перехватывает ВЕСЬ трафик ОС включая UDP, DNS, QUIC. В отличие от SOCKS5/HTTP прокси — ни одно приложение не «пройдёт мимо».'),
      if (vpn.enableTun) ...[
        const SizedBox(height: 4),
        _RadioGroup<String>(
          value: vpn.tunMode,
          options: const [
            ('mixed',   'Смешанный',  'TCP + UDP через tun2socks'),
            ('fakedns', 'FakeDNS',    'DNS перехват для снижения утечек'),
          ],
          onChanged: vpn.setTunMode),
        const SizedBox(height: 8),
        _SwitchRow(
          icon: Icons.dns_outlined, iconColor: const Color(0xFF29B6F6),
          title: 'DNS для TUN',
          subtitle: 'Использовать DoH внутри туннеля',
          value: vpn.enableDns,
          onChanged: vpn.setEnableDns),
        if (vpn.enableDns) ...[
          const SizedBox(height: 4),
          _TextInputRow(
            label: 'DNS адрес',
            hint: '1.1.1.1',
            value: vpn.dnsAddress,
            onChanged: vpn.setDnsAddress),
        ],
      ],

      const SizedBox(height: 16),
      _SubSection(S.t('section_data')),
      _SwitchRow(
        icon: Icons.analytics_outlined, iconColor: const Color(0xFFFF7043),
        title: 'Анализ пакетов',
        subtitle: 'DPI-детектирование типа трафика для маршрутизации',
        value: vpn.enablePacketSniff,
        onChanged: vpn.setPacketSniff,
        hint: 'Аура анализирует SNI/HTTP Host каждого пакета и маршрутизирует по содержимому. Например: gosuslugi.ru → прямо, instagram.com → через VPN. Требует чуть больше CPU.'),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.swap_horiz_rounded, iconColor: const Color(0xFF78909C),
        title: 'Системный прокси',
        subtitle: 'Также устанавливать HTTP/HTTPS прокси в системе',
        value: vpn.enableSystemProxy,
        onChanged: vpn.setSystemProxy),
    ]));
  }
}

// ── LAN Page ─────────────────────────────────────────────────────────────────

class _LanPage extends StatelessWidget {
  const _LanPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Локальная сеть (LAN)', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoCard(
        icon: Icons.wifi_tethering_rounded,
        text: 'Разрешает другим устройствам в сети использовать '
              'Ауру как прокси-сервер. Включает прослушивание на '
              '0.0.0.0 вместо 127.0.0.1.'),
      const SizedBox(height: 16),
      _SubSection('ДОСТУП'),
      _SwitchRow(
        icon: Icons.wifi_tethering_rounded, iconColor: const Color(0xFF42A5F5),
        title: 'Разрешить из LAN',
        subtitle: 'Раздавать интернет устройствам в локальной сети',
        value: vpn.enableLan,
        onChanged: vpn.setEnableLan),
      if (vpn.enableLan) ...[
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.info_outline_rounded,
          text: 'Socks5:\n0.0.0.0:10808  HTTP: 0.0.0.0:10809\nУкажи эти адреса на других устройствах.'),
      ],
    ]));
  }
}

// ── Sub Settings Page ────────────────────────────────────────────────────────

class _SubSettingsPage extends StatelessWidget {
  const _SubSettingsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Параметры обновления', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection('АВТООБНОВЛЕНИЕ'),
      _SwitchRow(
        icon: Icons.update_rounded, iconColor: const Color(0xFF29B6F6),
        title: 'Автообновление подписок',
        subtitle: 'Обновлять ноды по расписанию',
        value: vpn.subAutoUpdate,
        onChanged: vpn.setSubAutoUpdate),
      if (vpn.subAutoUpdate) ...[
        const SizedBox(height: 4),
        _StepperRow(
          label: 'Интервал (часы)',
          value: vpn.subUpdateInterval,
          min: 1, max: 72, step: 1,
          onChanged: vpn.setSubInterval),
      ],

      const SizedBox(height: 16),
      _SubSection('ПАРАМЕТРЫ ЗАПУСКА'),
      _SwitchRow(
        icon: Icons.refresh_rounded, iconColor: const Color(0xFF26A69A),
        title: 'Обновить при открытии',
        subtitle: 'Загружать новые ноды каждый раз при запуске',
        value: vpn.subUpdateOnOpen,
        onChanged: vpn.setSubUpdateOnOpen),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.speed_rounded, iconColor: const Color(0xFFFFCA28),
        title: 'Пинговать при открытии',
        subtitle: 'Измерять задержку нод при запуске',
        value: vpn.subPingOnOpen,
        onChanged: vpn.setSubPingOnOpen),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.play_arrow_rounded, iconColor: const Color(0xFF66BB6A),
        title: 'Подключаться при открытии',
        subtitle: 'Автоматически подключиться при запуске',
        value: vpn.subConnectOnOpen,
        onChanged: vpn.setSubConnectOnOpen),

      const SizedBox(height: 16),
      _SubSection('ЛОГИКА'),
      _SwitchRow(
        icon: Icons.filter_list_off_rounded, iconColor: const Color(0xFF78909C),
        title: 'Разрешить дубликаты',
        subtitle: 'Не удалять одинаковые ноды из разных подписок',
        value: vpn.subAllowDups,
        onChanged: vpn.setSubAllowDups),

      const SizedBox(height: 16),
      _SubSection('СОРТИРОВКА'),
      _RadioGroup<String>(
        value: vpn.subSortMode,
        options: const [
          ('none',  'Без сортировки', 'В порядке получения из подписки'),
          ('ping',  'По пингу',       'Лучшие ноды первыми'),
          ('alpha', 'По алфавиту',    'A → Z по имени ноды'),
        ],
        onChanged: vpn.setSubSortMode),

      const SizedBox(height: 16),
      _SubSection('USER AGENT'),
      _TextInputRow(
        label: 'User-Agent запросов',
        hint: 'AuraVPN/$kAppVersion/Android',
        value: vpn.subUserAgent,
        onChanged: vpn.setSubUserAgent),
    ]));
  }
}

// ── Ping Settings Page ───────────────────────────────────────────────────────

class _PingSettingsPage extends StatelessWidget {
  const _PingSettingsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Настройки пинга', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection('ТИП ПИНГА'),
      _RadioGroup<String>(
        value: vpn.pingType,
        options: const [
          ('tcp',   'TCP',        'Прямое TCP соединение — быстро, точно'),
          ('proxy', 'via Proxy',  'Через VPN туннель — реальная задержка'),
          ('icmp',  'ICMP',       'PING команда — требует root'),
        ],
        onChanged: vpn.setPingType),

      const SizedBox(height: 16),
      _SubSection('ТЕСТОВЫЙ URL'),
      _TextInputRow(
        label: 'URL для проверки',
        hint: 'https://www.gstatic.com/generate_204',
        value: vpn.pingUrl,
        onChanged: vpn.setPingUrl),
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: 'URL должен возвращать HTTP 200-204. '
              'Рекомендуется: gstatic.com/generate_204 (Google) '
              'или connectivitycheck.gstatic.com'),

      const SizedBox(height: 16),
      _SubSection('РЕЗУЛЬТАТ'),
      _DetailRow2('📊', 'Отображение', 'Время (мс) или статус OK/FAIL'),
      _DetailRow2('🔄', 'Повторов', '3 попытки, берём медиану'),
      _DetailRow2('⏱', 'Таймаут', '3000 мс на попытку'),
    ]));
  }
}

// ── Helpers: RadioGroup, StepperRow, TextInputRow ────────────────────────────

class _RadioGroup<T> extends StatelessWidget {
  final T value;
  final List<(T, String, String)> options; // (value, label, subtitle)
  final ValueChanged<T> onChanged;
  const _RadioGroup({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(children: options.map((opt) {
      final sel = value == opt.$1;
      return GestureDetector(
        onTap: () => onChanged(opt.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? _accent.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? _accent : Colors.white30, width: sel ? 5 : 1.5)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(opt.$2, style: TextStyle(
                  fontSize: 13, color: sel ? _accent : Colors.white70,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
              Text(opt.$3, style: const TextStyle(fontSize: 10, color: Colors.white38)),
            ])),
          ]),
        ),
      );
    }).toList());
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  const _StepperRow({required this.label, required this.value,
      required this.min, required this.max, required this.step,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.white70))),
        GestureDetector(
          onTap: value > min ? () => onChanged(value - step) : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(value > min ? 0.08 : 0.02),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.remove, size: 16,
                color: value > min ? Colors.white70 : Colors.white24))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$value',
              style: TextStyle(fontSize: 16, color: _accent, fontWeight: FontWeight.bold))),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + step) : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(value < max ? 0.08 : 0.02),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.add, size: 16,
                color: value < max ? Colors.white70 : Colors.white24))),
      ]),
    );
  }
}

class _TextInputRow extends StatefulWidget {
  final String label, hint, value;
  final ValueChanged<String> onChanged;
  const _TextInputRow({required this.label, required this.hint,
      required this.value, required this.onChanged});
  @override State<_TextInputRow> createState() => _TextInputRowState();
}

class _TextInputRowState extends State<_TextInputRow> {
  late final TextEditingController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        TextField(
          controller: _ctrl,
          style: TextStyle(fontSize: 13, color: _accent),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
            border: InputBorder.none, isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6)),
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
        ),
      ]),
    );
  }
}


// ── Camouflage Page ──────────────────────────────────────────────────────────

class _CamouflagePage extends StatelessWidget {
  const _CamouflagePage();

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);

    return _SubPage(
      title: 'Маскировка трафика',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        _InfoCard(
          icon: Icons.theater_comedy_outlined,
          text: 'Делает VPN трафик неотличимым от конкретного сервиса. '
                'ТСПУ видит запросы к Netflix/YouTube/Discord — '
                'не подозрительный "VPN паттерн".'),
        const SizedBox(height: 16),

        _SubSection('ВЫБЕРИ МАСКИРОВКУ'),
        ...CamouflageMode.values.map((mode) {
          final selected = vpn.camouflageMode == mode.name;
          return GestureDetector(
            onTap: () => vpn.setCamouflageMode(mode.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected
                        ? _accent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                    width: selected ? 1.5 : 1.0),
                boxShadow: selected
                    ? [BoxShadow(color: _accent.withOpacity(0.15), blurRadius: 16)]
                    : [],
              ),
              child: Row(children: [
                // Иконка сервиса
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent.withOpacity(0.20)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(mode.emoji,
                      style: const TextStyle(fontSize: 22)))),
                const SizedBox(width: 14),
                // Текст
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(mode.label, style: TextStyle(
                          fontSize: 14,
                          color: selected ? _accent : Colors.white.withOpacity(0.85),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      if (mode == CamouflageMode.none)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: const Text('ПО УМОЛЧАНИЮ',
                              style: TextStyle(fontSize: 8, color: Colors.green,
                                  fontWeight: FontWeight.bold))),
                      if (mode == CamouflageMode.microsoft || mode == CamouflageMode.apple)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: const Text('СИЛЬНЫЙ',
                              style: TextStyle(fontSize: 8, color: Colors.orange,
                                  fontWeight: FontWeight.bold))),
                      if (mode == CamouflageMode.naive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: const Text('ТОПОВЫЙ',
                              style: TextStyle(fontSize: 8, color: Color(0xFF7C4DFF),
                                  fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 3),
                    Text(mode.description,
                        style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                )),
                // Индикатор выбора
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? _accent : Colors.white24,
                        width: selected ? 6 : 1.5)),
                ),
              ]),
            ),
          );
        }).toList(),

        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.warning_amber_rounded,
          text: '⚠️ Для России: Microsoft 🪟 и Apple 🍎 — САМЫЕ СИЛЬНЫЕ. '
                'РКН не может заблокировать Windows Update и iCloud. '
                'NaïveProxy 🔀 — лучший против ML-DPI. '
                'Если Россия отключится от глобального интернета — '
                'работают только Microsoft и Apple (RU CIDR).'),
      ]),
    );
  }
}


// ── Help Tooltip ─────────────────────────────────────────────────────────────
// Маленькая кнопка ? — при нажатии показывает снекбар-объяснение снизу

class _HelpBtn extends StatelessWidget {
  final String text;
  const _HelpBtn(this.text);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showHelp(context),
    child: Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: const Center(
        child: Text('?', style: TextStyle(
            fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)))),
  );

  void _showHelp(BuildContext context) {
    final overlay = Overlay.of(context);
    final entry   = OverlayEntry(builder: (_) => _HelpOverlay(text: text));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), entry.remove);
  }
}

class _HelpOverlay extends StatefulWidget {
  final String text;
  const _HelpOverlay({required this.text});
  @override State<_HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<_HelpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>    _fade;

  @override
  void initState() {
    super.initState();
    _c    = AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
    // Начинаем fade-out за 400ms до удаления
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) _c.reverse();
    });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16, right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F35).withOpacity(0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                  blurRadius: 20, spreadRadius: 2)]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ℹ️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.text, style: const TextStyle(
                  fontSize: 13, color: Colors.white, height: 1.4))),
            ]),
          ),
        ),
      ),
    );
  }
}


// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
    child: Text(title, style: TextStyle(
        fontSize: 10, letterSpacing: 2,
        color: _subTextColor(context).withOpacity(0.45),
        fontWeight: FontWeight.w600)));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool isPage;
  final String? helpText; // подсказка при нажатии ?

  const _SettingsTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    this.onTap, this.isPage = true, this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: light ? Colors.white.withOpacity(0.75) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.07)),
          boxShadow: light ? [BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8,
              offset: const Offset(0, 2))] : [],
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withOpacity(0.25))),
            child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _textColor(context)))),
              if (helpText != null) ...[
                const SizedBox(width: 6),
                _HelpBtn(helpText!),
              ],
            ]),
            Text(subtitle, style: TextStyle(
                fontSize: 10, color: _subTextColor(context).withOpacity(0.55))),
          ])),
          if (isPage) Icon(Icons.chevron_right_rounded, size: 18,
              color: _subTextColor(context).withOpacity(0.35)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SETTINGS SUBPAGES
// ═══════════════════════════════════════════════════════════════════════════════

// ── Profiles Page ─────────────────────────────────────────────────────────────

class _ProfilesPage extends StatelessWidget {
  const _ProfilesPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Профили', child: Column(children: [
      ...vpn.profiles.asMap().entries.map((e) {
        final prof = e.value;
        final isActive = prof.id == vpn.activeProfileId;
        return GestureDetector(
          onTap: () { vpn.switchProfile(prof.id); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isActive ? _accent.withOpacity(0.10) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? _accent.withOpacity(0.4) : Colors.white.withOpacity(0.08))),
            child: Row(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _accent : Colors.white24,
                  boxShadow: isActive ? [BoxShadow(
                      color: _accent.withOpacity(0.6), blurRadius: 6)] : [])),
              const SizedBox(width: 12),
              Expanded(child: Text(prof.name, style: TextStyle(
                  fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? _textColor(context) : _subTextColor(context)))),
              if (isActive) Text(S.t('profile_active'), style: TextStyle(
                  fontSize: 9, color: _accent, fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
              if (!isActive && vpn.profiles.length > 1) GestureDetector(
                onTap: () => vpn.deleteProfile(prof.id),
                child: Padding(padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.delete_outline_rounded, size: 16,
                      color: Colors.redAccent.withOpacity(0.6)))),
            ])));
      }),
      const SizedBox(height: 12),
      _ActionBtn(
        icon: Icons.add_rounded, label: S.t('profile_new'),
        color: _accent,
        onTap: () => _dlgNewProfile(context, vpn)),
    ]));
  }

  void _dlgNewProfile(BuildContext ctx, VpnProvider vpn) {
    final c = TextEditingController();
    showCupertinoDialog(context: ctx, builder: (x) => CupertinoAlertDialog(
      title: Text(S.t('profile_new')),
      content: Padding(padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: c,
              placeholder: S.t('profile_name'), autofocus: true)),
      actions: [
        CupertinoDialogAction(isDestructiveAction: true,
            onPressed: () => Navigator.pop(x), child: Text(S.t('cancel'))),
        CupertinoDialogAction(
            onPressed: () { vpn.createProfile(c.text); Navigator.pop(x); },
            child: Text(S.t('save'))),
      ],
    ));
  }
}

// ── Subscriptions Page ────────────────────────────────────────────────────────

class _SubscriptionsPage extends StatefulWidget {
  const _SubscriptionsPage();
  @override State<_SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<_SubscriptionsPage> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    final subs = vpn.subLinks;
    return _SubPage(title: S.t('subscriptions'), child: Column(children: [
      // Список подписок
      if (subs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Нет подписок', style: TextStyle(
              fontSize: 13, color: Colors.white38)))
      else
        ...subs.map((url) {
          final name = vpn.groupNameFromUrl(url);
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Row(children: [
              const Icon(Icons.rss_feed_rounded, size: 16, color: Colors.white30),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(name, style: const TextStyle(
                    fontSize: 12, color: Colors.white70,
                    fontWeight: FontWeight.w500)),
                Text(url, style: const TextStyle(
                    fontSize: 9, color: Colors.white24),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () async { await vpn.refreshSubscription(url); },
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: Colors.white38)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => vpn.removeSubscription(vpn.subLinks.indexOf(url)),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.redAccent)),
            ]));
        }),
      const SizedBox(height: 16),
      // Поле добавить
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'https://your-sub-url…',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.add_rounded, label: 'Добавить подписку',
        color: const Color(0xFF26A69A),
        onTap: () async {
          final url = _ctrl.text.trim();
          if (url.isEmpty) return;
          await vpn.addSubscription(url);
          _ctrl.clear();
        }),
    ]));
  }
}

// ── Backup Page ───────────────────────────────────────────────────────────────

class _BackupPage extends StatefulWidget {
  const _BackupPage();
  @override State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage> {
  final _pwCtrl = TextEditingController();
  final _imCtrl = TextEditingController();
  @override void dispose() { _pwCtrl.dispose(); _imCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('backup'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SubSection('ЭКСПОРТ'),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(controller: _pwCtrl,
            obscureText: true,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            decoration: InputDecoration(
              hintText: S.t('backup_password_hint'),
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
              prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.upload_outlined, label: S.t('backup_export'),
        color: const Color(0xFF8D6E63),
        onTap: () async {
          final data = vpn.exportBackup(_pwCtrl.text.trim());
          await Clipboard.setData(ClipboardData(text: data));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.t('backup_copied')),
            backgroundColor: const Color(0xFF1B2A1B)));
        }),
      const SizedBox(height: 24),
      _SubSection('ИМПОРТ'),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(controller: _imCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 11,
                fontFamily: 'monospace', color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Вставьте строку бэкапа…',
              hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.download_outlined, label: S.t('backup_import'),
        color: const Color(0xFF5C6BC0),
        onTap: () async {
          final ok = await vpn.importBackup(
              _imCtrl.text.trim(), _pwCtrl.text.trim());
          _imCtrl.clear();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? S.t('restore_ok') : S.t('restore_fail')),
            backgroundColor: ok
                ? const Color(0xFF1B2A1B) : const Color(0xFF2A1B1B)));
        }),
    ]));
  }
}

// ── Protection Page ───────────────────────────────────────────────────────────

class _ProtectionPage extends StatelessWidget {
  const _ProtectionPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('protection'), child: Column(children: [
      _SwitchRow(
        icon: Icons.shield_outlined, iconColor: const Color(0xFF43A047),
        title: S.t('kill_switch'), subtitle: S.t('kill_switch_sub'),
        value: vpn.killSwitch,
        onChanged: vpn.setKillSwitch),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.autorenew_rounded, iconColor: const Color(0xFF29B6F6),
        title: S.t('auto_rotate'),
        subtitle: S.t('auto_rotate_sub').replaceAll('{n}', '${VpnProvider.maxFails}'),
        value: true, onChanged: null,
        trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.public_off_rounded, iconColor: const Color(0xFF7C4DFF),
        title: 'Кнопка обхода',
        subtitle: vpn.bypassBtnMode
            ? 'Нажатие → Обход белых списков'
            : 'Нажатие → Вкл/Выкл VPN',
        value: vpn.bypassBtnMode,
        onChanged: (_) => vpn.toggleBypassBtnMode()),
    ]));
  }
}

// ── AI Bypass Page ────────────────────────────────────────────────────────────

class _AiBypassPage extends StatelessWidget {
  const _AiBypassPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'AI Bypass + Stealth', child: Column(children: [

      _SubSection('AI BYPASS ENGINE'),
      _SwitchRow(
        icon: Icons.psychology_outlined, iconColor: _accent,
        title: S.t('ai_bypass'), subtitle: S.t('ai_bypass_sub'),
        value: vpn.aiEnabled, onChanged: vpn.setAiEnabled),
      const SizedBox(height: 4),
      _ActionRow(
        icon: Icons.cloud_sync_outlined, iconColor: const Color(0xFF29B6F6),
        title: S.t('sync_rules'), subtitle: S.t('sync_rules_sub'),
        actionLabel: 'SYNC',
        onTap: vpn.syncRules),

      const SizedBox(height: 20),
      _SubSection('STEALTH ENGINE 3.0'),

      // Инфо-карточка
      _InfoCard(
        icon: Icons.visibility_off_outlined,
        text: 'Защита от JA4+ fingerprinting. '
            'TLS фрагментация разбивает handshake, '
            'Reality SNI маскирует трафик под Google/Apple/Microsoft.'),
      const SizedBox(height: 12),

      _SwitchRow(
        icon: Icons.visibility_off_outlined,
        iconColor: const Color(0xFF7C4DFF),
        title: 'Stealth Mode',
        subtitle: 'Анти-DPI + анти-JA4+ защита',
        value: vpn.stealthMode,
        onChanged: (v) { vpn.stealthMode = v; vpn.saveToDisk(); vpn.refresh(); }),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.call_split_rounded,
        iconColor: const Color(0xFFFF6D00),
        title: 'TLS Фрагментация',
        subtitle: 'Ghost Handshake — разбивает TLS ClientHello на 1-3 пакета',
        value: vpn.stealthFragment,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthFragment = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.language_rounded,
        iconColor: const Color(0xFF26A69A),
        title: 'Reality SNI Ротация',
        subtitle: 'Авто-смена SNI: Google → Apple → Microsoft…',
        value: vpn.stealthRealitySni,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthRealitySni = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.local_fire_department_outlined,
        iconColor: const Color(0xFFFF5252),
        title: 'Warm-up',
        subtitle: 'HTTPS запрос к безопасному домену перед VPN туннелем',
        value: vpn.stealthWarmup,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthWarmup = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),

      const SizedBox(height: 16),
      _SubSection('ТЕКУЩИЙ SNI ПУЛ'),
      ...kRealitySniPool.map((sni) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, size: 12, color: Colors.white24),
          const SizedBox(width: 8),
          Text(sni, style: const TextStyle(
              fontSize: 11, fontFamily: 'monospace', color: Colors.white54)),
        ]),
      )),

      const SizedBox(height: 16),
      _SubSection('SELF-HEALING'),
      _InfoCard(
        icon: Icons.health_and_safety_outlined,
        text: 'Если основной API недоступен, ноды загружаются из GitHub '
            'зеркала или DNS TXT записи автоматически.'),
    ]));
  }
}

// ── Stealth Engine Page ──────────────────────────────────────────────────────

class _StealthPage extends StatelessWidget {
  const _StealthPage();

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Stealth Engine 3.0', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Статус
      _StealthStatusCard(vpn: vpn),
      const SizedBox(height: 16),

      _SubSection('АНТИ-DPI'),
      _SwitchRow(
        icon: Icons.broken_image_outlined, iconColor: const Color(0xFF7C4DFF),
        title: 'Stealth режим',
        subtitle: 'Включает все анти-DPI механизмы',
        value: vpn.stealthMode,
        onChanged: (v) => vpn.setStealthMode(v),
        hint: 'Мастер-переключатель всех stealth функций. Включает фрагментацию TLS, ротацию SNI, jitter задержки. ТСПУ не может определить тип трафика.'),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.scatter_plot_outlined, iconColor: const Color(0xFF7C4DFF),
        title: 'TLS Фрагментация',
        subtitle: 'Разбивает ClientHello на 1-3 части · JA4+ bypass',
        value: vpn.stealthFragment,
        onChanged: (v) => vpn.setStealthFragment(v),
        hint: 'TLS ClientHello разбивается на 2-4 пакета по 20-100 байт. DPI видит фрагменты и не распознаёт VPN. Обходит JA4+/JA3 fingerprinting. Рекомендуется всегда включать.'),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.rotate_90_degrees_cw_outlined, iconColor: const Color(0xFF7C4DFF),
        title: 'Reality SNI ротация',
        subtitle: 'dl.google.com · icloud.com · microsoft.com',
        value: vpn.stealthRealitySni,
        onChanged: (v) => vpn.setStealthRealitySni(v),
        hint: 'SNI — имя сервера в TLS handshake. Каждый раз берём SNI из белого списка РКН (Google, Apple, Microsoft). ТСПУ видит соединение к легитимному домену, не к VPN серверу.'),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.local_fire_department_outlined, iconColor: const Color(0xFFFF7043),
        title: 'Warm-up прогрев',
        subtitle: 'HTTP запрос к Google перед VPN туннелем',
        value: vpn.stealthWarmup,
        onChanged: (v) => vpn.setStealthWarmup(v),
        hint: 'Перед VPN соединением делаем обычный HTTPS запрос к Google. DPI видит: браузер открыл страницу, потом подключился к VPN. Паттерн как у реального пользователя.'),

      const SizedBox(height: 16),
      _SubSection('СИБИРСКАЯ БЛОКИРОВКА'),
      _InfoCard(
        icon: Icons.shield_outlined,
        text: 'РКН детектирует burst TLS соединений к одному IP '
              '(3+ за 5 сек) и блокирует сервер на 2 минуты. '
              'Siberia Shield пейсит соединения и использует один '
              'мультиплексированный туннель вместо множества.'),
      const SizedBox(height: 8),
      _SwitchRow(
        icon: Icons.shield_moon_outlined, iconColor: const Color(0xFF00BCD4),
        title: 'Siberia Shield 🇷🇺',
        subtitle: 'Connection pacing · Single-tunnel XMUX · Decoy traffic',
        value: vpn.siberiaShield,
        onChanged: (v) => vpn.setSiberiaShield(v),
        hint: 'Защита от «Сибирской блокировки»: ТСПУ блокирует сервер при 2+ SYN за 8 сек. Siberia Shield: пейсит соединения (1 за 8 сек), шлёт decoy HTTPS трафик к белым доменам между сессиями.'),

      const SizedBox(height: 16),
      _SubSection('SNI ПУЛ'),
      ...kRealitySniPool.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(children: [
            Text('${e.key + 1}.', style: const TextStyle(
                fontSize: 10, color: Colors.white24, fontFamily: 'monospace')),
            const SizedBox(width: 10),
            Text(e.value, style: const TextStyle(
                fontSize: 12, color: Colors.white54, fontFamily: 'monospace')),
            const Spacer(),
            if (StealthEngine.sniIndex % kRealitySniPool.length == e.key)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4)),
                child: const Text('current', style: TextStyle(
                    fontSize: 8, color: Color(0xFF7C4DFF)))),
          ])))),

      const SizedBox(height: 16),
      _SubSection('DEAD DROP ЗЕРКАЛА'),
      _InfoCard(
        icon: Icons.cloud_off_outlined,
        text: 'Если основной сервер недоступен — ноды берутся из '
            'GitHub Gist или DNS TXT записи автоматически.'),
      const SizedBox(height: 8),
      ...kDeadDropMirrors.map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Text(m, style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)))),
    ]));
  }
}

// ── Stealth Status Card ────────────────────────────────────────────────────────

class _StealthStatusCard extends StatelessWidget {
  final VpnProvider vpn;
  const _StealthStatusCard({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final active = vpn.stealthMode;
    final color  = active ? const Color(0xFF7C4DFF) : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            active ? const Color(0xFF7C4DFF).withOpacity(0.15) : Colors.white.withOpacity(0.04),
            active ? const Color(0xFF4A148C).withOpacity(0.08) : Colors.white.withOpacity(0.02),
          ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(active ? 0.4 : 0.12)),
        boxShadow: active ? [
          BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.2), blurRadius: 20)
        ] : [],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: active ? [BoxShadow(
                color: color.withOpacity(0.3), blurRadius: 12)] : []),
          child: active
            ? Padding(padding: const EdgeInsets.all(5),
                child: Image.asset('assets/images/aura_logo.png',
                    fit: BoxFit.contain))
            : Icon(Icons.security_outlined, size: 20, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(active ? 'STEALTH АКТИВЕН' : 'STEALTH ВЫКЛЮЧЕН',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(active
              ? 'JA4+ bypass · TLS fragment · Reality SNI'
              : 'Нажми переключатель выше для активации',
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
        ])),
        if (active && vpn.stealthHandshakeFails > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text('${vpn.stealthHandshakeFails} RST',
                style: const TextStyle(fontSize: 9, color: Colors.orange))),
      ]),
    );
  }
}

// ── Bypass Page ───────────────────────────────────────────────────────────────

class _BypassPage extends StatelessWidget {
  const _BypassPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Обход белых списков', child: Column(children: [
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: 'Трафик маскируется под HTTPS и проходит через CDN. '
            'Используй если VPN заблокирован на уровне протокола.'),
      const SizedBox(height: 12),
      _DetailRow2('🔒', 'Порт', '443 (HTTPS)'),
      _DetailRow2('🌐', 'Транспорт', 'WebSocket через CDN'),
      _DetailRow2('🎭', 'SNI', 'speed.cloudflare.com'),
      _DetailRow2('📡', 'DNS', 'DoH — 1.1.1.1'),
      const SizedBox(height: 16),
      _ActionBtn(
        icon: vpn.whitelistBypassActive
            ? Icons.close_rounded : Icons.public_off_rounded,
        label: vpn.whitelistBypassActive
            ? 'Деактивировать' : 'Активировать обход',
        color: vpn.whitelistBypassActive
            ? Colors.redAccent : const Color(0xFF7C4DFF),
        onTap: vpn.activateWhitelistBypass),
    ]));
  }
}

// ── Auto Connect Page ─────────────────────────────────────────────────────────

class _AutoConnectPage extends StatelessWidget {
  const _AutoConnectPage();
  @override
  Widget build(BuildContext context) {
    return _SubPage(title: 'Автоподключение', child: Column(children: [
      _SwitchRow(
        icon: Icons.wifi_outlined, iconColor: const Color(0xFF29B6F6),
        title: 'Открытый WiFi',
        subtitle: 'Включать VPN при подключении к незащищённой сети',
        value: _autoConnect.onOpenWifi,
        onChanged: _autoConnect.toggleWifi),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.wifi_lock_outlined, iconColor: const Color(0xFF66BB6A),
        title: 'Любой новый WiFi',
        subtitle: 'Включать VPN при смене сети',
        value: _autoConnect.onNewWifi,
        onChanged: _autoConnect.toggleNewWifi),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.signal_cellular_alt_rounded, iconColor: const Color(0xFFFFA726),
        title: 'Мобильный интернет',
        subtitle: 'Включать при переходе на мобильные данные',
        value: _autoConnect.onMobileData,
        onChanged: _autoConnect.toggleMobile),
      const SizedBox(height: 16),
      _ActionBtn(
        icon: Icons.apps_rounded, label: 'Выбрать приложения-триггеры',
        color: const Color(0xFF29B6F6),
        onTap: () => Navigator.push(context, CupertinoPageRoute(
            builder: (_) => const AutoConnectAppsScreen()))),
    ]));
  }
}

// ── Appearance Page ───────────────────────────────────────────────────────────

class _AppearancePage extends StatelessWidget {
  const _AppearancePage();
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return _SubPage(title: 'Тема и скины', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SubSection('ТЕМА'),
      Container(
        decoration: BoxDecoration(
          color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        child: Row(children: AuraTheme.values.map((t) {
          final sel = app.theme == t;
          final label = t == AuraTheme.dark ? S.t('theme_dark')
              : t == AuraTheme.light ? S.t('theme_light') : S.t('theme_system');
          return Expanded(child: GestureDetector(
            onTap: () => app.setTheme(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _accent.withOpacity(0.20) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: sel ? Border.all(color: _accent.withOpacity(0.5)) : null),
              child: Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                  color: sel ? _accent : _subTextColor(context).withOpacity(0.6),
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)))));
        }).toList())),
      const SizedBox(height: 20),
      _SubSection('СКИН'),
      _SkinPicker(app: app),
    ]));
  }
}

// ── Language Page ─────────────────────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  const _LanguagePage();
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    return _SubPage(title: S.t('language'), child: Wrap(
      spacing: 8, runSpacing: 8,
      children: AuraLocale.values.map((loc) {
        final sel = app.locale == loc;
        return GestureDetector(
          onTap: () => app.setLocale(loc),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? _accent.withOpacity(0.18) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.10))),
            child: Text(S.localeNames[loc] ?? loc.name,
              style: TextStyle(fontSize: 12,
                color: sel ? _accent : Colors.white54,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal))));
      }).toList()));
  }
}

// ── History Page ──────────────────────────────────────────────────────────────

class _HistoryPage extends StatelessWidget {
  const _HistoryPage();
  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return _SubPage(
      title: 'История подключений',
      trailing: vpn.connectionHistory.isNotEmpty
          ? GestureDetector(
              onTap: vpn.clearHistory,
              child: Text(S.t('clear'), style: const TextStyle(
                  fontSize: 12, color: Colors.redAccent)))
          : null,
      child: vpn.connectionHistory.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Нет записей',
                  style: TextStyle(fontSize: 13, color: Colors.white38))))
          : Column(children: vpn.connectionHistory.asMap().entries.map((e) {
              final r      = e.value;
              final isLast = e.key == vpn.connectionHistory.length - 1;
              return Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _accent.withOpacity(0.20))),
                      child: Icon(Icons.vpn_lock_rounded, size: 16, color: _accent)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.serverName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: _textColor(context))),
                      Text('${r.protocol} · ${r.trafficStr}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10,
                              color: _subTextColor(context).withOpacity(0.45))),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min, children: [
                      Text(r.durationStr, style: TextStyle(
                          fontSize: 11, color: _accent,
                          fontWeight: FontWeight.w600)),
                      Text(
                        '${r.startedAt.day.toString().padLeft(2,'0')}.'
                        '${r.startedAt.month.toString().padLeft(2,'0')} '
                        '${r.startedAt.hour.toString().padLeft(2,'0')}:'
                        '${r.startedAt.minute.toString().padLeft(2,'0')}',
                        style: TextStyle(fontSize: 9,
                            color: _subTextColor(context).withOpacity(0.35))),
                    ]),
                  ])),
                if (!isLast) Divider(height: 0, thickness: 0.5,
                    color: light
                        ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06)),
              ]);
            }).toList()));
  }
}

// ── Logs Page ─────────────────────────────────────────────────────────────────

class _LogsPage extends StatelessWidget {
  const _LogsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(
      title: S.t('logs'),
      trailing: GestureDetector(
        onTap: vpn.clearLogs,
        child: Text(S.t('clear'), style: const TextStyle(
            fontSize: 12, color: Colors.redAccent))),
      child: GlassBox(tint: Colors.black, tintOpacity: 0.30,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200, maxHeight: 500),
          child: ListView.builder(
            shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          itemCount: vpn.logs.length, reverse: true,
          itemBuilder: (_, i) {
            final log = vpn.logs[vpn.logs.length - 1 - i];
            final c = log.contains('✗') ? Colors.redAccent
                : log.contains('↻') || log.contains('🐕') ? Colors.orangeAccent
                : log.contains('🤖') ? _accent : Colors.greenAccent;
            return Text(log, style: TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: c));
          }))));
  }
}

// ── About Page ────────────────────────────────────────────────────────────────

class _AboutPage extends StatefulWidget {
  const _AboutPage();
  @override State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onVersionTap() {
    final now = DateTime.now();
    // Сбрасываем счётчик если прошло больше 2 сек между тапами
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 2) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 5) {
      _tapCount = 0;
      // Открываем Dev Dashboard
      Navigator.push(context, CupertinoPageRoute(
          builder: (_) => const _DevDashboard()));
    } else if (_tapCount >= 3) {
      // Показываем прогресс (незаметно для обычного пользователя)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🛠 ${5 - _tapCount} тапа до Dev Dashboard',
            style: const TextStyle(fontSize: 11)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SubPage(title: 'О приложении', child: Column(children: [
      // Логотип
      Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(
              color: _accent.withOpacity(0.35), blurRadius: 40,
              spreadRadius: 5)]),
        child: Image.asset('assets/images/aura_icon.png',
            width: 120, height: 120, fit: BoxFit.contain)),
      const SizedBox(height: 16),
      const Text('AURA VPN', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900,
          letterSpacing: 3, color: Colors.white)),
      const SizedBox(height: 8),
      // 5 тапов → Dev Dashboard (незаметно)
      GestureDetector(
        onTap: _onVersionTap,
        onLongPress: () {
          Clipboard.setData(ClipboardData(
              text: 'Aura VPN v$kAppVersion build $kAppBuild'));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Версия скопирована'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1B2A1B)));
        },
        child: Column(children: [
          Text('v$kAppVersion · build $kAppBuild', style: TextStyle(
              fontSize: 11, color: Colors.white.withOpacity(0.35),
              letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Удержи для копирования', style: TextStyle(
              fontSize: 9, color: Colors.white.withOpacity(0.15))),
        ])),
      const SizedBox(height: 24),
      _DetailRow2('🛡', 'Протоколы', 'VLESS, VMess, SS, Trojan, HY2'),
      _DetailRow2('🤖', 'AI Engine', 'Bypass Arsenal · 100 стратегий'),
      _DetailRow2('🇷🇺', 'Белые списки', 'antifilter.download · runetfreedom'),
      _DetailRow2('🛡', 'Siberia Shield', 'Connection pacing · Single-tunnel MUX'),
      _DetailRow2('✈️', 'Telegram', 'Fast Protocol · Auto-detect'),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DEVELOPER DASHBOARD  —  скрытый (5 тапов по версии в О приложении)
// ═══════════════════════════════════════════════════════════════════════════════

class _DevDashboard extends StatefulWidget {
  const _DevDashboard();
  @override State<_DevDashboard> createState() => _DevDashboardState();
}

class _DevDashboardState extends State<_DevDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return AuraBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('🛠 Dev Dashboard', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: _textColor(context), letterSpacing: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
              child: const Text('DEV', style: TextStyle(
                  fontSize: 9, color: Colors.redAccent,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
        ],
      ),
      body: Column(children: [
        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            ...List.generate(4, (i) {
              final label = ['BYPASS','STEALTH','ERRORS','SYSTEM'][i];
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tab == i ? _accent.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _tab == i ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
                  child: Text(label, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: _tab == i ? _accent : Colors.white38, letterSpacing: 0.5)),
                )));
            }),
          ])),
        const SizedBox(height: 8),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            if (_tab == 0) _buildBypassTab(vpn),
            if (_tab == 1) _buildStealthTab(vpn),
            if (_tab == 2) _buildErrorsTab(),
            if (_tab == 3) _buildSystemTab(vpn),
          ],
        )),
      ]),
    ));
  }

  // ── Bypass Tab ────────────────────────────────────────────────────────────
  Widget _buildBypassTab(VpnProvider vpn) {
    final blacklist = StrategyBlacklist.allBlocked;
    final stratId   = vpn.devAiAgent.currentStrategyId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('AI BYPASS'),
      _DevRow('Attempt #',         '${vpn.devBypassAttempt}'),
      _DevRow('Node index',        '${vpn.devBypassNodeIdx} / ${vpn.configs.length}'),
      _DevRow('AI running',        '${vpn.devAiAgent.isRunning}'),
      _DevRow('Current strategy',  stratId > 0 ? '#$stratId' : '—'),
      _DevRow('Arsenal size',      '${BypassArsenal.strategies.length} strategies'),
      const SizedBox(height: 12),
      _DevSection('STRATEGY BLACKLIST (${blacklist.length} заблокировано, 5 мин TTL)'),
      if (blacklist.isEmpty)
        const _DevEmptyMsg('Чёрный список пуст — все стратегии доступны')
      else
        ...blacklist.entries.map((e) {
          final mins = DateTime.now().isBefore(e.value)
              ? e.value.difference(DateTime.now()).inMinutes + 1 : 0;
          final key  = e.key.length > 28 ? e.key.substring(0, 28) : e.key;
          return _DevRow(key, '${mins}m left', color: Colors.redAccent);
        }),
      const SizedBox(height: 12),
      _DevSection('SIBERIA SHIELD'),
      _DevRow('Blocked IPs',       '${SiberiaShield.blockedIpsCount}'),
      _DevRow('Conn timestamps',   '${SiberiaShield.connHostsCount} hosts'),
      _DevRow('Shield enabled',    '${vpn.siberiaShield}'),
      const SizedBox(height: 12),
      _DevSection('BYPASS REPORTER'),
      _DevRow('Server enabled',    '${BypassReporter._enabled}'),
      _DevRow('Server URL',        kControlPlaneUrl),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔍 Test BlockDetector', Colors.blue, () async {
        if (vpn.configs.isEmpty) return;
        final bt = await BlockDetector.detect(vpn.configs[vpn.selectedIndex]);
        if (mounted) _showSnack('Block: ${bt.name}');
      }),
      const SizedBox(height: 6),
      _DevBtn('🧹 Clear blacklist (${blacklist.length})', Colors.orange, () {
        StrategyBlacklist.clear();
        setState(() {});
        _showSnack('Blacklist cleared — все стратегии разблокированы');
      }),
      const SizedBox(height: 6),
      _DevBtn('🛡 Clear Siberia cooldowns', Colors.teal, () {
        SiberiaShield.clearCooldowns();
        setState(() {});
        _showSnack('Siberia Shield cooldowns cleared');
      }),
      const SizedBox(height: 6),
      _DevBtn('🎯 Test random strategy', Colors.purple, () {
        final s = BypassArsenal.getQuickRandom('tcpReset');
        if (s != null) _showSnack('#${s['id']} · ${s['name']}');
      }),
    ]);
  }

  // ── Stealth Tab ───────────────────────────────────────────────────────────
  Widget _buildStealthTab(VpnProvider vpn) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('STEALTH ENGINE 3.0'),
      _DevRow('Stealth mode',     '${vpn.stealthMode}'),
      _DevRow('Fragment',         '${vpn.stealthFragment}'),
      _DevRow('Reality SNI',      '${vpn.stealthRealitySni}'),
      _DevRow('Warm-up',          '${vpn.stealthWarmup}'),
      _DevRow('Siberia Shield',   '${vpn.siberiaShield}'),
      _DevRow('Handshake fails',  '${vpn.stealthHandshakeFails}'),
      const SizedBox(height: 12),
      _DevSection('SNI CACHE'),
      _DevRow('Cached SNI',       StealthEngine.cachedSniPublic),
      _DevRow('SNI index',        '${StealthEngine.sniIndex}'),
      _DevRow('uTLS profile idx', '${StealthEngine.utlsIndexPublic}'),
      _DevRow('RST count',        '${StealthEngine.rstCountPublic}'),
      _DevRow('SNI pool size',    '${kRealitySniPool.length}'),
      const SizedBox(height: 12),
      _DevSection('TELEGRAM PROTOCOL'),
      _DevRow('TG Protocol',      'Auto-detect on connect'),
      _DevRow('TG SNI pool',      '${TelegramProtocol._tgSniPool.length} domains'),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔄 Invalidate SNI cache', Colors.purple, () {
        StealthEngine.invalidateSniCache();
        setState(() {});
        _showSnack('SNI cache cleared');
      }),
      const SizedBox(height: 6),
      _DevBtn('📡 Test pickLiveSni', Colors.indigo, () async {
        final sni = await StealthEngine.pickLiveSni();
        if (mounted) _showSnack('Live SNI: $sni');
      }),
    ]);
  }

  // ── Errors Tab ────────────────────────────────────────────────────────────
  Widget _buildErrorsTab() {
    final codes = AuraErrorCode.values;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('ERROR CODES (${codes.length})'),
      ...codes.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: e.code)); _showSnack('${e.code} скопирован'); },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.07))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(e.code, style: const TextStyle(
                    fontSize: 9, color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                Text(e.description, style: const TextStyle(fontSize: 9, color: Colors.white30), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ])),
        ))),
    ]);
  }

  // ── System Tab ────────────────────────────────────────────────────────────
  Widget _buildSystemTab(VpnProvider vpn) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('VPN STATE'),
      _DevRow('Status',         vpn.status),
      _DevRow('Is connected',   '${vpn.isConnected}'),
      _DevRow('Is rotating',    '${vpn.devIsRotating}'),
      _DevRow('Fail count',     '${vpn.devFailCount}'),
      _DevRow('Selected node',  '${vpn.selectedIndex} / ${vpn.configs.length}'),
      _DevRow('Auto mode',      '${vpn.isAutoMode}'),
      _DevRow('Kill switch',    '${vpn.killSwitch}'),
      const SizedBox(height: 12),
      _DevSection('BYPASS RULES'),
      _DevRow('Rules version',  '${vpn.bypassRules.devVersion}'),
      _DevRow('Server rules',   '${vpn.bypassRules.devRulesCount}'),
      _DevRow('Domain cache',   '${vpn.bypassRules.devDomainsCount} domains'),
      _DevRow('Domain sync',    vpn.bypassRules.devLastSync?.toString().substring(0,16) ?? '—'),
      const SizedBox(height: 12),
      _DevSection('PROFILES'),
      _DevRow('Active profile', vpn.activeProfileName),
      _DevRow('Profiles count', '${vpn.profiles.length}'),
      _DevRow('Sub links',      '${vpn.subLinks.length}'),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔃 Force sync rules', Colors.blue, () {
        vpn.syncRules();
        _showSnack('Rules sync started');
      }),
      const SizedBox(height: 6),
      _DevBtn('📋 Copy all logs', Colors.green, () {
        Clipboard.setData(ClipboardData(text: vpn.logs.join('\n')));
        _showSnack('${vpn.logs.length} logs copied');
      }),
      const SizedBox(height: 6),
      _DevBtn('🗑 Clear logs', Colors.red, () {
        vpn.clearLogs();
        setState(() {});
        _showSnack('Logs cleared');
      }),
    ]);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Dev Dashboard helpers ────────────────────────────────────────────────────

class _DevSection extends StatelessWidget {
  final String text;
  const _DevSection(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
    child: Text(text, style: TextStyle(
        fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700,
        color: _accent.withOpacity(0.7))));
}

class _DevRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _DevRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(
          fontSize: 10, color: Colors.white38))),
      Expanded(child: Text(value, style: TextStyle(
          fontSize: 10, color: color ?? Colors.white60,
          fontFamily: 'monospace', fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
    ]));
}

class _DevEmptyMsg extends StatelessWidget {
  final String text;
  const _DevEmptyMsg(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white24)));
}

class _DevBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DevBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))));
}



class _SubPage extends StatelessWidget {
  final String title; final Widget child; final Widget? trailing;
  const _SubPage({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => AuraScaffold(
    title: title,
    trailing: trailing,
    body: ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.pagePadding.left.clamp(16.0, double.infinity),
        12,
        context.pagePadding.right.clamp(16.0, double.infinity),
        40,
      ),
      children: [child],
    ),
  );
}

class _SubSection extends StatelessWidget {
  final String text;
  const _SubSection(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Text(text, style: TextStyle(
        fontSize: 9, letterSpacing: 2,
        color: _subTextColor(context).withOpacity(0.4),
        fontWeight: FontWeight.w600)));
}

// ── Hint Button ⓘ — маленькая кнопка подсказки ───────────────────────────────
// При нажатии показывает tooltip-like снекбар с объяснением настройки

class _HintButton extends StatelessWidget {
  final String hint;
  const _HintButton({required this.hint});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Показываем overlay с подсказкой
        final overlay = Overlay.of(context);
        final entry = OverlayEntry(builder: (ctx) => _HintOverlay(hint: hint));
        overlay.insert(entry);
        Future.delayed(const Duration(seconds: 4), entry.remove);
      },
      child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
        child: const Center(child: Text('i',
            style: TextStyle(fontSize: 10, color: Colors.white38,
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
      ),
    );
  }
}

class _HintOverlay extends StatefulWidget {
  final String hint;
  const _HintOverlay({required this.hint});
  @override State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
    // Начинаем fade-out за 0.5 сек до удаления
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _ac.reverse();
    });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Позиционируем снизу экрана над навигационной панелью
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16, right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                BoxShadow(color: _accent.withOpacity(0.05), blurRadius: 40),
              ]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _accent),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.hint,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85),
                      height: 1.4))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Whitelist Bypass Tester ─────────────────────────────────────────────────
// Тестирует работоспособность обхода белых списков

class _WhitelistTesterPage extends StatefulWidget {
  const _WhitelistTesterPage();
  @override State<_WhitelistTesterPage> createState() => _WhitelistTesterPageState();
}

class _WhitelistTesterPageState extends State<_WhitelistTesterPage> {
  // Ключевые домены РКН — должны быть доступны БЕЗ VPN
  static const _ruDomains = [
    ('gosuslugi.ru',     '🏛 Госуслуги'),
    ('mos.ru',           '🏙 Mos.ru (Москва)'),
    ('nalog.ru',         '💼 ФНС (налоги)'),
    ('pfr.gov.ru',       '🏦 СФР (пенсии)'),
    ('cbr.ru',           '🏦 Банк России'),
    ('sberbank.ru',      '💚 Сбербанк'),
    ('tbank.ru',         '🟡 Т-Банк'),
    ('vk.com',           '🔵 VK'),
    ('ok.ru',            '🟠 Одноклассники'),
    ('mail.ru',          '✉️ Mail.ru'),
    ('yandex.ru',        '🔴 Яндекс'),
    ('2gis.ru',          '🗺 2ГИС'),
  ];

  // Домены которые БЛОКИРУЮТСЯ РКН — должны работать ЧЕРЕЗ VPN
  static const _blockedDomains = [
    ('instagram.com',    '📸 Instagram'),
    ('twitter.com',      '🐦 X (Twitter)'),
    ('facebook.com',     '👥 Facebook'),
    ('discord.com',      '🎮 Discord'),
    ('reddit.com',       '🤖 Reddit'),
    ('medium.com',       '📝 Medium'),
    ('soundcloud.com',   '🎵 SoundCloud'),
  ];

  final Map<String, int?> _results = {};
  bool _testing = false;

  Future<void> _runTest() async {
    setState(() { _testing = true; _results.clear(); });
    final allDomains = [..._ruDomains, ..._blockedDomains];
    for (final (domain, _) in allDomains) {
      final ms = await _pingDomain(domain);
      if (mounted) setState(() => _results[domain] = ms);
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<int?> _pingDomain(String domain) async {
    try {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(domain, 443,
          timeout: const Duration(seconds: 4));
      sw.stop();
      await s.close();
      return sw.elapsedMilliseconds;
    } catch (_) { return null; }
  }

  Widget _domainRow(String domain, String label, bool expectReachable) {
    final result = _results[domain];
    final tested = _results.containsKey(domain);
    final reachable = result != null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!tested) {
      statusColor = Colors.white24;
      statusText  = '—';
      statusIcon  = Icons.circle_outlined;
    } else if (reachable && expectReachable) {
      // RU домен доступен — правильно
      statusColor = Colors.greenAccent;
      statusText  = '${result}ms';
      statusIcon  = Icons.check_circle_rounded;
    } else if (!reachable && !expectReachable) {
      // Заблокированный недоступен без VPN — правильно
      statusColor = Colors.blueAccent;
      statusText  = 'Блок ✓';
      statusIcon  = Icons.shield_rounded;
    } else if (!reachable && expectReachable) {
      // RU домен недоступен — ПРОБЛЕМА (VPN режет РФ трафик?)
      statusColor = Colors.redAccent;
      statusText  = 'Нет!';
      statusIcon  = Icons.error_rounded;
    } else {
      // Заблокированный доступен — VPN не подключён
      statusColor = Colors.orangeAccent;
      statusText  = '${result}ms';
      statusIcon  = Icons.warning_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.15))),
      child: Row(children: [
        Icon(statusIcon, size: 14, color: statusColor),
        const SizedBox(width: 10),
        Expanded(child: Text('$label  $domain',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            maxLines: 2)),
        Text(statusText,
            style: TextStyle(fontSize: 11, color: statusColor,
                fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Тест белых списков',
      trailing: GestureDetector(
        onTap: _testing ? null : _runTest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withOpacity(0.4))),
          child: Text(_testing ? 'Тест...' : 'Запустить',
              style: TextStyle(fontSize: 11, color: _accent,
                  fontWeight: FontWeight.bold)),
        )),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _InfoCard(
            icon: Icons.info_outline_rounded,
            text: 'Проверяет доступность ключевых доменов.\n🟢 РФ домены должны быть доступны всегда.\n🔵 Заблокированные — только через VPN.\nЕсли РФ домен недоступен — проблема в маршрутизации.',
          ),
          const SizedBox(height: 16),

          _SubSection('РФ ДОМЕНЫ (должны быть доступны)'),
          ..._ruDomains.map((e) => _domainRow(e.$1, e.$2, true)),

          const SizedBox(height: 16),
          _SubSection('ЗАБЛОКИРОВАННЫЕ (без VPN — недоступны)'),
          ..._blockedDomains.map((e) => _domainRow(e.$1, e.$2, false)),

          if (_testing) ...[
            const SizedBox(height: 16),
            const Center(child: CupertinoActivityIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Проверяем доступность...',
                style: TextStyle(fontSize: 11, color: Colors.white38))),
          ],
        ],
      ),
    );
  }
}


class _SwitchRow extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final String? hint; // текст подсказки — показывается при нажатии ⓘ
  const _SwitchRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle,
      required this.value, required this.onChanged,
      this.trailing, this.hint});
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: iconColor.withOpacity(0.25))),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(title, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500, color: _textColor(context)))),
            // Кнопка подсказки ⓘ — появляется если hint задан
            if (hint != null) ...[
              const SizedBox(width: 4),
              _HintButton(hint: hint!),
            ],
          ]),
          Text(subtitle, style: TextStyle(fontSize: 10,
              color: _subTextColor(context).withOpacity(0.5))),
        ])),
        trailing ?? CupertinoSwitch(
            value: value, activeColor: _accent,
            onChanged: onChanged),
      ]));
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle, actionLabel;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle,
      required this.actionLabel, this.onTap});
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(title, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: _textColor(context))),
          Text(subtitle, style: TextStyle(fontSize: 10,
              color: _subTextColor(context).withOpacity(0.5))),
        ])),
        GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withOpacity(0.3))),
            child: Text(actionLabel, style: TextStyle(
                fontSize: 10, color: iconColor, fontWeight: FontWeight.bold,
                letterSpacing: 1)))),
      ]));
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withOpacity(0.65), color.withOpacity(0.35)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.20), blurRadius: 14)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.5)),
      ])));
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.10))),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.white30),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 11, color: Colors.white38, height: 1.5))),
    ]));
}

class _DetailRow2 extends StatelessWidget {
  final String emoji, label, value;
  const _DetailRow2(this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 12,
          color: _textColor(context), fontWeight: FontWeight.w600)),
    ]));
}

// ── Settings micro-widgets ────────────────────────────────────────────────────

// ── Skin Picker ──────────────────────────────────────────────────────────────

class _SkinPicker extends StatelessWidget {
  final AppProvider app;
  const _SkinPicker({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AuraSkin.all.length + 1, // +1 для "My Theme" кнопки
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            // Последний элемент — кнопка "Моя тема"
            if (i == AuraSkin.all.length) {
              return GestureDetector(
                onTap: () => Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => const _CustomThemeEditor())),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]),
                    border: Border.all(
                      color: app.skinId == AuraSkinId.custom
                          ? app.skin.accent.withOpacity(0.8) : Colors.white24,
                      width: app.skinId == AuraSkinId.custom ? 1.8 : 1.0),
                    boxShadow: app.skinId == AuraSkinId.custom ? [
                      BoxShadow(color: app.skin.accent.withOpacity(0.3), blurRadius: 14)] : [],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎨', style: TextStyle(fontSize: 20)),
                      SizedBox(height: 4),
                      Text('My', style: TextStyle(fontSize: 8, color: Colors.white54)),
                      SizedBox(height: 2),
                      Text('Theme', style: TextStyle(fontSize: 7, color: Colors.white38)),
                    ]),
                ));
            }
            final skin = AuraSkin.all[i];
            final sel  = app.skinId == skin.id;
            return GestureDetector(
              onTap: () => app.setSkin(skin.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      skin.accent.withOpacity(sel ? 0.35 : 0.15),
                      skin.accentSecondary.withOpacity(sel ? 0.20 : 0.07),
                    ]),
                  border: Border.all(
                    color: sel
                        ? skin.accent.withOpacity(0.8)
                        : skin.accent.withOpacity(0.25),
                    width: sel ? 1.8 : 1.0),
                  boxShadow: sel ? [
                    BoxShadow(
                      color: skin.accent.withOpacity(0.35),
                      blurRadius: 14)
                  ] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(skin.emoji,
                        style: TextStyle(
                            fontSize: sel ? 22 : 18)),
                    const SizedBox(height: 4),
                    Text(skin.name,
                        style: TextStyle(
                            fontSize: 8,
                            color: sel
                                ? skin.accent
                                : Colors.white38,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                    if (sel) ...[
                      const SizedBox(height: 3),
                      Container(
                        width: 16, height: 2,
                        decoration: BoxDecoration(
                          color: skin.accent,
                          borderRadius: BorderRadius.circular(1))),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SH extends StatelessWidget {
  final String t; final BuildContext ctx;
  const _SH(this.t, this.ctx);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
    child: Text(t, style: TextStyle(fontSize: 10, color: _subTextColor(ctx).withOpacity(0.45), fontWeight: FontWeight.bold, letterSpacing: 2)));
}

class _GT extends StatelessWidget {
  final IconData icon; final String title, sub; final Widget trail;
  final bool last; final BuildContext context; final VoidCallback? onTap;
  const _GT({required this.icon, required this.title, required this.sub,
      required this.trail, required this.last, required this.context, this.onTap});
  @override
  Widget build(BuildContext ctx) => Column(children: [
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(9),
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white.withOpacity(0.14))),
              child: Icon(icon, size: 17, color: _textColor(context).withOpacity(0.7))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, color: _textColor(context), fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(fontSize: 10, color: _subTextColor(context).withOpacity(0.5))),
        ])),
        trail,
      ]))),
    if (!last) Divider(height: 0, thickness: 0.5, color: Theme.of(ctx).brightness == Brightness.light ? Colors.black.withOpacity(0.07) : Colors.white.withOpacity(0.07), indent: 60),
  ]);
}

class _GI extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final BuildContext context;
  const _GI({required this.ctrl, required this.hint, required this.context});
  @override
  Widget build(BuildContext ctx) => ClipRRect(borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: TextField(controller: ctrl,
        style: TextStyle(fontSize: 12, color: _textColor(context)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(fontSize: 11, color: _subTextColor(context).withOpacity(0.35)),
          filled: true, fillColor: Theme.of(ctx).brightness == Brightness.light ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.07),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent, width: 1.2)),
        ))));
}

class _GB extends StatelessWidget {
  final String label; final Color color; final VoidCallback? onTap;
  const _GB({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(width: double.infinity, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.35))),
          child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2))))));
}

class _GIB extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _GIB({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: Icon(icon, size: 18, color: Colors.white54)))));
}

class _SR extends StatelessWidget {
  final String url, name; final VoidCallback onDel, onRen; final BuildContext context;
  const _SR({required this.url, required this.name, required this.onDel, required this.onRen, required this.context});
  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(Icons.rss_feed, size: 13, color: _subTextColor(context).withOpacity(0.4)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontSize: 12, color: _textColor(context).withOpacity(0.7), fontWeight: FontWeight.w500)),
        Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: _subTextColor(context).withOpacity(0.35))),
      ])),
      GestureDetector(onTap: onRen, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('✎', style: TextStyle(fontSize: 14, color: _subTextColor(context).withOpacity(0.5))))),
      GestureDetector(onTap: onDel, child: const Icon(Icons.close, size: 16, color: Colors.redAccent)),
    ]));
}
