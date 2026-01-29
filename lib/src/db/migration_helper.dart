import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_manager.dart';
import '../license/license_service.dart';

/// Helper class për të migruar nga databaza e vjetër single-tenant
/// tek sistemi i ri multi-tenant me databaza të veçanta
class MigrationHelper {
  MigrationHelper._();

  /// Kontrollo nëse ekziston databaza e vjetër (shoe_store.sqlite)
  static Future<bool> hasOldDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final oldPath = p.join(dir.path, 'shoe_store.sqlite');
    return File(oldPath).exists();
  }

  /// Kontrollo nëse ekziston databaza e re admin (në db/)
  static Future<bool> hasNewDatabase() async {
    final dbRoot = await DatabaseManager.getDatabaseRootPath();
    final newPath = p.join(dbRoot, DatabaseManager.kAdminDbFileName);
    return File(newPath).exists();
  }

  /// Migro nga databaza e vjetër tek e reja
  static Future<void> migrateToMultiTenant() async {
    DatabaseManager.ensureSqfliteInitialized();

    final dir = await getApplicationSupportDirectory();
    final oldPath = p.join(dir.path, 'shoe_store.sqlite');
    final backupPath = p.join(dir.path, 'shoe_store_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite');

    // 1. Backup i databazës së vjetër
    print('📦 Duke krijuar backup...');
    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      await oldFile.copy(backupPath);
      print('✅ Backup u krijua: $backupPath');
    } else {
      print('⚠️ Nuk u gjet databaza e vjetër.');
      return;
    }

    // 2. Hap databazën e vjetër
    print('📂 Duke hapur databazën e vjetër...');
    final oldDb = await openDatabase(oldPath);

    try {
      // 3. Krijo databazën admin dhe migro superadmin + businesses
      print('🔧 Duke krijuar databazën admin...');
      final adminDb = await DatabaseManager.getAdminDb();

      // Migro superadmin users
      final superadminUsers = await oldDb.query(
        'users',
        where: 'role = ?',
        whereArgs: ['superadmin'],
      );

      for (final user in superadminUsers) {
        try {
          await adminDb.insert('users', {
            'username': user['username'],
            'password': user['password'],
            'role': 'superadmin',
            'active': user['active'],
            'createdAtMs': user['createdAtMs'],
          });
          print('✅ Migruar superadmin: ${user['username']}');
        } catch (e) {
          print('⚠️ Superadmin already exists: ${user['username']}');
        }
      }

      // Migro businesses
      final businesses = await oldDb.query('businesses');
      print('📊 Duke migruar ${businesses.length} biznese...');

      for (final business in businesses) {
        final businessId = business['id'] as int;
        print('\n🏢 Biznes: ${business['name']}');

        // Krijo business në admin DB (nëse nuk ekziston)
        try {
          final existingBiz = await adminDb.query(
            'businesses',
            where: 'id = ?',
            whereArgs: [businessId],
          );

          if (existingBiz.isEmpty) {
            await adminDb.insert('businesses', business);
            print('  ✅ Biznesi u krijua në admin DB');
          } else {
            print('  ℹ️ Biznesi ekziston tashmë në admin DB');
          }
        } catch (e) {
          print('  ❌ Error duke krijuar biznesin: $e');
          continue;
        }

        // Krijo databazën e biznesit
        print('  📁 Duke krijuar databazën për biznesin...');
        await DatabaseManager.createBusinessDatabase(businessId);
        final businessDb = await DatabaseManager.getBusinessDb(businessId);

        // Migro users të biznesit
        final businessUsers = await oldDb.query(
          'users',
          where: 'businessId = ?',
          whereArgs: [businessId],
        );
        for (final user in businessUsers) {
          try {
            await businessDb.insert('users', user);
          } catch (e) {
            print('  ⚠️ User already exists: ${user['username']}');
          }
        }
        print('  ✅ Migruar ${businessUsers.length} users');

        // Migro products (TË GJITHA produktet shkojnë në çdo business - mund të modifikohet)
        final products = await oldDb.query('products');
        for (final product in products) {
          try {
            await businessDb.insert('products', product);
          } catch (e) {
            // Product already exists
          }
        }
        print('  ✅ Migruar ${products.length} produkte');

        // Migro product_variants
        try {
          final variants = await oldDb.query('product_variants');
          for (final variant in variants) {
            try {
              await businessDb.insert('product_variants', variant);
            } catch (e) {
              // Variant already exists
            }
          }
          print('  ✅ Migruar ${variants.length} variante');
        } catch (e) {
          print('  ℹ️ Nuk ka product_variants për të migruar');
        }

        // Migro sales (TË GJITHA sales shkojnë në çdo business - mund të modifikohet)
        final sales = await oldDb.query('sales');
        for (final sale in sales) {
          try {
            await businessDb.insert('sales', sale);
          } catch (e) {
            // Sale already exists
          }
        }
        print('  ✅ Migruar ${sales.length} shitje');

        // Migro sale_items
        final saleItems = await oldDb.query('sale_items');
        for (final item in saleItems) {
          try {
            await businessDb.insert('sale_items', item);
          } catch (e) {
            // Item already exists
          }
        }
        print('  ✅ Migruar ${saleItems.length} sale items');

        // Migro investments
        final investments = await oldDb.query('investments');
        for (final inv in investments) {
          try {
            await businessDb.insert('investments', inv);
          } catch (e) {
            // Investment already exists
          }
        }
        print('  ✅ Migruar ${investments.length} investime');

        // Migro expenses
        final expenses = await oldDb.query('expenses');
        for (final exp in expenses) {
          try {
            await businessDb.insert('expenses', exp);
          } catch (e) {
            // Expense already exists
          }
        }
        print('  ✅ Migruar ${expenses.length} shpenzime');

        // Migro settlements
        try {
          final settlements = await oldDb.query('settlements');
          for (final settlement in settlements) {
            try {
              await businessDb.insert('settlements', settlement);
            } catch (e) {
              // Settlement already exists
            }
          }
          print('  ✅ Migruar ${settlements.length} settlements');
        } catch (e) {
          print('  ℹ️ Nuk ka settlements për të migruar');
        }

        // 4. ✅ Auto-krijo licensën 365-ditore për çdo biznes
        print('  🔑 Duke krijuar licensën...');
        try {
          final now = DateTime.now().millisecondsSinceEpoch;
          final validDays = 365;
          
          // Check if license already exists
          final existingLicense = await adminDb.query(
            'business_licenses',
            where: 'businessId = ?',
            whereArgs: [businessId],
            limit: 1,
          );

          if (existingLicense.isEmpty) {
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
              'notes': 'Auto-krijuar gjatë migrimit',
            });
            print('  ✅ Licensa 365-ditore u krijua');
          } else {
            print('  ℹ️ Licensa ekziston tashmë');
          }
        } catch (e) {
          print('  ❌ Error duke krijuar licensën: $e');
        }

        print('  ✅ Migrimi i biznesit u kompletua!\n');
      }

      print('🎉 Migrimi u kompletua me sukses!');
      print('📦 Backup: $backupPath');
      print('🗄️ Databaza e re admin: shoe_store_admin.sqlite');
      print('🗄️ Databazat e bizneseve: business_*.sqlite');
      
    } catch (e) {
      print('❌ Error gjatë migrimit: $e');
      rethrow;
    } finally {
      await oldDb.close();
    }
  }

  /// Fshi databazën e vjetër (KUJDES: përdore vetëm pas migrimit të suksesshëm!)
  static Future<void> deleteOldDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final oldPath = p.join(dir.path, 'shoe_store.sqlite');
    final file = File(oldPath);
    
    if (await file.exists()) {
      await file.delete();
      print('✅ Databaza e vjetër u fshi');
    }
  }

  /// Print info mbi databazat (në db/)
  static Future<void> printDatabaseInfo() async {
    final dbRoot = await DatabaseManager.getDatabaseRootPath();
    print('\n📊 Database Info:');
    print('─' * 50);
    final dbDir = Directory(dbRoot);
    if (await dbDir.exists()) {
      final files = await dbDir.list().toList();
      for (final file in files) {
        if (file.path.endsWith('.sqlite')) {
          final name = p.basename(file.path);
          final size = await (file as File).length();
          final sizeKB = (size / 1024).toStringAsFixed(2);
          print('  $name ($sizeKB KB)');
        }
      }
    }
    print('─' * 50);
  }
}
