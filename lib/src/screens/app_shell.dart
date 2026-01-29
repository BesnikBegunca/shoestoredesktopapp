import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shoe_store_manager/auth/role_store.dart';

import '../theme/app_theme.dart';
import '../local/local_api.dart';
import 'login_screen.dart';
import 'daily_sale_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'fitimet_screen.dart';
import 'shpenzimet_screen.dart';
import 'license_info_screen.dart';
import 'developer_screen.dart';
import 'help_screen.dart';

enum _NavSection { 
  shitjaDitore,
  permbledhja, 
  stoku, 
  regjistrimiMallit, 
  fitimet, 
  shpenzimet, 
  licenca, 
  help 
}

/// Fjalëkalimi për hyrje te Fitimet dhe Shpenzimet
const String _protectedSectionsPassword = 'superadmin123';

/// Dialogu i fjalëkalimit; posedon TextEditingController që fshihet kur route hiqet.
class _PasswordDialogBody extends StatefulWidget {
  final _NavSection section;
  final String expectedPassword;

  const _PasswordDialogBody({
    required this.section,
    required this.expectedPassword,
  });

  @override
  State<_PasswordDialogBody> createState() => _PasswordDialogBodyState();
}

class _PasswordDialogBodyState extends State<_PasswordDialogBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final expectedPassword = widget.expectedPassword;
    return AlertDialog(
      title: const Text('Fjalëkalim'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section == _NavSection.fitimet
                ? 'Vendosni fjalëkalimin për të hyrë te Fitimet.'
                : 'Vendosni fjalëkalimin për të hyrë te Shpenzimet.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Fjalëkalimi',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value == expectedPassword) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text == expectedPassword) {
              Navigator.pop(context, true);
            } else {
              Navigator.pop(context, false);
            }
          },
          child: const Text('Hyr'),
        ),
      ],
    );
  }
}

class AppShell extends StatefulWidget {
  final bool readonly;
  const AppShell({super.key, this.readonly = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _NavSection section = _NavSection.shitjaDitore;
  String _businessName = 'Administrator';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
  }

  Future<void> _loadBusinessInfo() async {
    try {
      final businessId = await RoleStore.getBusinessId();
      if (businessId != null) {
        final business = await LocalApi.I.getBusinessById(businessId);
        if (mounted) {
          setState(() {
            _businessName = business?.name ?? 'Administrator';
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _businessName = 'Administrator';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _businessName = 'Administrator';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? currentPage;
    
    switch (section) {
      case _NavSection.shitjaDitore:
        currentPage = const DailySaleScreen();
        break;
      case _NavSection.permbledhja:
        currentPage = const DashboardScreen();
        break;
      case _NavSection.stoku:
        currentPage = const InventoryScreen();
        break;
      case _NavSection.regjistrimiMallit:
        currentPage = const ProductsScreen();
        break;
      case _NavSection.fitimet:
        currentPage = const FitimetScreen();
        break;
      case _NavSection.shpenzimet:
        currentPage = const ShpenzimetScreen();
        break;
      case _NavSection.licenca:
        currentPage = const LicenseInfoScreen();
        break;
      case _NavSection.help:
        currentPage = const HelpScreen();
        break;
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Row(
          children: [
            // ================= DARK SIDEBAR =================
            _darkSidebar(),

            // ================= MAIN CONTENT AREA =================
            Expanded(
              child: Container(
                color: AppTheme.bg,
                width: double.infinity,
                height: double.infinity,
                child: currentPage ?? const DashboardScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DARK SIDEBAR =================
  Widget _darkSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarDark,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title - Shfaq emrin e biznesit
            Text(
              _businessName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 40),

            // Navigation Items - Main Menu (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _navItemSvg(
                      svgPath: 'assets/icons/shitja_ditore.svg',
                      label: 'Shitja Ditore',
                      section: _NavSection.shitjaDitore,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/permbledhja.svg',
                      label: 'Permbledhja',
                      section: _NavSection.permbledhja,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/stoku.svg',
                      label: 'Regjistrimi i Mallit',
                      section: _NavSection.stoku,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/regjistrimi_mallit.svg',
                      label: 'Stoku',
                      section: _NavSection.regjistrimiMallit,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/fitimet.svg',
                      label: 'Fitimet',
                      section: _NavSection.fitimet,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/shpenzimet.svg',
                      label: 'Shpenzimet',
                      section: _NavSection.shpenzimet,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/licenca.svg',
                      label: 'Licenca',
                      section: _NavSection.licenca,
                    ),
                    _navItemSvg(
                      svgPath: 'assets/icons/info.svg',
                      label: 'Help & FAQs',
                      section: _NavSection.help,
                    ),
                  ],
                ),
              ),
            ),

            // Close button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _closeApp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/logout.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.red,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Mbyll',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Logout button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/logout.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Dalje',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ================= CLOSE APP =================
  Future<void> _closeApp() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Close App'),
          content: const Text('Are you sure you want to close this app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (shouldClose ?? false) {
      exit(0);
    }
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    await RoleStore.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Navigon te seksioni; për Fitimet dhe Shpenzimet kërkon fjalëkalim.
  Future<void> _navigateToSection(_NavSection section) async {
    final needsPassword = section == _NavSection.fitimet || section == _NavSection.shpenzimet;
    if (!needsPassword) {
      setState(() => this.section = section);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PasswordDialogBody(
        section: section,
        expectedPassword: _protectedSectionsPassword,
      ),
    );

    if (mounted && (result == true)) {
      setState(() => this.section = section);
    } else if (mounted && result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fjalëkalimi është i gabuar.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= NAV ITEM WITH SVG =================
  Widget _navItemSvg({
    required String svgPath,
    required String label,
    required _NavSection section,
  }) {
    final active = this.section == section;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToSection(section),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? AppTheme.sidebarActive : Colors.transparent,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                svgPath,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
