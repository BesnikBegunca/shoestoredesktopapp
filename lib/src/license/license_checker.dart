import '../db/database_manager.dart';

/// Klasa për të kontrolluar statusin e licensës së bizneseve
class LicenseChecker {
  LicenseChecker._();
  
  /// Kontrollo nëse një biznes ka licensë të vlefshme
  static Future<bool> isBusinessLicenseValid(int businessId) async {
    try {
      final adminDb = await DatabaseManager.getAdminDb();
      
      // Merr licensën më të re active për biznesin
      final rows = await adminDb.query(
        'business_licenses',
        where: 'businessId = ? AND active = 1',
        whereArgs: [businessId],
        orderBy: 'expiresAtMs DESC',
        limit: 1,
      );
      
      if (rows.isEmpty) return false;
      
      final license = rows.first;
      final expiresAt = license['expiresAtMs'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Kontrollo nëse ka skaduar
      if (now >= expiresAt) return false;
      
      // ✅ Update lastCheckedMs për anti-tamper
      await adminDb.update(
        'business_licenses',
        {'lastCheckedMs': now},
        where: 'id = ?',
        whereArgs: [license['id']],
      );
      
      return true;
    } catch (e) {
      // Në rast gabimi, kthe false për siguri
      return false;
    }
  }
  
  /// Merr detajet e licensës së biznesit
  static Future<LicenseInfo?> getBusinessLicenseInfo(int businessId) async {
    try {
      final adminDb = await DatabaseManager.getAdminDb();
      
      final rows = await adminDb.query(
        'business_licenses',
        where: 'businessId = ?',
        whereArgs: [businessId],
        orderBy: 'expiresAtMs DESC',
        limit: 1,
      );
      
      if (rows.isEmpty) return null;
      
      return LicenseInfo.fromRow(rows.first);
    } catch (e) {
      return null;
    }
  }
  
  /// Merr të gjitha licensat e një biznesi
  static Future<List<LicenseInfo>> getAllBusinessLicenses(int businessId) async {
    try {
      final adminDb = await DatabaseManager.getAdminDb();
      
      final rows = await adminDb.query(
        'business_licenses',
        where: 'businessId = ?',
        whereArgs: [businessId],
        orderBy: 'issuedAtMs DESC',
      );
      
      return rows.map((r) => LicenseInfo.fromRow(r)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Merr ditët e mbetura deri në skadim (0 nëse ka skaduar ose nuk ka licensë)
  static Future<int> getDaysRemaining(int businessId) async {
    final license = await getBusinessLicenseInfo(businessId);
    if (license == null) return 0;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= license.expiresAtMs) return 0;
    
    final remaining = license.expiresAtMs - now;
    final days = (remaining / (24 * 60 * 60 * 1000)).ceil();
    
    return days > 0 ? days : 0;
  }
  
  /// Merr statusin e licensës: "active", "expired", "none"
  static Future<String> getLicenseStatus(int businessId) async {
    final license = await getBusinessLicenseInfo(businessId);
    if (license == null) return 'none';
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= license.expiresAtMs) return 'expired';
    
    return 'active';
  }
}

/// Model për informacionin e licensës
class LicenseInfo {
  final int id;
  final int businessId;
  final String licenseKey;
  final int validDays;
  final int issuedAtMs;
  final int expiresAtMs;
  final int? activatedAtMs;
  final int? lastCheckedMs;
  final bool active;
  final String? notes;
  
  const LicenseInfo({
    required this.id,
    required this.businessId,
    required this.licenseKey,
    required this.validDays,
    required this.issuedAtMs,
    required this.expiresAtMs,
    this.activatedAtMs,
    this.lastCheckedMs,
    required this.active,
    this.notes,
  });
  
  static LicenseInfo fromRow(Map<String, Object?> r) {
    return LicenseInfo(
      id: (r['id'] as int?) ?? 0,
      businessId: (r['businessId'] as int?) ?? 0,
      licenseKey: (r['licenseKey'] as String?) ?? '',
      validDays: (r['validDays'] as int?) ?? 0,
      issuedAtMs: (r['issuedAtMs'] as int?) ?? 0,
      expiresAtMs: (r['expiresAtMs'] as int?) ?? 0,
      activatedAtMs: r['activatedAtMs'] as int?,
      lastCheckedMs: r['lastCheckedMs'] as int?,
      active: ((r['active'] as int?) ?? 1) == 1,
      notes: r['notes'] as String?,
    );
  }
  
  /// Formaton datën për shfaqje
  String formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${pad2(d.day)}.${pad2(d.month)}.${d.year}';
  }
  
  String get issuedAtFormatted => formatDate(issuedAtMs);
  String get expiresAtFormatted => formatDate(expiresAtMs);
  
  /// Kontrollo nëse ka skaduar
  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= expiresAtMs;
  }
  
  /// Merr ditët e mbetura
  int get daysRemaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiresAtMs) return 0;
    
    final remaining = expiresAtMs - now;
    final days = (remaining / (24 * 60 * 60 * 1000)).ceil();
    
    return days > 0 ? days : 0;
  }
  
  /// Kontrollo nëse po skadon së shpejti (më pak se 30 ditë)
  bool get isExpiringSoon {
    if (isExpired) return false;
    return daysRemaining <= 30;
  }
  
  /// Merr statusin e licensës për shfaqje
  String get status {
    if (isExpired) return 'Ka Skaduar';
    if (isExpiringSoon) return 'Po Skadon';
    return 'Aktive';
  }
  
  /// Merr license key të shkurtër për shfaqje (first 8 + last 8 chars)
  String get licenseKeyShort {
    if (licenseKey.length <= 20) return licenseKey;
    return '${licenseKey.substring(0, 8)}...${licenseKey.substring(licenseKey.length - 8)}';
  }
}
