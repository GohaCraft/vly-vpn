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

  group('Классификатор блокировок ТСПУ', () {
    test('распознаёт тип блокировки по тексту ошибки', () {
      expect(TspuCountermeasures2026.classifyError('Connection reset by peer'),
          BlockType.tcpReset);
      expect(TspuCountermeasures2026.classifyError('TLS handshake failed'),
          BlockType.tlsFingerprint);
      expect(TspuCountermeasures2026.classifyError('DNS lookup failed'),
          BlockType.dnsPoisoning);
      expect(TspuCountermeasures2026.classifyError('Operation timed out'),
          BlockType.timeout);
      expect(TspuCountermeasures2026.classifyError('Connection refused'),
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
}
