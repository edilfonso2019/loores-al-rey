import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta: azul profundo + dorado (realeza, "Loores al Rey").
class AppTheme {
  static const seed = Color(0xFF1E3A8A);
  static const gold = Color(0xFFC9A227);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      secondary: gold,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      textTheme: GoogleFonts.loraTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
