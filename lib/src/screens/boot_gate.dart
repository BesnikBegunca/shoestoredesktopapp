import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/src/license/license_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'app_shell.dart';
import 'license_screen.dart';

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
    // Check license first
    final licenseMode = await LicenseService.I.checkStatus();
    print('BootGate: Initial license mode: $licenseMode');

    if (!mounted) return;

    if (licenseMode == LicenseMode.unlicensed ||
        licenseMode == LicenseMode.tampered ||
        licenseMode == LicenseMode.expired_readonly) {
      print('BootGate: Showing license screen');
      // Show license screen and wait for result
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LicenseScreen()),
      );
      print('BootGate: License screen result: $result');

      // If license was activated successfully, continue to app
      if (result == true) {
        // Re-check license status after activation
        final newLicenseMode = await LicenseService.I.checkStatus();
        print('BootGate: New license mode after activation: $newLicenseMode');
        if (newLicenseMode == LicenseMode.active ||
            newLicenseMode == LicenseMode.expired_readonly) {
          // License is now valid, proceed to role-based navigation
          await _navigateToApp(newLicenseMode);
          return;
        }
      }

      // If license activation failed or was cancelled, stay on license screen
      // This will keep the app on the license screen
      print(
        'BootGate: License activation failed or cancelled, staying on license screen',
      );
      return;
    }

    // License is already valid, proceed to app
    print('BootGate: License already valid, proceeding to app');
    await _navigateToApp(licenseMode);
  }

  Future<void> _navigateToApp(LicenseMode licenseMode) async {
    final isReadonly = licenseMode == LicenseMode.expired_readonly;

    final role = await RoleStore.getRole();

    if (role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (role == UserRole.worker) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScreen(readonly: isReadonly)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AppShell(readonly: isReadonly)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
