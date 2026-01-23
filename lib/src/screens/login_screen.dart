import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import '../local/local_api.dart';
import '../theme/app_theme.dart';
import '../db/database_manager.dart';
import '../license/license_checker.dart';
import 'main_screen.dart';
import 'app_shell.dart';
import 'superadmin_screen.dart';
import 'developer_screen.dart';

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
    await LocalApi.I.ensureDefaultAdmin(); // default admin
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
      final res = await LocalApi.I.login(username: u, password: p);

      UserRole role;
      if (res.role == 'superadmin') {
        role = UserRole.superadmin;
      } else if (res.role == 'admin') {
        role = UserRole.admin;
      } else {
        role = UserRole.worker;
      }

      // ✅ Ruaj session me businessId
      await RoleStore.setSession(
        userId: res.id,
        username: res.username,
        role: role,
        businessId: res.businessId,
      );

      if (!mounted) return;

      // ✅ Superadmin -> Developer Panel
      if (role == UserRole.superadmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DeveloperScreen()),
        );
        return;
      }

      // ✅ Business users -> switch to business DB dhe kontrollo licensën
      if (res.businessId != null) {
        // Switch to business database
        await DatabaseManager.switchToBusiness(res.businessId!);
        
        // Kontrollo licensën
        final licenseValid = await LicenseChecker.isBusinessLicenseValid(res.businessId!);
        
        if (!licenseValid) {
          // Licensa e skaduar -> shfaq warning dhe blloko aksesin
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text(
                'Licensa e Skaduar',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
              ),
              content: const Text(
                'Licensa e këtij biznesi ka skaduar. Ju lutem kontaktoni administratorin për të rinovuar licensën.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Kthehu në login screen
                    RoleStore.clear();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
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
      } else {
        // User pa businessId (nuk duhet të ndodhë)
        _showError('User configuration error.');
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
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Login')),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ EMRI I DYQANIT
                  const Text(
                    'PERLINA KIDS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Hyrja',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
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
                        onPressed: () =>
                            setState(() => hide = !hide),
                        icon: Icon(
                          hide
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _doLogin(),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _doLogin,
                      icon: loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.login),
                      label: Text(loading ? 'Duke hy...' : 'HYR'),
                    ),
                  ),

                  const SizedBox(height: 12),


                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
