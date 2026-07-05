// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unused_local_variable, dead_code, avoid_print, unused_field, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, always_use_package_imports
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  BYPASS HEALTH MONITOR  — real-time детект «обход отключился»
//
//  Пока VPN подключён, периодически пробит представительные endpoint'ы КАЖДОГО
//  сервиса ЧЕРЕЗ туннель. Мгновенно ловит, что один или несколько обходов
//  деградировали (throttle) или умерли (block), и реагирует:
//   • помечает стратегию в self-healing блеклист,
//   • при массовом падении (туннель мёртв) — триггерит failover,
//   • отдаёт состояние в UI.
//
//  «Мозг» (анализ новостей/сравнение методов) — на сервере: он пушит свежие
//  стратегии в bypass_rules.json, клиент подхватывает их без обновления app.
//  Монитор — это «органы чувств» клиента, которые видят реальность мгновенно.
// ═══════════════════════════════════════════════════════════════════════════

enum BypassHealth { healthy, degraded, down }

class _SvcHealth {
  BypassHealth state = BypassHealth.healthy;
  int       consecutiveFails = 0;
  int       lastLatencyMs    = 0;
  DateTime? lastChange;
}

class BypassHealthMonitor {
  static final Map<String, _SvcHealth> _h = {};
  static Timer? _timer;
  static void Function(String)? _log;
  static void Function(List<String> downIds)? _onDown;

  // Латентность выше порога = деградация (throttle, как у YouTube/Telegram).
  static const int _degradedLatencyMs = 2500;
  // Столько проб подряд провалено = сервис «down» (мгновенный детект отключения).
  static const int _downThreshold = 2;
  static const Duration _probeTimeout  = Duration(seconds: 3);
  static const Duration _probeInterval = Duration(seconds: 12);

  // ── Чистая логика (тестируемо, без сети) ──────────────────────────────────
  // Отчёт о результате пробы. Возвращает true, если состояние УХУДШИЛОСЬ
  // (healthy→degraded→down) — момент, который надо ловить мгновенно.
  static bool report(String serviceId, {required bool ok, int latencyMs = 0}) {
    final h = _h.putIfAbsent(serviceId, () => _SvcHealth());
    final prev = h.state;
    if (!ok) {
      h.consecutiveFails++;
      h.state = h.consecutiveFails >= _downThreshold
          ? BypassHealth.down
          : BypassHealth.degraded;
    } else {
      h.consecutiveFails = 0;
      h.lastLatencyMs = latencyMs;
      h.state = latencyMs > _degradedLatencyMs
          ? BypassHealth.degraded
          : BypassHealth.healthy;
    }
    if (h.state != prev) h.lastChange = DateTime.now();
    return h.state.index > prev.index; // ухудшилось
  }

  static BypassHealth stateOf(String id) => _h[id]?.state ?? BypassHealth.healthy;
  static int latencyOf(String id) => _h[id]?.lastLatencyMs ?? 0;

  static List<String> get downServices => _h.entries
      .where((e) => e.value.state == BypassHealth.down).map((e) => e.key).toList();
  static List<String> get degradedServices => _h.entries
      .where((e) => e.value.state == BypassHealth.degraded).map((e) => e.key).toList();

  static void reset([String? id]) { if (id == null) _h.clear(); else _h.remove(id); }

  // ── Real-time мониторинг (сетевой) ────────────────────────────────────────
  static bool get isRunning => _timer != null;

  static void start({
    required void Function(String) log,
    void Function(List<String> downIds)? onServicesDown,
  }) {
    stop();
    _log = log;
    _onDown = onServicesDown;
    _timer = Timer.periodic(_probeInterval, (_) => _tick());
    log('💓 Health monitor: слежу за ${ServiceBypassProfiles.all.length} сервисами');
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _tick() async {
    final newlyDown = <String>[];
    await Future.wait(ServiceBypassProfiles.all.map((p) async {
      final host = p.domains.firstWhere(
          (d) => !d.startsWith('*'), orElse: () => p.domains.first);
      final sw = Stopwatch()..start();
      bool ok = false; int ms = 0;
      try {
        final s = await SecureSocket.connect(host, 443,
            timeout: _probeTimeout, onBadCertificate: (_) => true);
        sw.stop(); ms = sw.elapsedMilliseconds; await s.close(); ok = true;
      } catch (_) { ok = false; }
      final worsened = report(p.id, ok: ok, latencyMs: ms);
      if (worsened && stateOf(p.id) == BypassHealth.down) newlyDown.add(p.id);
      // ПРИМЕЧАНИЕ: раньше здесь дёргали StrategyBlacklist.markFailed(p.strategy).
      // Это была ошибка пространств имён — p.strategy ('reality_fragment' и т.п.)
      // НЕ совпадает с типами каскада ('vless_xhttp'…), так что бан оседал
      // фантомным мусором и на выбор стратегии не влиял. Реакция на смерть
      // сервиса — это failover + end-to-end наказание активной руки в
      // _onBypassDown (AiMemory.penalizeActive), а не бан несуществующего ключа.
    }));
    if (newlyDown.isNotEmpty) {
      _log?.call('🔴 Обход отключился: ${newlyDown.join(", ")}');
      _onDown?.call(newlyDown);
    }
  }
}
