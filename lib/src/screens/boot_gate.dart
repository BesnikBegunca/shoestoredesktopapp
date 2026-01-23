import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'app_shell.dart';
import 'developer_screen.dart';
import '../theme/app_theme.dart';
import '../db/database_manager.dart';
import '../license/license_checker.dart';
import '../local/local_api.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    if (!mounted) return;

    // ✅ Initialize LocalApi (opens admin DB)
    await LocalApi.I.init();
    await LocalApi.I.ensureDefaultAdmin();

    final role = await RoleStore.getRole();

    if (role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ✅ Superadmin -> Developer Panel
    if (role == UserRole.superadmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeveloperScreen()),
      );
      return;
    }

    // ✅ Business users -> kontrollo licensën
    final businessId = await RoleStore.getBusinessId();
    
    if (businessId != null) {
      try {
        // Switch to business database
        await DatabaseManager.switchToBusiness(businessId);
        
        // Kontrollo licensën
        final licenseValid = await LicenseChecker.isBusinessLicenseValid(businessId);
        
        if (!licenseValid) {
          // Licensa e skaduar -> kthehu në login
          if (!mounted) return;
          await RoleStore.clear();
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          
          // Shfaq mesazh
          Future.delayed(Duration.zero, () {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text(
                  'Licensa e Skaduar',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
                ),
                content: const Text(
                  'Licensa e këtij biznesi ka skaduar. Ju lutem kontaktoni administratorin.',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
          return;
        }
        
        // Licensa valide -> vazhdo në app
        if (!mounted) return;
        if (role == UserRole.worker) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
      } catch (e) {
        // Error -> kthehu në login
        if (!mounted) return;
        await RoleStore.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      // Nuk ka businessId -> kthehu në login
      await RoleStore.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
