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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF0F4F8),
              const Color(0xFFE6EEF5),
              const Color(0xFFF5F9FC),
            ],
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ LEFT COLUMN - Branding (60%)
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo + Brand
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        'assets/icons/binary_devs.png',
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Binary Devs',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              // Headline
                              const Text(
                                'Platforma Juaj për\nMenaxhimin e Dyqanit',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Description
                              Text(
                                'Menaxhoni shitjet, inventarin dhe operacionet e biznesit tuaj nga një panel i unifikuar. Të dhënat tuaja janë të sigurta dhe gjithmonë të aksesueshme.',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ✅ RIGHT COLUMN - Login Card (40%)
                      Expanded(
                        flex: 4,
                        child: _buildLoginCard(),
                      ),
                    ],
                  )
                : _buildLoginCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Mirë se erdhe',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            'Identifikohu për të aksesuar panelin tënd',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          // Email Label
          Text(
            'Username',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          // Email Input
          TextField(
            controller: userC,
            decoration: InputDecoration(
              hintText: 'username',
              prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _doLogin(),
          ),
          const SizedBox(height: 20),
          // Password Label
          Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          // Password Input
          TextField(
            controller: passC,
            obscureText: hide,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
              suffixIcon: IconButton(
                onPressed: () => setState(() => hide = !hide),
                icon: Icon(
                  hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.grey.shade500,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _doLogin(),
          ),
          const SizedBox(height: 24),
          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: loading ? null : _doLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hyr',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
