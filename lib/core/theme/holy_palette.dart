import 'package:flutter/material.dart';

/// Complete moods, following SunRize's coordinated surface / particle palettes.
@immutable
class HolyPalette {
  final String id, name;
  final Color background, card, blush, edge, accent, ink, muted, champagne;
  const HolyPalette(this.id, this.name, this.background, this.card, this.blush,
      this.edge, this.accent, this.ink, this.muted, this.champagne);
  bool get isDark => id == 'midnight';
  static const all = [
    HolyPalette(
        'pearl',
        'Pearl',
        Color(0xFFFFFAF7),
        Color(0xFFFFFEFC),
        Color(0xFFF5E4E7),
        Color(0xFFE8CED6),
        Color(0xFF98516A),
        Color(0xFF382735),
        Color(0xFF796772),
        Color(0xFFEAD9BC)),
    HolyPalette(
        'rose',
        'Rose',
        Color(0xFFF9ECF0),
        Color(0xFFFFF8FA),
        Color(0xFFEFCBD6),
        Color(0xFFE1B6C5),
        Color(0xFF96445F),
        Color(0xFF402331),
        Color(0xFF7F5968),
        Color(0xFFE9CBB8)),
    HolyPalette(
        'lavender',
        'Lavender',
        Color(0xFFF3EFF9),
        Color(0xFFFDFBFF),
        Color(0xFFE2D7EF),
        Color(0xFFD0BEDF),
        Color(0xFF79548E),
        Color(0xFF352641),
        Color(0xFF74627E),
        Color(0xFFE6D6CB)),
    HolyPalette(
        'sage',
        'Sage',
        Color(0xFFF1F4ED),
        Color(0xFFFDFFF9),
        Color(0xFFDCE6D4),
        Color(0xFFC2D0BA),
        Color(0xFF516C57),
        Color(0xFF2D3A30),
        Color(0xFF647466),
        Color(0xFFE8DABD)),
    HolyPalette(
        'dawn',
        'Dawn',
        Color(0xFFFFF3E8),
        Color(0xFFFFFCF7),
        Color(0xFFF4D7C1),
        Color(0xFFE7C6A9),
        Color(0xFF9A573B),
        Color(0xFF432D2A),
        Color(0xFF80665C),
        Color(0xFFF1D8A9)),
    HolyPalette(
        'midnight',
        'Midnight',
        Color(0xFF211D2D),
        Color(0xFF332A40),
        Color(0xFF4C3A56),
        Color(0xFF695372),
        Color(0xFFE8B7CE),
        Color(0xFFF9F0F5),
        Color(0xFFCCBCCA),
        Color(0xFFB29B78)),
  ];
  static HolyPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}
