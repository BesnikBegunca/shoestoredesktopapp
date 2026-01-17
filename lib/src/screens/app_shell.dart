import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';

import '../theme/app_theme.dart';
import 'settings_screen.dart';

import 'main_screen.dart';
import 'products_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      MainScreen(),
      ProductsScreen(),
      AdminScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12), // ✅ hapësirë rreth krejt app-it
          child: Row(
            children: [
              // ================= SIDEBAR =================
              _roundedSidebar(),

              const SizedBox(width: 12),

              // ================= CONTENT AREA =================
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      // ✅ PA BORDER
                    ),
                    child: pages[index],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ================= SIDEBAR =================
  Widget _roundedSidebar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.stroke,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Shoe Store',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),

              _navItem(icon: Icons.point_of_sale, label: 'Shitja', i: 0),
              _navItem(icon: Icons.inventory_2, label: 'Produktet', i: 1),
              _navItem(
                icon: Icons.admin_panel_settings,
                label: 'Admin',
                i: 2,
              ),
              _navItem(icon: Icons.settings, label: 'Settings', i: 3),

              const Spacer(),

              Divider(color: Colors.white.withOpacity(0.12)),
              const SizedBox(height: 6),
              _logoutBtn(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NAV ITEM =================
  Widget _navItem({
    required IconData icon,
    required String label,
    required int i,
  }) {
    final active = index == i;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => index = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: active
                ? AppTheme.primaryPurple.withOpacity(0.12)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? AppTheme.primaryPurple.withOpacity(0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? AppTheme.primaryPurple : Colors.grey,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active ? AppTheme.primaryPurple : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= LOGOUT =================
  Widget _logoutBtn() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await RoleStore.clear();
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
