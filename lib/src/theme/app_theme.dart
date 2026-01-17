import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF1C2F4A);

  static const surface = Color(0xFF223A5E);

  static const surface2 = Color(0xFF0F3460);
  static const stroke = Color.fromRGBO(255, 255, 255, 0.1);
  static const text = Color(0xFFE9ECEF);
  static const muted = Color.fromRGBO(233, 236, 239, 0.7);
  static const subtle = Color.fromRGBO(233, 236, 239, 0.5);

  static const success = Color(0xFF4CAF50);
  static const delete = Color(0xFFF44336);
  static const warning = Color(0xFFFF9800);
  static const info = Color(0xFF2196F3);
  static const accent = Color(0xFFF72585);
  static const primaryPurple = Color(0xFF7209B7);
  static const darkPurple = Color(0xFF3A0CA3);
  static const blueAccent = Color(0xFF4361EE);
  static const cyanAccent = Color(0xFF4CC9F0);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple, // Custom purple as primary
        secondary: blueAccent, // Custom blue as secondary
        tertiary: cyanAccent, // Custom cyan as tertiary
        surface: surface,
        onSurface: text,
        error: delete,
        onPrimary: text,
        onSecondary: text,
        onError: text,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent, // Custom pink accent for primary actions
          foregroundColor: Colors.black,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent, // Custom pink accent for filled buttons
          foregroundColor: Colors.black,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: stroke),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
    );
  }
}
