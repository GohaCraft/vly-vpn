// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  AI BYPASS AGENT v4.0 — Апрель 2026
//  Актуальные данные:
//  ✅ Hysteria2 + Salamander obfs — лучший выбор (UDP, ТСПУ плохо анализирует)
//  ✅ VLESS + xHTTP transport — работает (новый транспорт, не детектируется)
//  ✅ VLESS + Reality + VK/Yandex SNI — работает если SNI в белом списке
//  ✅ VLESS + gRPC — работает на большинстве провайдеров
//  ⚠️  VLESS + Reality + Google SNI — частично блокируется (IP whitelist РКН)
//  ❌ VLESS + TCP plain TLS — заблокирован с 17.02.2026
//  ❌ WireGuard — заблокирован давно
//  ❌ OpenVPN — заблокирован давно
// ═══════════════════════════════════════════════════════════════════════════

// Режимы обхода — выбирается пользователем в настройках
enum BypassMode {
  auto,         // AI сам выбирает лучший метод (по умолчанию)
  hysteria2,    // Принудительно Hysteria2/QUIC/UDP
  xhttp,        // VLESS + xHTTP (новый транспорт 2026)
  realityVk,   // VLESS + Reality + VK/Yandex SNI (белый список)
  grpc,         // VLESS + gRPC
  fragmented,   // Fragmented Reality (1-5 байт фрагменты)
  whitelist,    // Обход белых списков (domain fronting)
}

// Описание каждого режима для UI
extension BypassModeInfo on BypassMode {
  String get label {
    switch (this) {
      case BypassMode.auto:        return 'Авто (рекомендуется)';
      case BypassMode.hysteria2:   return 'Hysteria2 / QUIC';
      case BypassMode.xhttp:       return 'VLESS + xHTTP';
      case BypassMode.realityVk:  return 'VLESS + Reality (VK SNI)';
      case BypassMode.grpc:        return 'VLESS + gRPC';
      case BypassMode.fragmented:  return 'Fragmented Reality';
      case BypassMode.whitelist:   return 'Обход белых списков';
    }
  }

  String get description {
    switch (this) {
      case BypassMode.auto:
        return 'AI автоматически подбирает рабочий метод за 5-15 секунд';
      case BypassMode.hysteria2:
        return 'UDP протокол — ТСПУ плохо анализирует UDP трафик. '
            'Лучший выбор для Ростелеком/МТС (апрель 2026)';
      case BypassMode.xhttp:
        return 'Новый транспорт Xray 2026 — маскируется под HTTP/1.1. '
            'Работает даже там где Reality заблокирован';
      case BypassMode.realityVk:
        return 'Reality с SNI vk.com/yandex.ru — в белом списке РКН. '
            'Трафик выглядит как обращение к VK';
      case BypassMode.grpc:
        return 'gRPC транспорт — работает на большинстве провайдеров. '
            'Чуть медленнее xHTTP но надёжнее';
      case BypassMode.fragmented:
        return 'Разбивает первый TLS пакет на фрагменты 1-5 байт. '
            'Обходит DPI который анализирует начало соединения';
      case BypassMode.whitelist:
        return 'Для мобильного интернета с белыми списками. '
            'Domain fronting через разрешённые домены РКН';
    }
  }

  String get emoji {
    switch (this) {
      case BypassMode.auto:       return '🤖';
      case BypassMode.hysteria2:  return '⚡';
      case BypassMode.xhttp:      return '🌐';
      case BypassMode.realityVk: return '🛡';
      case BypassMode.grpc:       return '🔧';
      case BypassMode.fragmented: return '🔀';
      case BypassMode.whitelist:  return '📋';
    }
  }

  // Актуальность метода на апрель 2026
  String get status {
    switch (this) {
      case BypassMode.auto:       return '✅ Актуально';
      case BypassMode.hysteria2:  return '✅ Актуально — лучший выбор';
      case BypassMode.xhttp:      return '✅ Актуально — новый 2026';
      case BypassMode.realityVk: return '✅ Актуально — белый список';
      case BypassMode.grpc:       return '✅ Работает';
      case BypassMode.fragmented: return '⚠️ Экспериментальный';
      case BypassMode.whitelist:  return '⚠️ Только мобильный интернет';
    }
  }

  bool get isRecommended => this == BypassMode.hysteria2 ||
      this == BypassMode.xhttp || this == BypassMode.auto;
}

class AiBypassAgent {
  final BypassRulesEngine  _rules;
  final Function(String)   _log;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Текущая активная стратегия (видна в UI)
  int    currentStrategyId   = 0;
  String currentStrategyName = '';

  // Выбранный пользователем режим обхода
  BypassMode bypassMode = BypassMode.auto;

  AiBypassAgent(this._rules, this._log);

  // Принудительная остановка — вызывается из toggle() при disconnect
  void stop() {
    _isRunning = false;
    _log('🛑 E-2000: AI Bypass остановлен');
  }

  Future<VpnConfig?> findBypass(VpnConfig blocked) async {
    if (_isRunning) return null;
    _isRunning = true;
    try {
      // Глобальный таймаут 30с — без него может висеть минутами
      return await _findInternal(blocked).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('⏱ E-2001: AI Bypass таймаут (30с) — остановлен');
          _isRunning = false;
          return null;
        });
    } finally { _isRunning = false; }
  }

  Future<VpnConfig?> _findInternal(VpnConfig blocked) async {
    // Если выбран конкретный режим — применяем его напрямую (быстро!)
    if (bypassMode != BypassMode.auto) {
      return _applyDirectMode(blocked, bypassMode);
    }

    // AUTO режим — умный подбор
    return _runAutoMode(blocked);
  }

  // Прямое применение выбранного режима — работает за 1-2 секунды
  Future<VpnConfig?> _applyDirectMode(VpnConfig blocked, BypassMode mode) async {
    _log('🎯 E-2010: Прямой режим: ${mode.label}');
    currentStrategyName = mode.label;

    switch (mode) {
      case BypassMode.hysteria2:
        // Hysteria2: меняем протокол на hy2:// если нода поддерживает
        // Иначе применяем стратегию на существующую ноду
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'hysteria2_fallback', params: {}));

      case BypassMode.xhttp:
        // xHTTP — новый транспорт 2026, не детектируется ТСПУ
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'change_transport',
          params: {'transport': 'xhttp', 'path': '/api/v1/update', 'mode': 'packet-up'}));

      case BypassMode.realityVk:
        // Reality с VK SNI — в белом списке РКН
        final vkSni = ['vk.com', 'userapi.com', 'vkvideo.ru', 'yandex.ru'][
          DateTime.now().second % 4];
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'vless_vision_whitelist',
          params: {'sni': vkSni, 'tier': 1}));

      case BypassMode.grpc:
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'change_transport',
          params: {'transport': 'grpc', 'service': 'TunService'}));

      case BypassMode.fragmented:
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'fragmented_reality',
          params: {'fragSize': 2, 'delayMs': 50, 'sni': 'yandex.ru'}));

      case BypassMode.whitelist:
        return _applyStrategy(blocked, BypassStrategy(
          priority: 1, type: 'vless_vision_whitelist',
          params: {'sni': 'yandex.ru', 'tier': 0}));

      case BypassMode.auto:
        return _runAutoMode(blocked);
    }
  }

  // Применяет одну стратегию и проверяет работает ли
  Future<VpnConfig?> _applyStrategy(VpnConfig blocked, BypassStrategy s) async {
    try {
      final patched = _rules.applyStrategy(blocked, s);
      if (!_isRunning) return null;
      final works = await BypassProber.probe(patched)
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (works) {
        _log('✅ E-2011: ${s.type} работает');
        return patched;
      }
      _log('✗ E-2012: ${s.type} не прошёл');
      return null;
    } catch (e) {
      _log('✗ E-2013: ${s.type} ошибка: $e');
      return null;
    }
  }

  // AUTO режим — умный каскад по актуальным данным апрель 2026
  Future<VpnConfig?> _runAutoMode(VpnConfig blocked) async {
    // Шаг 1: Проверяем тип блокировки (быстро — 2с макс)
    _log('🔍 E-2002: Определяем тип блокировки...');
    final bt = await BlockDetector.detect(blocked)
        .timeout(const Duration(seconds: 2), onTimeout: () => BlockType.timeout);
    _log('🔍 E-2003: Тип: ${bt.name}');

    if (bt == BlockType.none) {
      _log('✅ E-2004: Блокировки нет — прямое подключение');
      return blocked;
    }

    // Шаг 2: Белые списки? (мобильный интернет)
    final whitelistActive = await WhitelistBypassEngine.isWhitelistActive()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);

    if (whitelistActive) {
      _log('🟡 E-2005: Белые списки активны — пробуем domain fronting');
      final wlResult = await _tryWhitelistStrategies(blocked);
      if (wlResult != null) return wlResult;
    }

    // Шаг 3: Приоритетный каскад — актуальные методы 2026
    // Порядок подобран по статистике работоспособности на российских провайдерах
    const kMaxAttempts = 10;
    final cascade = _buildCascade(bt).take(kMaxAttempts).toList();
    _log('🤖 E-2006: Cascade: ${cascade.length} (лимит $kMaxAttempts)');

    for (int i = 0; i < cascade.length; i++) {
      if (!_isRunning) return null;
      final s = cascade[i];
      currentStrategyId   = i + 1;
      currentStrategyName = s.type.replaceAll('_', ' ');
      _log('🤖 #${i+1}/${cascade.length} · ${s.type}');

      final result = await _applyStrategy(blocked, s);
      if (result != null) {
        _log('✅ E-2007: Найден обход: ${s.type}');
        return result;
      }
    }

    _log('✗ E-2008: Все методы не прошли — смена ноды');
    return null;
  }

  // Приоритетный каскад на апрель 2026
  // Порядок: от самого актуального к менее актуальному
  List<BypassStrategy> _buildCascade(BlockType bt) {
    final vkSni = ['vk.com', 'userapi.com', 'vkvideo.ru', 'yandex.ru'][
        DateTime.now().millisecond % 4];
    final yaSni = ['yandex.ru', 'ya.ru', 'mail.yandex.ru'][
        DateTime.now().millisecond % 3];

    return [
      // 1. Hysteria2 — лучший выбор апрель 2026 (UDP, ТСПУ плохо анализирует)
      BypassStrategy(priority: 1, type: 'hysteria2_fallback', params: {}),

      // 2. VLESS + xHTTP — новый транспорт 2026, не детектируется
      BypassStrategy(priority: 2, type: 'change_transport',
          params: {'transport': 'xhttp', 'path': '/api/v1/update', 'mode': 'packet-up'}),

      // 3. VLESS + Reality + VK SNI — белый список РКН
      BypassStrategy(priority: 3, type: 'vless_vision_whitelist',
          params: {'sni': vkSni, 'tier': 1}),

      // 4. VLESS + Reality + Яндекс SNI — Tier 0 (Ростелеком не блокирует)
      BypassStrategy(priority: 4, type: 'vless_vision_whitelist',
          params: {'sni': yaSni, 'tier': 0}),

      // 5. VLESS + gRPC — работает на большинстве провайдеров
      BypassStrategy(priority: 5, type: 'change_transport',
          params: {'transport': 'grpc', 'service': 'TunService'}),

      // 6. gRPC gun mode
      BypassStrategy(priority: 6, type: 'change_transport',
          params: {'transport': 'grpc', 'service': 'gun'}),

      // 7. Fragmented Reality — обходит DPI анализ начала соединения
      BypassStrategy(priority: 7, type: 'fragmented_reality',
          params: {'fragSize': 2, 'delayMs': 50, 'sni': yaSni}),

      // 8. WebSocket + 443 — классика, ещё работает
      BypassStrategy(priority: 8, type: 'change_transport',
          params: {'transport': 'ws', 'path': '/api', 'port': 443}),

      // 9. Rotate SNI — другой Reality SNI
      BypassStrategy(priority: 9, type: 'rotate_reality_sni', params: {}),

      // 10. CDN fallback — через Cloudflare Workers
      BypassStrategy(priority: 10, type: 'cdn_fallback',
          params: {'url': 'aura-cdn.pages.dev'}),
    ];
  }

  // Стратегии для белых списков
  Future<VpnConfig?> _tryWhitelistStrategies(VpnConfig blocked) async {
    final strategies = WhitelistBypassEngine.getStrategies();
    for (final ep in strategies.take(4)) {
      if (!_isRunning) return null;
      _log('🟡 Whitelist: ${ep['name']} (${ep['host']})');
      final result = await _applyStrategy(blocked, BypassStrategy(
        priority: 0, type: 'vless_vision_whitelist',
        params: {'sni': ep['host'], 'tier': ep['tier']}));
      if (result != null) return result;
    }
    return null;
  }

  int _stratId(BypassStrategy s) => s.priority;
}

// ── Strategy Blacklist ─────────────────────────────────────────────────────
class StrategyBlacklist {
  static final Map<String, DateTime> _blocked = {};

  static void block(String id, String type, Map params, {int minutes = 30}) {
    _blocked['\$id:\$type:\$params'] = DateTime.now().add(Duration(minutes: minutes));
  }

  static bool isBlocked(String id, String type, Map params) {
    final key = '\$id:\$type:\$params';
    final exp = _blocked[key];
    if (exp == null) return false;
    if (DateTime.now().isAfter(exp)) { _blocked.remove(key); return false; }
    return true;
  }

  static int minutesLeft(String id, String type, Map params) {
    final exp = _blocked['\$id:\$type:\$params'];
    if (exp == null) return 0;
    return exp.difference(DateTime.now()).inMinutes.clamp(0, 999);
  }

  // Все заблокированные стратегии — для Dev Dashboard
  static List<MapEntry<String, DateTime>> get allBlocked =>
      _blocked.entries.where((e) => DateTime.now().isBefore(e.value)).toList();

  // Очистить весь blacklist
  static void clear() => _blocked.clear();
}

// ── Bypass Reporter ────────────────────────────────────────────────────────
class BypassReporter {
  static final List<Map<String, dynamic>> _history = [];
  static bool _enabled = true; // отправка репортов на сервер

  static void report({required String strategyType, required bool success,
      required int latencyMs}) {
    _history.add({
      'type': strategyType, 'ok': success,
      'ms': latencyMs, 'ts': DateTime.now().millisecondsSinceEpoch,
    });
    if (_history.length > 100) _history.removeRange(0, _history.length - 100);
  }

  static List<Map<String, dynamic>> get history => List.unmodifiable(_history);
}

// ── News Awareness ─────────────────────────────────────────────────────────
class NewsAwareness {
  static final Set<String> _blacklistedStrategies = {};

  static Future<void> load() async {
    // В будущем — загружать из Dead Drop зеркал актуальный список
    // заблокированных стратегий и обновлять _blacklistedStrategies
  }

  static bool isBlacklisted(String strategyType) =>
      _blacklistedStrategies.contains(strategyType);
}

// ── Whitelist Bypass Engine ────────────────────────────────────────────────
class WhitelistBypassEngine {
  static Future<bool> isWhitelistActive() async {
    try {
      final s = await Socket.connect('youtube.com', 443,
          timeout: const Duration(seconds: 2));
      await s.close();
      return false; // YouTube доступен — белых списков нет
    } catch (_) {
      try {
        final s = await Socket.connect('vk.com', 443,
            timeout: const Duration(seconds: 2));
        await s.close();
        return true; // VK есть, YouTube нет → белые списки
      } catch (_) { return false; }
    }
  }

  static List<Map<String, dynamic>> getStrategies() => [
    {'name': 'Яндекс SNI',  'host': 'yandex.ru',           'tier': 0},
    {'name': 'ya.ru SNI',   'host': 'ya.ru',                'tier': 0},
    {'name': 'VK SNI',      'host': 'vk.com',               'tier': 1},
    {'name': 'vkvideo.ru',  'host': 'vkvideo.ru',           'tier': 1},
    {'name': 'Mail.ru SNI', 'host': 'mail.ru',              'tier': 1},
    {'name': 'MS Update',   'host': 'update.microsoft.com', 'tier': 2},
    {'name': 'iCloud',      'host': 'mask.icloud.com',      'tier': 2},
  ];

  static Map<String, dynamic>? getEndpointByKey(String key) {
    try { return getStrategies().firstWhere((e) => e['host'] == key); }
    catch (_) { return null; }
  }
}

// ── TSPU Bypass Window Detector ───────────────────────────────────────────
class TspuBypassWindowDetector {
  static DateTime? _lastCheck;
  static bool      _lastResult = false;

  static Future<bool> check({required Function(String) log}) async {
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!).inSeconds < 30) {
      return _lastResult;
    }
    _lastCheck = DateTime.now();
    try {
      final s = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(milliseconds: 800));
      await s.close();
      _lastResult = true;
      log('🟢 E-2010: ТСПУ bypass window');
      return true;
    } catch (_) {
      _lastResult = false;
      return false;
    }
  }
}