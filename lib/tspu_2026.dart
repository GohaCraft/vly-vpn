// ignore_for_file: unused_import, unused_element
part of 'main.dart';

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

