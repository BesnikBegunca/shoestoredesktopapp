import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import '../local/local_api.dart';
import 'main_screen.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;
  bool hide = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await LocalApi.I.init();

    // ✅ Nëse e ke këtë funksion në LocalApi, leje.
    // Nëse s’e ke, komento rreshtin poshtë.
    await LocalApi.I.ensureDefaultAdmin();
  }

  @override
  void dispose() {
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gabim', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Future<void> _doLogin() async {
    if (loading) return;

    final u = userC.text.trim();
    final p = passC.text;

    if (u.isEmpty || p.isEmpty) {
      _showError('Shkruaj username dhe password.');
      return;
    }

    setState(() => loading = true);

    try {
      // ✅ login duhet me kthy: userId, username, role
      final res = await LocalApi.I.login(username: u, password: p);

      final role = res.role == 'admin' ? UserRole.admin : UserRole.worker;

      await RoleStore.setSession(
        userId: res.id,
        username: res.username,
        role: role,
      );


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
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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

                  TextField(
                    controller: userC,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _doLogin(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: passC,
                    obscureText: hide,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hide = !hide),
                        icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    onSubmitted: (_) => _doLogin(),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _doLogin,
                      icon: loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.login),
                      label: Text(loading ? 'Duke hy...' : 'HYR'),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Default Admin: admin / 1234',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
