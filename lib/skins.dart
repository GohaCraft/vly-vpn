// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

// Тип узора фона
enum SkinPattern {
  none,       // без узора
  dots,       // точки
  grid,       // сетка
  hex,        // гексагоны
  circuit,    // схема / кибerpunk
  stars,      // звёзды
  waves,      // волны
  particles,  // частицы
}

extension SkinPatternInfo on SkinPattern {
  String get label {
    switch (this) {
      case SkinPattern.none:     return 'Нет';
      case SkinPattern.dots:     return 'Точки';
      case SkinPattern.grid:     return 'Сетка';
      case SkinPattern.hex:      return 'Гексы';
      case SkinPattern.circuit:  return 'Схема';
      case SkinPattern.stars:    return 'Звёзды';
      case SkinPattern.waves:    return 'Волны';
      case SkinPattern.particles:return 'Частицы';
    }
  }
  String get emoji {
    switch (this) {
      case SkinPattern.none:     return '○';
      case SkinPattern.dots:     return '·';
      case SkinPattern.grid:     return '⊞';
      case SkinPattern.hex:      return '⬡';
      case SkinPattern.circuit:  return '⚡';
      case SkinPattern.stars:    return '★';
      case SkinPattern.waves:    return '≋';
      case SkinPattern.particles:return '✦';
    }
  }
}

class AuraSkin {
  final AuraSkinId    id;
  final String        name;
  final String        emoji;
  final Color         accent;
  final Color         accentSecondary;
  final Color         bgDark;
  final Color         bgGradientMid;
  final Color         bgGradientEnd;
  final List<Color>   blobs;
  final SkinPattern   pattern;       // узор поверх фона
  final double        patternOpacity; // прозрачность узора 0.0-1.0
  final Color         glassAccent;   // iOS 26 Liquid Glass tint цвет
  final double        glassBlur;     // Blur strength для этой темы

  const AuraSkin({
    required this.id,
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accentSecondary,
    required this.bgDark,
    Color? bgGradientMid,
    Color? bgGradientEnd,
    required this.blobs,
    this.pattern        = SkinPattern.none,
    this.patternOpacity = 0.06,
    Color? glassAccent,
    this.glassBlur      = 40.0,
  }) : bgGradientMid = bgGradientMid ?? bgDark,
       bgGradientEnd = bgGradientEnd ?? bgDark,
       glassAccent   = glassAccent ?? accent;

  static const all = [
    // 1. MIDNIGHT — звёздное небо
    AuraSkin(
      id: AuraSkinId.midnight, name: 'Midnight', emoji: '🌌',
      accent: Color(0xFF00E5FF), accentSecondary: Color(0xFF4FC3F7),
      bgDark: Color(0xFF050610), bgGradientMid: Color(0xFF0A0A20), bgGradientEnd: Color(0xFF0F0F30),
      blobs: [Color(0xFF1A1A35), Color(0xFF0D1B4B), Color(0xFF00E5FF), Color(0xFF1565C0), Color(0xFF0F0F25), Color(0xFF162040)],
      pattern: SkinPattern.stars, patternOpacity: 0.5),

    // 2. OCEAN — волны и пузыри
    AuraSkin(
      id: AuraSkinId.ocean, name: 'Ocean', emoji: '🌊',
      accent: Color(0xFF00B4D8), accentSecondary: Color(0xFF90E0EF),
      bgDark: Color(0xFF001828), bgGradientMid: Color(0xFF005580), bgGradientEnd: Color(0xFF0096B4),
      blobs: [Color(0xFF001F3F), Color(0xFF0077A8), Color(0xFF00B4D8), Color(0xFF0096C7), Color(0xFF023E8A), Color(0xFF0077A8)],
      pattern: SkinPattern.waves, patternOpacity: 0.12),

    // 3. FOREST — точки как светлячки
    AuraSkin(
      id: AuraSkinId.forest, name: 'Forest', emoji: '🌿',
      accent: Color(0xFF00E676), accentSecondary: Color(0xFFA3E8C8),
      bgDark: Color(0xFF081510), bgGradientMid: Color(0xFF0F2A1A), bgGradientEnd: Color(0xFF1A4A2A),
      blobs: [Color(0xFF1E5C3A), Color(0xFF13402A), Color(0xFF00E676), Color(0xFF00BFA5), Color(0xFF0F2419), Color(0xFF1B5E20)],
      pattern: SkinPattern.particles, patternOpacity: 0.35),

    // 4. CRIMSON — схема / оружие
    AuraSkin(
      id: AuraSkinId.crimson, name: 'Crimson', emoji: '🔴',
      accent: Color(0xFFFF4D4D), accentSecondary: Color(0xFFFF1744),
      bgDark: Color(0xFF130508), bgGradientMid: Color(0xFF380A0E), bgGradientEnd: Color(0xFF7A1515),
      blobs: [Color(0xFF9C1C1C), Color(0xFF4A0F15), Color(0xFFFF4D4D), Color(0xFFBF360C), Color(0xFF7F0000), Color(0xFF4A0010)],
      pattern: SkinPattern.circuit, patternOpacity: 0.10),

    // 5. SUNSET — тёплые волны
    AuraSkin(
      id: AuraSkinId.sunset, name: 'Sunset', emoji: '🌅',
      accent: Color(0xFFFF6B35), accentSecondary: Color(0xFFFF4D94),
      bgDark: Color(0xFF1A0A20), bgGradientMid: Color(0xFF6B1535), bgGradientEnd: Color(0xFFCC3D00),
      blobs: [Color(0xFFFF5E00), Color(0xFFFF4D94), Color(0xFF2C1B4D), Color(0xFFE65100), Color(0xFF7B3300), Color(0xFF4A1800)],
      pattern: SkinPattern.waves, patternOpacity: 0.08),

    // 6. VIOLET — магический вихрь
    AuraSkin(
      id: AuraSkinId.violet, name: 'Violet', emoji: '💜',
      accent: Color(0xFFCE93D8), accentSecondary: Color(0xFFE1BEE7),
      bgDark: Color(0xFF180830), bgGradientMid: Color(0xFF4A2070), bgGradientEnd: Color(0xFF7B3FA0),
      blobs: [Color(0xFF6B3A9C), Color(0xFF2C0F4D), Color(0xFFC8A2E0), Color(0xFF4A0080), Color(0xFF2A0050), Color(0xFF6A1B9A)],
      pattern: SkinPattern.particles, patternOpacity: 0.25),

    // 7. ROSE GOLD — тонкая сетка
    AuraSkin(
      id: AuraSkinId.rose, name: 'Rose Gold', emoji: '🌸',
      accent: Color(0xFFE8B8A0), accentSecondary: Color(0xFFFFF0E0),
      bgDark: Color(0xFF1A0D14), bgGradientMid: Color(0xFF8B5A4A), bgGradientEnd: Color(0xFFD4907A),
      blobs: [Color(0xFFE8B8A0), Color(0xFFC68A7A), Color(0xFF2C1C24), Color(0xFFF48FB1), Color(0xFF6A0030), Color(0xFF880E4F)],
      pattern: SkinPattern.dots, patternOpacity: 0.10),

    // 8. AURORA — северное сияние (звёзды + частицы)
    AuraSkin(
      id: AuraSkinId.aurora, name: 'Aurora', emoji: '🧊',
      accent: Color(0xFF00FF9F), accentSecondary: Color(0xFF9B5DE5),
      bgDark: Color(0xFF050812), bgGradientMid: Color(0xFF050812), bgGradientEnd: Color(0xFF050812),
      blobs: [Color(0xFF00FF9F), Color(0xFF9B5DE5), Color(0xFF00D4FF), Color(0xFF1C2D3F), Color(0xFF005F4B), Color(0xFF3D1C96)],
      pattern: SkinPattern.stars, patternOpacity: 0.45),

    // 9. MATRIX — сетка / цифровой дождь
    AuraSkin(
      id: AuraSkinId.matrix, name: 'Matrix', emoji: '🟩',
      accent: Color(0xFF00FF41), accentSecondary: Color(0xFF00CC33),
      bgDark: Color(0xFF020502), bgGradientMid: Color(0xFF051205), bgGradientEnd: Color(0xFF051205),
      blobs: [Color(0xFF003311), Color(0xFF001500), Color(0xFF00FF41), Color(0xFF008F11), Color(0xFF002800), Color(0xFF004D1A)],
      pattern: SkinPattern.circuit, patternOpacity: 0.18),

    // 10. GALAXY — звёзды и туманности
    AuraSkin(
      id: AuraSkinId.galaxy, name: 'Galaxy', emoji: '✨',
      accent: Color(0xFF7C4DFF), accentSecondary: Color(0xFFB388FF),
      bgDark: Color(0xFF030310), bgGradientMid: Color(0xFF1A0838), bgGradientEnd: Color(0xFF120528),
      blobs: [Color(0xFF6B2E8C), Color(0xFF2E8C9C), Color(0xFF7C4DFF), Color(0xFF3D1C96), Color(0xFF1A0040), Color(0xFF2D0060)],
      pattern: SkinPattern.stars, patternOpacity: 0.55),

    // 11. CARBON — гексагоны
    AuraSkin(
      id: AuraSkinId.carbon, name: 'Carbon', emoji: '⚫',
      accent: Color(0xFF757575), accentSecondary: Color(0xFFBDBDBD),
      bgDark: Color(0xFF0E0E0E), bgGradientMid: Color(0xFF181818), bgGradientEnd: Color(0xFF222222),
      blobs: [Color(0xFF2A2A2A), Color(0xFF1E1E1E), Color(0xFF5C5C5C), Color(0xFF424242), Color(0xFF333333), Color(0xFF1A1A1A)],
      pattern: SkinPattern.hex, patternOpacity: 0.12),

    // 12. SAKURA — цветущие точки
    AuraSkin(
      id: AuraSkinId.sakura, name: 'Sakura', emoji: '🌺',
      accent: Color(0xFFFFB5D8), accentSecondary: Color(0xFFFFE0E9),
      bgDark: Color(0xFF180B16), bgGradientMid: Color(0xFF2E1022), bgGradientEnd: Color(0xFF3D1530),
      blobs: [Color(0xFFFF9EC1), Color(0xFFFFB5D8), Color(0xFF2C1324), Color(0xFFAD1457), Color(0xFF880E4F), Color(0xFF6A0030)],
      pattern: SkinPattern.particles, patternOpacity: 0.30),

    // 13. DARK — минимализм без узора
    AuraSkin(
      id: AuraSkinId.gold, name: 'Dark', emoji: '⬛',
      accent: Color(0xFF616161), accentSecondary: Color(0xFF9E9E9E),
      bgDark: Color(0xFF0A0A0A), bgGradientMid: Color(0xFF141414), bgGradientEnd: Color(0xFF1E1E1E),
      blobs: [Color(0xFF1A1A1A), Color(0xFF242424), Color(0xFF2C2C2C), Color(0xFF333333), Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
      pattern: SkinPattern.none, patternOpacity: 0.0),
  ];

  static AuraSkin byId(AuraSkinId id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

void _applySkin(AuraSkin skin) {
  _accent     = skin.accent;
  _accentBlue = skin.accentSecondary;
}

enum AuraTheme { dark, light, system }