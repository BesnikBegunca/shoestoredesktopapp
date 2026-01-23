import 'package:flutter/material.dart';

class ThemeProvider extends InheritedWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const ThemeProvider({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
    required super.child,
  });

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
}
