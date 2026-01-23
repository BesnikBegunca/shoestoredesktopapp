import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// GLOBAL DESIGN SYSTEM
/// Single source of truth for all styling across the app
/// ═══════════════════════════════════════════════════════════════════════════
class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. TYPOGRAPHY - Roboto Font Family
  // ═══════════════════════════════════════════════════════════════════════════
  static const String fontFamily = 'Roboto';

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. COLORS - Consistent palette across all widgets
  // ═══════════════════════════════════════════════════════════════════════════
  
  // Backgrounds
  static const Color bgPage = Color(0xFFF5F7FA);           // Very light gray page background
  static const Color bgSurface = Color(0xFFFFFFFF);        // White cards/containers
  static const Color bgInput = Color(0xFFF8FAFC);          // Light gray input background
  
  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);      // Dark text (almost black)
  static const Color textSecondary = Color(0xFF64748B);    // Gray text (muted)
  static const Color textTertiary = Color(0xFF94A3B8);     // Light gray text (subtle)
  
  // Border Colors
  static const Color borderLight = Color(0xFFE2E8F0);      // Light gray borders
  static const Color borderMedium = Color(0xFFCBD5E1);     // Medium gray borders
  static const Color borderDark = Color(0xFF94A3B8);       // Dark gray borders
  
  // Button Colors
  static const Color btnPrimary = Color(0xFF1E293B);       // Dark/black primary button
  static const Color btnPrimaryHover = Color(0xFF334155);  // Primary button hover
  static const Color btnSecondary = Color(0xFFFFFFFF);     // White secondary button
  static const Color btnSecondaryBorder = Color(0xFFE2E8F0); // Secondary button border
  
  // Status Colors
  static const Color success = Color(0xFF10B981);          // Green success
  static const Color error = Color(0xFFEF4444);            // Red error
  static const Color warning = Color(0xFFF59E0B);          // Orange warning
  static const Color info = Color(0xFF3B82F6);             // Blue info
  
  // Special Colors (for specific use cases)
  static const Color accent = Color(0xFF6366F1);           // Purple/indigo accent
  static const Color sidebarDark = Color(0xFF1E3A5F);      // Dark blue sidebar
  static const Color sidebarActive = Color(0xFF2A4F7A);    // Sidebar active item

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. BORDER RADIUS - Consistent rounded corners
  // ═══════════════════════════════════════════════════════════════════════════
  static const double radiusSmall = 8.0;                   // Small elements
  static const double radiusMedium = 10.0;                 // Standard elements (buttons, inputs)
  static const double radiusLarge = 12.0;                  // Cards, containers
  static const double radiusXLarge = 16.0;                 // Modals, dialogs

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SHADOWS - Soft, subtle shadows
  // ═══════════════════════════════════════════════════════════════════════════
  static List<BoxShadow> get shadowSoft => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. SPACING - Consistent spacing system
  // ═══════════════════════════════════════════════════════════════════════════
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. LEGACY COMPATIBILITY (keeping old names for gradual migration)
  // ═══════════════════════════════════════════════════════════════════════════
  static const bg = bgPage;
  static const surface = bgSurface;
  static const surface2 = sidebarDark;
  static const stroke = borderLight;
  static const text = textPrimary;
  static const muted = textSecondary;
  static const subtle = textTertiary;
  static const delete = error;
  static const primaryPurple = accent;         // Legacy: mapped to accent
  static const darkPurple = textSecondary;     // Legacy: mapped to text secondary
  static const blueAccent = textSecondary;     // Legacy: mapped to text secondary
  static const cyanAccent = textTertiary;      // Legacy: mapped to text tertiary

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. THEME DATA - Material Theme Configuration
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgPage,
      fontFamily: fontFamily, // ✅ Global Roboto font
      useMaterial3: true,

      // ═══════════════════════════════════════════════════════════════════════
      // Typography with Roboto
      // ═══════════════════════════════════════════════════════════════════════
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamily: fontFamily, color: textSecondary, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: fontFamily, color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamily: fontFamily, color: textSecondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontFamily: fontFamily, color: textTertiary, fontWeight: FontWeight.w500),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Color Scheme
      // ═══════════════════════════════════════════════════════════════════════
      colorScheme: const ColorScheme.light(
        primary: btnPrimary,
        onPrimary: Colors.white,
        secondary: textSecondary,
        onSecondary: textPrimary,
        surface: bgSurface,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
        outline: borderLight,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Button Themes
      // ═══════════════════════════════════════════════════════════════════════
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: btnPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: btnSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: btnSecondaryBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Input Theme
      // ═══════════════════════════════════════════════════════════════════════
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: btnPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: btnPrimary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textTertiary,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Card Theme
      // ═══════════════════════════════════════════════════════════════════════
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // AppBar Theme
      // ═══════════════════════════════════════════════════════════════════════
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Dialog Theme
      // ═══════════════════════════════════════════════════════════════════════
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Dropdown Theme
      // ═══════════════════════════════════════════════════════════════════════
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgInput,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: borderLight, width: 1.5),
          ),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Text Selection Theme
      // ═══════════════════════════════════════════════════════════════════════
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.black,
        selectionColor: Color(0xFFBFDBFE),
        selectionHandleColor: btnPrimary,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Checkbox Theme
      // ═══════════════════════════════════════════════════════════════════════
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return btnPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: borderMedium, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Radio Theme
      // ═══════════════════════════════════════════════════════════════════════
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return btnPrimary;
          }
          return borderMedium;
        }),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // Switch Theme
      // ═══════════════════════════════════════════════════════════════════════
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return borderMedium;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return btnPrimary;
          }
          return borderLight;
        }),
      ),
    );
  }
}
