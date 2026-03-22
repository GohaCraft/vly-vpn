// ignore_for_file: unused_import, unused_element
part of 'main.dart';

class AuraSkin {
  final AuraSkinId id;
  final String     name;
  final String     emoji;
  final Color      accent;
  final Color      accentSecondary;
  final Color      bgDark;
  final List<Color> blobs;

  const AuraSkin({
    required this.id,
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accentSecondary,
    required this.bgDark,
    required this.blobs,
  });

  static const all = [
    AuraSkin(
      id: AuraSkinId.midnight, name: 'Midnight', emoji: '🌌',
      accent: Color(0xFF00E5FF), accentSecondary: Color(0xFF4FC3F7),
      bgDark: Color(0xFF050610),
      blobs: [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF00E5FF), Color(0xFF1565C0)]),
    AuraSkin(
      id: AuraSkinId.ocean, name: 'Ocean', emoji: '🌊',
      accent: Color(0xFF2979FF), accentSecondary: Color(0xFF448AFF),
      bgDark: Color(0xFF020814),
      blobs: [Color(0xFF0D1B4B), Color(0xFF1A237E), Color(0xFF2979FF), Color(0xFF0277BD)]),
    AuraSkin(
      id: AuraSkinId.forest, name: 'Forest', emoji: '🌿',
      accent: Color(0xFF00E676), accentSecondary: Color(0xFF69FF47),
      bgDark: Color(0xFF020A05),
      blobs: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00E676), Color(0xFF00BFA5)]),
    AuraSkin(
      id: AuraSkinId.crimson, name: 'Crimson', emoji: '🔴',
      accent: Color(0xFFFF1744), accentSecondary: Color(0xFFFF5252),
      bgDark: Color(0xFF0A0204),
      blobs: [Color(0xFF4A0010), Color(0xFF7F0000), Color(0xFFFF1744), Color(0xFFBF360C)]),
    AuraSkin(
      id: AuraSkinId.sunset, name: 'Sunset', emoji: '🌅',
      accent: Color(0xFFFF6D00), accentSecondary: Color(0xFFFFAB40),
      bgDark: Color(0xFF0A0500),
      blobs: [Color(0xFF4A1800), Color(0xFF7B3300), Color(0xFFFF6D00), Color(0xFFE65100)]),
    AuraSkin(
      id: AuraSkinId.violet, name: 'Violet', emoji: '💜',
      accent: Color(0xFFD500F9), accentSecondary: Color(0xFFE040FB),
      bgDark: Color(0xFF080410),
      blobs: [Color(0xFF2A0050), Color(0xFF4A0080), Color(0xFFD500F9), Color(0xFF6A1B9A)]),
    AuraSkin(
      id: AuraSkinId.rose, name: 'Rose', emoji: '🌸',
      accent: Color(0xFFFF4081), accentSecondary: Color(0xFFFF80AB),
      bgDark: Color(0xFF0A0308),
      blobs: [Color(0xFF4A0020), Color(0xFF880E4F), Color(0xFFFF4081), Color(0xFFC2185B)]),
    AuraSkin(
      id: AuraSkinId.gold, name: 'Gold', emoji: '✨',
      accent: Color(0xFFFFD740), accentSecondary: Color(0xFFFFE57F),
      bgDark: Color(0xFF08070A),
      blobs: [Color(0xFF3E2800), Color(0xFF5D4037), Color(0xFFFFD740), Color(0xFFFF8F00)]),
    // ── Новые темы ────────────────────────────────────────────────────────────
    AuraSkin(
      id: AuraSkinId.aurora, name: 'Aurora', emoji: '🧊',
      accent: Color(0xFF88C0D0), accentSecondary: Color(0xFF81A1C1),
      bgDark: Color(0xFF0D1117),
      blobs: [Color(0xFF1C2D3F), Color(0xFF243447), Color(0xFF88C0D0), Color(0xFF5E81AC)]),
    AuraSkin(
      id: AuraSkinId.matrix, name: 'Matrix', emoji: '🟩',
      accent: Color(0xFF00FF41), accentSecondary: Color(0xFF00CC33),
      bgDark: Color(0xFF000500),
      blobs: [Color(0xFF001500), Color(0xFF002800), Color(0xFF00FF41), Color(0xFF008F11)]),
    AuraSkin(
      id: AuraSkinId.galaxy, name: 'Galaxy', emoji: '🌌',
      accent: Color(0xFF7C4DFF), accentSecondary: Color(0xFFB388FF),
      bgDark: Color(0xFF04010F),
      blobs: [Color(0xFF1A0040), Color(0xFF2D0060), Color(0xFF7C4DFF), Color(0xFF3D1C96)]),
    AuraSkin(
      id: AuraSkinId.carbon, name: 'Carbon', emoji: '⚫',
      accent: Color(0xFFE0E0E0), accentSecondary: Color(0xFF9E9E9E),
      bgDark: Color(0xFF090909),
      blobs: [Color(0xFF1A1A1A), Color(0xFF2C2C2C), Color(0xFF424242), Color(0xFF616161)]),
    AuraSkin(
      id: AuraSkinId.sakura, name: 'Sakura', emoji: '🌸',
      accent: Color(0xFFE91E63), accentSecondary: Color(0xFFF48FB1),
      bgDark: Color(0xFF0A0306),
      blobs: [Color(0xFF3E0020), Color(0xFF6A0030), Color(0xFFE91E63), Color(0xFFAD1457)]),
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
//  AURA SKIN SYSTEM  v5.3
// ═══════════════════════════════════════════════════════════════════════════════
enum AuraTheme { dark, light, system }

