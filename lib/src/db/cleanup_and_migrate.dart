import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_manager.dart';
import '../license/license_service.dart';

/// Script për të fshirë databazat e vjetra dhe filluar nga e para
class CleanupAndMigrate {
  CleanupAndMigrate._();

  /// Fshi të gjitha databazat dhe fillo nga e para
  static Future<void> cleanAllAndRestart() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    
    print('🗑️  Duke fshirë të gjitha databazat...');
    
    // Lista e të gjitha .sqlite files
    final files = await dir.list().toList();
    for (final file in files) {
      if (file.path.endsWith('.sqlite')) {
        final name = p.basename(file.path);
        await (file as File).delete();
        print('  ✅ Fshiu: $name');
      }
    }
    
    print('\n🔧 Duke krijuar sistemin e ri...');
    
    // Krijo admin DB me superadmin
    final adminDb = await DatabaseManager.getAdminDb();
    
    // Krijo superadmin user
    final now = DateTime.now().millisecondsSinceEpoch;
    await adminDb.insert('users', {
      'username': 'superadmin',
      'password': '123123',
      'role': 'superadmin',
      'active': 1,
      'createdAtMs': now,
    });
    
    print('  ✅ Superadmin u krijua (username: superadmin, password: 123123)');
    print('\n✨ Sistemi është i gatshëm!');
    print('   Login si superadmin për të filluar.');
  }

  /// Fshi vetëm bizneset dhe databazat e tyre (mbaj superadmin)
  static Future<void> deleteAllBusinesses() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final adminDb = await DatabaseManager.getAdminDb();
    
    print('🗑️  Duke fshirë të gjitha bizneset...');
    
    // Merr listën e bizneseve
    final businesses = await adminDb.query('businesses');
    
    for (final business in businesses) {
      final businessId = business['id'] as int;
      final businessName = business['name'] as String;
      
      // Fshi licensat
      await adminDb.delete('business_licenses', where: 'businessId = ?', whereArgs: [businessId]);
      
      // Fshi biznesin
      await adminDb.delete('businesses', where: 'id = ?', whereArgs: [businessId]);
      
      // Fshi databazën
      final dbPath = p.join(dir.path, 'business_$businessId.sqlite');
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      print('  ✅ Fshiu biznesin: $businessName (ID: $businessId)');
    }
    
    print('\n✨ Të gjitha bizneset u fshinë!');
  }

  /// Krijo një biznes test me të dhëna default
  static Future<void> createTestBusiness({
    String name = 'Dyqani Test',
    String password = 'test123',
    String ownerName = 'Pronar Test',
    String email = 'test@test.com',
    String phone = '044123456',
  }) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final adminDb = await DatabaseManager.getAdminDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    print('🏢 Duke krijuar biznesin test: $name');
    
    // 1. Krijo biznesin në admin DB
    final businessId = await adminDb.insert('businesses', {
      'name': name,
      'password': password,
      'address': 'Adresa Test',
      'city': 'Prishtinë',
      'postalCode': '10000',
      'phone': phone,
      'email': email,
      'ownerName': ownerName,
      'taxId': '123456789',
      'registrationNumber': 'REG123',
      'contactPerson': ownerName,
      'website': '',
      'notes': 'Biznes test për zhvillim',
      'createdByUserId': 1, // superadmin
      'createdAtMs': now,
      'active': 1,
    });
    
    print('  ✅ Biznesi u krijua (ID: $businessId)');
    
    // 2. Krijo databazën e biznesit
    await DatabaseManager.createBusinessDatabase(businessId);
    final businessDb = await DatabaseManager.getBusinessDb(businessId);
    
    print('  ✅ Databaza e biznesit u krijua');
    
    // 3. Krijo admin user në business DB
    final username = email.isNotEmpty ? email : name.toLowerCase().replaceAll(' ', '');
    await businessDb.insert('users', {
      'username': username,
      'password': password,
      'role': 'admin',
      'active': 1,
      'createdAtMs': now,
      'businessId': businessId,
    });
    
    print('  ✅ Admin user u krijua (username: $username, password: $password)');
    
    // 4. Krijo licensën 365-ditore
    final validDays = 365;
    final licenseKey = await LicenseService.I.generateLicenseKey(
      'business-$businessId',
      validDays: validDays,
    );
    
    final expiresAtMs = now + (validDays * 24 * 60 * 60 * 1000);
    
    await adminDb.insert('business_licenses', {
      'businessId': businessId,
      'licenseKey': licenseKey,
      'validDays': validDays,
      'issuedAtMs': now,
      'expiresAtMs': expiresAtMs,
      'activatedAtMs': now,
      'lastCheckedMs': now,
      'active': 1,
      'notes': 'Licensa test 365-ditore',
    });
    
    print('  ✅ Licensa 365-ditore u krijua');
    print('\n✨ Biznesi test është gati!');
    print('   Login: $username / $password');
  }

  /// Shfaq informacion mbi databazat aktuale
  static Future<void> printSystemInfo() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    
    print('\n📊 Informacion i Sistemit');
    print('═' * 60);
    
    // Databazat
    print('\n📁 Databazat:');
    final files = await dir.list().toList();
    for (final file in files) {
      if (file.path.endsWith('.sqlite')) {
        final name = p.basename(file.path);
        final size = await (file as File).length();
        final sizeKB = (size / 1024).toStringAsFixed(2);
        print('  • $name ($sizeKB KB)');
      }
    }
    
    // Bizneset
    try {
      final adminDb = await DatabaseManager.getAdminDb();
      final businesses = await adminDb.query('businesses');
      
      print('\n🏢 Bizneset (${businesses.length}):');
      for (final b in businesses) {
        final id = b['id'];
        final name = b['name'];
        final email = b['email'] ?? 'N/A';
        
        // Kontrollo licensën
        final licenseRows = await adminDb.query(
          'business_licenses',
          where: 'businessId = ? AND active = 1',
          whereArgs: [id],
          orderBy: 'expiresAtMs DESC',
          limit: 1,
        );
        
        String licenseStatus = 'N/A';
        if (licenseRows.isNotEmpty) {
          final expiresAt = licenseRows.first['expiresAtMs'] as int;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now < expiresAt) {
            final daysLeft = ((expiresAt - now) / (24 * 60 * 60 * 1000)).ceil();
            licenseStatus = '✅ Aktive ($daysLeft ditë)';
          } else {
            licenseStatus = '❌ E Skaduar';
          }
        }
        
        print('  • ID $id: $name ($email) - Licensa: $licenseStatus');
      }
      
      // Users
      final users = await adminDb.query('users');
      print('\n👤 Users në Admin DB (${users.length}):');
      for (final u in users) {
        final username = u['username'];
        final role = u['role'];
        print('  • $username ($role)');
      }
      
    } catch (e) {
      print('\n⚠️  Error duke lexuar admin DB: $e');
    }
    
    print('\n' + '═' * 60);
  }
}
