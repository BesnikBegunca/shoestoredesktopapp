import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final oldC = TextEditingController();
  final newC = TextEditingController();
  final confirmC = TextEditingController();

  bool saving = false;
  bool usedMaster = false;
  String currentPinMasked = '••••';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    // ✅ A u perdor MASTER PIN hera e fundit?
    final um = await RoleStore.usedMasterLastLogin();

    // ✅ lexo pin-in aktual (mos e shfaq realisht; veq mask)
    final p = await RoleStore.getAdminPin();
    final masked = p.isEmpty ? '••••' : List.filled(p.length, '•').join();

    if (!mounted) return;
    setState(() {
      usedMaster = um;
      currentPinMasked = masked;
    });
  }

  @override
  void dispose() {
    oldC.dispose();
    newC.dispose();
    confirmC.dispose();
    super.dispose();
  }

  void _err(String msg) {
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

  Future<void> _ok(String msg) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sukses', style: TextStyle(fontWeight: FontWeight.w900)),
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

  bool _isValidPin(String s) {
    final t = s.trim();
    if (t.length < 4) return false; // min 4
    final onlyDigits = RegExp(r'^\d+$');
    return onlyDigits.hasMatch(t);
  }

  Future<void> _save() async {
    if (saving) return;

    final oldPin = oldC.text.trim();
    final newPin = newC.text.trim();
    final conf = confirmC.text.trim();

    if (!_isValidPin(oldPin)) {
      _err('Shkruaj PIN-in e vjetër (min 4 shifra).');
      return;
    }
    if (!_isValidPin(newPin)) {
      _err('PIN i ri duhet min 4 shifra (vetëm numra).');
      return;
    }
    if (newPin != conf) {
      _err('PIN i ri dhe konfirmimi s’janë njëjtë.');
      return;
    }
    if (newPin == oldPin) {
      _err('PIN i ri s’mund me qenë i njejtë me të vjetrin.');
      return;
    }

    setState(() => saving = true);
    try {
      // ✅ pranon edhe MASTER PIN (verifyAdminPin e lejon)
      final ok = await RoleStore.verifyAdminPin(oldPin);
      if (!ok) {
        _err('PIN i vjetër gabim.');
        return;
      }

      await RoleStore.setAdminPin(newPin);

      // ✅ mas ndryshimit, s’ka ma nevoje “used master”
      await RoleStore.setUsedMaster(false);

      await _ok('PIN u ndryshua me sukses ✅');

      oldC.clear();
      newC.clear();
      confirmC.clear();

      await _loadMeta();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _logout() async {
    await RoleStore.clear();
    await RoleStore.setUsedMaster(false);
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ndrysho Admin PIN',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(Icons.lock, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'PIN aktual: $currentPinMasked',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (usedMaster)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.withOpacity(0.35)),
                        ),
                        child: Text(
                          '⚠️ Ke hyrë me MASTER PIN.\n'
                              'Tash mundesh me e resetu PIN-in normal këtu.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: oldC,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN i vjetër (ose MASTER)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: newC,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN i ri',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: confirmC,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Konfirmo PIN-in e ri',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.lock_reset),
                        label: Text(saving ? 'Duke ruajt...' : 'Ruaj PIN-in'),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'PIN duhet të ketë minimum 4 shifra (vetëm numra).',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
