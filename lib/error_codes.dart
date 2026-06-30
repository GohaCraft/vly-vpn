// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';


// ═══════════════════════════════════════════════════════════════
//  ERROR CODES
// ═══════════════════════════════════════════════════════════════

enum VlyErrorCode {
  // ── Подключение ──────────────────────────────────────────────────────────
  e1001('E-1001', 'Permission denied',        'VPN permission denied. Settings → Apps → Vly VPN → Permissions.'),
  e1002('E-1002', 'Connection timeout',       'VPN tunnel failed. Server may be down or DPI-blocked.'),
  e1003('E-1003', 'Config empty',             'getFullConfiguration() returned empty. Re-import this node.'),
  e1004('E-1004', 'Config parse error',       'Node config is malformed JSON. Try re-importing.'),
  e1005('E-1005', 'Network unreachable',      'No internet. Check WiFi or mobile data.'),
  e1006('E-1006', 'TLS handshake failed',     'TLS/Reality rejected by DPI. РКН blocking this node.'),
  e1007('E-1007', 'Protocol rejected',        'Server rejected protocol. Try WS or gRPC transport.'),
  e1008('E-1008', 'Port blocked',             'Port blocked by ISP. Try port 443 or 2053.'),
  e1009('E-1009', 'DNS poisoned',             'DNS intercepted. DoH enforced on next connect.'),
  e1010('E-1010', 'Kill Switch triggered',    'VPN dropped. Kill Switch blocked traffic to protect IP.'),
  // ── Stealth Engine ────────────────────────────────────────────────────────
  e1011('E-1011', 'SNI pool exhausted',       'All 15 SNI domains blocked. Update app or add custom nodes.'),
  e1012('E-1012', 'Fragment failed',          'TLS fragment injection failed. VPN started without fragmentation.'),
  e1013('E-1013', 'Warm-up timeout',          'Pre-connect warm-up timed out (3s). Slow network.'),
  e1014('E-1014', 'Reality pbk missing',      'VLESS+Reality node has no publicKey. Node misconfigured.'),
  e1015('E-1015', 'uTLS fingerprint error',   'Cannot apply uTLS fingerprint. Using default fp.'),
  e1016('E-1016', 'pickLiveSni timeout',      'All SNI probes timed out (4s). Using fallback SNI.'),
  e1017('E-1017', 'patchConfig failed',       'Config patching threw exception. VPN used original config.'),
  e1018('E-1018', 'Routing build failed',     'Russia routing rules failed. Using IPv6-block only.'),
  e1019('E-1019', 'Telegram Protocol error',  'TG Fast Protocol config threw. Connected without TG opt.'),
  e1020('E-1020', 'V2Ray engine crash',       'v2ray-core crashed. Engine restarting. Reinstall if persists.'),
  // ── Siberia Shield ────────────────────────────────────────────────────────
  e1021('E-1021', 'Siberia burst detected',   'IP burst-blocked by РКН. Cooldown 3 min. Switching node.'),
  e1022('E-1022', 'Pacing overflow',          'Connection pacing queue full. Shield temporarily bypassed.'),
  e1023('E-1023', 'Decoy failed',             'Pre-connect decoy request failed. No internet to check sites.'),
  e1024('E-1024', 'applyToConfig error',      'SiberiaShield.applyToConfig threw. mux not applied.'),
  // ── Bypass & AI ───────────────────────────────────────────────────────────
  e1025('E-1025', 'Block type unknown',       'BlockDetector returned none. New РКН method or unstable net.'),
  e1026('E-1026', 'All strategies failed',    'All 100 bypass strategies + 60 node rotations failed.'),
  e1027('E-1027', 'Bypass probe error',       'BypassProber TCP+TLS probe threw exception.'),
  e1028('E-1028', 'Strategy apply error',     'applyStrategy() threw. Node link may be malformed.'),
  e1029('E-1029', 'Arsenal empty',            'BypassArsenal returned 0 strategies for this block type.'),
  e1030('E-1030', 'Bypass loop limit',        'Retry limit (20 attempts) reached. Manual action needed.'),
  e1031('E-1031', 'Strategy deprecated',      'Strategy marked broken by NewsAwareness. Skipped.'),
  // ── Подписки & данные ─────────────────────────────────────────────────────
  e1032('E-1032', 'Subscription failed',      'Cannot download sub. Check URL, internet, or sub expiry.'),
  e1033('E-1033', 'Subscription empty',       'Sub returned 0 nodes. URL may be expired or invalid.'),
  e1034('E-1034', 'Subscription parse error', 'Sub format unknown. Expected base64 or plain vless list.'),
  e1035('E-1035', 'Rules sync failed',        'Bypass rules server unreachable. Using cached rules.'),
  e1036('E-1036', 'Domain list failed',       'antifilter.download down. Using built-in domain list.'),
  e1037('E-1037', 'Dead drop exhausted',      'All mirrors (GitHub, DNS TXT) failed. Import nodes manually.'),
  // ── Хранилище ─────────────────────────────────────────────────────────────
  e1038('E-1038', 'Save failed',              'Cannot write settings. Check storage space (need >10MB).'),
  e1039('E-1039', 'Backup export failed',     'Cannot create backup. Check storage permissions.'),
  e1040('E-1040', 'Backup import failed',     'Cannot restore. Wrong password or corrupted file.'),
  e1041('E-1041', 'Profile corrupted',        'Profile data broken. Default profile restored.'),
  e1042('E-1042', 'Deobfuscation failed',     'Cannot read stored profiles. Re-import your nodes.'),
  // ── Нативный слой ─────────────────────────────────────────────────────────
  e1043('E-1043', 'VPN permission revoked',   'VPN permission revoked while connected. Reconnect to restore.'),
  e1044('E-1044', 'Notification failed',      'Cannot show persistent VPN notification. Android restriction.'),
  e1045('E-1045', 'Tile update failed',       'Quick Settings tile update failed. Minor UI issue only.'),
  e1046('E-1046', 'File read error',          'Cannot read selected file. Try copy-paste instead.'),
  e1047('E-1047', 'QR parse failed',          'QR code has no valid VPN config. Need vless/vmess/ss link.'),
  e1048('E-1048', 'Clipboard empty',          'Clipboard is empty. Copy a vless:// link first.'),
  e1049('E-1049', 'IP check failed',          'All IP APIs (ipapi.co / ip-api.com / ipwho.is) failed.'),
  e1050('E-1050', 'Watchdog timeout',         'VPN did not reach CONNECTED in 30s. Watchdog fired bypass.'),
  // ── Whitelist Bypass (04.04.2026) ─────────────────────────────────────────
  e1051('E-1051', 'Whitelist active',         'Mobile whitelist detected. Only gov/CDN IPs allowed. Domain fronting applied.'),
  e1052('E-1052', 'Domain fronting failed',   'All whitelist endpoints blocked. ISP blocking gov portals too.'),
  e1053('E-1053', 'Endpoint probe timeout',   'Whitelist endpoint probe timed out (3s). Slow network or partial block.'),
  // ── TSPU Bypass Window ─────────────────────────────────────────────────────
  e1054('E-1054', 'TSPU bypass detected',     'TSPU overloaded (40K+ rules). Direct connection possible without stealth.'),
  e1055('E-1055', 'TSPU bypass ended',        'TSPU recovered. Switching back to stealth mode.'),
  e1056('E-1056', 'Bypass window missed',     'TSPU bypass ended during connection. Reconnecting with stealth.'),
  // ── Adaptive Mimicry ───────────────────────────────────────────────────────
  e1057('E-1057', 'Persona generation failed','Cannot generate digital persona. Using default browser fingerprint.'),
  e1058('E-1058', 'Behavioral delay error',   'Behavioral delay interrupted. ML-DPI may detect uniform traffic.'),
  e1059('E-1059', 'Network profile error',    'Cannot apply network profile (MTU/TTL). Using OS defaults.'),
  // ── MTProxy Fallback ───────────────────────────────────────────────────────
  e1060('E-1060', 'MTProxy DC unreachable',   'Telegram MTProxy DC timed out. Trying next DC.'),
  e1061('E-1061', 'All MTProxy DCs blocked',  'All 5 Telegram DCs blocked. TSPU targeting MTProxy specifically.'),
  e1062('E-1062', 'Fake TLS rejected',        'MTProxy Fake TLS rejected by DPI. Telegram CDN pattern detected.'),
  // ── News Awareness (04.04.2026) ────────────────────────────────────────────
  e1063('E-1063', 'Yandex/VK/Sber blocked',   'Yandex/VK/Sber now helping MinTsifry block VPN. Endpoints removed.'),
  e1064('E-1064', 'Gov portals still open',   'Gosuslugi/FNS/SFR still in whitelist. Using these for domain fronting.'),
  e1065('E-1065', 'CDN endpoints active',     'Cloudflare/AWS/Fastly still neutral. Domain fronting via international CDN.'),

  // ── QUIC/HTTP3 (04.04.2026) ────────────────────────────────────────────────
  e1066('E-1066', 'QUIC blocked',             'QUIC/UDP blocked by ISP. Falling back to TCP/TLS.'),
  e1067('E-1067', 'HTTP3 tunnel failed',      'CDN edge relay unreachable. QUIC tunnel failed.'),
  e1068('E-1068', 'ALPN mismatch',            'HTTP/3 ALPN negotiation failed. Server does not support h3.'),
  // ── Residential IP ──────────────────────────────────────────────────────────
  e1069('E-1069', 'Datacenter IP detected',   'Server IP is from datacenter ASN. High risk of blocking.'),
  e1070('E-1070', 'Residential IP check fail','Cannot verify IP type. Using IP reputation databases.'),
  e1071('E-1071', 'IP blacklisted',           'Server IP found in RKN VPN blacklist. Switch node needed.'),
  // ── VPN Tariff / 15GB Limit ────────────────────────────────────────────────
  e1072('E-1072', 'Traffic limit warning',    'Approaching 15GB monthly limit. Operator may charge extra.'),
  e1073('E-1073', 'International traffic fee', 'VPN traffic classified as international. Extra fees apply.'),
  e1074('E-1074', 'Traffic shaping detected', 'ISP throttling VPN speed. Possible tariff enforcement.'),
  // ── Platform VPN Blocking ──────────────────────────────────────────────────
  e1075('E-1075', 'Platform blocking VPN',    'Service (Yandex/VK/WB) detecting and blocking VPN users.'),
  e1076('E-1076', 'White list platform block','Platform in whitelist must block VPN. Switch to direct.'),
  // ── Smart VPN Timer ────────────────────────────────────────────────────────
  e1077('E-1077', 'Smart timer auto-off',     'VPN auto-disconnected after 15min idle. Saves traffic limit.'),
  e1078('E-1078', 'App-specific VPN mode',    'VPN active only for selected apps. Other traffic goes direct.'),
  // ── Kill Switch v2 ─────────────────────────────────────────────────────────
  e1079('E-1079', 'Kill Switch v2 activated', 'ALL traffic blocked on VPN drop. IPv6/WebRTC/DNS killed.'),
  e1080('E-1080', 'IPv6 leak blocked',        'IPv6 traffic blocked to prevent leaks.'),
  e1081('E-1081', 'WebRTC leak blocked',      'WebRTC disabled to prevent local IP exposure.'),
  // ── App Store Obfuscation ──────────────────────────────────────────────────
  e1082('E-1082', 'Stealth mode active',      'App disguised as utility. VPN keywords hidden from UI.'),
  e1083('E-1083', 'App Store detection risk', 'VPN-related keywords detected in app. Risk of removal.');

  final String code, title, description;
  const VlyErrorCode(this.code, this.title, this.description);

  /// Lookup по коду — для диагностики в логах
  static VlyErrorCode? fromCode(String code) {
    try { return VlyErrorCode.values.firstWhere((e) => e.code == code); }
    catch (_) { return null; }
  }

  /// Быстрый маппинг событий → коды для _log
  static String codeFor(String event) {
    const map = {
      'permission':  'E-1001', 'timeout':      'E-1002', 'empty_config': 'E-1003',
      'parse':       'E-1004', 'network':       'E-1005', 'tls':         'E-1006',
      'protocol':    'E-1007', 'port':          'E-1008', 'dns':         'E-1009',
      'kill_switch': 'E-1010', 'sni':           'E-1011', 'fragment':    'E-1012',
      'warmup':      'E-1013', 'pbk':           'E-1014', 'utls':        'E-1015',
      'live_sni':    'E-1016', 'patch':         'E-1017', 'routing':     'E-1018',
      'telegram':    'E-1019', 'v2ray_crash':   'E-1020', 'siberia':     'E-1021',
      'bypass':      'E-1026', 'probe':         'E-1027', 'sub':         'E-1032',
      'save':        'E-1038', 'backup':        'E-1039', 'profile':     'E-1041',
      'watchdog':    'E-1050', 'whitelist':     'E-1051', 'tspu_bypass': 'E-1054',
      'mimicry':     'E-1057', 'mtproxy':       'E-1060', 'news':        'E-1063',
    };
    return map[event] ?? 'E-0000';
  }
}

Future<void> showVlyError(BuildContext ctx, VlyErrorCode err, List<String> logs) async {
  if (!ctx.mounted) return;
  final logText = logs.join('\n');
  await showDialog(
    context: ctx,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1226),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
              child: Text(err.code, style: const TextStyle(
                  fontSize: 11, color: Colors.redAccent,
                  fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
            const SizedBox(width: 10),
            Expanded(child: Text(err.title,
                style: const TextStyle(fontSize: 14, color: Colors.white,
                    fontWeight: FontWeight.w700))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(err.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
              const SizedBox(height: 10),
              Text(kSupportEmail,
                  style: TextStyle(fontSize: 11, color: _accent,
                      decoration: TextDecoration.underline)),
            ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: '[${err.code}]\n$logText'));
                Navigator.pop(c);
              },
              child: Text(S.t('download_log'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12))),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(S.t('ok'),
                  style: TextStyle(color: _accent, fontWeight: FontWeight.bold))),
          ],
        ),  // AlertDialog
      ),    // ConstrainedBox
    ),      // Dialog
  );
}


// ═══════════════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
//  VLY SKIN SYSTEM  v5.3
//  Скины меняют акцентный цвет + градиенты блобов + тинт карточек
// ═══════════════════════════════════════════════════════════════════════════════

enum VlySkinId {
  midnight,  // дефолт — циан
  ocean,     // синий
  forest,    // зелёный
  crimson,   // красный
  sunset,    // оранжевый
  aurora,    // Nord — ледяной северный
  matrix,    // зелёный на чёрном
  galaxy,    // фиолетово-синий космос
  carbon,    // тёмно-серый минимализм
  sakura,    // розово-белая светлая тема
  custom,    // пользовательская темавый
  violet,    // фиолетовый
  rose,      // розовый
  gold,      // золотой
}
