import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'shoe_store.db');

    final database = await openDatabase(
      dbPath,
      version: kDbVersion,
      onCreate: (d, v) async {
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
      },
      onUpgrade: (d, oldV, newV) async {
        // future migrations
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
