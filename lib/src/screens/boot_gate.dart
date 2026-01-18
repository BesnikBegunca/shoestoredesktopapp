import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'app_shell.dart';

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
    final role = await RoleStore.getRole();

    if (!mounted) return;

    if (role == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (role == UserRole.worker) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
