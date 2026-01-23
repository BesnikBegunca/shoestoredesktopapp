// license_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/role_store.dart';
import '../license/license_checker.dart';
import '../theme/app_theme.dart';

class LicenseInfoScreen extends StatefulWidget {
  const LicenseInfoScreen({super.key});

  @override
  State<LicenseInfoScreen> createState() => _LicenseInfoScreenState();
}

class _LicenseInfoScreenState extends State<LicenseInfoScreen> {
  LicenseInfo? _licenseInfo;
  bool _loading = true;
  String? _businessName;

  @override
  void initState() {
    super.initState();
    _loadLicenseInfo();
  }

  Future<void> _loadLicenseInfo() async {
    setState(() => _loading = true);
    
    try {
      final businessId = await RoleStore.getBusinessId();
      if (businessId == null) {
        setState(() => _loading = false);
        return;
      }

      // Load business name from SharedPreferences if available
      final prefs = await SharedPreferences.getInstance();
      _businessName = prefs.getString('business_name');

      final info = await LicenseChecker.getBusinessLicenseInfo(businessId);
      setState(() {
        _licenseInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _copyLicenseKey() {
    if (_licenseInfo?.licenseKey != null) {
      Clipboard.setData(ClipboardData(text: _licenseInfo!.licenseKey));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çelësi i licensës u kopjua!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Informacioni i Licensës',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                if (_licenseInfo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _licenseInfo!.isExpired
                          ? Colors.red.withOpacity(0.15)
                          : _licenseInfo!.isExpiringSoon
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _licenseInfo!.isExpired
                            ? Colors.red.withOpacity(0.35)
                            : _licenseInfo!.isExpiringSoon
                            ? Colors.orange.withOpacity(0.35)
                            : Colors.green.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      _licenseInfo!.status,
                      style: TextStyle(
                        color: _licenseInfo!.isExpired
                            ? Colors.red
                            : _licenseInfo!.isExpiringSoon
                            ? Colors.orange
                            : Colors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _licenseInfo == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 64,
                              color: Colors.orange.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nuk ka licensë të aktivizuar',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kontaktoni administratorin për të aktivizuar licensën.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Icon(
                              Icons.vpn_key,
                              size: 64,
                              color: _licenseInfo!.isExpired
                                  ? Colors.red
                                  : AppTheme.primaryPurple,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _licenseInfo!.isExpired
                                  ? 'Licensa ka Skaduar'
                                  : 'Licensa Aktive',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                            if (_businessName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _businessName!,
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 30),
                            
                            // Days Remaining Card
                            Container(
                              width: 500,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _licenseInfo!.isExpired
                                    ? Colors.red.withOpacity(0.1)
                                    : _licenseInfo!.isExpiringSoon
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _licenseInfo!.isExpired
                                      ? Colors.red
                                      : _licenseInfo!.isExpiringSoon
                                      ? Colors.orange
                                      : Colors.green,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_licenseInfo!.daysRemaining}',
                                    style: TextStyle(
                                      color: _licenseInfo!.isExpired
                                          ? Colors.red
                                          : _licenseInfo!.isExpiringSoon
                                          ? Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ditë të Mbetura',
                                    style: TextStyle(
                                      color: AppTheme.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // License Details
                            Container(
                              width: 500,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.stroke),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow('Data e Lëshimit', _licenseInfo!.issuedAtFormatted),
                                  const Divider(height: 24),
                                  _buildInfoRow('Data e Skadimit', _licenseInfo!.expiresAtFormatted),
                                  const Divider(height: 24),
                                  _buildInfoRow('Validiteti', '${_licenseInfo!.validDays} ditë'),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Çelësi i Licensës',
                                        style: TextStyle(
                                          color: AppTheme.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 200),
                                            child: Text(
                                              _licenseInfo!.licenseKey,
                                              style: const TextStyle(
                                                color: AppTheme.text,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _copyLicenseKey,
                                            icon: const Icon(Icons.copy, size: 16),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Kopjo',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            if (_licenseInfo!.isExpired)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Licensa juaj ka skaduar! Kontaktoni administratorin për ta rinovuar.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_licenseInfo!.isExpiringSoon)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Licensa juaj po skadon së shpejti! Kontaktoni administratorin për ta rinovuar.',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
