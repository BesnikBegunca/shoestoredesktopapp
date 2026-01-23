import 'package:flutter/material.dart';

class AppTheme {
  // =====================
  // BACKGROUNDS (Light Mode)
  // =====================
  static const bg = Color(0xFFF5F7FA);        // very light gray background - better contrast
  static const surface = Color(0xFFFFFFFF);   // white cards
  static const surface2 = Color(0xFF1E3A5F);  // dark blue sidebar
  static const sidebarDark = Color(0xFF1E3A5F); // dark blue for sidebar
  static const sidebarActive = Color(0xFF2A4F7A); // lighter blue for active item

  // Dark Mode Colors - better contrast
  static const bgDark = Color(0xFF0D1117);      // darker background for better contrast
  static const surfaceDark = Color(0xFF161B22); // darker surface
  static const surface2Dark = Color(0xFF21262D); // even darker for cards

  // =====================
  // BORDERS & TEXT (Light Mode) - Better contrast
  // =====================
  static const stroke = Color.fromRGBO(0, 0, 0, 0.15);  // stronger border
  static const text = Color(0xFF0D1117); // darker text for better readability
  static const muted = Color.fromRGBO(0, 0, 0, 0.75);   // better contrast
  static const subtle = Color.fromRGBO(0, 0, 0, 0.6);

  // Dark Mode Text - Better contrast
  static const textDark = Color(0xFFF0F6FC);  // brighter text
  static const mutedDark = Color.fromRGBO(255, 255, 255, 0.8);  // better contrast
  static const strokeDark = Color.fromRGBO(255, 255, 255, 0.2);  // stronger borders
  
  // =====================
  // DYNAMIC COLOR GETTERS
  // =====================
  static Color getBg(bool isDark) => isDark ? bgDark : bg;
  static Color getSurface(bool isDark) => isDark ? surfaceDark : surface;
  static Color getText(bool isDark) => isDark ? textDark : text;
  static Color getMuted(bool isDark) => isDark ? mutedDark : muted;
  static Color getStroke(bool isDark) => isDark ? strokeDark : stroke;

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

      // ✅ Global cursor color for all text fields
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.black,
      ),

      inputDecorationTheme: const InputDecorationTheme(
        // Ensure cursor color is black in all text fields
        // This is applied globally
      ),
    );
  }
}
