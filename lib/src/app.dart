import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/products_screen.dart';
import 'screens/admin_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [MainScreen(), ProductsScreen(), AdminScreen()];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Row(
          children: [
            // Sidebar (desktop vibe)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: AppTheme.surface2,
                border: Border(right: BorderSide(color: AppTheme.stroke, width: 1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text("Shoe Store", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    _NavBtn(
                      active: index == 0,
                      label: "Main",
                      onTap: () => setState(() => index = 0),
                    ),
                    _NavBtn(
                      active: index == 1,
                      label: "Products",
                      onTap: () => setState(() => index = 1),
                    ),
                    _NavBtn(
                      active: index == 2,
                      label: "Admin",
                      onTap: () => setState(() => index = 2),
                    ),
                    const Spacer(),
                    const Text("Local • SQLite", style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.bg,
                ),
                child: pages[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _NavBtn({required this.active, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6D5EF6) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? Colors.transparent : AppTheme.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF0B0F14) : AppTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
