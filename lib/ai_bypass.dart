// ignore_for_file: unused_import, unused_element
part of 'main.dart';

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
    // Шаг 0: Проверяем ТСПУ bypass window — если ТСПУ перегружен, подключаемся напрямую
    final tspuBypass = await TspuBypassWindowDetector.check(log: _log);
    if (tspuBypass) {
      _log('🟢 ТСПУ в bypass — подключаемся без стелса');
      currentStrategyId = 0;
      return blocked; // ТСПУ не фильтрует — подключаемся напрямую
    }

    _log('🤖 Detecting block type…');
    final bt = await BlockDetector.detect(blocked);
    _log('🤖 Block: ${bt.name}');
    if (bt == BlockType.none) return blocked;

    // Проверяем белый список на мобильном интернете
    final whitelistActive = await WhitelistBypassEngine.isWhitelistActive();
    if (whitelistActive) {
      _log('🟡 Whitelist detected — applying domain fronting');
      // Пробуем whitelist domain fronting стратегии первыми
      final wlStrategies = WhitelistBypassEngine.getStrategies();
      for (final endpoint in wlStrategies.take(3)) {
        if (!_isRunning) return null;
        _log('🤖 Trying whitelist: ${endpoint['name']}');
        try {
          final patched = blocked;
          // Помечаем конфиг для domain fronting
          final link = '${blocked.link}#whitelist_df=${endpoint['host']}';
          final wlConfig = VpnConfig(
            name: '${blocked.name} [WL]',
            link: link,
            groupName: blocked.groupName,
            sourceUrl: blocked.sourceUrl,
            isManual: blocked.isManual,
            isAiPatched: true,
            isFavourite: blocked.isFavourite,
          );
          final works = await BypassProber.probe(wlConfig);
          if (works) {
            _log('🤖 ✅ Whitelist bypass works: ${endpoint['name']}');
            return wlConfig;
          }
        } catch (_) {}
      }
    }

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
        var patched = _rules.applyStrategy(blocked, s);

        // Применяем адаптивную мимикрию если стратегия требует
        if (s.type == 'adaptive_mimicry') {
          _log('🎭 Applying adaptive mimicry: ${AdaptiveMimicryEngine.persona.device}');
          // Поведенческая задержка для имитации реального пользователя
          await AdaptiveMimicryEngine.behavioralDelay();
        }

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



