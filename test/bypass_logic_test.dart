// Тесты ключевой логики обхода (детерминированные, без сети).
// Запуск: flutter test test/bypass_logic_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_new/main.dart';

void main() {
  group('Честный xHTTP-транспорт', () {
    test('строит реальный xHTTP-конфиг из vless-ссылки', () {
      const link = 'vless://uuid-1234@example.com:8443'
          '?security=reality&pbk=ABC&sid=DE&sni=vk.com&type=tcp#Node';
      final out = StealthEngine.buildHonestXhttp(link, sni: 'yandex.ru');
      expect(out, isNotNull);
      final j  = jsonDecode(out!) as Map<String, dynamic>;
      final ob = (j['outbounds'] as List).first as Map<String, dynamic>;
      expect(ob['protocol'], 'vless');
      final ss = ob['streamSettings'] as Map<String, dynamic>;
      expect(ss['network'], 'xhttp'); // реальный транспорт, не tcp
      final vnext = ((ob['settings'] as Map)['vnext'] as List).first as Map;
      expect(vnext['address'], 'example.com');
      expect(vnext['port'], 8443);
      expect((vnext['users'] as List).first['id'], 'uuid-1234');
    });

    test('возвращает null для не-vless ссылки (фолбэк на стандартный путь)', () {
      expect(StealthEngine.buildHonestXhttp('trojan://x@h:443'), isNull);
    });
  });

  group('Честный VLESS+Reality+Vision', () {
    test('строит reality+vision при наличии pbk/sid', () {
      const link = 'vless://u-1@srv.net:443'
          '?security=reality&pbk=PUBKEY123&sid=SHORT1&sni=vk.com#N';
      final out = StealthEngine.buildHonestVision(link, sni: 'vk.com');
      expect(out, isNotNull);
      final j  = jsonDecode(out!) as Map<String, dynamic>;
      final ob = (j['outbounds'] as List).first as Map<String, dynamic>;
      final ss = ob['streamSettings'] as Map<String, dynamic>;
      expect(ss['security'], 'reality');
      final rs = ss['realitySettings'] as Map<String, dynamic>;
      expect(rs['publicKey'], 'PUBKEY123');
      expect(rs['shortId'], 'SHORT1');
      // Vision flow — на уровне user (xray читает flow только оттуда)
      final users = (((ob['settings'] as Map)['vnext'] as List).first as Map)['users'] as List;
      expect((users.first as Map)['flow'], 'xtls-rprx-vision');
    });

    test('возвращает null без pbk (не настоящая Reality-нода)', () {
      expect(StealthEngine.buildHonestVision('vless://u@h:443?security=tls#N'), isNull);
    });
  });

  group('Self-healing блеклист', () {
    setUp(() { StrategyBlacklist.clear(); StrategyBlacklist.setEnabled(true); });

    test('markFailed банит, markSuccess мгновенно снимает', () {
      expect(StrategyBlacklist.isFailed('s1'), isFalse);
      StrategyBlacklist.markFailed('s1');
      expect(StrategyBlacklist.isFailed('s1'), isTrue);
      StrategyBlacklist.markSuccess('s1');
      expect(StrategyBlacklist.isFailed('s1'), isFalse); // само-восстановление
    });

    test('clear сбрасывает все баны', () {
      StrategyBlacklist.markFailed('a');
      StrategyBlacklist.markFailed('b');
      StrategyBlacklist.clear();
      expect(StrategyBlacklist.isFailed('a'), isFalse);
      expect(StrategyBlacklist.isFailed('b'), isFalse);
    });

    test('выключенный блеклист никогда не банит', () {
      StrategyBlacklist.setEnabled(false);
      StrategyBlacklist.markFailed('x');
      expect(StrategyBlacklist.isFailed('x'), isFalse);
      StrategyBlacklist.setEnabled(true);
    });
  });

  group('Классификатор блокировок DPI', () {
    test('распознаёт тип блокировки по тексту ошибки', () {
      expect(NetworkCountermeasures2026.classifyError('Connection reset by peer'),
          BlockType.tcpReset);
      expect(NetworkCountermeasures2026.classifyError('TLS handshake failed'),
          BlockType.tlsFingerprint);
      expect(NetworkCountermeasures2026.classifyError('DNS lookup failed'),
          BlockType.dnsPoisoning);
      expect(NetworkCountermeasures2026.classifyError('Operation timed out'),
          BlockType.timeout);
      expect(NetworkCountermeasures2026.classifyError('Connection refused'),
          BlockType.portBlocked);
    });
  });

  group('BypassRulesEngine — реальные трансформы ссылки', () {
    test('change_port реально меняет порт в ссылке', () {
      final engine = BypassRulesEngine();
      final cfg = VpnConfig(name: 'n', link: 'vless://uid@host.com:443?type=tcp#x');
      final out = engine.applyStrategy(cfg,
          const BypassStrategy(priority: 1, type: 'change_port', params: {'port': 8443}));
      expect(out.link.contains(':8443'), isTrue);
      expect(out.link.contains(':443?'), isFalse);
    });

    test('isBlocked распознаёт заблокированные домены и поддомены', () {
      final engine = BypassRulesEngine();
      expect(engine.isBlocked('instagram.com'), isTrue);
      expect(engine.isBlocked('sub.instagram.com'), isTrue);
      expect(engine.isBlocked('yandex.ru'), isFalse);
    });
  });

  group('Пер-сервисный обход (per-app)', () {
    test('detect определяет сервис по хосту и поддоменам', () {
      expect(ServiceBypassProfiles.detect('rr1.googlevideo.com')?.id, 'youtube');
      expect(ServiceBypassProfiles.detect('youtube.com')?.id, 'youtube');
      expect(ServiceBypassProfiles.detect('t.me')?.id, 'telegram');
      expect(ServiceBypassProfiles.detect('api.telegram.org')?.id, 'telegram');
      expect(ServiceBypassProfiles.detect('byteoversea.com')?.id, 'tiktok');
      expect(ServiceBypassProfiles.detect('yandex.ru'), isNull); // не сервис
    });

    test('форки Telegram покрыты профилем telegram (общие серверы)', () {
      // AyuGram/ExtraGram/Nicegram ходят на те же домены/DC Telegram
      final tg = ServiceBypassProfiles.telegram;
      expect(tg.domains, contains('telegram.org'));
      expect(tg.domains, contains('t.me'));
      expect(tg.ips.any((c) => c.startsWith('149.154.160')), isTrue);
    });

    test('каждый профиль валиден (домены + стратегия)', () {
      for (final p in ServiceBypassProfiles.all) {
        expect(p.domains, isNotEmpty, reason: '${p.id}: нет доменов');
        expect(p.strategy, isNotEmpty, reason: '${p.id}: нет стратегии');
      }
    });

    test('buildRoutingRules даёт валидные xray-правила на proxy', () {
      final rules = ServiceBypassProfiles.buildRoutingRules();
      expect(rules, isNotEmpty);
      expect(rules.every((r) => r['outboundTag'] == 'proxy'), isTrue);
      // есть и доменные, и IP-правила (для Telegram)
      expect(rules.any((r) => r.containsKey('domain')), isTrue);
      expect(rules.any((r) => r.containsKey('ip')), isTrue);
    });
  });

  group('Health monitor — мгновенный детект отключения', () {
    setUp(() => BypassHealthMonitor.reset());

    test('2 провала подряд → сервис down (мгновенный детект)', () {
      expect(BypassHealthMonitor.report('youtube', ok: false), isTrue); // healthy→degraded
      expect(BypassHealthMonitor.stateOf('youtube'), BypassHealth.degraded);
      final worsened = BypassHealthMonitor.report('youtube', ok: false); // degraded→down
      expect(worsened, isTrue);
      expect(BypassHealthMonitor.stateOf('youtube'), BypassHealth.down);
      expect(BypassHealthMonitor.downServices, contains('youtube'));
    });

    test('успешная проба восстанавливает (само-восстановление)', () {
      BypassHealthMonitor.report('telegram', ok: false);
      BypassHealthMonitor.report('telegram', ok: false);
      expect(BypassHealthMonitor.stateOf('telegram'), BypassHealth.down);
      BypassHealthMonitor.report('telegram', ok: true, latencyMs: 120);
      expect(BypassHealthMonitor.stateOf('telegram'), BypassHealth.healthy);
      expect(BypassHealthMonitor.downServices, isNot(contains('telegram')));
    });

    test('высокая латентность = деградация (throttle)', () {
      expect(BypassHealthMonitor.report('youtube', ok: true, latencyMs: 4000), isTrue);
      expect(BypassHealthMonitor.stateOf('youtube'), BypassHealth.degraded);
    });

    test('видит, что НЕСКОЛЬКО обходов отключились', () {
      for (final id in ['youtube', 'tiktok', 'x']) {
        BypassHealthMonitor.report(id, ok: false);
        BypassHealthMonitor.report(id, ok: false);
      }
      expect(BypassHealthMonitor.downServices.length, 3);
    });
  });

  group('AI память — per-network + персист', () {
    test('netClass различает режимы сети', () {
      expect(AiMemory.netClass(true, true), 'mobile_wl');
      expect(AiMemory.netClass(true, false), 'mobile');
      expect(AiMemory.netClass(false, false), 'wifi');
    });

    test('recordWinner/winnerFor запоминает победителя по классу сети', () {
      AiMemory.recordWinner('wifi', 'vless_xhttp');
      AiMemory.recordWinner('mobile_wl', 'vless_reality_vk');
      expect(AiMemory.winnerFor('wifi'), 'vless_xhttp');
      expect(AiMemory.winnerFor('mobile_wl'), 'vless_reality_vk');
      expect(AiMemory.winnerFor('mobile'), isNull);
    });

    test('recordLatency/rankedTypes ранжирует стратегии по скорости', () {
      const net = 'wifi_lat';
      AiMemory.recordLatency(net, 'vless_grpc_reality', 800);
      AiMemory.recordLatency(net, 'vless_xhttp', 120);
      AiMemory.recordLatency(net, 'vless_reality_vk', 350);
      // Самая быстрая — первой (xhttp 120ms < vk 350ms < grpc 800ms).
      expect(AiMemory.rankedTypes(net), ['vless_xhttp', 'vless_reality_vk', 'vless_grpc_reality']);
      expect(AiMemory.latencyFor(net, 'vless_xhttp'), 120);
      // EWMA сглаживает: повтор с бОльшим значением поднимает среднее, но плавно.
      AiMemory.recordLatency(net, 'vless_xhttp', 320);
      final smoothed = AiMemory.latencyFor(net, 'vless_xhttp')!;
      expect(smoothed, greaterThan(120));
      expect(smoothed, lessThan(320)); // не прыгает сразу на новое значение
    });

    test('rankedTypes пуст для неизученной сети', () {
      expect(AiMemory.rankedTypes('never_seen_net'), isEmpty);
    });

    test('блеклист сериализуется и восстанавливается (персист между запусками)', () {
      StrategyBlacklist.clear();
      StrategyBlacklist.markFailed('s1');
      final json = StrategyBlacklist.toJson();
      expect(json.containsKey('s1'), isTrue);
      StrategyBlacklist.clear();
      expect(StrategyBlacklist.isFailed('s1'), isFalse);
      StrategyBlacklist.restoreJson(json);
      expect(StrategyBlacklist.isFailed('s1'), isTrue); // восстановлен cooldown
    });
  });

  group('ИИ-бандит — умный скоринг + самокоррекция', () {
    setUp(() => AiMemory.resetAll());

    test('надёжность важнее сырой скорости (score = надёжн × скорость × свежесть)', () {
      // Быстрая, но нестабильная: 100мс, 1 успех и 5 провалов.
      AiMemory.recordSuccess('n', 'fast_flaky', 100);
      for (var i = 0; i < 5; i++) { AiMemory.recordFailure('n', 'fast_flaky'); }
      // Медленнее, но стабильная: 500мс, 4 успеха без провалов.
      for (var i = 0; i < 4; i++) { AiMemory.recordSuccess('n', 'slow_solid', 500); }
      // Стабильная должна встать выше — ИИ не гонится за скоростью в ущерб связи.
      expect(AiMemory.rankedTypes('n').first, 'slow_solid');
    });

    test('при равной надёжности выигрывает более быстрая', () {
      AiMemory.recordSuccess('n2', 'slow', 700);
      AiMemory.recordSuccess('n2', 'fast', 120);
      expect(AiMemory.rankedTypes('n2'), ['fast', 'slow']);
    });

    test('penalizeActive наказывает активную (последнюю успешную) руку', () {
      AiMemory.recordSuccess('n3', 'active_one', 200);
      expect(AiMemory.statsFor('n3', 'active_one')!['losses'], 0);
      AiMemory.penalizeActive(); // сигнал «живой туннель умер»
      expect(AiMemory.statsFor('n3', 'active_one')!['losses'], 1);
    });

    test('recordFailure не создаёт фантомных записей для неизвестных стратегий', () {
      AiMemory.recordFailure('n4', 'never_seen');
      expect(AiMemory.statsFor('n4', 'never_seen'), isNull);
      expect(AiMemory.rankedTypes('n4'), isEmpty);
    });

    test('провалы опускают ранее лидировавшую стратегию (самокоррекция)', () {
      // Обе стартуют одинаково быстрыми и надёжными.
      AiMemory.recordSuccess('n5', 'a', 150);
      AiMemory.recordSuccess('n5', 'b', 150);
      // «a» начинает валиться сквозь туннель — модель должна её опустить.
      for (var i = 0; i < 4; i++) { AiMemory.recordFailure('n5', 'a'); }
      expect(AiMemory.rankedTypes('n5').first, 'b');
    });

    test('EWMA-задержка сглаживает джиттер, не прыгая на новое значение', () {
      AiMemory.recordSuccess('n6', 's', 120);
      expect(AiMemory.latencyFor('n6', 's'), 120);
      AiMemory.recordSuccess('n6', 's', 320);
      final ms = AiMemory.latencyFor('n6', 's')!;
      expect(ms, greaterThan(120));
      expect(ms, lessThan(320));
    });
  });

  group('Серверный AI-каскад (mutation-программы, blueprint §4b)', () {
    setUp(() => MutationRegistry.reset());

    Map<String, dynamic> validProgram({int version = 1, int? ttl, int? expiresAt,
        int minClient = 1}) => {
      'schema': 1, 'min_client': minClient, 'version': version,
      if (ttl != null) 'ttl_seconds': ttl,
      if (expiresAt != null) 'expires_at': expiresAt,
      'by_net': {
        'wifi': [
          {'priority': 1, 'type': 'vless_xhttp', 'params': {'sni': 'vk.com'}},
          {'priority': 2, 'type': 'vless_reality_vk', 'params': {}},
        ],
      },
      'generic': [
        {'priority': 1, 'type': 'vless_grpc_reality', 'params': {}},
      ],
    };

    test('валидная программа парсится и отдаёт стратегии по классу сети', () {
      final p = MutationProgram.decode(validProgram(ttl: 3600))!;
      expect(p.isUsable, isTrue);
      final wifi = p.strategiesFor('wifi')!;
      expect(wifi.length, 2);
      expect(wifi.first.type, 'vless_xhttp');
      expect(wifi.first.params['sni'], 'vk.com');
    });

    test('нет класса сети → отдаётся generic', () {
      final p = MutationProgram.decode(validProgram(ttl: 3600))!;
      expect(p.strategiesFor('mobile')!.single.type, 'vless_grpc_reality');
    });

    test('истёкшая по TTL программа не используется (auto-expire)', () {
      final past = DateTime.now()
          .subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      final p = MutationProgram.decode(validProgram(expiresAt: past))!;
      expect(p.isExpired, isTrue);
      expect(p.isUsable, isFalse);
      expect(p.strategiesFor('wifi'), isNull);
    });

    test('программа новее клиента (min_client) отвергается', () {
      expect(MutationProgram.decode(
          validProgram(minClient: kAiCascadeSchema + 1)), isNull);
    });

    test('битый/пустой payload → null (клиент откатится на вшитый каскад)', () {
      expect(MutationProgram.decode('не map'), isNull);
      expect(MutationProgram.decode({'schema': 0}), isNull);            // нет схемы
      expect(MutationProgram.decode({'schema': 1, 'version': 1}), isNull); // пусто
      // стратегии без type отбраковываются → программа пустая → null
      expect(MutationProgram.decode({
        'schema': 1, 'version': 1,
        'generic': [{'priority': 1, 'params': {}}],
      }), isNull);
    });

    test('registry.apply: новее — заменяет, равное/старее — отклоняется', () {
      expect(MutationRegistry.apply(
          MutationProgram.decode(validProgram(version: 5, ttl: 3600))!), isTrue);
      expect(MutationRegistry.version, 5);
      // Старее — не применяется.
      expect(MutationRegistry.apply(
          MutationProgram.decode(validProgram(version: 3, ttl: 3600))!), isFalse);
      expect(MutationRegistry.version, 5);
      // Новее — применяется.
      expect(MutationRegistry.apply(
          MutationProgram.decode(validProgram(version: 9, ttl: 3600))!), isTrue);
      expect(MutationRegistry.version, 9);
      expect(MutationRegistry.active, isNotNull);
    });

    test('registry.active скрывает истёкшую программу', () {
      final past = DateTime.now()
          .subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
      // apply отклонит непригодную (истёкшую) программу.
      expect(MutationRegistry.apply(
          MutationProgram.decode(validProgram(expiresAt: past))!), isFalse);
      expect(MutationRegistry.active, isNull);
    });
  });
}
