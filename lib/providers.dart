// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class AppProvider extends ChangeNotifier {
  VlyTheme  _theme  = VlyTheme.system;
  VlyLocale _locale = VlyLocale.en;
  VlySkinId _skinId = VlySkinId.crimson;
  bool _disposed = false;

  // Пользовательская тема
  Color  _customAccent     = const Color(0xFF00E5FF);
  Color  _customAccent2    = const Color(0xFF4FC3F7);
  Color  _customBg         = const Color(0xFF050610);
  Color  _customBlob1      = const Color(0xFF1A237E);
  Color  _customBlob2      = const Color(0xFF0D47A1);
  String _customMediaPath  = ''; // путь к фото/GIF
  String _customMediaType  = ''; // 'photo' | 'gif' | ''

  VlyTheme  get theme  => _theme;
  VlyLocale get locale => _locale;
  VlySkinId get skinId => _skinId;
  VlySkin   get skin   => _skinId == VlySkinId.custom ? _buildCustomSkin() : VlySkin.byId(_skinId);
  
  // Custom theme getters
  Color  get customAccent    => _customAccent;
  Color  get customAccent2   => _customAccent2;
  Color  get customBg        => _customBg;
  Color  get customBlob1     => _customBlob1;
  Color  get customBlob2     => _customBlob2;
  String get customMediaPath => _customMediaPath;
  String get customMediaType => _customMediaType;
  bool   get hasCustomMedia  => _customMediaPath.isNotEmpty && File(_customMediaPath).existsSync();

  VlySkin _buildCustomSkin() => VlySkin(
    id: VlySkinId.custom,
    name: 'My Theme',
    emoji: '🎨',
    accent: _customAccent,
    accentSecondary: _customAccent2,
    bgDark: _customBg,
    blobs: [_customBlob1, _customBlob2, _customAccent, _customAccent2],
  );

  ThemeMode get themeMode {
    switch (_theme) {
      case VlyTheme.dark:   return ThemeMode.dark;
      case VlyTheme.light:  return ThemeMode.light;
      case VlyTheme.system: return ThemeMode.system;
    }
  }

  AppProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final ts  = p.getString('vly_theme') ?? 'system';
    final sid = p.getString('vly_skin')  ?? 'crimson';
    _theme  = VlyTheme.values.firstWhere((e) => e.name == ts,  orElse: () => VlyTheme.system);
    _skinId = VlySkinId.values.firstWhere((e) => e.name == sid, orElse: () => VlySkinId.crimson);
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

  Future<void> setTheme(VlyTheme t) async {
    _theme = t;
    final p = await SharedPreferences.getInstance();
    await p.setString('vly_theme', t.name);
    _safeNotify();
  }

  Future<void> setSkin(VlySkinId id) async {
    _skinId = id;
    _applySkin(skin); // skin getter уже учитывает custom
    final p = await SharedPreferences.getInstance();
    await p.setString('vly_skin', id.name);
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
    _skinId = VlySkinId.custom;
    _applySkin(_buildCustomSkin());
    final p = await SharedPreferences.getInstance();
    await p.setInt('ct_accent',   _customAccent.value);
    await p.setInt('ct_accent2',  _customAccent2.value);
    await p.setInt('ct_bg',       _customBg.value);
    await p.setInt('ct_blob1',    _customBlob1.value);
    await p.setInt('ct_blob2',    _customBlob2.value);
    await p.setString('ct_media_path', _customMediaPath);
    await p.setString('ct_media_type', _customMediaType);
    await p.setString('vly_skin', 'custom');
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

  Future<void> setLocale(VlyLocale l) async {
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

class VlyProfile {
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

  VlyProfile({
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
    this.subUserAgent     = 'VlyVPN/$kAppVersion/Android',
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

  factory VlyProfile.fromJson(Map<String, dynamic> j) => VlyProfile(
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
    subUserAgent: j['subUserAgent'] ?? 'VlyVPN/$kAppVersion/Android',
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