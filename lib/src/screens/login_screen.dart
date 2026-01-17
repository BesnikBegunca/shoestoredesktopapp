import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'main_screen.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final pinC = TextEditingController();
  bool showPin = false;
  bool checking = false;

  @override
  void dispose() {
    pinC.dispose();
    super.dispose();
  }

  Future<void> _loginWorker() async {
    await RoleStore.setRole(UserRole.worker);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _loginAdmin() async {
    if (checking) return;
    setState(() => checking = true);

    final pin = pinC.text.trim();

    final ok = await RoleStore.verifyAdminPin(pin);
    if (!ok) {
      if (!mounted) return;
      setState(() => checking = false);
      _showError('PIN gabim.');
      return;
    }

    // ✅ ruaj a u perdor MASTER pin apo jo (per Settings screen)
    await RoleStore.setUsedMaster(pin == RoleStore.masterAdminPin);

    await RoleStore.setRole(UserRole.admin);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Gabim',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hyrja',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 14),

                  // ✅ Worker hyn pa PIN
                  FilledButton.icon(
                    onPressed: _loginWorker,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('PUNTOR (Vetëm Shitja)'),
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ✅ Admin – kërkon PIN (normal ose MASTER)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => showPin = !showPin),
                      icon: Icon(showPin ? Icons.lock_open : Icons.lock),
                      label: Text(
                        showPin ? 'Mbyll Admin PIN' : 'Admin Login (me PIN)',
                      ),
                    ),
                  ),

                  if (showPin) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: pinC,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Admin PIN',
                        border: OutlineInputBorder(),
                        hintText: 'Shkruaj PIN (ose MASTER)',
                      ),
                      onSubmitted: (_) => _loginAdmin(),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: checking ? null : _loginAdmin,
                      icon: checking
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.admin_panel_settings),
                      label: Text(checking ? 'Duke verifikuar...' : 'HYR SI ADMIN'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Admin hyn me PIN-in normal ose me MASTER PIN në rast se harrohet.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
