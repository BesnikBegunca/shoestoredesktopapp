import 'cleanup_and_migrate.dart';

/// Script për të menaxhuar databazat
/// 
/// Përdorimi:
/// dart lib/src/db/run_cleanup.dart <command>
/// 
/// Komanda të disponueshme:
/// - clean_all: Fshi të gjitha databazat dhe fillo nga zero
/// - delete_businesses: Fshi vetëm bizneset (mbaj superadmin)
/// - create_test: Krijo një biznes test
/// - info: Shfaq informacion mbi databazat aktuale

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('''
╔══════════════════════════════════════════════════════════════╗
║                  Database Management Tool                    ║
╚══════════════════════════════════════════════════════════════╝

Komanda të disponueshme:

  clean_all          - Fshi TË GJITHA databazat dhe fillo nga zero
  delete_businesses  - Fshi vetëm bizneset (mbaj superadmin)
  create_test        - Krijo një biznes test
  info               - Shfaq informacion mbi databazat

Përdorimi:
  dart lib/src/db/run_cleanup.dart <command>

Shembuj:
  dart lib/src/db/run_cleanup.dart clean_all
  dart lib/src/db/run_cleanup.dart delete_businesses
  dart lib/src/db/run_cleanup.dart create_test
  dart lib/src/db/run_cleanup.dart info
    ''');
    return;
  }

  final command = args[0];

  switch (command) {
    case 'clean_all':
      print('\n⚠️  KUJDES: Kjo do të fshijë TË GJITHA databazat!');
      print('Prit 3 sekonda për të anuluar (Ctrl+C)...\n');
      await Future.delayed(const Duration(seconds: 3));
      await CleanupAndMigrate.cleanAllAndRestart();
      break;

    case 'delete_businesses':
      print('\n⚠️  KUJDES: Kjo do të fshijë të gjitha bizneset!');
      print('Prit 3 sekonda për të anuluar (Ctrl+C)...\n');
      await Future.delayed(const Duration(seconds: 3));
      await CleanupAndMigrate.deleteAllBusinesses();
      break;

    case 'create_test':
      await CleanupAndMigrate.createTestBusiness();
      break;

    case 'info':
      await CleanupAndMigrate.printSystemInfo();
      break;

    default:
      print('❌ Komandë e panjohur: $command');
      print('Përdor: clean_all, delete_businesses, create_test, ose info');
  }
}
