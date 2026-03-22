// ignore_for_file: unused_import, unused_element
part of 'main.dart';

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

