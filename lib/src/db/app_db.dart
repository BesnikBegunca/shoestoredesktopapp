import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';
import 'database_manager.dart';

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();

  Database? _db;

  Future<void> _tryAddColumn(Database d, String table, String columnSql) async {
    try {
      await d.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {
      // ignore
    }
  }

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    DatabaseManager.ensureSqfliteInitialized();

    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'shoe_store.db');

    final database = await openDatabase(
      dbPath,
      version: kDbVersion,
      onCreate: (d, v) async {
        await d.execute(kSqlCreateUsers);
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);

        // ✅ default worker
        final now = DateTime.now().millisecondsSinceEpoch;
        await d.insert('users', {
          'username': 'worker1',
          'role': 'worker',
          'active': 1,
          'createdAtMs': now,
        });
      },
      onUpgrade: (d, oldV, newV) async {
        await d.execute(kSqlCreateUsers);
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);

        if (oldV < 5) {
          await _tryAddColumn(d, 'sales', 'userId INTEGER NOT NULL DEFAULT 0');
          await _tryAddColumn(d, 'investments', 'userId INTEGER NOT NULL DEFAULT 0');
          await _tryAddColumn(d, 'expenses', 'userId INTEGER NOT NULL DEFAULT 0');
        }
      },
      onOpen: (d) async {
        await d.execute(kSqlCreateUsers);
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);

        await _tryAddColumn(d, 'sales', 'userId INTEGER NOT NULL DEFAULT 0');
        await _tryAddColumn(d, 'investments', 'userId INTEGER NOT NULL DEFAULT 0');
        await _tryAddColumn(d, 'expenses', 'userId INTEGER NOT NULL DEFAULT 0');
      },
    );

    _db = database;
    return database;
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }
}
