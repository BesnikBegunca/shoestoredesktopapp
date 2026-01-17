import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 4;

/* ======================= SQL ======================= */

const String kSqlCreateProducts = '''
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sku TEXT,
  serialNumber TEXT UNIQUE,
  price REAL NOT NULL,
  purchasePrice REAL,
  stockQty INTEGER NOT NULL DEFAULT 0,
  discountPercent REAL NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  imagePath TEXT,
  sizeStockJson TEXT,
  createdAtMs INTEGER,
  updatedAtMs INTEGER
);
''';

const String kSqlCreateSales = '''
CREATE TABLE IF NOT EXISTS sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceNo TEXT NOT NULL,
  total REAL NOT NULL,
  profitTotal REAL NOT NULL,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER
);
''';

const String kSqlCreateSaleItems = '''
CREATE TABLE IF NOT EXISTS sale_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  saleId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  name TEXT NOT NULL,
  sku TEXT,
  serialNumber TEXT,
  qty INTEGER NOT NULL,
  unitPrice REAL NOT NULL,
  unitPurchasePrice REAL NOT NULL,
  discountPercent REAL NOT NULL,
  lineTotal REAL NOT NULL,
  lineProfit REAL NOT NULL,
  shoeSize INTEGER,
  FOREIGN KEY (saleId) REFERENCES sales(id)
);
''';

const String kSqlCreateInvestments = '''
CREATE TABLE IF NOT EXISTS investments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount REAL NOT NULL,
  note TEXT,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER
);
''';

const String kSqlCreateExpenses = '''
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER
);
''';

/* ======================= HELPERS ======================= */

double round2(num n) => (n * 100).roundToDouble() / 100;
double clampDouble(double v, double min, double max) =>
    v < min ? min : (v > max ? max : v);

String pad2(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
String monthKey(DateTime d) => '${d.year}-${pad2(d.month)}';

double calcFinalPrice({
  required double price,
  required double discountPercent,
}) {
  final p = price.isFinite ? price : 0;
  final d = clampDouble(discountPercent.isFinite ? discountPercent : 0, 0, 100);
  return round2(p * (1 - d / 100));
}

Map<int, int> _decodeSizeStock(String? raw) {
  if (raw == null) return {};
  final t = raw.trim();
  if (t.isEmpty) return {};
  try {
    final m = jsonDecode(t);
    if (m is! Map) return {};
    final out = <int, int>{};
    for (final e in m.entries) {
      final k = int.tryParse(e.key.toString());
      final v = (e.value is num)
          ? (e.value as num).toInt()
          : int.tryParse('${e.value}');
      if (k != null && v != null) out[k] = v;
    }
    return out;
  } catch (_) {
    return {};
  }
}

String _encodeSizeStock(Map<int, int> sizeStock) {
  final clean = <String, int>{};
  for (final e in sizeStock.entries) {
    final s = e.key;
    final q = e.value;
    clean[s.toString()] = q < 0 ? 0 : q;
  }
  return jsonEncode(clean);
}

int _totalStock(Map<int, int> sizeStock) =>
    sizeStock.values.fold(0, (a, b) => a + (b < 0 ? 0 : b));

/* ======================= MODELS ======================= */

class Product {
  final int id;
  final String name;
  final String? sku;
  final String? serialNumber;
  final double price;
  final double? purchasePrice;

  final int stockQty;

  final double discountPercent;
  final bool active;
  final String? imagePath;

  final Map<int, int> sizeStock;

  final int? createdAtMs;
  final int? updatedAtMs;

  const Product({
    required this.id,
    required this.name,
    this.sku,
    this.serialNumber,
    required this.price,
    this.purchasePrice,
    required this.stockQty,
    required this.discountPercent,
    required this.active,
    this.imagePath,
    required this.sizeStock,
    this.createdAtMs,
    this.updatedAtMs,
  });

  double get finalPrice =>
      calcFinalPrice(price: price, discountPercent: discountPercent);

  List<int> get sizesSorted {
    final s = sizeStock.keys.toList()..sort();
    return s;
  }

  int qtyForSize(int size) => sizeStock[size] ?? 0;

  static Product fromRow(Map<String, Object?> r) {
    final jsonRaw = r['sizeStockJson'] as String?;
    final hasJson = jsonRaw != null && jsonRaw.trim().isNotEmpty;
    final decoded = _decodeSizeStock(jsonRaw);

    final legacyQty = (r['stockQty'] as int?) ?? 0;
    final sizeStock = hasJson ? decoded : <int, int>{};
    final total = hasJson ? _totalStock(sizeStock) : legacyQty;

    return Product(
      id: (r['id'] as int),
      name: (r['name'] as String?) ?? '',
      sku: r['sku'] as String?,
      serialNumber: r['serialNumber'] as String?,
      price: (r['price'] as num?)?.toDouble() ?? 0,
      purchasePrice: (r['purchasePrice'] as num?)?.toDouble(),
      stockQty: total,
      discountPercent: (r['discountPercent'] as num?)?.toDouble() ?? 0,
      active: ((r['active'] as int?) ?? 1) == 1,
      imagePath: r['imagePath'] as String?,
      sizeStock: sizeStock,
      createdAtMs: r['createdAtMs'] as int?,
      updatedAtMs: r['updatedAtMs'] as int?,
    );
  }
}

class ActivityItem {
  final String type; // SALE / INVEST / EXPENSE
  final int createdAtMs;
  final String title;
  final String sub;
  final double amount;

  final int? refId;

  final bool reverted;

  const ActivityItem({
    required this.type,
    required this.createdAtMs,
    required this.title,
    required this.sub,
    required this.amount,
    this.refId,
    this.reverted = false,
  });
}

class ExpenseDoc {
  final int id;
  final String category;
  final double amount;
  final String? note;
  final String dayKey;
  final String monthKey;
  final int createdAtMs;
  final int? revertedAtMs;

  const ExpenseDoc({
    required this.id,
    required this.category,
    required this.amount,
    this.note,
    required this.dayKey,
    required this.monthKey,
    required this.createdAtMs,
    this.revertedAtMs,
  });

  static ExpenseDoc fromRow(Map<String, Object?> r) => ExpenseDoc(
    id: (r['id'] as int),
    category: (r['category'] as String?) ?? '',
    amount: ((r['amount'] as num?) ?? 0).toDouble(),
    note: r['note'] as String?,
    dayKey: (r['dayKey'] as String?) ?? '',
    monthKey: (r['monthKey'] as String?) ?? '',
    createdAtMs: (r['createdAtMs'] as int?) ?? 0,
    revertedAtMs: r['revertedAtMs'] as int?,
  );
}

class AdminStats {
  final double totalSalesAll;
  final double totalProfitAll;
  final int countSalesAll;
  final double totalInvestAll;
  final double totalExpensesAll;

  final double totalSalesMonth;
  final double totalProfitMonth;
  final int countSalesMonth;
  final double totalInvestMonth;
  final double totalExpensesMonth;

  final double totalSalesToday;
  final double totalProfitToday;
  final int countSalesToday;
  final double totalInvestToday;
  final double totalExpensesToday;

  final int totalStock;
  final double totalStockValueFinal;

  const AdminStats({
    required this.totalSalesAll,
    required this.totalProfitAll,
    required this.countSalesAll,
    required this.totalInvestAll,
    required this.totalExpensesAll,
    required this.totalSalesMonth,
    required this.totalProfitMonth,
    required this.countSalesMonth,
    required this.totalInvestMonth,
    required this.totalExpensesMonth,
    required this.totalSalesToday,
    required this.totalProfitToday,
    required this.countSalesToday,
    required this.totalInvestToday,
    required this.totalExpensesToday,
    required this.totalStock,
    required this.totalStockValueFinal,
  });
}

class SellResult {
  final int saleId;
  final String invoiceNo;
  final double total;
  final double profit;

  const SellResult({
    required this.saleId,
    required this.invoiceNo,
    required this.total,
    required this.profit,
  });
}

/* ======================= LOCAL API ======================= */

class LocalApi {
  LocalApi._();
  static final LocalApi I = LocalApi._();

  Database? _db;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _open();
    _ready = true;
  }

  Future<void> _tryAddColumn(
    Database d, {
    required String table,
    required String columnSql,
  }) async {
    try {
      await d.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {
      // ignore
    }
  }

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final String dbPath = p.join(dir.path, 'shoe_store.sqlite');

    final db = await openDatabase(
      dbPath,
      version: kDbVersion,
      onCreate: (d, v) async {
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);
      },
      onUpgrade: (d, oldV, newV) async {
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);

        if (oldV < 2) {
          await _tryAddColumn(
            d,
            table: 'products',
            columnSql: 'sizeStockJson TEXT',
          );
        }
        if (oldV < 3) {
          await _tryAddColumn(
            d,
            table: 'sale_items',
            columnSql: 'shoeSize INTEGER',
          );
        }
        if (oldV < 4) {
          await _tryAddColumn(
            d,
            table: 'sales',
            columnSql: 'revertedAtMs INTEGER',
          );
          await _tryAddColumn(
            d,
            table: 'investments',
            columnSql: 'revertedAtMs INTEGER',
          );
          await _tryAddColumn(
            d,
            table: 'expenses',
            columnSql: 'revertedAtMs INTEGER',
          );
        }
      },
      onOpen: (d) async {
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);

        await _tryAddColumn(
          d,
          table: 'products',
          columnSql: 'sizeStockJson TEXT',
        );
        await _tryAddColumn(
          d,
          table: 'sale_items',
          columnSql: 'shoeSize INTEGER',
        );

        await _tryAddColumn(
          d,
          table: 'sales',
          columnSql: 'revertedAtMs INTEGER',
        );
        await _tryAddColumn(
          d,
          table: 'investments',
          columnSql: 'revertedAtMs INTEGER',
        );
        await _tryAddColumn(
          d,
          table: 'expenses',
          columnSql: 'revertedAtMs INTEGER',
        );
      },
    );

    _db = db;
    return db;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  /* ---------------- PRODUCTS ---------------- */

  Future<List<Product>> getProducts({
    String orderBy = 'createdAtMs DESC',
  }) async {
    final db = await _open();
    final rows = await db.query('products', orderBy: orderBy);
    return rows.map(Product.fromRow).toList();
  }

  Future<int> addProduct({
    required String name,
    String? sku,
    String? serialNumber,
    required double price,
    double? purchasePrice,
    required Map<int, int> sizeStock,
    required double discountPercent,
    required bool active,
    String? imagePath,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final total = _totalStock(sizeStock);

    final map = {
      'name': name.trim(),
      'sku': (sku?.trim().isEmpty ?? true) ? null : sku!.trim(),
      'serialNumber': (serialNumber?.trim().isEmpty ?? true)
          ? null
          : serialNumber!.trim(),
      'price': round2(price),
      'purchasePrice': purchasePrice == null ? null : round2(purchasePrice),
      'stockQty': total,
      'discountPercent': round2(discountPercent),
      'active': active ? 1 : 0,
      'imagePath': imagePath,
      'sizeStockJson': _encodeSizeStock(sizeStock),
      'createdAtMs': now,
      'updatedAtMs': now,
    };

    return db.insert('products', map);
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    String? sku,
    String? serialNumber,
    required double price,
    double? purchasePrice,
    required Map<int, int> sizeStock,
    required double discountPercent,
    required bool active,
    String? imagePath,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final total = _totalStock(sizeStock);

    final map = {
      'name': name.trim(),
      'sku': (sku?.trim().isEmpty ?? true) ? null : sku!.trim(),
      'serialNumber': (serialNumber?.trim().isEmpty ?? true)
          ? null
          : serialNumber!.trim(),
      'price': round2(price),
      'purchasePrice': purchasePrice == null ? null : round2(purchasePrice),
      'stockQty': total,
      'discountPercent': round2(discountPercent),
      'active': active ? 1 : 0,
      'imagePath': imagePath,
      'sizeStockJson': _encodeSizeStock(sizeStock),
      'updatedAtMs': now,
    };

    await db.update('products', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await _open();
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleActive(int id, bool active) async {
    final db = await _open();
    await db.update(
      'products',
      {
        'active': active ? 1 : 0,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> searchProductsBySerialOrName(String q) async {
    final db = await _open();
    final s = q.trim();
    if (s.isEmpty) return [];
    final like = '%$s%';

    final rows = await db.query(
      'products',
      where: '(serialNumber LIKE ? OR sku LIKE ? OR name LIKE ?)',
      whereArgs: [like, like, like],
      orderBy: 'createdAtMs DESC',
      limit: 50,
    );
    return rows.map(Product.fromRow).toList();
  }

  /* ---------------- SELL ---------------- */

  Future<SellResult> sellOne({
    required int productId,
    required int size,
  }) async {
    final db = await _open();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    return db.transaction((tx) async {
      final prodRows = await tx.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (prodRows.isEmpty) throw Exception('Produkti nuk ekziston.');

      final p0 = Product.fromRow(prodRows.first);
      if (!p0.active) throw Exception('Ky produkt është OFF.');

      final map = Map<int, int>.from(p0.sizeStock);
      final q = map[size] ?? 0;
      if (q <= 0) throw Exception('S’ka stok për numrin $size.');

      map[size] = q - 1;
      final newTotal = _totalStock(map);

      final unitPrice = p0.finalPrice;
      final unitPurchase = (p0.purchasePrice ?? 0);
      final profit = round2(unitPrice - unitPurchase);
      final total = round2(unitPrice);

      await tx.update(
        'products',
        {
          'sizeStockJson': _encodeSizeStock(map),
          'stockQty': newTotal,
          'updatedAtMs': nowMs,
        },
        where: 'id = ?',
        whereArgs: [p0.id],
      );

      final invNo = 'INV-$nowMs';
      final saleId = await tx.insert('sales', {
        'invoiceNo': invNo,
        'total': total,
        'profitTotal': profit,
        'dayKey': dayKey(now),
        'monthKey': monthKey(now),
        'createdAtMs': nowMs,
        'revertedAtMs': null,
      });

      await tx.insert('sale_items', {
        'saleId': saleId,
        'productId': p0.id,
        'name': p0.name,
        'sku': p0.sku,
        'serialNumber': p0.serialNumber,
        'qty': 1,
        'unitPrice': unitPrice,
        'unitPurchasePrice': unitPurchase,
        'discountPercent': p0.discountPercent,
        'lineTotal': total,
        'lineProfit': profit,
        'shoeSize': size,
      });

      return SellResult(
        saleId: saleId,
        invoiceNo: invNo,
        total: total,
        profit: profit,
      );
    });
  }

  /* ---------------- REVERT ---------------- */

  /// ✅ Revert SALE: e kthen stokun mbrapsht (me size) dhe e shënon revertedAtMs
  Future<void> revertSale({required int saleId}) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      final saleRows = await tx.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) throw Exception('Shitja nuk ekziston.');

      final revertedAt = saleRows.first['revertedAtMs'] as int?;
      if (revertedAt != null)
        throw Exception('Kjo shitje veç është revert-uar.');

      final items = await tx.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      if (items.isEmpty) {
        // gjithsesi e shënojmë reverted, që mos me e pa si aktive
        await tx.update(
          'sales',
          {'revertedAtMs': nowMs},
          where: 'id = ?',
          whereArgs: [saleId],
        );
        return;
      }

      for (final it in items) {
        final productId = (it['productId'] as int);
        final qty = (it['qty'] as int?) ?? 1;
        final shoeSize = it['shoeSize'] as int?;

        final prodRows = await tx.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (prodRows.isEmpty) continue; // produkt i fshirë

        final p0 = Product.fromRow(prodRows.first);

        // ✅ nëse kemi shoeSize, e kthejm sizeStock
        if (shoeSize != null) {
          final map = Map<int, int>.from(p0.sizeStock);
          map[shoeSize] = (map[shoeSize] ?? 0) + qty;
          final total = _totalStock(map);

          await tx.update(
            'products',
            {
              'sizeStockJson': _encodeSizeStock(map),
              'stockQty': total,
              'updatedAtMs': nowMs,
            },
            where: 'id = ?',
            whereArgs: [productId],
          );
        } else {
          // fallback për shitje të vjetra pa shoeSize
          await tx.update(
            'products',
            {'stockQty': p0.stockQty + qty, 'updatedAtMs': nowMs},
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
      }

      // ✅ shëno sale si reverted
      await tx.update(
        'sales',
        {'revertedAtMs': nowMs},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  /// ✅ Revert INVEST (veç e shënon)
  Future<void> revertInvestment({required int investId}) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'investments',
      where: 'id = ?',
      whereArgs: [investId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Investimi nuk ekziston.');
    final revertedAt = rows.first['revertedAtMs'] as int?;
    if (revertedAt != null)
      throw Exception('Ky investim veç është revert-uar.');

    await db.update(
      'investments',
      {'revertedAtMs': nowMs},
      where: 'id = ?',
      whereArgs: [investId],
    );
  }

  /// ✅ Revert EXPENSE (veç e shënon)
  Future<void> revertExpense({required int expenseId}) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Shpenzimi nuk ekziston.');
    final revertedAt = rows.first['revertedAtMs'] as int?;
    if (revertedAt != null)
      throw Exception('Ky shpenzim veç është revert-uar.');

    await db.update(
      'expenses',
      {'revertedAtMs': nowMs},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  /* ---------------- INVESTMENTS ---------------- */

  Future<void> addInvestment({required double amount, String? note}) async {
    final db = await _open();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    if (!amount.isFinite || amount <= 0) throw Exception('Amount invalid.');

    await db.insert('investments', {
      'amount': round2(amount),
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'dayKey': dayKey(now),
      'monthKey': monthKey(now),
      'createdAtMs': nowMs,
      'revertedAtMs': null,
    });
  }

  Future<List<Map<String, Object?>>> getInvestments({
    String? monthKeyFilter,
  }) async {
    final db = await _open();
    if (monthKeyFilter == null) {
      return db.query('investments', orderBy: 'createdAtMs DESC', limit: 200);
    }
    return db.query(
      'investments',
      where: 'monthKey = ?',
      whereArgs: [monthKeyFilter],
      orderBy: 'createdAtMs DESC',
      limit: 200,
    );
  }

  /* ---------------- EXPENSES ---------------- */

  Future<void> addExpense({
    required String category,
    required double amount,
    String? note,
  }) async {
    final db = await _open();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final cat = category.trim();
    if (cat.isEmpty) throw Exception('Kategoria është e zbrazët.');
    if (!amount.isFinite || amount <= 0) throw Exception('Amount invalid.');

    await db.insert('expenses', {
      'category': cat,
      'amount': round2(amount),
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'dayKey': dayKey(now),
      'monthKey': monthKey(now),
      'createdAtMs': nowMs,
      'revertedAtMs': null,
    });
  }

  Future<List<ExpenseDoc>> getExpenses({String? monthKeyFilter}) async {
    final db = await _open();
    final rows = monthKeyFilter == null
        ? await db.query('expenses', orderBy: 'createdAtMs DESC', limit: 300)
        : await db.query(
            'expenses',
            where: 'monthKey = ?',
            whereArgs: [monthKeyFilter],
            orderBy: 'createdAtMs DESC',
            limit: 300,
          );
    return rows.map(ExpenseDoc.fromRow).toList();
  }

  /* ---------------- ADMIN / STATS ---------------- */

  Future<List<String>> getMonthOptions() async {
    final db = await _open();
    final rows1 = await db.rawQuery(
      'SELECT DISTINCT monthKey FROM sales ORDER BY monthKey DESC',
    );
    final rows2 = await db.rawQuery(
      'SELECT DISTINCT monthKey FROM investments ORDER BY monthKey DESC',
    );
    final rows3 = await db.rawQuery(
      'SELECT DISTINCT monthKey FROM expenses ORDER BY monthKey DESC',
    );

    final set = <String>{};
    set.add(monthKey(DateTime.now()));

    for (final r in rows1) {
      final mk = r['monthKey'] as String?;
      if (mk != null && mk.isNotEmpty) set.add(mk);
    }
    for (final r in rows2) {
      final mk = r['monthKey'] as String?;
      if (mk != null && mk.isNotEmpty) set.add(mk);
    }
    for (final r in rows3) {
      final mk = r['monthKey'] as String?;
      if (mk != null && mk.isNotEmpty) set.add(mk);
    }

    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<AdminStats> getAdminStats({required String selectedMonth}) async {
    final db = await _open();
    final todayK = dayKey(DateTime.now());

    // ✅ SALES: mos i numro reverted
    final sAll = await db.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp '
      'FROM sales WHERE revertedAtMs IS NULL',
    );
    final countAll = (sAll.first['c'] as int?) ?? 0;
    final totalSalesAll = ((sAll.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitAll = ((sAll.first['tp'] as num?) ?? 0).toDouble();

    final sM = await db.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp '
      'FROM sales WHERE monthKey = ? AND revertedAtMs IS NULL',
      [selectedMonth],
    );
    final countMonth = (sM.first['c'] as int?) ?? 0;
    final totalSalesMonth = ((sM.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitMonth = ((sM.first['tp'] as num?) ?? 0).toDouble();

    final sT = await db.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp '
      'FROM sales WHERE dayKey = ? AND revertedAtMs IS NULL',
      [todayK],
    );
    final countToday = (sT.first['c'] as int?) ?? 0;
    final totalSalesToday = ((sT.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitToday = ((sT.first['tp'] as num?) ?? 0).toDouble();

    // ✅ INVEST: mos i numro reverted
    final iAll = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM investments WHERE revertedAtMs IS NULL',
    );
    final totalInvestAll = ((iAll.first['s'] as num?) ?? 0).toDouble();

    final iM = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM investments WHERE monthKey = ? AND revertedAtMs IS NULL',
      [selectedMonth],
    );
    final totalInvestMonth = ((iM.first['s'] as num?) ?? 0).toDouble();

    final iT = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM investments WHERE dayKey = ? AND revertedAtMs IS NULL',
      [todayK],
    );
    final totalInvestToday = ((iT.first['s'] as num?) ?? 0).toDouble();

    // ✅ EXPENSE: mos i numro reverted
    final eAll = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE revertedAtMs IS NULL',
    );
    final totalExpensesAll = ((eAll.first['s'] as num?) ?? 0).toDouble();

    final eM = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE monthKey = ? AND revertedAtMs IS NULL',
      [selectedMonth],
    );
    final totalExpensesMonth = ((eM.first['s'] as num?) ?? 0).toDouble();

    final eT = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE dayKey = ? AND revertedAtMs IS NULL',
      [todayK],
    );
    final totalExpensesToday = ((eT.first['s'] as num?) ?? 0).toDouble();

    // STOCK totals + value final
    final pRows = await db.query(
      'products',
      columns: ['stockQty', 'price', 'discountPercent'],
    );
    int totalStock = 0;
    double totalValueFinal = 0;
    for (final r in pRows) {
      final qty = (r['stockQty'] as int?) ?? 0;
      final price = ((r['price'] as num?) ?? 0).toDouble();
      final disc = ((r['discountPercent'] as num?) ?? 0).toDouble();
      final fp = calcFinalPrice(price: price, discountPercent: disc);

      totalStock += qty;
      totalValueFinal += fp * qty;
    }

    return AdminStats(
      totalSalesAll: round2(totalSalesAll),
      totalProfitAll: round2(totalProfitAll),
      countSalesAll: countAll,
      totalInvestAll: round2(totalInvestAll),
      totalExpensesAll: round2(totalExpensesAll),

      totalSalesMonth: round2(totalSalesMonth),
      totalProfitMonth: round2(totalProfitMonth),
      countSalesMonth: countMonth,
      totalInvestMonth: round2(totalInvestMonth),
      totalExpensesMonth: round2(totalExpensesMonth),

      totalSalesToday: round2(totalSalesToday),
      totalProfitToday: round2(totalProfitToday),
      countSalesToday: countToday,
      totalInvestToday: round2(totalInvestToday),
      totalExpensesToday: round2(totalExpensesToday),

      totalStock: totalStock,
      totalStockValueFinal: round2(totalValueFinal),
    );
  }

  /// ✅ Activity me ID + reverted
  Future<List<ActivityItem>> getActivity({int limit = 60}) async {
    final db = await _open();

    final sales = await db.rawQuery(
      '''
      SELECT id, createdAtMs, total, profitTotal, invoiceNo, revertedAtMs
      FROM sales
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''',
      [limit],
    );

    final inv = await db.rawQuery(
      '''
      SELECT id, createdAtMs, amount, COALESCE(note,'') note, revertedAtMs
      FROM investments
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''',
      [limit],
    );

    final exp = await db.rawQuery(
      '''
      SELECT id, createdAtMs, amount, COALESCE(note,'') note, category, revertedAtMs
      FROM expenses
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''',
      [limit],
    );

    final items = <ActivityItem>[];

    for (final r in sales) {
      final id = (r['id'] as int?) ?? 0;
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final total = ((r['total'] as num?) ?? 0).toDouble();
      final profit = ((r['profitTotal'] as num?) ?? 0).toDouble();
      final invNo = (r['invoiceNo'] as String?) ?? '';
      final reverted = (r['revertedAtMs'] as int?) != null;

      items.add(
        ActivityItem(
          type: 'SALE',
          refId: id,
          reverted: reverted,
          createdAtMs: ms,
          title: reverted ? 'SHITJE (REVERT)' : 'SHITJE',
          sub:
              'Total: €${total.toStringAsFixed(2)} • Fitim: €${profit.toStringAsFixed(2)}${invNo.isEmpty ? '' : ' • $invNo'}',
          amount: total,
        ),
      );
    }

    for (final r in inv) {
      final id = (r['id'] as int?) ?? 0;
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final amount = ((r['amount'] as num?) ?? 0).toDouble();
      final note = (r['note'] as String?) ?? '';
      final reverted = (r['revertedAtMs'] as int?) != null;

      items.add(
        ActivityItem(
          type: 'INVEST',
          refId: id,
          reverted: reverted,
          createdAtMs: ms,
          title: reverted ? 'BLEJ MALL (REVERT)' : 'BLEJ MALL',
          sub: note.isEmpty ? '—' : note,
          amount: amount,
        ),
      );
    }

    for (final r in exp) {
      final id = (r['id'] as int?) ?? 0;
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final amount = ((r['amount'] as num?) ?? 0).toDouble();
      final note = (r['note'] as String?) ?? '';
      final cat = (r['category'] as String?) ?? 'Expense';
      final reverted = (r['revertedAtMs'] as int?) != null;

      items.add(
        ActivityItem(
          type: 'EXPENSE',
          refId: id,
          reverted: reverted,
          createdAtMs: ms,
          title: reverted ? 'SHPENZIM (REVERT)' : 'SHPENZIM',
          sub:
              '${cat.trim().isEmpty ? 'Tjera' : cat}${note.isEmpty ? '' : ' • $note'}',
          amount: amount,
        ),
      );
    }

    items.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items.take(limit).toList();
  }
}
