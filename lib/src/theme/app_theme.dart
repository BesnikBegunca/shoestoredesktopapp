import 'package:flutter/material.dart';

class AppTheme {
  // =====================
  // BACKGROUNDS
  // =====================
  static const bg = Color(0xFF121212);        // almost black
  static const surface = Color(0xFF1E1E1E);   // dark gray
  static const surface2 = Color(0xFF2A2A2A);  // medium gray

  // =====================
  // BORDERS & TEXT
  // =====================
  static const stroke = Color.fromRGBO(255, 255, 255, 0.08);
  static const text = Color(0xFFFFFFFF); // white
  static const muted = Color.fromRGBO(255, 255, 255, 0.65);
  static const subtle = Color.fromRGBO(255, 255, 255, 0.45);

  // =====================
  // STATUS COLORS
  // =====================
  static const success = Color(0xFF4CAF50);
  static const delete = Color(0xFFE53935);
  static const warning = Color(0xFFFFB300);
  static const info = Color(0xFF90CAF9);

  // =====================
  // ACCENTS (neutralized)
  // =====================
  static const accent = Color(0xFFE0E0E0);        // light gray
  static const primaryPurple = Color(0xFFFFFFFF); // white primary
  static const darkPurple = Color(0xFFBDBDBD);    // gray
  static const blueAccent = Color(0xFF9E9E9E);    // neutral gray
  static const cyanAccent = Color(0xFF757575);   // darker gray

  // =====================
  // THEME
  // =====================
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,

      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: muted,
        ),
      ),

      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: blueAccent,
        tertiary: cyanAccent,
        surface: surface,
        onSurface: text,
        error: delete,
        onPrimary: bg,
        onSecondary: bg,
        onError: text,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surface2,
          foregroundColor: text,
          elevation: 0,
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
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
    );
  }
}
