// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class VpnProvider extends ChangeNotifier {
  late FlutterV2ray _v2ray;
  bool _disposed = false;
  bool get mounted => !_disposed;

  // ── VPN Detection Shield ───────────────────────────────────────────────────
  // Случайный SOCKS5-порт на каждый запуск приложения — против scan-based
  // детекции (сканирование localhost-портов). Порт выбирается ОДИН раз при
  // старте; ротация «на лету» не применяется (рвала бы активное соединение).
  // (Убран мёртвый блок getActiveProxyPort/startPortRotation — не вызывался и
  //  вводил в заблуждение комментарием про «ротацию каждые 90с».)
  static final int    _secureProxyPort = 10000 + (DateTime.now().millisecondsSinceEpoch % 55535);
  static final String _sessionKey      =
      (DateTime.now().millisecondsSinceEpoch ^ 0xDEADBEEF).toRadixString(36) +
      (DateTime.now().microsecond * 31337).toRadixString(16);

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
  bool   perAppBypass           = true;   // пер-сервисный обход (TG/YT/TikTok…)
  int    stealthHandshakeFails  = 0;      // счётчик провалов handshake
  String stealthStatus          = '';     // статус для UI
  bool   _userInitiatedStop     = false;  // true = отключил пользователь (не обрыв)
  int    _killSwitchReconnects  = 0;      // счётчик авто-реконнектов при обрыве

  // ── Proxy Chain (DerevVPN-style) — TUN → SOCKS5 → VPN ─────────────────────
  bool   proxyModeEnabled       = false;  // выключен по умолчанию
  int    proxyPort              = 1080;   // локальный SOCKS5 порт
  String proxyModeStatus       = 'OFF';   // статус для UI

  // ── App Store Obfuscation (05.04.2026) ─────────────────────────────────────
  // Apple удалила 20+ VPN из App Store РФ. Скрываем VPN-название приложения.
  bool   appStoreStealth        = false;
  // Режим обхода — выбирается пользователем в настройках
  BypassMode bypassMode = BypassMode.auto;  // скрыть VPN-ключевые слова из UI
  String stealthAppName        = 'Vly';  // нейтральное название приложения

  // ── App Store Obfuscation (05.04.2026) ─────────────────────────────────────
  // Apple удалила 20+ VPN из App Store РФ. Скрываем VPN-название приложения.

  // ── Трафик (v4.0) ─────────────────────────────────────────────────────────
  int    trafficUp   = 0; // bytes/s текущая скорость
  int    trafficDown = 0;
  int    totalUp     = 0; // bytes total сессия
  int    totalDown   = 0;
  Duration sessionDuration = Duration.zero;
  DateTime? _connectedAt;
  Timer?  _trafficTimer;
  Timer?  _saveDebounce;   // дебаунс записи на диск (см. saveToDisk/saveNow)
  Timer?  _rulesSyncTimer; // периодическая синхронизация bypass-правил с сервером

  // ── История подключений (v4.0) ────────────────────────────────────────────
  List<ConnectionRecord> connectionHistory = [];

  // ── Профили (v3.0) ────────────────────────────────────────────────────────
  List<VlyProfile> profiles      = [];
  String            activeProfileId = '';

  // ── Текущий профиль — удобные геттеры ─────────────────────────────────────
  VlyProfile get _prof {
    if (profiles.isEmpty) { _ensureDefaultProfile(); }
    return profiles.firstWhere((p) => p.id == activeProfileId,
        orElse: () => profiles.first);
  }

  List<VpnConfig>       get configs   => _configs;
  List<String>          get subLinks  => _prof.subLinks;
  Map<String, String>   get subNames  => _prof.subNames;
  bool get killSwitch   => _prof.killSwitch;
  bool get aiEnabled    => _prof.aiEnabled;
  bool get telemetryEnabled => _prof.telemetryEnabled;
  AppUpdate? get updateAvailable => UpdateChecker.available;
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
  static const int      maxFails        = 2;
  // FIX: 9с слишком мало — pacing+warmup+SNI может занять до 15 сек
  // Увеличено до 30с — это реальный timeout для VPN подключения
  static const Duration _watchdogTimeout = Duration(seconds: 8);

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
    if (sourceUrl == 'server')  return 'Vly Servers';
    if (sourceUrl == 'other')   return 'Other';
    if (subNames.containsKey(sourceUrl)) return subNames[sourceUrl]!;
    try { return Uri.parse(sourceUrl).host.replaceAll('www.', ''); }
    catch (_) { return sourceUrl; }
  }

  // ── Constructor ───────────────────────────────────────────────────────────

  VpnProvider() {
    _bypassRules = BypassRulesEngine();
    _aiAgent     = AiBypassAgent(_log);
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
        _killSwitchReconnects = 0;
        _cancelWd();
        _connectedAt = DateTime.now();
        _startTrafficTimer();
        // Real-time мониторинг здоровья обходов — мгновенный детект отключения.
        if (perAppBypass) {
          BypassHealthMonitor.reset();
          BypassHealthMonitor.start(log: _log, onServicesDown: _onBypassDown);
        }
        final nodeName = (_configs.isNotEmpty && selectedIndex < _configs.length)
            ? _configs[selectedIndex].displayName : 'Vly';
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
        BypassHealthMonitor.stop();
        _dismissPersistentNotif();                       // убрать постоянное уведомление
        Future.delayed(const Duration(seconds: 2), () => _ipCheck.fetchCurrent(force: true)); // обновить IP
        _updateTile(active: false);                      // обновить тайл
        if (prev == 'CONNECTING' && !_isRotating) {
          _failCount++;
          _log('⚠ Fail #$_failCount/$maxFails');
          if (_failCount >= maxFails) _scheduleBypass();
        }
        if (prev == 'CONNECTED') {
          // Неожиданный обрыв (не ручное отключение). При включённом Kill Switch
          // окно, пока туннель упал, = утечка реального IP. Минимизируем его —
          // авто-реконнект к текущей ноде. Ограничено 3 попытками, чтобы не зациклить;
          // если не вышло — дальше включается обычная failover-логика (_failCount).
          if (!_userInitiatedStop && killSwitch && _configs.isNotEmpty &&
              _killSwitchReconnects < 3 && !_isRotating) {
            _killSwitchReconnects++;
            _log('🛡 Kill Switch: обрыв туннеля — авто-реконнект #$_killSwitchReconnects/3');
            Future.delayed(const Duration(milliseconds: 700), () {
              if (!_disposed && !_userInitiatedStop && !isConnected) _connectCurrent();
            });
          } else {
            _sendNotification('🔓 VPN отключён', 'Сессия завершена');
          }
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
    _rulesSyncTimer?.cancel();
    _logDebounce?.cancel();
    // Флаш отложенной записи, чтобы не потерять последние изменения настроек.
    if (_saveDebounce?.isActive ?? false) { _saveDebounce!.cancel(); saveNow(); }
    super.dispose();
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  // ── Stealth Engine 2.0 — публичные setters ────────────────────────────────
  void setStealthMode(bool v)       { stealthMode       = v; _saveStealthPrefs(); _notify(); }
  void setStealthFragment(bool v)   { stealthFragment   = v; _saveStealthPrefs(); _notify(); }
  void setStealthRealitySni(bool v) { stealthRealitySni = v; _saveStealthPrefs(); _notify(); }
  void setStealthWarmup(bool v)     { stealthWarmup     = v; _saveStealthPrefs(); _notify(); }
  void setSiberiaShield(bool v)     { siberiaShield     = v; _saveStealthPrefs(); _notify(); }
  void setPerAppBypass(bool v)      { perAppBypass      = v; _saveStealthPrefs(); _notify(); }

  Future<void> _saveStealthPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('stealth_mode',        stealthMode);
      await p.setBool('stealth_fragment',    stealthFragment);
      await p.setBool('stealth_reality_sni', stealthRealitySni);
      await p.setBool('stealth_warmup',      stealthWarmup);
      await p.setBool('siberia_shield',      siberiaShield);
      await p.setBool('per_app_bypass',      perAppBypass);
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
      perAppBypass      = p.getBool('per_app_bypass')      ?? true;
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
  void setTelemetryEnabled(bool v) {
    _prof.telemetryEnabled = v;
    Telemetry.configure(enabled: v);   // мгновенно применяем (и чистим очередь при выкл)
    saveToDisk(); _notify();
  }
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
    if (logs.length > 300) logs.removeRange(0, logs.length - 300);
    // Debounce: обновляем UI не чаще чем раз в 100ms
    _logDebounce?.cancel();
    _logDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) notifyListeners();
    });
  }

  // Возвращает весь лог одной строкой — для кнопки "Копировать лог"
  String getAllLogs() {
    final header = '=== VLY LOG ===\n'
        'Version: $kAppVersion build $kAppBuild\n'
        'Nodes: ${_configs.length} | Selected: $selectedIndex\n'
        'Status: $status | AI: $aiStatus\n'
        '====================\n';
    return header + logs.join('\n');
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

  static const _notifChannel  = MethodChannel('vly_vpn/notifications');
  static const _tileChannel   = MethodChannel('vly_vpn/tile');
  static const _cmdChannel    = MethodChannel('vly_vpn/commands');
  // Публичный доступ для _CustomThemeEditorState
  static const cmdChannel = _cmdChannel;

  Future<void> _sendNotification(String title, String body) async {
    try {
      await _notifChannel.invokeMethod('show', {'title': title, 'body': body});
    } catch (_) {}
  }

  // Открыть системный экран VPN, где включается настоящий kill switch Android
  // (Always-on VPN + «блокировать соединения без VPN»). Возвращает true, если
  // открылся именно VPN-экран; false — если только общие настройки (нет экрана).
  Future<bool> openSystemVpnSettings() async {
    try {
      final ok = await const MethodChannel('vly_vpn/share')
          .invokeMethod<bool>('openVpnSettings');
      return ok ?? false;
    } catch (e) {
      _log('⚠ openVpnSettings: $e');
      return false;
    }
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
  Future<void> _updateTile({required bool active, String server = 'Vly'}) async {
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
    // NewsAwareness.load() — disabled (no server)
    _setupCommandChannel();
    _ipCheck.fetchReal();
    await _loadStealthPrefs();
    // _autoConnect.load() - disabled
    // Долговременная память ИИ: победители по классам сетей + блеклист.
    AiMemory.load();
    // Анонимная диагностика (opt-in): применяем сохранённый выбор пользователя.
    Telemetry.init().then((_) => Telemetry.configure(enabled: _prof.telemetryEnabled));
    // Проверка обновлений (sideload → авто-апдейта нет). При наличии — покажем.
    UpdateChecker.check().then((u) { if (u != null && !_disposed) _notify(); });
    // Серверно-обновляемый AI-каскад (blueprint §4b): грузим кэш, тянем свежую.
    MutationRegistry.load().then((_) => MutationRegistry.syncFromServer(_log));
    _bypassRules.syncFromServer(_log).then((_) => _notify());
    // Периодическое обновление стратегий обхода с сервера (без апдейта app).
    // Раньше правила тянулись только один раз при старте. Теперь — раз в час,
    // чтобы серверный «мозг» мог подкидывать свежие методы на лету.
    _rulesSyncTimer?.cancel();
    _rulesSyncTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (_disposed) return;
      _bypassRules.syncFromServer(_log).then((_) { if (!_disposed) _notify(); });
      MutationRegistry.syncFromServer(_log); // + свежие mutation-программы
    });
    // Синхронизируем статистику стратегий с сервером (фоново)
    // NewsAwareness.syncFromServer disabled (no server configured)
    _fetchServerNodes();
  }

  // ── Profiles (v3.0) ──────────────────────────────────────────────────────

  void _ensureDefaultProfile() {
    if (profiles.isEmpty) {
      final def = VlyProfile(id: 'default', name: 'Default', splitMode: SplitTunnelMode.bypass);
      profiles = [def];
      activeProfileId = def.id;
    }
  }

  Future<void> createProfile(String name) async {
    final trimmed = name.trim().isEmpty ? 'Profile' : name.trim();
    final limited = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;
    final p = VlyProfile(id: VlyProfile._uid(), name: limited);
    profiles.add(p);
    await saveNow(); _notify();
  }

  Future<void> switchProfile(String id) async {
    if (!profiles.any((p) => p.id == id)) return;
    // Сохраняем текущие конфиги в профиль
    _prof.configsJson = _configs.map((c) => c.toMap()).toList();
    activeProfileId = id;
    // Загружаем конфиги нового профиля
    _configs = List<VpnConfig>.from(_prof.configsJson
        .map((m) { try { return VpnConfig.fromMap(m); } catch (_) { return null; } })
        .whereType<VpnConfig>());
    if (selectedIndex >= _configs.length) selectedIndex = 0;
    await saveNow(); _notify();
  }

  Future<void> deleteProfile(String id) async {
    if (profiles.length <= 1) return; // нельзя удалить единственный профиль
    profiles.removeWhere((p) => p.id == id);
    if (activeProfileId == id) activeProfileId = profiles.first.id;
    await saveNow(); _notify();
  }

  Future<void> renameProfile(String id, String newName) async {
    final p = profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
    p.name = newName.trim().isEmpty ? 'Profile' : newName.trim();
    await saveNow(); _notify();
  }

  // ── Split Tunnel (v3.0) ──────────────────────────────────────────────────

  Future<void> setSplitMode(SplitTunnelMode mode) async {
    _prof.splitMode = mode;
    await saveNow(); _notify();
  }

  Future<void> toggleSplitApp(String packageName) async {
    final list = List<String>.from(_prof.splitApps);
    if (list.contains(packageName)) list.remove(packageName);
    else list.add(packageName);
    _prof.splitApps = list;
    await saveNow(); _notify();
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
          .map((j) => VlyProfile.fromJson(j as Map<String, dynamic>))
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
      await saveNow(); _notify();
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

  // Реакция на МГНОВЕННЫЙ детект отключения обхода(ов) от HealthMonitor.
  void _onBypassDown(List<String> downIds) {
    if (_disposed) return;
    final total   = ServiceBypassProfiles.all.length;
    final downAll = BypassHealthMonitor.downServices.length;
    stealthStatus = '🔴 Обход недоступен: ${downIds.join(", ")}';
    _notify();
    // Один сервис мёртв — мог быть точечно прикрыт его профиль. Но если упало
    // >= половины сервисов — деградировал сам туннель/обход → мгновенный failover,
    // не дожидаясь полного обрыва соединения.
    if (downAll >= (total / 2).ceil() && !_isRotating) {
      _log('🔴 Массовое падение обходов ($downAll/$total) → немедленный failover');
      // End-to-end сигнал: активная стратегия прошла TLS-пробу, но сквозь живой
      // туннель по факту не держит связь — наказываем её, чтобы ИИ опустил её
      // в рейтинге. В грейс-окне (шум сразу после коннекта) наказание пропустится.
      final penalized = AiMemory.penalizeActive();
      _log(penalized
          ? '📉 Активная стратегия наказана (end-to-end провал)'
          : '⏳ Провал в грейс-окне — стратегию не наказываем (вероятно, сеть)');
      stealthHandshakeFails = 3; // форсируем путь обхода
      _scheduleBypass();
    }
  }

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

    // Каждые 5 попыток — cooldown (даём провайдер "остыть")
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
        _log('🤖 ${VlyErrorCode.e1030.code}: bypass loop limit');
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
    if (_isRotating) return;
    _isRotating = true; _notify();
    try { await _v2ray.stopV2Ray(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 350)); // ускорено v7.0
    if (_disposed) { _isRotating = false; return; }
    // Очищаем AI-суффиксы из ссылки (#whitelist_df=... и т.д.)
    final cleanLink = cfg.link
        .split('#whitelist_df=').first
        .split('#fragment=').first;
    final cleanCfg = VpnConfig(
      name: cfg.name, link: cleanLink,
      customName: cfg.customName, groupName: cfg.groupName,
      sourceUrl: cfg.sourceUrl, isManual: cfg.isManual,
      isAiPatched: true, isFavourite: cfg.isFavourite,
    );
    _log('🔄 Reconnecting: ${cleanCfg.displayName}');
    await _connectWith(cleanCfg);
    _isRotating = false; aiStatus = 'IDLE'; _notify();
  }


  // (Удалён _configCache: кэш никогда не заполнялся — _cacheConfig не вызывался,
  //  поэтому _getCachedConfig всегда возвращал null. Мёртвая оптимизация.)

  // (Удалён «предиктивный авто-переключатель» ЗАДАЧА 10: был полностью написан,
  //  но НИКОГДА не запускался (_startPredictiveMonitor не вызывался нигде) —
  //  заявлял фичу «переключаемся до разрыва», которой по факту не было.
  //  Проактивное переключение нод — хорошая фича, но её надо делать осознанно:
  //  с пользовательским тумблером и тестами на устройстве, а не молча switch'ать
  //  сессию по флуктуации пинга. Кандидат в фазу «логика ИИ».)

  Future<void> _autoNext() async {
    if (_configs.isEmpty) { _isRotating = false; return; }
    try { await _v2ray.stopV2Ray(); } catch (_) {}
    // FIX v3.0: DNS leak gap — увеличена пауза при авто-переключении ноды
    await Future.delayed(const Duration(milliseconds: 350)); // ускорено v7.0
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


  // ═══ Security Patches v7.0 — DPI невидимость ════════════════════════════
  static String _applySecurityPatches(String cfg) {
    try {
      final j = jsonDecode(cfg) as Map<String, dynamic>;

      // 1. Нет логов на диск — /proc/net leak защита
      j['log'] = {'loglevel': 'none', 'access': '', 'error': ''};

      // 2. Sniffing выключен — DPI не читает домены через xray
      if (j['inbounds'] is List) {
        for (final ib in j['inbounds'] as List) {
          if (ib is Map) ib['sniffing'] = {'enabled': false};
        }
      }

      // 3. Chrome 134 fingerprint + MTU 1500 + ALPN + tcpFastOpen
      if (j['outbounds'] is List) {
        for (final ob in j['outbounds'] as List) {
          if (ob is! Map) continue;
          final ss = ob['streamSettings'];
          if (ss is! Map) continue;
          final sec = ss['security'];
          if (sec == 'tls' || sec == 'reality') {
            final key = sec == 'reality' ? 'realitySettings' : 'tlsSettings';
            if (ss[key] is Map) {
              (ss[key] as Map)['fingerprint'] = 'chrome';
              // ALPN точно как у Chrome — h2 + http/1.1
              (ss[key] as Map)['alpn'] ??= ['h2', 'http/1.1'];
            }
          }
          // tcpFastOpen + domainStrategy
          ss['sockopt'] = {
            'tcpFastOpen': true,
            'domainStrategy': 'UseIPv4v6',
          };
        }
      }

      // 4. DoH DNS — провайдер не видит DNS запросы (защита от DNS leak)
      j['dns'] ??= {
        'servers': [
          'https+local://1.1.1.1/dns-query',
          'https+local://8.8.8.8/dns-query',
          '223.5.5.5',
        ],
        'queryStrategy': 'UseIPv4',
      };

      // 5. Routing hybrid matcher
      if (j['routing'] is Map) {
        (j['routing'] as Map)['domainMatcher'] ??= 'hybrid';
      }

      // 6. ЗАДАЧА 1: Удалить xray gRPC management API
      // XrayAPIDetector сканирует порт 10085 — убираем API секцию
      // yourvpndead PoC использует это для дампа конфигов
      j.remove('api');
      if (j['inbounds'] is List) {
        final inbounds = (j['inbounds'] as List);
        inbounds.removeWhere((ib) =>
          ib is Map && (ib['tag'] == 'api' || ib['protocol'] == 'dokodemo-door'));
      }
      if (j['routing'] is Map && (j['routing'] as Map)['rules'] is List) {
        final rules = (j['routing'] as Map)['rules'] as List;
        rules.removeWhere((r) => r is Map && r['outboundTag'] == 'api');
      }

      // 8. ЗАДАЧА 3: Блокировка telemetry (anti-Happ)
      // Блокируем известные телеметрические хосты в routing
      // Защита: наше приложение не может случайно утечь данные
      if (j['routing'] is Map && (j['routing'] as Map)['rules'] is List) {
        final rules = (j['routing'] as Map)['rules'] as List;
        rules.insert(0, {
          'type': 'field',
          'domain': [
            'check.happ.su',       // Happ telemetry
            'api.happ.su',
            'update.happ.su',
            'metric.happ.su',
            'analytics.',          // generic analytics
            'telemetry.',
            'collect.',
            'stat.',
          ],
          'outboundTag': 'block',
        });
      }

      // 7. ЗАДАЧА 2: Anti-WebRTC STUN leak
      // Meta Pixel / Яндекс.Метрика используют WebRTC STUN для сканирования localhost
      // Блокируем UDP трафик к STUN серверам через routing
      if (j['routing'] is Map && (j['routing'] as Map)['rules'] is List) {
        final rules = (j['routing'] as Map)['rules'] as List;
        // Блокируем stun.l.google.com и другие STUN серверы
        rules.insert(0, {
          'type': 'field',
          'domain': ['stun.l.google.com', 'stun1.l.google.com',
                     'stun.cloudflare.com', 'stun.nextcloud.com'],
          'outboundTag': 'block',
          'network': 'udp',
        });
      }
      // Убедимся что есть blackhole outbound
      if (j['outbounds'] is List) {
        final outs = j['outbounds'] as List;
        final hasBlock = outs.any((o) => o is Map && o['tag'] == 'block');
        if (!hasBlock) {
          outs.add({'tag': 'block', 'protocol': 'blackhole',
              'settings': {'response': {'type': 'none'}}});
        }
      }

      return jsonEncode(j);
    } catch (e, st) {
      // Патч не применился → защита (anti-WebRTC/telemetry/API-dump) тихо не
      // работает. Возвращаем исходный конфиг, чтобы подключение не сорвалось,
      // но фиксируем причину, иначе провал невидим при диагностике.
      CrashReporter.record(e, st);
      return cfg;
    }
  }

  Future<void> _connectWith(VpnConfig cfg) async {
    _log('⚡ ${cfg.displayName}');
    _userInitiatedStop = false; // это попытка подключения, не ручное отключение
    try {
      // ── БЫСТРЫЙ ПУТЬ: макс 5 сек до startV2Ray ────────────────────────────
      // FIX: ForegroundServiceDidNotStartInTimeException — Android убивает
      // сервис если startForeground() не вызван за 5 сек после startForegroundService()
      // Решение: НЕ делаем никаких blocking операций до startV2Ray
      // Stealth операции (warmup, SNI, pacing) — только в фоне после старта

      // Шаг 1: Парсим конфиг — извлекаем AI патчи из суффикса, затем очищаем
      final _rawLink = cfg.link;
      
      // Извлекаем параметры из AI-суффиксов перед очисткой
      String? _aiSni;
      String? _aiMode;
      String  _aiGrpcSvc = 'GrpcService';
      if (_rawLink.contains('#whitelist_df=')) {
        final after = _rawLink.split('#whitelist_df=').last;
        _aiSni = Uri.decodeComponent(after.split('&').first);
      } else if (_rawLink.contains('#xhttp_sni=')) {
        final after = _rawLink.split('#xhttp_sni=').last;
        _aiSni = Uri.decodeComponent(after.split('&').first);
        _aiMode = 'xhttp';
      } else if (_rawLink.contains('#vision_sni=')) {
        final after = _rawLink.split('#vision_sni=').last;
        _aiSni = Uri.decodeComponent(after.split('&').first);
        _aiMode = 'vision';
      } else if (_rawLink.contains('#grpc_sni=')) {
        final after = _rawLink.split('#grpc_sni=').last;
        _aiSni = Uri.decodeComponent(after.split('&').first);
        _aiMode = 'grpc';
        if (after.contains('svc=')) {
          _aiGrpcSvc = Uri.decodeComponent(after.split('svc=').last.split('&').first);
        }
      } else if (_rawLink.contains('#shadowtls_v3=')) {
        final after = _rawLink.split('#shadowtls_v3=').last;
        _aiSni = Uri.decodeComponent(after.split('&').first);
        _aiMode = 'shadowtls';
      } else if (_rawLink.contains('#fragment=')) {
        final after = _rawLink.split('#fragment=').last;
        if (after.contains('sni=')) {
          _aiSni = Uri.decodeComponent(after.split('sni=').last.split('&').first);
        }
      }
      if (_aiSni != null) _log('🎯 AI-SNI: $_aiSni${_aiMode != null ? " mode=$_aiMode" : ""}');

      // Очищаем суффиксы — v2ray их не понимает
      String finalLink = _rawLink
          .split('#whitelist_df=').first
          .split('#fragment=').first
          .split('#hy2_fallback').first
          .split('#xhttp_sni=').first
          .split('#vision_sni=').first
          .split('#grpc_sni=').first
          .split('#shadowtls_v3=').first;


      // ── HYSTERIA2 AUTO-DETECT: QUIC/UDP обход DPI ────────────────────────
      // DPI не умеет анализировать QUIC трафик (март 2026)
      if (finalLink.startsWith('hy2://') || finalLink.startsWith('hysteria2://')) {
        _log('⚡ Hysteria2 QUIC/UDP — DPI bypass');
        try {
          final uri      = Uri.parse(finalLink);
          final host     = uri.host;
          final port     = uri.port > 0 ? uri.port : 443;
          final password = uri.userInfo;
          final sni      = uri.queryParameters['sni'] ?? host;
          final obfs     = uri.queryParameters['obfs'] ?? '';
          final obfsPass = uri.queryParameters['obfs-password'] ?? '';
          final h2config = <String, dynamic>{
            'log': {'loglevel': 'warning'},
            'inbounds': [{'tag': 'socks', 'port': _secureProxyPort, 'listen': '127.0.0.1',
              'protocol': 'socks',
              'settings': {
                'auth': 'password',
                'accounts': [{'user': 'vly', 'pass': _sessionKey}],
                'udp': true,
                'ip': '127.0.0.1',
              }}],
            'outbounds': [<String, dynamic>{
              'protocol': 'hysteria2',
              'settings': {
                'servers': [<String, dynamic>{
                  'address': host, 'port': port, 'password': password,
                  if (obfs == 'salamander')
                    'obfs': {'type': 'salamander', 'password': obfsPass},
                }],
              },
              'streamSettings': {
                'network': 'tcp', 'security': 'tls',
                'tlsSettings': {
                  'serverName': sni, 'alpn': ['h3'],
                  'allowInsecure': uri.queryParameters['insecure'] == '1',
                },
              },
            }],
          };
          _log('⚡ Hysteria2: $host:$port sni=$sni');
          await _v2ray.startV2Ray(
            remark: cfg.displayName,
            config: jsonEncode(h2config),
            blockedApps: _splitArgsForConnect(),
          );
          _isRotating = false; status = 'CONNECTED'; _notify(); return;
        } catch (e) { _log('✗ Hysteria2: $e — falling back'); }
      }

      // Reality SNI — приоритет: AI-SNI > кэш > пул
      if (stealthMode && stealthRealitySni) {
        final cachedSni = StealthEngine.cachedSniPublic;
        final sni = _aiSni ?? (cachedSni.isNotEmpty && cachedSni != '—'
            ? cachedSni
            : StealthEngine.pickLiveSniFromCache());
        finalLink = StealthEngine.injectRealityWithSni(finalLink, sni);
      } else if (_aiSni != null) {
        // AI выбрал SNI но stealth mode выключен — применяем напрямую
        finalLink = StealthEngine.injectRealityWithSni(finalLink, _aiSni);
      }

      // Honest transport: режим gRPC реально переключает транспорт на type=grpc.
      // Раньше стратегия gRPC меняла только SNI — parseFromURL строил исходный
      // type=tcp. Теперь инжектим type=grpc&serviceName в ссылку, и v2ray строит
      // настоящий gRPC-стрим. Только vless/trojan (vmess base64 — пропускаем).
      if (_aiMode == 'grpc' &&
          (finalLink.startsWith('vless://') || finalLink.startsWith('trojan://'))) {
        try {
          final u = Uri.parse(finalLink);
          final q = Map<String, String>.from(u.queryParameters);
          q['type']        = 'grpc';
          q['serviceName'] = _aiGrpcSvc;
          q['mode']        = q['mode'] ?? 'gun';
          finalLink = u.replace(queryParameters: q).toString();
          _log('📡 gRPC honest transport (svc=$_aiGrpcSvc)');
        } catch (e) { _log('⚠ gRPC inject fail: $e'); }
      }

      final patchedCfg = VpnConfig(
        name: cfg.name, link: finalLink,
        customName: cfg.customName, groupName: cfg.groupName,
        sourceUrl: cfg.sourceUrl, isManual: cfg.isManual,
        isAiPatched: cfg.isAiPatched, isFavourite: cfg.isFavourite,
      );

      // Шаг 2: Генерируем конфиг (мгновенно)
      String configStr = '';

      // Honest transport: режим xHTTP строит РЕАЛЬНЫЙ xHTTP-конфиг через builder.
      // Раньше стратегия xHTTP меняла только SNI — транспорт оставался type=tcp
      // (parseFromURL), т.е. обход был фиктивным. Теперь генерируем настоящий
      // xHTTP outbound. При любой неудаче — тихий фолбэк на стандартный путь ниже.
      if (_aiMode == 'xhttp') {
        final built = StealthEngine.buildHonestXhttp(patchedCfg.link, sni: _aiSni);
        if (built != null && built.isNotEmpty) {
          configStr = built;
          _log('🌐 xHTTP honest config (real transport)');
        }
      } else if (_aiMode == 'vision') {
        // VLESS+Reality+Vision из чистого шаблона (если в ноде есть pbk/sid)
        final built = StealthEngine.buildHonestVision(patchedCfg.link, sni: _aiSni);
        if (built != null && built.isNotEmpty) {
          configStr = built;
          _log('🛡 VLESS+Vision honest config (clean reality template)');
        }
      }

      if (configStr.isEmpty) {
        final V2RayURL parsed = FlutterV2ray.parseFromURL(patchedCfg.link);
        configStr = parsed.getFullConfiguration();
      }
      if (configStr.isEmpty) {
        _log('✗ E-1003: getFullConfiguration() returned empty');
        _isRotating = false; status = 'ERROR'; stealthStatus = ''; _notify(); return;
      }

      // Шаг 3: Патчим конфиг (CPU only, мгновенно)
      // VPN Detection Shield: patch SOCKS5 port + auth before starting
      configStr = StealthEngine.patchConfigSecure(
          configStr,
          fragment: stealthMode && stealthFragment,
          socksPort: VpnProvider._secureProxyPort,
          socksPass: VpnProvider._sessionKey,
      );
      // Дополнительные патчи безопасности: Chrome fingerprint, DoH DNS, sniffing off
      configStr = _applySecurityPatches(configStr);
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
          final route = _bypassRules.buildRussiaRoutingRules();
          // Пер-сервисный обход: точные правила для TG/YouTube/TikTok/… ставим
          // в начало (приоритет), чтобы трафик этих сервисов гарантированно шёл
          // через VPN с нужным обходом. Форки Telegram покрыты автоматически.
          if (perAppBypass) {
            final rules = (route['rules'] as List?)?.cast<dynamic>() ?? <dynamic>[];
            rules.insertAll(0, ServiceBypassProfiles.buildRoutingRules());
            route['rules'] = rules;
            _log('📱 Per-app bypass: ${ServiceBypassProfiles.all.length} сервисов');
          }
          jRoute['routing'] = route;
          final obs = jRoute['outbounds'] as List? ?? [];
          if (!obs.any((o) => o is Map && o['tag'] == 'direct')) {
            obs.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
          }
          if (!obs.any((o) => o is Map && o['tag'] == 'block')) {
            obs.add({'tag': 'block', 'protocol': 'blackhole', 'settings': {}});
          }
          configStr = jsonEncode(jRoute);
        }
      } catch (e) {
        // Smart routing не применился → трафик пойдёт без RU-правил обхода.
        // Не критично для самого коннекта, но диагностически важно знать.
        _log('⚠️ smart routing skip: $e');
      }

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
      // proxyOnly=true означает «только локальный прокси, БЕЗ системного VPN-туннеля»
      // (из доков flutter_v2ray). Раньше тут было proxyOnly: killSwitch — это была
      // ИНВЕРСИЯ: включение kill switch отключало перехват всего трафика, т.е. давало
      // самый незащищённый режим. Для full-tunnel VPN (и для любой kill-switch семантики,
      // где TUN блокирует трафик при падении) нужен системный туннель → proxyOnly=false.
      // Прокси-режим — отдельная осознанная опция пользователя (proxyModeEnabled —
      // это цепочка TUN→SOCKS5→VPN, всё равно с туннелем, поэтому тоже не proxyOnly).
      await _v2ray.startV2Ray(
        remark:        cfg.displayName,
        config:        configStr,
        blockedApps:   _splitArgsForConnect(),
        bypassSubnets: null,
        proxyOnly:     false,
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

      // NetworkCountermeasures2026: умная классификация ошибки
      final blockType = NetworkCountermeasures2026.classifyError(e.toString());
      final errStr = e.toString().toLowerCase();
      final isBlock = blockType != BlockType.timeout ||
                      errStr.contains('reset') || errStr.contains('timeout') ||
                      errStr.contains('refused') || errStr.contains('connection');

      // Логируем определённый тип блокировки для Dev Dashboard. Реальный выбор
      // стратегии дальше делает адаптивный бандит в AiMemory/каскаде.
      if (blockType != BlockType.timeout) {
        _log('🔍 Тип блокировки: ${blockType.name}');
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
        // Авто-discovery рабочих фронтов белого списка — переоткрываем заранее,
        // чтобы следующий коннект/ротация взяли уже измеренный живой фронт.
        if (stealthMode) {
          unawaited(WhitelistBypassEngine.autoRediscover(log: _log));
        }
      } catch (_) {}
    });
  }

  Future<void> toggle() async {
    if (isConnected || status == 'CONNECTING') {
      // Принудительно останавливаем всё — bypass, AI, rotation
      _userInitiatedStop = true; // отключил пользователь → не авто-реконнектить
      _isRotating = false;
      _aiAgent.stop();   // останавливаем AI bypass если висит
      _cancelWd();
      _failCount = 0;
      aiStatus = 'IDLE';
      stealthStatus = '';
      whitelistBypassActive  = false;
      whitelistBypassStatus  = 'IDLE';
      await _v2ray.stopV2Ray();
      await _dismissPersistentNotif();
      await _updateTile(active: false);
      status = 'DISCONNECTED';
      _notify();
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
    // Поддержка нескольких конфигов сразу (multiline paste)
    final lines = raw.trim().split('\n');
    if (lines.length > 1) {
      int added = 0;
      for (final l in lines) {
        final trimmed = l.trim();
        if (trimmed.isNotEmpty) {
          _addOneKey(trimmed);
          added++;
        }
      }
      if (added > 0) { saveToDisk(); _notify(); }
      _log('✚ Добавлено конфигов: $added');
      return;
    }
    _addOneKey(raw.trim());
    saveToDisk(); _notify();
  }

  void _addOneKey(String link) {
    if (link.isEmpty) return;
    const validProtocols = [
      'vless://', 'vmess://', 'trojan://', 'ss://', 'ssr://',
      'hysteria2://', 'hy2://', 'hysteria://', 'wireguard://',
      'shadowtls://', 'tuic://', 'juicity://', 'naive+https://',
    ];
    final hasValidProtocol = validProtocols.any((p) => link.toLowerCase().startsWith(p));
    if (!hasValidProtocol) {
      _log('✗ Неподдерживаемый протокол: ${link.split('://').first}');
      return;
    }
    if (_configs.any((c) => c.link == link)) { _log('⚠ Дубликат пропущен'); return; }
    String name = 'Manual Key';
    if (link.contains('#')) {
      try {
        final rawName = link.split('#').last;
        final n = Uri.decodeFull(rawName).replaceAll('+', ' ').trim();
        if (n.isNotEmpty && !n.contains('=')) name = n;
      } catch (_) {}
    }
    // Определяем протокол для красивого имени
    if (link.startsWith('hy2://') || link.startsWith('hysteria2://')) {
      name = name == 'Manual Key' ? '⚡ Hysteria2' : '⚡ $name';
    } else if (link.startsWith('vless://')) {
      name = name == 'Manual Key' ? '🔷 VLESS' : name;
    } else if (link.startsWith('vmess://')) {
      name = name == 'Manual Key' ? '🔶 VMess' : name;
    } else if (link.startsWith('trojan://')) {
      name = name == 'Manual Key' ? '🔴 Trojan' : name;
    } else if (link.startsWith('ss://')) {
      name = name == 'Manual Key' ? '🟢 Shadowsocks' : name;
    }
    _configs.add(VpnConfig(
      name: name, link: link,
      groupName: 'Ручные ключи',
      sourceUrl: 'manual',
      isManual: true,
    ));
    _log('✚ Добавлен: $name');
  }

  // Сбросить ключ/конфиг к оригинальному (как пришёл от провайдера/подписки)
  // Убирает все AI-патчи, маскировку, изменения транспорта
  void resetNodeToOriginal(int idx) {
    if (idx < 0 || idx >= _configs.length) return;
    _configs[idx].resetToOriginal();
    _log('↩ "${_configs[idx].displayName}" — сброс к оригинальному ключу провайдера');
    saveNow();
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
    _prof.subLinks = List<String>.from(_prof.subLinks);
    _prof.subLinks.add(u);
    _log('📡 Загружаю: $u');
    _notify();
    await _fetchSub(u);
    saveNow();
    _notify();
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
    _log('✔ ${_configs.length} nodes'); _notify(); saveNow();
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

      // Парсим свежие ноды подписки в отдельный список.
      final fresh = <VpnConfig>[];
      final seen  = <String>{};
      // Ссылки из ДРУГИХ источников — не дублируем их в этой подписке.
      final otherLinks = _configs
          .where((c) => c.sourceUrl != url)
          .map((c) => c.link).toSet();
      // Строгая валидация: строка = нода ТОЛЬКО если начинается с известной
      // VPN-схемы (VpnConfig.isSupportedNodeLink). Иначе подписка, вернувшая
      // HTML/капчу/Happ-crypt, плодила мусорные «ноды» вроде "<SCRIPT>…".
      for (final line in raw.split(RegExp(r'[\n\r]+'))) {
        final l = line.trim();
        final lower = l.toLowerCase();
        if (!VpnConfig.isSupportedNodeLink(l)) continue; // не конфиг
        if (otherLinks.contains(l) || !seen.add(l)) continue; // дубль (другой источник / внутри)
        String name = '';
        if (l.contains('#')) {
          try {
            final n = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim();
            if (n.isNotEmpty) name = n;
          } catch (_) {}
        }
        // Санитизация имени (убирает управляющие символы/<>, режет длину).
        name = VpnConfig.sanitizeNodeName(name);
        if (name.isEmpty) {
          // Нет метки — осмысленное имя из хоста вместо безликого "Node".
          final host = _extractHost(l);
          name = host.isNotEmpty ? host : '$gname ${fresh.length + 1}';
        }
        if (lower.startsWith('hy2://') || lower.startsWith('hysteria2://')) name = '⚡ $name';
        fresh.add(VpnConfig(name: name, link: l, groupName: gname, sourceUrl: url));
      }
      if (fresh.isEmpty) {
        _log('✔ $gname +0 (в ответе нет валидных нод — возможно, подписка вернула '
             'страницу/капчу, а не список; список не тронут)');
        return;
      }

      // ОБНОВЛЕНИЕ = СИНХРОНИЗАЦИЯ (replace), а не append. Иначе при ротации нод
      // провайдером старые мёртвые ноды копятся в списке навсегда. Сохраняем
      // пользовательские пометки (избранное/кастомное имя) по совпадению ссылки.
      // Ноды из других источников и ручные (другой sourceUrl) не трогаем.
      final oldOfThisSrc = {
        for (final c in _configs.where((c) => c.sourceUrl == url)) c.link: c
      };
      for (final f in fresh) {
        final prev = oldOfThisSrc[f.link];
        if (prev != null) {
          f.isFavourite = prev.isFavourite;
          if (prev.customName.isNotEmpty) f.customName = prev.customName;
        }
      }
      final before = oldOfThisSrc.length;
      _configs.removeWhere((c) => c.sourceUrl == url);
      _configs.addAll(fresh);
      // Корректируем selectedIndex, чтобы не указывал мимо после replace.
      if (selectedIndex >= _configs.length) selectedIndex = _configs.isEmpty ? 0 : _configs.length - 1;
      _log('✔ $gname: ${fresh.length} нод (было $before, синхронизировано)');
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
        String name = 'Vly Node';
        if (l.contains('#')) {
          try { name = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim(); } catch (_) {}
        }
        _configs.add(VpnConfig(name: name, link: l,
            groupName: 'Vly Servers', sourceUrl: 'server'));
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
          String name = 'Vly Node';
          if (l.contains('#')) {
            try { name = Uri.decodeFull(l.split('#').last).replaceAll('+', ' ').trim(); } catch (_) {}
          }
          _configs.add(VpnConfig(name: name, link: l,
              groupName: 'Vly Servers', sourceUrl: 'server'));
          added++;
        }
        if (added > 0) { _log('✔ +$added server nodes'); saveToDisk(); _notify(); }
      }
    } catch (_) {}
  }

  // ── Ping (TCP, parallel 8) ────────────────────────────────────────────────

  // silent=true — не дёргать _notify() на каждую ноду (для batch-пинга в pingAll:
  // раньше при пинге N нод было ~2N полных перерисовок дерева — джанк. Теперь
  // pingAll делает один _notify() на батч).
  Future<void> pingNode(int i, {bool silent = false}) async {
    if (_disposed) return;
    if (i < 0 || i >= _configs.length) return;
    final cfg = _configs[i];
    if (cfg.isPinging) return;
    cfg.isPinging = true; if (!silent) _notify();
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
    if (!_disposed && !silent) _notify();
  }

  Future<void> pingAll() async {
    if (isPingAllRunning || _configs.isEmpty || _disposed) return;
    isPingAllRunning = true;
    _log('◎ Ping ${_configs.length} nodes...'); _notify();
    final total = _configs.length;
    // Batch 32 параллельно — максимальная скорость пинга
    for (int i = 0; i < total; i += 32) {
      if (_disposed) { isPingAllRunning = false; _notify(); return; }
      final batch = (i + 32 <= total) ? 32 : total - i; // 32 ноды параллельно
      await Future.wait(List.generate(batch, (j) => pingNode(i + j, silent: true)));
      if (!_disposed) _notify(); // один раз на батч вместо ~2 на ноду
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
        await Future.wait(List.generate(batch, (j) => pingNode(i + j, silent: true)));
        autoStatus = 'Пингую… ${((i + batch) / total * 100).toInt()}%';
        _notify(); // один раз на батч (pingNode silent — без двойного notify на ноду)
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

    if (_configs.isEmpty || selectedIndex >= _configs.length) {
      whitelistBypassStatus = 'FAILED';
      _log('✗ Нет активной ноды для обхода');
      _notify();
      await Future.delayed(const Duration(seconds: 2));
      whitelistBypassStatus = 'IDLE';
      _notify();
      return;
    }

    whitelistBypassStatus = 'ACTIVATING';
    _notify();
    _log('🌐 Активируем обход белых списков...');

    try {
      // Берём ИЗМЕРЕННЫЙ лучший whitelist-фронт: движок проверяет живость фронтов
      // в текущей сети и ранжирует по задержке. Раньше кнопка жёстко зашивала
      // speed.cloudflare.com + слепо форсила ws/tls/443 — это игнорировало
      // измерение и РВАЛО Reality-ноды (сервер не ждёт ws). Теперь SNI-фронт
      // накладывается суффиксом #whitelist_df=, который connect-путь применяет
      // корректно под каждый протокол (в т.ч. Reality/Vision), не ломая транспорт.
      String sni;
      try {
        sni = await WhitelistBypassEngine.getBestSni()
            .timeout(const Duration(seconds: 4), onTimeout: () => 'vk.com');
      } catch (_) { sni = 'vk.com'; }

      final cur  = _configs[selectedIndex];
      final base = cur.link.split('#whitelist_df=').first;
      final patched = VpnConfig(
        name:       '${cur.name} [WL]',
        link:       '$base#whitelist_df=${Uri.encodeComponent(sni)}',
        customName: '',
        groupName:  cur.groupName,
        sourceUrl:  cur.sourceUrl,
        isManual:   cur.isManual,
        isAiPatched: true,
      );

      whitelistBypassActive = true;
      whitelistBypassStatus = 'ACTIVE';
      _log('✅ Обход белых списков: SNI-фронт «$sni» (измерен движком)');
      _notify();

      // Реконнект с наложением whitelist_df. НЕ через _reconnect (он срезает
      // суффикс whitelist_df), а напрямую через _connectWith, который его читает.
      if (isConnected) {
        _isRotating = true; _notify();
        try { await _v2ray.stopV2Ray(); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 350));
        if (!_disposed) await _connectWith(patched);
        _isRotating = false; _notify();
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
  static const _storageKey = 'VlyVPN\$t0r4g3K3y2026';
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

  // Установить режим обхода (вызывается из UI)
  Future<void> setBypassMode(BypassMode mode) async {
    // Нерабочий на текущем ядре режим (Hysteria2/ShadowTLS) не выставляем —
    // коэрсим в auto, чтобы не оставить пользователя со сломанным выбором.
    if (!mode.isAvailable) mode = BypassMode.auto;
    bypassMode = mode;
    _aiAgent.bypassMode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString('bypass_mode', mode.name);
    _log('🎯 Режим обхода: \${mode.label}');
    _notify();
  }

  // ── Персистенция (дебаунс для производительности) ─────────────────────────
  // saveToDisk() раньше сериализовал ВСЕ ноды+профили, обфусцировал JSON и писал
  // в SharedPreferences на КАЖДОМ сеттере/тоггле (десятки вызовов). Быстрые
  // изменения = повторная тяжёлая сериализация всего. Теперь saveToDisk()
  // дебаунсит (коалесцирует burst в одну запись через 600мс), а saveNow()
  // пишет немедленно — для мутаций данных (импорт/удаление/сброс нод).
  void saveToDisk() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), saveNow);
  }

  Future<void> saveNow() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final p = await SharedPreferences.getInstance();
    // Профили (ноды/конфиги) — критичные данные. Сохраняем их изолированно от
    // остальных настроек: ошибка сериализации одного профиля не должна
    // заблокировать запись флагов, и наоборот — иначе теряем всё разом.
    try {
      _prof.configsJson = _configs.map((c) => c.toMap()).toList();
      final json = jsonEncode(profiles.map((x) => x.toJson()).toList());
      await p.setString('vly_profiles',      _obfuscate(json));
      await p.setString('vly_active_profile', activeProfileId);
    } catch (e) { _log('✗ Save profiles: $e'); }
    try {
      await p.setInt('selected_index',       selectedIndex);
      await p.setBool('stealth_mode',        stealthMode);
      await p.setBool('stealth_fragment',    stealthFragment);
      await p.setBool('stealth_reality_sni', stealthRealitySni);
      await p.setBool('stealth_warmup',      stealthWarmup);
    } catch (e) { _log('✗ Save settings: $e'); }
  }

  Future<void> loadFromDisk() async {
    try {
      final p = await SharedPreferences.getInstance();
      // Профили парсим изолированно: повреждённый/подменённый блоб не должен
      // сорвать всю загрузку и оставить приложение без активного профиля
      // (иначе последующий profiles.first крашит старт).
      try {
        final profilesRaw = _deobfuscate(p.getString('vly_profiles'));
        if (profilesRaw != null) {
          profiles = (jsonDecode(profilesRaw) as List)
              .map((j) => VlyProfile.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        _log('✗ Профили повреждены — восстанавливаю дефолт: $e');
        profiles = [];
      }
      _ensureDefaultProfile();
      activeProfileId = p.getString('vly_active_profile') ?? profiles.first.id;
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