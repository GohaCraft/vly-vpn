// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports
part of 'main.dart';

class NetworkCountermeasures2026 {
  static final _rng = Random();

  // ── Детектор типа блокировки по коду ошибки ────────────────────────────────
  // Разные типы блокировок требуют разных контрмер
  static BlockType classifyError(String errorMsg) {
    final e = errorMsg.toLowerCase();
    // TCP RST — активная блокировка (DPI инжектирует RST)
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

}
