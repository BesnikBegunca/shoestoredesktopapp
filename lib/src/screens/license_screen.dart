import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../license/license_service.dart';
import '../theme/app_theme.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // License activation
  final _licenseController = TextEditingController();
  bool _licenseLoading = false;
  String? _licenseError;

  // Developer login
  final _devUsernameController = TextEditingController();
  final _devPasswordController = TextEditingController();
  bool _devAuthenticated = false;
  String? _devError;

  // License generation
  final _customerIdController = TextEditingController();
  bool _generateLoading = false;
  String? _generatedKey;

  // Live status + countdown
  LicenseMode _mode = LicenseMode.unlicensed;
  String _countdown = '--:--';
  Timer? _uiTimer; // refresh UI every second

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _refresh(); // initial
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _uiTimer?.cancel();

    _tabController.dispose();
    _licenseController.dispose();
    _devUsernameController.dispose();
    _devPasswordController.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final mode = await LicenseService.I.checkStatus();

    String cd = '--:--';
    if (mode == LicenseMode.active) {
      cd = await LicenseService.I.remainingFormatted();
    }

    if (!mounted) return;

    // Update state only if changed (avoids extra rebuild noise)
    if (mode != _mode || cd != _countdown) {
      setState(() {
        _mode = mode;
        _countdown = cd;
      });
    }
  }

  Color _modeColor(LicenseMode m) {
    switch (m) {
      case LicenseMode.active:
        return AppTheme.success;
      case LicenseMode.expired_readonly:
        return Colors.orange;
      case LicenseMode.tampered:
        return Colors.red;
      case LicenseMode.unlicensed:
        return AppTheme.muted;
    }
  }

  IconData _modeIcon(LicenseMode m) {
    switch (m) {
      case LicenseMode.active:
        return Icons.verified;
      case LicenseMode.expired_readonly:
        return Icons.schedule;
      case LicenseMode.tampered:
        return Icons.warning_amber_rounded;
      case LicenseMode.unlicensed:
        return Icons.lock_outline;
    }
  }

  String _modeLabel(LicenseMode m) {
    switch (m) {
      case LicenseMode.active:
        return 'ACTIVE';
      case LicenseMode.expired_readonly:
        return 'EXPIRED (READONLY)';
      case LicenseMode.tampered:
        return 'TAMPERED (CLOCK CHANGED)';
      case LicenseMode.unlicensed:
        return 'UNLICENSED';
    }
  }

  Widget _statusCard() {
    final color = _modeColor(_mode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Icon(_modeIcon(_mode), color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _modeLabel(_mode),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                if (_mode == LicenseMode.active)
                  Text(
                    'Skadon për: $_countdown',
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (_mode == LicenseMode.expired_readonly)
                  const Text(
                    'Licenca ka skadu. Fut key të ri për me vazhdu.',
                    style: TextStyle(color: AppTheme.muted),
                  )
                else if (_mode == LicenseMode.tampered)
                  const Text(
                    'Ora e sistemit u ndryshu mbrapa. Rregullo kohën dhe fut key prap.',
                    style: TextStyle(color: AppTheme.muted),
                  )
                else
                  const Text(
                    'Fut një key për me aktivizu licencën.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _licenseLoading ? null : _clearLicense,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _activateLicense() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      setState(() => _licenseError = 'Please enter a license key');
      return;
    }

    setState(() {
      _licenseLoading = true;
      _licenseError = null;
    });

    try {
      await LicenseService.I.activate(key);
      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License activated ✅')),
      );

      // Pop back to BootGate with success result to allow app usage
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _licenseError = e.toString());
    } finally {
      if (mounted) setState(() => _licenseLoading = false);
    }
  }

  Future<void> _clearLicense() async {
    await LicenseService.I.clearLicense();
    await _refresh();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License cleared')),
    );
  }

  void _loginDeveloper() {
    final username = _devUsernameController.text.trim();
    final password = _devPasswordController.text.trim();

    if (LicenseService.I.authenticateDeveloper(username, password)) {
      setState(() {
        _devAuthenticated = true;
        _devError = null;
      });
    } else {
      setState(() => _devError = 'Invalid credentials');
    }
  }

  Future<void> _generateLicense() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a customer ID')),
      );
      return;
    }

    setState(() => _generateLoading = true);

    try {
      final key = await LicenseService.I.generateLicenseKey(customerId);
      if (!mounted) return;
      setState(() => _generatedKey = key);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating license: $e')),
      );
    } finally {
      if (mounted) setState(() => _generateLoading = false);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License key copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        foregroundColor: AppTheme.text,
        title: const Text(
          'License Management',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activate License'),
            Tab(text: 'Developer Tools'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ======================
          // Activate License TAB
          // ======================
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statusCard(),
                    const SizedBox(height: 24),

                    const Icon(Icons.lock_outline,
                        size: 80, color: AppTheme.text),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter License Key',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This application requires a valid license to function.\nPlease enter your license key below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: _licenseController,
                      style: const TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        labelText: 'License Key',
                        hintText: 'payload.signature',
                        border: const OutlineInputBorder(),
                        errorText: _licenseError,
                      ),
                      maxLines: 3,
                      enabled: !_licenseLoading,
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _licenseLoading ? null : _activateLicense,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        child: _licenseLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Activate License'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================
          // Developer Tools TAB
          // ======================
          Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Developer Login',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!_devAuthenticated) ...[
                      TextField(
                        controller: _devUsernameController,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _devPasswordController,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (_devError != null)
                        Text(_devError!,
                            style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loginDeveloper,
                          child: const Text('Login as Developer'),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        '✅ Developer authenticated',
                        style: TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Generate License Key',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customerIdController,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          labelText: 'Customer ID',
                          hintText: 'Enter customer identifier',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _generateLoading ? null : _generateLicense,
                          child: _generateLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Generate License'),
                        ),
                      ),
                      if (_generatedKey != null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Generated License Key:',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.stroke),
                          ),
                          child: SelectableText(
                            _generatedKey!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _copyToClipboard(_generatedKey!),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy to Clipboard'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  _licenseController.text = _generatedKey!;
                                  _tabController.animateTo(0);
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Use This License'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
