// ignore_for_file: unused_import, unused_element
part of 'main.dart';

class AuraSkin {
  final AuraSkinId id;
  final String     name;
  final String     emoji;
  final Color      accent;
  final Color      accentSecondary;
  final Color      bgDark;
  final Color      bgGradientMid;   // средний цвет радиального градиента
  final Color      bgGradientEnd;   // конец градиента
  final List<Color> blobs;

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
  }) : bgGradientMid = bgGradientMid ?? bgDark,
       bgGradientEnd = bgGradientEnd ?? bgDark;

  static const all = [
    // ── 1. MIDNIGHT ───────────────────────────────────────────────────────────
    // Бесконечная технологичная ночь. Невидимый щит в космосе.
    AuraSkin(
      id: AuraSkinId.midnight, name: 'Midnight', emoji: '🌌',
      accent:          Color(0xFF00E5FF),
      accentSecondary: Color(0xFF4FC3F7),
      bgDark:          Color(0xFF0A0A12),
      bgGradientMid:   Color(0xFF0F0F25),
      bgGradientEnd:   Color(0xFF1A1A35),
      blobs: [
        Color(0xFF1A1A35), Color(0xFF0D1B4B),
        Color(0xFF00E5FF), Color(0xFF1565C0),
        Color(0xFF0F0F25), Color(0xFF162040),
      ]),

    // ── 2. OCEAN ──────────────────────────────────────────────────────────────
    // Прохладная океанская глубина. Абсолютная чистота.
    AuraSkin(
      id: AuraSkinId.ocean, name: 'Ocean', emoji: '🌊',
      accent:          Color(0xFF00B4D8),
      accentSecondary: Color(0xFF90E0EF),
      bgDark:          Color(0xFF001F3F),
      bgGradientMid:   Color(0xFF0077A8),
      bgGradientEnd:   Color(0xFF00B4D8),
      blobs: [
        Color(0xFF001F3F), Color(0xFF0077A8),
        Color(0xFF00B4D8), Color(0xFF0096C7),
        Color(0xFF023E8A), Color(0xFF0077A8),
      ]),

    // ── 3. FOREST ─────────────────────────────────────────────────────────────
    // Тёмный мистический лес. Спокойствие + тайна.
    AuraSkin(
      id: AuraSkinId.forest, name: 'Forest', emoji: '🌿',
      accent:          Color(0xFF00E676),
      accentSecondary: Color(0xFFA3E8C8),
      bgDark:          Color(0xFF0F2419),
      bgGradientMid:   Color(0xFF13402A),
      bgGradientEnd:   Color(0xFF1E5C3A),
      blobs: [
        Color(0xFF1E5C3A), Color(0xFF13402A),
        Color(0xFF00E676), Color(0xFF00BFA5),
        Color(0xFF0F2419), Color(0xFF1B5E20),
      ]),

    // ── 4. CRIMSON ────────────────────────────────────────────────────────────
    // Мощь, страсть, контролируемая ярость. VPN как оружие.
    AuraSkin(
      id: AuraSkinId.crimson, name: 'Crimson', emoji: '🔴',
      accent:          Color(0xFFFF4D4D),
      accentSecondary: Color(0xFFFF1744),
      bgDark:          Color(0xFF1F0B0F),
      bgGradientMid:   Color(0xFF4A0F15),
      bgGradientEnd:   Color(0xFF9C1C1C),
      blobs: [
        Color(0xFF9C1C1C), Color(0xFF4A0F15),
        Color(0xFFFF4D4D), Color(0xFFBF360C),
        Color(0xFF7F0000), Color(0xFF4A0010),
      ]),

    // ── 5. SUNSET ─────────────────────────────────────────────────────────────
    // Тёплый вечер премиум-уровня. Расслабление.
    AuraSkin(
      id: AuraSkinId.sunset, name: 'Sunset', emoji: '🌅',
      accent:          Color(0xFFFF5E00),
      accentSecondary: Color(0xFFFF4D94),
      bgDark:          Color(0xFF2C1B4D),
      bgGradientMid:   Color(0xFFFF4D94),
      bgGradientEnd:   Color(0xFFFF5E00),
      blobs: [
        Color(0xFFFF5E00), Color(0xFFFF4D94),
        Color(0xFF2C1B4D), Color(0xFFE65100),
        Color(0xFF7B3300), Color(0xFF4A1800),
      ]),

    // ── 6. VIOLET ─────────────────────────────────────────────────────────────
    // Загадочная магия и утончённая элегантность.
    AuraSkin(
      id: AuraSkinId.violet, name: 'Violet', emoji: '💜',
      accent:          Color(0xFFC8A2E0),
      accentSecondary: Color(0xFFE0C6FF),
      bgDark:          Color(0xFF2C0F4D),
      bgGradientMid:   Color(0xFF6B3A9C),
      bgGradientEnd:   Color(0xFF9B59B6),
      blobs: [
        Color(0xFF6B3A9C), Color(0xFF2C0F4D),
        Color(0xFFC8A2E0), Color(0xFF4A0080),
        Color(0xFF2A0050), Color(0xFF6A1B9A),
      ]),

    // ── 7. ROSE GOLD ──────────────────────────────────────────────────────────
    // Люксовый, дорогой, слегка женственный хайтек.
    AuraSkin(
      id: AuraSkinId.rose, name: 'Rose Gold', emoji: '🌸',
      accent:          Color(0xFFE8B8A0),
      accentSecondary: Color(0xFFFFF0E0),
      bgDark:          Color(0xFF2C1C24),
      bgGradientMid:   Color(0xFFC68A7A),
      bgGradientEnd:   Color(0xFFE8B8A0),
      blobs: [
        Color(0xFFE8B8A0), Color(0xFFC68A7A),
        Color(0xFF2C1C24), Color(0xFFF48FB1),
        Color(0xFF6A0030), Color(0xFF880E4F),
      ]),

    // ── 8. AURORA (северное сияние) ───────────────────────────────────────────
    // Северное сияние в цифровом измерении. Волшебно и технологично.
    AuraSkin(
      id: AuraSkinId.aurora, name: 'Aurora', emoji: '🧊',
      accent:          Color(0xFF00FF9F),
      accentSecondary: Color(0xFF9B5DE5),
      bgDark:          Color(0xFF0B0E1F),
      bgGradientMid:   Color(0xFF0B0E1F),
      bgGradientEnd:   Color(0xFF0B0E1F),
      blobs: [
        Color(0xFF00FF9F), Color(0xFF9B5DE5),
        Color(0xFF00D4FF), Color(0xFF1C2D3F),
        Color(0xFF005F4B), Color(0xFF3D1C96),
      ]),

    // ── 9. MATRIX ─────────────────────────────────────────────────────────────
    // Чистый киберпанк 2026. Цифровой дождь.
    AuraSkin(
      id: AuraSkinId.matrix, name: 'Matrix', emoji: '🟩',
      accent:          Color(0xFF00FF41),
      accentSecondary: Color(0xFF00CC33),
      bgDark:          Color(0xFF0A0A0A),
      bgGradientMid:   Color(0xFF003311),
      bgGradientEnd:   Color(0xFF003311),
      blobs: [
        Color(0xFF003311), Color(0xFF001500),
        Color(0xFF00FF41), Color(0xFF008F11),
        Color(0xFF002800), Color(0xFF004D1A),
      ]),

    // ── 10. GALAXY ────────────────────────────────────────────────────────────
    // Бесконечный космос. Глубина и величие.
    AuraSkin(
      id: AuraSkinId.galaxy, name: 'Galaxy', emoji: '🌌',
      accent:          Color(0xFF7C4DFF),
      accentSecondary: Color(0xFFB388FF),
      bgDark:          Color(0xFF0A0A1F),
      bgGradientMid:   Color(0xFF2E1A4D),
      bgGradientEnd:   Color(0xFF1A0A3D),
      blobs: [
        Color(0xFF6B2E8C), Color(0xFF2E8C9C),
        Color(0xFF7C4DFF), Color(0xFF3D1C96),
        Color(0xFF1A0040), Color(0xFF2D0060),
      ]),

    // ── 11. CARBON ────────────────────────────────────────────────────────────
    // Промышленный премиум-минимализм. Прочность и надёжность.
    AuraSkin(
      id: AuraSkinId.carbon, name: 'Carbon', emoji: '⚫',
      accent:          Color(0xFF5C5C5C),
      accentSecondary: Color(0xFF9E9E9E),
      bgDark:          Color(0xFF161616),
      bgGradientMid:   Color(0xFF1E1E1E),
      bgGradientEnd:   Color(0xFF2A2A2A),
      blobs: [
        Color(0xFF2A2A2A), Color(0xFF1E1E1E),
        Color(0xFF5C5C5C), Color(0xFF424242),
        Color(0xFF333333), Color(0xFF1A1A1A),
      ]),

    // ── 12. SAKURA ────────────────────────────────────────────────────────────
    // Нежная японская эстетика + высокие технологии.
    AuraSkin(
      id: AuraSkinId.sakura, name: 'Sakura', emoji: '🌸',
      accent:          Color(0xFFFFB5D8),
      accentSecondary: Color(0xFFFFE0E9),
      bgDark:          Color(0xFF2C1324),
      bgGradientMid:   Color(0xFF3D1A2E),
      bgGradientEnd:   Color(0xFF4A2038),
      blobs: [
        Color(0xFFFF9EC1), Color(0xFFFFB5D8),
        Color(0xFF2C1324), Color(0xFFAD1457),
        Color(0xFF880E4F), Color(0xFF6A0030),
      ]),

    // ── 13. DARK (чистая тёмная) ──────────────────────────────────────────────
    // Максимально чисто и профессионально. Ноль лишнего.
    AuraSkin(
      id: AuraSkinId.gold, name: 'Dark', emoji: '⬛',
      accent:          Color(0xFF424242),
      accentSecondary: Color(0xFF616161),
      bgDark:          Color(0xFF121212),
      bgGradientMid:   Color(0xFF1A1A1A),
      bgGradientEnd:   Color(0xFF242424),
      blobs: [
        Color(0xFF1A1A1A), Color(0xFF242424),
        Color(0xFF2C2C2C), Color(0xFF333333),
        Color(0xFF1E1E1E), Color(0xFF2A2A2A),
      ]),
  ];

  static AuraSkin byId(AuraSkinId id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

// Применить скин — обновляет глобальные переменные цвета
void _applySkin(AuraSkin skin) {
  _accent     = skin.accent;
  _accentBlue = skin.accentSecondary;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AURA SKIN SYSTEM  v6.1
// ═══════════════════════════════════════════════════════════════════════════════
enum AuraTheme { dark, light, system }
