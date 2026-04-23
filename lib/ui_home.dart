// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

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
            // VLY логотип — PNG с прозрачным фоном, показываем как есть
            SvgPicture.asset('assets/images/vly_logo_clean.svg',
                width: 96, height: 38, fit: BoxFit.contain),
          ]),
          actions: [
            _ABtn(Icons.qr_code_scanner, () => _goQr(context)),
            _ABtn(Icons.add_circle_outline_rounded, () => _showAddMenu(context, vpn)),
            // Кнопка выйти из приложения
            _ABtn(Icons.exit_to_app_rounded, () => _confirmExit(context, vpn)),
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
      PageRouteBuilder(
            pageBuilder: (_, a, __) => const QrScanScreen(),
            transitionsBuilder: (_, a, __, c) => SlideTransition(
              position: Tween(begin: const Offset(0,1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: c)));

  void _confirmExit(BuildContext ctx, VpnProvider vpn) {
    showCupertinoDialog(context: ctx, builder: (x) => CupertinoAlertDialog(
      title: const Text('Выйти из Vly?'),
      content: Text(vpn.isConnected
          ? 'VPN будет отключён' : 'Приложение закроется'),
      actions: [
        CupertinoDialogAction(
            onPressed: () => Navigator.pop(x),
            child: Text(S.t('cancel'))),
        CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(x);
              if (vpn.isConnected) {
                try { await vpn.toggle(); } catch (_) {}
              }
              await Future.delayed(const Duration(milliseconds: 300));
              SystemNavigator.pop();
            },
            child: const Text('Выйти')),
      ],
    ));
  }
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
      child: GlassBox(blur: 32, tint: const Color(0xFF2A0810), tintOpacity: light ? 0.06 : 0.20,
        borderColor: sc.withOpacity(light ? 0.20 : 0.40),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(children: [
            // Power button — с тенью для видимости в светлой теме
            // iOS 26: spring animation кнопка подключения
            _LiquidGlassButton(
              status: vpn.status,
              statusColor: sc,
              isLight: light,
              onTap: () {
                HapticFeedback.mediumImpact();
                vpn.toggle();
              }),
            const SizedBox(height: 14),
            // iOS 26: крупный статус в стиле SF Pro
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(st, key: ValueKey(st),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: sc, letterSpacing: 2.5,
                  shadows: [Shadow(color: sc.withOpacity(0.4), blurRadius: 12)]))),
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
            // Proxy Mode — TUN → SOCKS5 proxy chain
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: vpn.isConnecting ? null : () => vpn.toggleProxyMode(),
                child: AnimatedContainer(duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: vpn.proxyModeEnabled
                        ? const Color(0xFFFF9500).withOpacity(0.20)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: vpn.proxyModeEnabled
                          ? const Color(0xFFFF9500).withOpacity(0.50)
                          : Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shuffle, size: 11,
                        color: vpn.proxyModeEnabled ? const Color(0xFFFF9500) : Colors.white38),
                    const SizedBox(width: 5),
                    Text(
                      vpn.proxyModeEnabled ? 'PROXY CHAIN: ON' : 'PROXY CHAIN: OFF',
                      style: TextStyle(fontSize: 9,
                          color: vpn.proxyModeEnabled
                              ? const Color(0xFFFF9500)
                              : Colors.white38,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.bold),
                    ),
                  ])),
              ),
            ),
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
        DateTime.now().difference(_lastFetch!).inSeconds < 15) return; // обновляем каждые 15с
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
      // ipapi.co disabled (rate limited)
        // 'https://ipapi.co/json/',
      'https://ip-api.com/json/?fields=query,country,countryCode,city,isp',
        'https://freeipapi.com/api/json',
        'https://api.myip.com',
      'https://ipwho.is/',
    ];

    for (final apiUrl in apis) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
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
    ));  // Scaffold
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

  static const _shareChannel = MethodChannel('vly_vpn/share');

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
                onTap: () { Navigator.pop(context); Navigator.push(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => const QrScanScreen(),
            transitionsBuilder: (_, a, __, c) => SlideTransition(
              position: Tween(begin: const Offset(0,1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: c))); },
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
            return RepaintBoundary(child: _NodeTile(
              cfg: e.value, idx: idx,
              isLast: e.key == nodes.length - 1,
              vpn: vpn,
              onRename: () => _dlgNodeStatic(ctx, vpn, idx)));
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
  static const _appsChannel = MethodChannel('vly_vpn/apps');

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
  static const _appsChannel = MethodChannel('vly_vpn/apps');

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
      await const MethodChannel('vly_vpn/share')
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

// ─────────────────────────────────────────────────────────────────────────────
//  iOS 26 LIQUID GLASS BUTTON — кнопка подключения
// ─────────────────────────────────────────────────────────────────────────────
class _LiquidGlassButton extends StatefulWidget {
  final String status;
  final Color statusColor;
  final bool isLight;
  final VoidCallback onTap;
  const _LiquidGlassButton({
    required this.status, required this.statusColor,
    required this.isLight, required this.onTap});
  @override State<_LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<_LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 500));
    // Spring back — iOS 26 signature feel
    _scaleAnim = Tween(begin: 1.0, end: 0.87).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeIn,
            reverseCurve: Curves.elasticOut));
  }

  @override void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sc = widget.statusColor;
    final light = widget.isLight;
    final connected  = widget.status == 'CONNECTED';
    final connecting = widget.status == 'CONNECTING';

    return GestureDetector(
      onTapDown: (_) { _anim.forward(); HapticFeedback.mediumImpact(); },
      onTapUp:   (_) { _anim.reverse(); widget.onTap(); },
      onTapCancel: () => _anim.reverse(),
      child: AnimatedBuilder(animation: _scaleAnim,
        builder: (_, __) => Transform.scale(scale: _scaleAnim.value,
          child: SizedBox(width: 110, height: 110,
            child: Stack(alignment: Alignment.center, children: [

              // Outer glow ring (iOS 26 signature)
              AnimatedContainer(
                duration: const Duration(milliseconds: 600), curve: Curves.easeOut,
                width: 110, height: 110,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: sc.withOpacity(connected ? 0.55 : 0.22),
                      blurRadius: connected ? 50 : 22),
                  BoxShadow(color: sc.withOpacity(connected ? 0.22 : 0.08),
                      blurRadius: connected ? 90 : 45),
                ])),

              // Liquid Glass core — translucent + refraction
              ClipOval(child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600), curve: Curves.easeOut,
                  width: 104, height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4), radius: 1.0,
                        colors: light
                            ? [Colors.white.withOpacity(0.85),
                               sc.withOpacity(0.15),
                               sc.withOpacity(0.05)]
                            : [Colors.white.withOpacity(connected ? 0.24 : 0.15),
                               sc.withOpacity(connected ? 0.20 : 0.09),
                               Colors.black.withOpacity(0.22)]),
                    border: Border.all(
                        color: sc.withOpacity(light ? 0.72 : 0.50), width: 1.5)),
                  child: Stack(children: [
                    // iOS 26 specular highlight — полоска света сверху
                    Positioned(top: 10, left: 20, right: 46, child: Container(height: 1.2,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            gradient: LinearGradient(colors: [
                              Colors.white.withOpacity(light ? 0.95 : 0.65),
                              Colors.transparent])))),
                    // Icon / Spinner
                    Center(child: connecting
                        ? SizedBox(width: 36, height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: sc,
                                backgroundColor: sc.withOpacity(0.2)))
                        : Icon(
                            connected ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                            size: 44, color: sc,
                            shadows: [Shadow(color: sc.withOpacity(0.6), blurRadius: 20)])),
                  ])
                ))),

            ])))));
  }
}
