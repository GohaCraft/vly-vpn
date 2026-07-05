// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';


class BackupEngine {
  // ── НАСТОЯЩАЯ КРИПТА: AES-256-GCM + PBKDF2-HMAC-SHA256 (формат v5) ─────────
  // Раньше бэкап «шифровался» самопальным XOR (в комментарии буквально «Это не
  // AES»). Для security-инструмента это неприемлемо. Теперь: ключ растягивается
  // PBKDF2 (100k итераций HMAC-SHA256) из пароля+соли, шифрование AES-256-GCM
  // даёт и конфиденциальность, и аутентификацию (GCM-тег ловит подмену/неверный
  // пароль). Старый XOR-путь оставлен ТОЛЬКО для восстановления старых бэкапов.
  static const int _pbkdf2Iterations = 100000;
  static const int _fmtV5 = 5; // байт-версия формата AES-GCM

  static Uint8List _deriveKeyPbkdf2(String password, List<int> salt) {
    final d = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(
          Uint8List.fromList(salt), _pbkdf2Iterations, 32));
    return d.process(Uint8List.fromList(utf8.encode(password)));
  }

  // [v5(1)][salt(16)][nonce(12)][ciphertext+GCM-tag(16)]
  static List<int> _aesGcmEncrypt(List<int> data, String password) {
    final rng   = Random.secure();
    final salt  = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
    final key   = _deriveKeyPbkdf2(password, salt);
    final gcm = pc.GCMBlockCipher(pc.AESEngine())
      ..init(true, pc.AEADParameters(pc.KeyParameter(key), 128,
          Uint8List.fromList(nonce), Uint8List(0)));
    final ct = gcm.process(Uint8List.fromList(data));
    return [_fmtV5, ...salt, ...nonce, ...ct];
  }

  // null → неверный пароль / повреждение / подмена (GCM-тег не сходится).
  static List<int>? _aesGcmDecrypt(List<int> data, String password) {
    if (data.isEmpty || data[0] != _fmtV5) return null;
    if (data.length < 1 + 16 + 12 + 16) return null;
    final salt  = data.sublist(1, 17);
    final nonce = data.sublist(17, 29);
    final ct    = data.sublist(29);
    final key   = _deriveKeyPbkdf2(password, salt);
    try {
      final gcm = pc.GCMBlockCipher(pc.AESEngine())
        ..init(false, pc.AEADParameters(pc.KeyParameter(key), 128,
            Uint8List.fromList(nonce), Uint8List(0)));
      return gcm.process(Uint8List.fromList(ct));
    } catch (_) {
      return null; // InvalidCipherText: неверный пароль или подмена
    }
  }

  // ── LEGACY (XOR) — только для чтения старых бэкапов v3/v4 ──────────────────
  // Key stretching: повторяем ключ через многократное XOR + перестановки
  static List<int> _deriveKey(String password, List<int> salt) {
    if (password.isEmpty) return salt.isEmpty ? List.filled(32, 0x42) : salt;
    final pw = utf8.encode(password);
    // PBKDF2-like: 1000 итераций XOR+rotate
    var key = List<int>.from(pw + salt);
    for (int round = 0; round < 1000; round++) {
      key = List.generate(key.length, (i) {
        final prev = key[(i - 1 + key.length) % key.length];
        final next = key[(i + 1) % key.length];
        return (key[i] ^ prev ^ next ^ (round & 0xFF)) & 0xFF;
      });
    }
    // Растягиваем до 32 байт
    while (key.length < 32) key = [...key, ...key];
    return key.sublist(0, 32);
  }

  static List<int> _encrypt(List<int> data, String password) {
    // Генерируем случайный salt (16 байт)
    final rng  = Random.secure();
    final salt = List.generate(16, (_) => rng.nextInt(256));
    final key  = _deriveKey(password, salt);

    // XOR с derived key (значительно лучше простого XOR с паролем)
    final encrypted = List.generate(data.length,
        (i) => data[i] ^ key[i % key.length]);

    // Добавляем HMAC-like checksum для верификации (8 байт)
    var checksum = 0xDEADBEEF;
    for (int i = 0; i < encrypted.length; i++) {
      checksum = ((checksum << 5) ^ encrypted[i] ^ key[i % key.length]) & 0xFFFFFFFF;
    }
    final cs = [
      (checksum >> 24) & 0xFF, (checksum >> 16) & 0xFF,
      (checksum >> 8)  & 0xFF,  checksum        & 0xFF,
    ];

    // Формат: [salt(16)] [checksum(4)] [encrypted data]
    return [...salt, ...cs, ...encrypted];
  }

  static List<int>? _decrypt(List<int> data, String password) {
    if (data.length < 20) return null; // слишком короткий
    final salt      = data.sublist(0, 16);
    final cs_stored = data.sublist(16, 20);
    final encrypted = data.sublist(20);
    final key       = _deriveKey(password, salt);

    // Верифицируем checksum
    var checksum = 0xDEADBEEF;
    for (int i = 0; i < encrypted.length; i++) {
      checksum = ((checksum << 5) ^ encrypted[i] ^ key[i % key.length]) & 0xFFFFFFFF;
    }
    final cs_expected = [
      (checksum >> 24) & 0xFF, (checksum >> 16) & 0xFF,
      (checksum >> 8)  & 0xFF,  checksum        & 0xFF,
    ];
    if (!_listEq(cs_stored, cs_expected)) return null; // неверный пароль или битый файл

    return List.generate(encrypted.length,
        (i) => encrypted[i] ^ key[i % key.length]);
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  static String export(List<VlyProfile> profiles, String activeId, String password) {
    final payload = jsonEncode({
      'magic':    kBackupMagic,
      'version':  5,
      'ts':       DateTime.now().millisecondsSinceEpoch,
      'activeId': activeId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
    });
    final bytes     = utf8.encode(payload);
    final encrypted = _aesGcmEncrypt(bytes, password); // AES-256-GCM
    return base64.encode(encrypted);
  }

  static Map<String, dynamic>? import(String b64, String password) {
    try {
      final bytes = base64.decode(b64.trim());

      // Новый формат v5 (AES-GCM) — по байт-версии в начале.
      Map<String, dynamic>? _tryJson(List<int>? plain) {
        if (plain == null) return null;
        try {
          final m = jsonDecode(utf8.decode(plain));
          return (m is Map<String, dynamic> && m['magic'] == kBackupMagic) ? m : null;
        } catch (_) { return null; }
      }

      final v5 = _tryJson(_aesGcmDecrypt(bytes, password));
      if (v5 != null) return v5;

      // ── LEGACY: старые бэкапы XOR v4 (salt+checksum) и v3 (голый XOR) ──────
      final v4 = _tryJson(_decrypt(bytes, password));
      if (v4 != null) return v4;

      final key = utf8.encode(password);
      final v3  = List.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
      return _tryJson(v3);
    } catch (_) { return null; }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SIBERIA SHIELD  —  Anti-Burst Detection Engine
//  Март 2026: провайдер «Сибирская блокировка» — детектирует burst TLS соединений
//  к одному IP (3-8 handshake за <5 сек) → блокирует IP на 2 минуты
//
//  Стратегия обхода (как Durov VPN / Outline):
//  1. CONNECTION PACING — не более 1 нового TLS за 2+ сек к одному IP
//  2. SINGLE TUNNEL MUX — один TCP туннель, всё внутри него (xmux/smux)
//  3. TRAFFIC SHAPING — размер пакетов имитирует HTTPS стриминг
//  4. IP COOLDOWN — если IP заблокирован, ждём 2+ мин и ротируем
//  5. DECOY TRAFFIC — фоновые HTTP запросы к белым доменам между handshake
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  PINNED HTTP CLIENT  —  Certificate Pinning для нашего сервера
//
//  Защита от MITM: провайдер или провайдер не смогут подменить SSL-сертификат
//  и подсунуть фальшивые ноды или выключить приложение удалённо.
//
//  Применяется ТОЛЬКО к kPinnedDomains (api.vlyvpn.app).
//  Cloudflare DoH, antifilter.download, GitHub — без pinning (доверяем их цепочке).
//
//  ВАЖНО: Замени kPinnedSha256 на реальные SHA-256 когда развернёшь сервер.
//  Команда: openssl s_client -connect api.vlyvpn.app:443 |
//           openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
//           openssl dgst -sha256 -binary | base64
// ═══════════════════════════════════════════════════════════════════════════════

// HTTP-клиент с настоящим certificate pinning для наших доменов.
//
// Тонкость: HttpClient.badCertificateCallback срабатывает ТОЛЬКО для
// сертификатов, невалидных по CA. MITM с mis-issued, но валидным по CA
// сертификатом проходит стандартную проверку — поэтому пин сверяется на
// peerCertificate ОТВЕТА (после хендшейка, до чтения тела), и при
// несовпадении соединение рвётся, а данные не читаются.
//
// Пин активен только когда в kPinnedSha256 заданы реальные значения (не
// PLACEHOLDER). До появления сертификата сервера действует обычная
// CA-проверка — так пиннинг не ломает работу на этапе без сервера. Как только
// реальные пины добавлены — enforcement включается автоматически.
class PinnedHttpClient {
  static bool get _pinningActive =>
      kPinnedSha256.any((s) => s.isNotEmpty && !s.startsWith('PLACEHOLDER'));

  // Диагностика: включён ли реально enforcement пиннинга (заданы настоящие пины).
  static bool get pinningActive => _pinningActive;

  static bool _isPinnedHost(String host) =>
      kPinnedDomains.any((d) => host == d || host.endsWith('.$d'));

  // SHA-256(DER сертификата) в base64 — формат, совпадающий с kPinnedSha256.
  static String certFingerprint(X509Certificate cert) =>
      base64.encode(sha256.convert(cert.der).bytes);

  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
    bool pinOurServer = true,
  }) => _send('GET', url, headers: headers, timeout: timeout);

  static Future<http.Response> post(
    String url, {
    required String body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 5),
  }) => _send('POST', url, headers: headers, body: body, timeout: timeout);

  static Future<http.Response> _send(
    String method,
    String url, {
    Map<String, String>? headers,
    String? body,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(url);

    // Пиним ТОЛЬКО наши домены и ТОЛЬКО когда пины настроены. Иначе —
    // обычный http (прежнее поведение), чтобы ничего не сломать до сервера.
    if (!(_pinningActive && _isPinnedHost(uri.host))) {
      final hdrs = {
        'User-Agent': kStealthUA,
        if (body != null) 'Content-Type': 'application/json',
        ...?headers,
      };
      return method == 'GET'
          ? http.get(uri, headers: hdrs).timeout(timeout)
          : http.post(uri, headers: hdrs, body: body).timeout(timeout);
    }

    final client = HttpClient()..userAgent = kStealthUA;
    client.badCertificateCallback = (_, __, ___) => false; // невалидные — отклоняем
    try {
      final req = await (method == 'GET'
          ? client.getUrl(uri)
          : client.postUrl(uri)).timeout(timeout);
      req.headers.set('User-Agent', kStealthUA);
      headers?.forEach((k, v) => req.headers.set(k, v));
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(body);
      }
      final resp = await req.close().timeout(timeout);

      // ПИН-ПРОВЕРКА до чтения тела: сертификат пира обязан совпасть с пином.
      final cert = resp.certificate;
      if (cert == null || !kPinnedSha256.contains(certFingerprint(cert))) {
        throw const HandshakeException(
            'Certificate pin mismatch — возможен MITM, соединение разорвано');
      }

      final bodyStr = await resp.transform(utf8.decoder).join().timeout(timeout);
      final respHeaders = <String, String>{};
      resp.headers.forEach((k, v) => respHeaders[k] = v.join(', '));
      return http.Response(bodyStr, resp.statusCode, headers: respHeaders);
    } finally {
      client.close(force: true);
    }
  }

  // Утилита для настройки пиннинга: подключается к URL и возвращает текущий
  // отпечаток сертификата (base64 SHA-256 DER) — значение для kPinnedSha256.
  // Вызвать один раз, когда сервер поднят, и вставить результат в constants.
  static Future<String?> fetchFingerprint(String url,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final client = HttpClient()..userAgent = kStealthUA;
    client.badCertificateCallback = (_, __, ___) => false;
    try {
      final req  = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      final cert = resp.certificate;
      await resp.drain<void>();
      return cert == null ? null : certFingerprint(cert);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}