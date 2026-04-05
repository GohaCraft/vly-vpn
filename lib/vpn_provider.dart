// ignore_for_file: unused_import, unused_element
part of 'main.dart';

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

  // ── Proxy Chain (DerevVPN-style) — TUN → SOCKS5 → VPN ─────────────────────
  bool   proxyModeEnabled       = false;  // выключен по умолчанию
  int    proxyPort              = 1080;   // локальный SOCKS5 порт
  String proxyModeStatus       = 'OFF';   // статус для UI

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
      await p.setBool('proxy_mode',          proxyModeEnabled);
      await p.setInt('proxy_port',           proxyPort);
      await p.setBool('proxy_mode',          proxyModeEnabled);
      await p.setInt('proxy_port',           proxyPort);
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
      proxyModeEnabled  = p.getBool('proxy_mode')          ?? false;
      proxyPort         = p.getInt('proxy_port')           ?? 1080;
      proxyModeEnabled  = p.getBool('proxy_mode')          ?? false;
      proxyPort         = p.getInt('proxy_port')           ?? 1080;
    } catch (_) {}
  }


  

  // ── Публичные методы (вызываются из UI) ──────────────────────────────────
  void refresh()               { _notify(); }
  String get activeProfileName => _prof.name;
  bool get isConnecting        => status == 'CONNECTING';

  // ── Proxy Chain — публичные методы ────────────────────────────────────────
  void toggleProxyMode() {
    proxyModeEnabled = !proxyModeEnabled;
    proxyModeStatus = proxyModeEnabled ? 'TUN → SOCKS5:$proxyPort → VPN' : 'OFF';
    _saveStealthPrefs();
    _notify();
    _log(proxyModeEnabled ? '🔀 Proxy Chain ENABLED: TUN → SOCKS5:$proxyPort → VPN'
                          : '🔀 Proxy Chain DISABLED');
  }

  void setProxyPort(int port) {
    if (port >= 1024 && port <= 65535) {
      proxyPort = port;
      proxyModeStatus = proxyModeEnabled ? 'TUN → SOCKS5:$proxyPort → VPN' : 'OFF';
      _saveStealthPrefs();
      _notify();
    }
  }
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
