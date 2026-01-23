import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoe_store_manager/models/business.dart';

import '../../auth/role_store.dart';
import '../local/local_api.dart';
import '../theme/app_theme.dart';
import '../license/license_service.dart';
import '../license/license_checker.dart';
import 'login_screen.dart';

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  bool _authenticated = false;
  bool _loading = false;
  bool _hidePassword = true;
  bool _showAddForm = false;
  List<Business> _businesses = [];
  Map<int, Map<String, int>> _businessStats = {};
  Map<int, LicenseInfo?> _businessLicenses = {};
  final _passwordController = TextEditingController();
  
  // Add business form controllers
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _businessPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _nameController.dispose();
    _ownerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _businessPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_passwordController.text == '123123') {
      setState(() => _authenticated = true);
      await _loadBusinesses();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password gabim!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    // Clear session
    await RoleStore.clear();
    
    if (!mounted) return;
    
    // Navigate to login screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loading = true);
    try {
      final list = await LocalApi.I.getBusinesses(createdByUserId: null);
      
      // Load stats dhe licenses
      final stats = <int, Map<String, int>>{};
      final licenses = <int, LicenseInfo?>{};
      final allUsers = await LocalApi.I.getAllUsers();
      
      for (final b in list) {
        try {
          final businessUsers = allUsers.where((u) => u.businessId == b.id).toList();
          stats[b.id] = {
            'products': 0,
            'users': businessUsers.length,
            'sales': 0,
          };
          
          // ✅ Load license info
          final licenseInfo = await LicenseChecker.getBusinessLicenseInfo(b.id);
          licenses[b.id] = licenseInfo;
        } catch (e) {
          stats[b.id] = {'products': 0, 'users': 0, 'sales': 0};
          licenses[b.id] = null;
        }
      }
      
      if (!mounted) return;
      setState(() {
        _businesses = list;
        _businessStats = stats;
        _businessLicenses = licenses;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _addBusiness() async {
    // Validate required fields
    final name = _nameController.text.trim();
    final password = _businessPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('Ju lutem shkruani emrin e biznesit!');
      return;
    }

    if (password.isEmpty) {
      _showError('Ju lutem shkruani password-in!');
      return;
    }

    setState(() => _loading = true);

    try {
      // Get current logged-in user ID
      final createdByUserId = await RoleStore.getUserId();

      await LocalApi.I.createBusiness(
        name: name,
        password: password,
        ownerName: _ownerController.text.trim().isEmpty ? null : _ownerController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        createdByUserId: createdByUserId,
      );

      _showSuccess('Biznesi "$name" u shtua me sukses!');
      
      // Clear form and close
      _clearForm();
      setState(() => _showAddForm = false);
      
      // Reload businesses
      await _loadBusinesses();
    } catch (e) {
      _showError('Gabim gjatë shtimit të biznesit: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDeleteBusiness(Business business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Konfirmo Fshirjen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A jeni të sigurt që dëshironi të fshini këtë biznes?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📌 ${business.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade900,
                      fontSize: 14,
                    ),
                  ),
                  if (business.ownerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pronari: ${business.ownerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kjo veprim do të fshijë të gjitha të dhënat e biznesit, përfshirë databazën dedikuar!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Po, Fshije'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteBusiness(business);
    }
  }

  Future<void> _deleteBusiness(Business business) async {
    setState(() => _loading = true);

    try {
      await LocalApi.I.deleteBusiness(business.id);
      _showSuccess('Biznesi "${business.name}" u fshi me sukses!');
      await _loadBusinesses();
    } catch (e) {
      _showError('Gabim gjatë fshirjes së biznesit: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${pad2(d.day)}.${pad2(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icons/binary_devs.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      const Text(
                        'Developer Access',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtitle
                      const Text(
                        'Kjo faqe është vetëm për developer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Password Field
                      Material(
                        type: MaterialType.transparency,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Developer Password',
                            labelStyle: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w700,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF6366F1),
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF6366F1),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _hidePassword = !_hidePassword);
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                              ),
                              tooltip: _hidePassword
                                  ? 'Shfaq password'
                                  : 'Fsheh password',
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onSubmitted: (_) => _authenticate(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _authenticate,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.login, color: Colors.white),
                          label: const Text(
                            'HYR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Bar with Logout Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
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
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_businesses.length}',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Logout Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.logout,
                        size: 22,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _loadBusinesses,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Rifresko'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _showAddForm = !_showAddForm);
                    },
                    icon: Icon(_showAddForm ? Icons.close : Icons.add, size: 18),
                    label: Text(_showAddForm ? 'Mbyll' : 'Shto Biznes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Add Business Form (inline)
            if (_showAddForm)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_business,
                            color: Color(0xFF6366F1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Shto Biznes të Ri',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Form fields in grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'Emri i Biznesit',
                                icon: Icons.business,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _taxIdController,
                                label: 'NIPT',
                                icon: Icons.badge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _ownerController,
                                label: 'Pronari',
                                icon: Icons.person,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Telefon',
                                icon: Icons.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _businessPasswordController,
                                label: 'Password',
                                icon: Icons.lock,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _showAddForm = false);
                            _clearForm();
                          },
                          child: const Text('Anulo'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _addBusiness,
                          icon: _loading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_loading ? 'Duke ruajtur...' : 'Ruaj'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Business Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: Text(
                            'Emri i Biznesit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Pronari',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            'Telefoni',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'NIPT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Status Licensë',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Skadon më',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Text(
                            'Aksione',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Table Body
                  if (_businesses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'S\'ka biznese të regjistruara ende.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _businesses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (_, i) {
                        final b = _businesses[i];
                        final stats = _businessStats[b.id];
                        final license = _businessLicenses[b.id];
                        final isEven = i % 2 == 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isEven ? const Color(0xFFF8FAFC) : Colors.white,
                          ),
                          child: Row(
                            children: [
                              // Business Name
                              SizedBox(
                                width: 180,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          'assets/icons/binary_devs.png',
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        b.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Owner
                              SizedBox(
                                width: 100,
                                child: Text(
                                  b.ownerName ?? '-',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // Phone
                              SizedBox(
                                width: 90,
                                child: Text(
                                  b.phone ?? '-',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // NIPT (Tax ID)
                              SizedBox(
                                width: 80,
                                child: Text(
                                  b.taxId ?? '-',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // Password
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    b.password,
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              
                              // Email
                              SizedBox(
                                width: 120,
                                child: Text(
                                  b.email ?? '-',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                              // ✅ License Status
                              Expanded(
                                child: Center(
                                  child: _buildLicenseStatus(license),
                                ),
                              ),
                              
                              // ✅ Expires At
                              SizedBox(
                                width: 100,
                                child: Center(
                                  child: Text(
                                    license != null ? license.expiresAtFormatted : '-',
                                    style: TextStyle(
                                      color: license != null && license.isExpired 
                                          ? Colors.red 
                                          : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // ✅ Actions
                              SizedBox(
                                width: 140,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // License button
                                    ElevatedButton.icon(
                                      onPressed: () => _showLicenseDialog(b),
                                      icon: const Icon(Icons.vpn_key, size: 12),
                                      label: const Text(
                                        'Licenca',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Delete button
                                    IconButton(
                                      onPressed: () => _confirmDeleteBusiness(b),
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: Colors.red,
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Fshi Biznesin',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _ownerController.clear();
    _emailController.clear();
    _phoneController.clear();
    _taxIdController.clear();
    _businessPasswordController.clear();
  }

  // ✅ Build license status badge
  Widget _buildLicenseStatus(LicenseInfo? license) {
    if (license == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'S\'ka Licensë',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      );
    }

    if (license.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'E Skaduar',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      );
    }

    // Active
    final daysLeft = license.daysRemaining;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Aktive ($daysLeft ditë)',
        style: const TextStyle(
          color: Color(0xFF10B981),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  // ✅ Show license dialog
  Future<void> _showLicenseDialog(Business business) async {
    final validDaysController = TextEditingController(text: '365');
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Menaxho Licensën - ${business.name}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current License Info
              FutureBuilder<LicenseInfo?>(
                future: LicenseChecker.getBusinessLicenseInfo(business.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final license = snapshot.data;
                  if (license == null) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ky biznes nuk ka licensë aktive.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: license.isExpired ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: license.isExpired ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              license.isExpired ? Icons.error : Icons.check_circle,
                              color: license.isExpired ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              license.isExpired ? 'Licensë e Skaduar' : 'Licensë Aktive',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: license.isExpired ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _licenseInfoRow('Lëshuar më:', license.issuedAtFormatted),
                        _licenseInfoRow('Skadon më:', license.expiresAtFormatted),
                        _licenseInfoRow('Ditë të mbetura:', '${license.daysRemaining}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Key: ${license.licenseKeyShort}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: license.licenseKey));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('License key u kopjua!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              tooltip: 'Kopjo Key',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Add New License Section
              const Text(
                'Shto Licensë të Re',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: validDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ditë të Vlefshme',
                    hintText: '365',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Shënime (opsionale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mbyll'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final validDays = int.tryParse(validDaysController.text.trim());
              if (validDays == null || validDays <= 0) {
                _showError('Ditë të vlefshme invalide!');
                return;
              }

              try {
                setState(() => _loading = true);
                
                // Generate license key
                final licenseKey = await LicenseService.I.generateLicenseKey(
                  'business-${business.id}',
                  validDays: validDays,
                );
                
                // Add to database
                await LocalApi.I.addBusinessLicense(
                  businessId: business.id,
                  licenseKey: licenseKey,
                  validDays: validDays,
                  notes: notesController.text.trim().isEmpty 
                      ? null 
                      : notesController.text.trim(),
                );
                
                _showSuccess('Licensa u shtua me sukses!');
                Navigator.pop(ctx);
                await _loadBusinesses();
              } catch (e) {
                _showError('Gabim: $e');
              } finally {
                setState(() => _loading = false);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Shto Licensë'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _licenseInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
