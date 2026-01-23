import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/models/business.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  bool loading = false;
  List<Business> businesses = [];
  Map<int, Map<String, int>> businessStats = {}; // businessId -> {products, users, sales}

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() => loading = true);
    try {
      final userId = await RoleStore.getUserId();
      final list = await LocalApi.I.getBusinesses(createdByUserId: userId);
      if (!mounted) return;
      
      // Load stats for each business
      final stats = <int, Map<String, int>>{};
      final allUsers = await LocalApi.I.getAllUsers();
      
      for (final b in list) {
        try {
          final businessUsers = allUsers.where((u) => u.businessId == b.id).toList();
          stats[b.id] = {
            'products': 0, // TODO: Filter products by business
            'users': businessUsers.length,
            'sales': 0, // Placeholder for now
          };
        } catch (e) {
          stats[b.id] = {'products': 0, 'users': 0, 'sales': 0};
        }
      }
      
      setState(() {
        businesses = list;
        businessStats = stats;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  Future<void> _showSuccessDialog(String msg) async {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'success',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _SuccessPopup(message: msg),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _openCreateBusinessDialog() async {
    final nameC = TextEditingController();
    final passwordC = TextEditingController();
    final addressC = TextEditingController();
    final cityC = TextEditingController();
    final postalCodeC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final ownerNameC = TextEditingController();
    final taxIdC = TextEditingController();
    final registrationNumberC = TextEditingController();
    final contactPersonC = TextEditingController();
    final websiteC = TextEditingController();
    final notesC = TextEditingController();
    bool hidePassword = true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Krijo Biznes',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Informacioni bazë
                  const Text(
                    'Informacioni Bazë',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i biznesit *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordC,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ownerNameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i pronarit/përgjegjësit (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Kontakt
                  const Text(
                    'Kontakt',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailC,
                    decoration: const InputDecoration(
                      labelText: 'Email (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactPersonC,
                    decoration: const InputDecoration(
                      labelText: 'Personi kontaktues (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: websiteC,
                    decoration: const InputDecoration(
                      labelText: 'Website (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Adresa
                  const Text(
                    'Adresa',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressC,
                    decoration: const InputDecoration(
                      labelText: 'Adresa (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityC,
                          decoration: const InputDecoration(
                            labelText: 'Qyteti (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: postalCodeC,
                          decoration: const InputDecoration(
                            labelText: 'Kodi postar (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Të dhëna ligjore
                  const Text(
                    'Të Dhëna Ligjore',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: taxIdC,
                    decoration: const InputDecoration(
                      labelText: 'NIPT/Numri tatimor (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: registrationNumberC,
                    decoration: const InputDecoration(
                      labelText: 'Numri i regjistrimit (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Shënime
                  TextField(
                    controller: notesC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Shënime (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulo'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameC.text.trim();
                      final password = passwordC.text;

                      if (name.isEmpty) {
                        _showError('Shkruaj emrin e biznesit.');
                        return;
                      }
                      if (password.isEmpty) {
                        _showError('Shkruaj password.');
                        return;
                      }

                      setLocal(() => saving = true);
                      try {
                        final userId = await RoleStore.getUserId();
                        await LocalApi.I.createBusiness(
                          name: name,
                          password: password,
                          address: addressC.text.trim().isEmpty ? null : addressC.text.trim(),
                          city: cityC.text.trim().isEmpty ? null : cityC.text.trim(),
                          postalCode: postalCodeC.text.trim().isEmpty ? null : postalCodeC.text.trim(),
                          phone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                          email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                          ownerName: ownerNameC.text.trim().isEmpty ? null : ownerNameC.text.trim(),
                          taxId: taxIdC.text.trim().isEmpty ? null : taxIdC.text.trim(),
                          registrationNumber: registrationNumberC.text.trim().isEmpty ? null : registrationNumberC.text.trim(),
                          contactPerson: contactPersonC.text.trim().isEmpty ? null : contactPersonC.text.trim(),
                          website: websiteC.text.trim().isEmpty ? null : websiteC.text.trim(),
                          notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                          createdByUserId: userId,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _loadBusinesses();
                        await _showSuccessDialog('Biznesi u kriju ✅');
                      } catch (e) {
                        _showError('Gabim: $e');
                      } finally {
                        if (mounted) setLocal(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.add_business),
              label: Text(saving ? 'Duke ruajt...' : 'KRIJO'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditBusinessDialog(Business business) async {
    final nameC = TextEditingController(text: business.name);
    final passwordC = TextEditingController();
    final addressC = TextEditingController(text: business.address ?? '');
    final cityC = TextEditingController(text: business.city ?? '');
    final postalCodeC = TextEditingController(text: business.postalCode ?? '');
    final phoneC = TextEditingController(text: business.phone ?? '');
    final emailC = TextEditingController(text: business.email ?? '');
    final ownerNameC = TextEditingController(text: business.ownerName ?? '');
    final taxIdC = TextEditingController(text: business.taxId ?? '');
    final registrationNumberC = TextEditingController(text: business.registrationNumber ?? '');
    final contactPersonC = TextEditingController(text: business.contactPerson ?? '');
    final websiteC = TextEditingController(text: business.website ?? '');
    final notesC = TextEditingController(text: business.notes ?? '');
    bool hidePassword = true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Edit Biznes',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Informacioni bazë
                  const Text(
                    'Informacioni Bazë',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i biznesit *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordC,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password (opsional)',
                      hintText: 'lëre zbrazët nëse s\'do me ndrru',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ownerNameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i pronarit/përgjegjësit (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Kontakt
                  const Text(
                    'Kontakt',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailC,
                    decoration: const InputDecoration(
                      labelText: 'Email (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contactPersonC,
                    decoration: const InputDecoration(
                      labelText: 'Personi kontaktues (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: websiteC,
                    decoration: const InputDecoration(
                      labelText: 'Website (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Adresa
                  const Text(
                    'Adresa',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressC,
                    decoration: const InputDecoration(
                      labelText: 'Adresa (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityC,
                          decoration: const InputDecoration(
                            labelText: 'Qyteti (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: postalCodeC,
                          decoration: const InputDecoration(
                            labelText: 'Kodi postar (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Të dhëna ligjore
                  const Text(
                    'Të Dhëna Ligjore',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: taxIdC,
                    decoration: const InputDecoration(
                      labelText: 'NIPT/Numri tatimor (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: registrationNumberC,
                    decoration: const InputDecoration(
                      labelText: 'Numri i regjistrimit (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Shënime
                  TextField(
                    controller: notesC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Shënime (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulo'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameC.text.trim();
                      if (name.isEmpty) {
                        _showError('Shkruaj emrin e biznesit.');
                        return;
                      }

                      setLocal(() => saving = true);
                      try {
                        await LocalApi.I.updateBusiness(
                          businessId: business.id,
                          name: name,
                          password: passwordC.text.trim().isEmpty ? null : passwordC.text,
                          address: addressC.text.trim().isEmpty ? null : addressC.text.trim(),
                          city: cityC.text.trim().isEmpty ? null : cityC.text.trim(),
                          postalCode: postalCodeC.text.trim().isEmpty ? null : postalCodeC.text.trim(),
                          phone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                          email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                          ownerName: ownerNameC.text.trim().isEmpty ? null : ownerNameC.text.trim(),
                          taxId: taxIdC.text.trim().isEmpty ? null : taxIdC.text.trim(),
                          registrationNumber: registrationNumberC.text.trim().isEmpty ? null : registrationNumberC.text.trim(),
                          contactPerson: contactPersonC.text.trim().isEmpty ? null : contactPersonC.text.trim(),
                          website: websiteC.text.trim().isEmpty ? null : websiteC.text.trim(),
                          notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _loadBusinesses();
                        await _showSuccessDialog('Biznesi u përditësu ✅');
                      } catch (e) {
                        _showError('Gabim: $e');
                      } finally {
                        if (mounted) setLocal(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.save),
              label: Text(saving ? 'Duke ruajt...' : 'RUAJ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteBusiness(Business business) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Fshij biznes?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Je i sigurt që do me fshi "${business.name}"? Kjo do të fshijë edhe të gjithë user-at e këtij biznesi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Fshij'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteBusiness(Business business) async {
    final ok = await _confirmDeleteBusiness(business);
    if (!ok) return;

    setState(() => loading = true);
    try {
      await LocalApi.I.deleteBusiness(business.id);
      await _loadBusinesses();
      await _showSuccessDialog('Biznesi u fshi ✅');
    } catch (e) {
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> doLogout(BuildContext context) async {
    await RoleStore.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${pad2(d.day)}.${pad2(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppTheme.surface2,
              border: Border(
                right: BorderSide(color: AppTheme.stroke, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.developer_mode,
                          color: AppTheme.primaryPurple,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'DEVELOPER',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.stroke, height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Panel për testim dhe debug',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Superadmin',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: const BorderSide(color: AppTheme.stroke),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => doLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // System Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryPurple.withOpacity(0.1),
                                Colors.blue.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.primaryPurple, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Developer Panel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppTheme.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Këtu mund të shihni të gjitha bizneset e regjistruara, përdoruesit, dhe informacione të tjera diagnostikuese.',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/icons/binary_devs.png',
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Të gjitha bizneset',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${businesses.length} ${businesses.length == 1 ? 'biznes' : 'biznese'}',
                                style: const TextStyle(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _loadBusinesses,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Rifresko'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.text,
                                side: const BorderSide(color: AppTheme.stroke),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _openCreateBusinessDialog,
                              icon: const Icon(Icons.add_business),
                              label: const Text('Krijo Biznes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.stroke),
                            ),
                            child: businesses.isEmpty
                                ? Center(
                                    child: Text(
                                      'S\'ka biznese. Kliko "Krijo Biznes" për të shtuar një të ri.',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: businesses.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final b = businesses[i];

                                      return Slidable(
                                        key: ValueKey('business-${b.id}'),
                                        endActionPane: ActionPane(
                                          motion: const DrawerMotion(),
                                          extentRatio: 0.28,
                                          children: [
                                            SlidableAction(
                                              onPressed: (_) =>
                                                  _openEditBusinessDialog(b),
                                              backgroundColor: Colors.blueGrey,
                                              foregroundColor: Colors.white,
                                              icon: Icons.edit,
                                              label: 'Edit',
                                            ),
                                            SlidableAction(
                                              onPressed: (_) => _deleteBusiness(b),
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              icon: Icons.delete_forever,
                                              label: 'Fshij',
                                            ),
                                          ],
                                        ),
                                        child: Card(
                                          margin: EdgeInsets.zero,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.transparent,
                                              child: ClipOval(
                                                child: Image.asset(
                                                  'assets/icons/binary_devs.png',
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    b.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                // Stats badges
                                                if (businessStats[b.id] != null) ...[
                                                  _statBadge(
                                                    icon: Icons.inventory_2,
                                                    label: '${businessStats[b.id]!['products']} prod.',
                                                    color: Colors.blue,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _statBadge(
                                                    icon: Icons.people,
                                                    label: '${businessStats[b.id]!['users']} users',
                                                    color: Colors.orange,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                // Pronari
                                                if (b.ownerName != null && b.ownerName!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.person, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                          'Pronari: ${b.ownerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Email
                                                if (b.email != null && b.email!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.email, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Email: ${b.email}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Telefon
                                                if (b.phone != null && b.phone!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.phone, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Telefon: ${b.phone}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Personi kontaktues
                                                if (b.contactPerson != null && b.contactPerson!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.contact_mail, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Kontakt: ${b.contactPerson}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Adresa e plotë
                                                if ((b.address != null && b.address!.isNotEmpty) ||
                                                    (b.city != null && b.city!.isNotEmpty) ||
                                                    (b.postalCode != null && b.postalCode!.isNotEmpty))
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(Icons.location_on, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            [
                                                              if (b.address != null && b.address!.isNotEmpty) b.address,
                                                              if (b.city != null && b.city!.isNotEmpty) b.city,
                                                              if (b.postalCode != null && b.postalCode!.isNotEmpty) b.postalCode,
                                                            ].where((e) => e != null && e.isNotEmpty).join(', '),
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // NIPT
                                                if (b.taxId != null && b.taxId!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.badge, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'NIPT: ${b.taxId}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Numri i regjistrimit
                                                if (b.registrationNumber != null && b.registrationNumber!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.description, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Nr. Regjistrimit: ${b.registrationNumber}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Website
                                                if (b.website != null && b.website!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.language, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Website: ${b.website}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Shënime
                                                if (b.notes != null && b.notes!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(Icons.note, size: 14, color: AppTheme.muted),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            'Shënime: ${b.notes}',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 12,
                                                              color: Colors.grey.shade600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.surface2,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.lock, size: 12, color: AppTheme.muted),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Password: ${b.password}',
                                                        style: TextStyle(
                                                          color: AppTheme.muted,
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 11,
                                                          fontFamily: 'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Krijuar: ${_formatDate(b.createdAtMs)}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Edit',
                                                  onPressed: () =>
                                                      _openEditBusinessDialog(b),
                                                  icon: const Icon(Icons.edit),
                                                ),
                                                IconButton(
                                                  tooltip: 'Fshij',
                                                  onPressed: () =>
                                                      _deleteBusiness(b),
                                                  icon: const Icon(
                                                    Icons.delete_forever,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPopup extends StatelessWidget {
  final String message;
  const _SuccessPopup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 2,
            color: Colors.black.withOpacity(0.35),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withOpacity(0.35)),
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
