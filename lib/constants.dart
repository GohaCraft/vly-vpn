// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
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
// Порядок: сначала Яндекс/VK (белый список РКН) → потом GitHub → DNS TXT
const List<String> kDeadDropMirrors = [
  // ── Tier 0: Яндекс — всегда белый список РКН (AS13238) ───────────────────
  // storage.yandexcloud.net: S3-совместимое Object Storage, Яндекс CDN
  // Не блокируется т.к. используется тысячами российских сайтов
  'https://storage.yandexcloud.net/auravpn-nodes/nodes.json',
  // Яндекс Диск public link (через get.disk.yandex.net — белый список)
  'https://getfile.dokpub.com/yandex/get/https://disk.yandex.ru/d/auravpn-nodes',

  // ── Tier 1: VK — крупнейшая российская соцсеть (AS47541) ─────────────────
  // userapi.com / vk.com CDN — блокировка означает падение ВКонтакте
  'https://vk.com/doc-auravpn_nodes',             // VK Documents (публичный)
  'https://sun6-21.userapi.com/auravpn/nodes.json', // VK CDN edge

  // ── Tier 2: GitHub (международный, может быть заблокирован) ──────────────
  'https://raw.githubusercontent.com/auravpn/nodes/main/nodes.json',
  'https://gist.githubusercontent.com/auravpn/nodes/raw/nodes.json',

  // ── Tier 3: jsDelivr CDN — зеркало GitHub через CDN ─────────────────────
  // jsDelivr использует Cloudflare + Fastly — сложнее заблокировать
  'https://cdn.jsdelivr.net/gh/auravpn/nodes@main/nodes.json',

  // DNS TXT: dig TXT nodes.auravpn.app — содержит base64 списка нод
];
const String kDeadDropDnsTxt = 'nodes.auravpn.app';

// Reality SNI пул — высокоавторитетные домены (в белом списке РКН)
// SNI-пул актуализирован 28.03.2026
// Источник: анализ CIDR белых списков ТСПУ + net4people/bbs #490 + XTLS/Xray-examples
// Критерии: (1) IP в CIDR-whitelist РКН, (2) TLS1.3 + поддержка REALITY, (3) не блокируется в РФ
// ВАЖНО: dest и serverName должны совпадать — XTLS-Vision требует реального TLS с этого сервера
const List<String> kRealitySniPool = [
  // ── Tier 0: ЯНДЕКС — 100% белый список РКН (AS13238, 77.88.0.0/18) ──────
  // Самый надёжный выбор для России — Яндекс никогда не блокируется
  'www.yandex.ru',               // Яндекс главная — иконический российский домен
  'mail.yandex.ru',              // Яндекс Почта — корпоративный whitelist
  'yastatic.net',                // Яндекс Static CDN — используется тысячами сайтов
  'storage.yandexcloud.net',     // Яндекс Object Storage S3 — корпоративный трафик
  'api.browser.yandex.com',      // Яндекс Браузер API — высокий трафик

  // ── Tier 1: VK / MAIL.RU GROUP (AS47541, 87.240.128.0/18) ───────────────
  // Блокировка VK = социальный коллапс → ТСПУ никогда не тронет
  'vk.com',                      // ВКонтакте — крупнейшая соцсеть РФ
  'userapi.com',                 // VK CDN — медиа контент всех пользователей
  'mail.ru',                     // Mail.ru — почта, белый список
  'ok.ru',                       // Одноклассники — белый список

  // ── Tier 2: MICROSOFT — крупнейший CIDR whitelist (20.112.0.0/13) ────────
  'www.microsoft.com',           // Рекомендован XTLS-examples для России/Ирана
  'login.microsoft.com',         // Microsoft Login — высокий корпоративный трафик
  'login.microsoftonline.com',   // Azure AD OAuth — в белом списке РКН
  'update.microsoft.com',        // Windows Update — критически важен для РКН
  'office.com',                  // Microsoft Office Online
  'teams.microsoft.com',         // Microsoft Teams — корпоративный, всегда whitelist

  // ── Tier 3: APPLE — iCloud всегда доступен (17.0.0.0/8) ──────────────────
  'www.apple.com',               // Рекомендован XTLS/Xray-examples как dest
  'gateway.icloud.com',          // iCloud Gateway — Private Relay IP
  'mask.icloud.com',             // iCloud Private Relay — надёжный SNI
  'swscan.apple.com',            // Apple Software Updates — corporate whitelist

  // ── Tier 4: GOOGLE — максимальный трафик (142.250.0.0/15) ────────────────
  'dl.google.com',               // Google Download CDN
  'www.gstatic.com',             // Google Static — connectivitycheck хост
  'accounts.google.com',         // Google Auth
  'play.googleapis.com',         // Google Play

  // ── Tier 5: CLOUDFLARE — крупнейший CDN (104.16.0.0/13) ─────────────────
  'www.cloudflare.com',          // Cloudflare главная
  'speed.cloudflare.com',        // Cloudflare Speed Test — в whitelist

  // ── Tier 6: AMAZON AWS — глобальный CDN (205.251.0.0/17) ─────────────────
  'www.amazon.com',              // Рекомендован XTLS/Xray-examples
  'd1.awsstatic.com',            // AWS Static CDN

  // ── Tier 7: MOZILLA — Firefox в корпоративных whitelist ──────────────────
  'addons.mozilla.org',          // Firefox Addons
  'aus5.mozilla.org',            // Firefox Auto-Update
];

// CDN Workers URL для финального fallback
// Трафик идёт через Cloudflare CDN — блокировка означает блокировку половины интернета
const List<String> kCdnFallbackUrls = [
  'https://aura-vpn.workers.dev',  // Cloudflare Workers
  'https://aura-cdn.pages.dev',    // Cloudflare Pages
];

// ── Hysteria2 настройки по умолчанию ────────────────────────────────────────
// Hysteria2 использует QUIC (UDP) — ТСПУ плохо фильтрует UDP трафик
// Salamander: XOR обфускация QUIC пакетов — скрывает Hysteria fingerprint
// Порт 443 — выглядит как QUIC/HTTP3 (Chrome, YouTube используют QUIC)
const kHysteria2Defaults = {
  'obfs':           'salamander',  // обфускация протокола
  'obfsPassword':   '',            // заполняется из конфига ноды
  'sni':            '',            // заполняется из SNI пула
  'insecure':       false,         // не использовать без крайней нужды
  'fastOpen':       true,          // TFO — ускоряет переподключения
  'lazy':           false,         // не ленивое — сразу устанавливаем туннель
  'bandwidth': {
    'up':   '50 mbps',
    'down': '200 mbps',
  },
};

// ── Zapret интеграция ────────────────────────────────────────────────────────
// Zapret — локальный инструмент обхода DPI (не VPN, работает на сетевом уровне)
// Используется как ДОПОЛНЕНИЕ к VPN когда ТСПУ активно блокирует TLS handshake
// Режимы: fake_sni (подмена SNI) + disorder (переупорядочивание пакетов)
// Источник: github.com/bol-van/zapret
const kZapretConfig = {
  'enabled':     false,            // по умолчанию выключен — только если VPN упал
  'httpPort':    1080,             // локальный SOCKS5 порт Zapret
  'strategies': [
    'fake_sni',     // подменяет SNI в ClientHello → ТСПУ видит разрешённый домен
    'disorder',     // переупорядочивает TLS пакеты → DPI не собирает fingerprint
    'split',        // split TLS ClientHello → аналог fragment в Xray
    'ttl_trick',    // TTL=5 для первого пакета → ТСПУ не видит, сервер видит
  ],
  'fakeSniFallback': 'www.yandex.ru',  // SNI для подмены — Яндекс всегда в whitelist
};

// Zapret/GoodbyeDPI локальный порт (запускается отдельно на устройстве)
const int    kZapretLocalPort     = 1080;  // SOCKS5 порт Zapret
const String kZapretDefaultSni    = 'www.microsoft.com'; // SNI для fake_sni стратегии


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
const String kBackupMagic       = 'VLY_VPN_BACKUP_V1';

// ─── COLORS ──────────────────────────────────────────────────────────────────

// ── Версия приложения ────────────────────────────────────────────────────────
const kAppVersion = '6.3.0';
const kAppBuild   = '20260414';

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
  // Chrome 137 Mobile (март 2026) — актуальные JA4+ fingerprint не под блокировкой
  'Mozilla/5.0 (Linux; Android 15; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.48 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.48 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.55 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; SM-A556B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.48 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; Redmi Note 13 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.48 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 13; POCOF5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.55 Mobile Safari/537.36',
  // Chrome 136 — запасной (менее новый но работает)
  'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.125 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.125 Mobile Safari/537.36',

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