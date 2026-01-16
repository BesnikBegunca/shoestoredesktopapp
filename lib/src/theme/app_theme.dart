import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0B0F14);
  static const surface = Color(0xFF111827);
  static const surface2 = Color(0xFF0F172A);
  static const stroke = Color.fromRGBO(255, 255, 255, 0.10);
  static const text = Color(0xFFE5E7EB);
  static const muted = Color.fromRGBO(229, 231, 235, 0.70);
  static const subtle = Color.fromRGBO(229, 231, 235, 0.50);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
    );
  }
}
