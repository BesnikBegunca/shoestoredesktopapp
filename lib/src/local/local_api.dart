import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int kDbVersion = 1;

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
  createdAtMs INTEGER NOT NULL
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
  createdAtMs INTEGER NOT NULL
);
''';

const String kSqlCreateExpenses = '''
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,   -- p.sh. "Rroga", "Qera", "Rryma", "Uji", "Berloku", "Tjera"
  amount REAL NOT NULL,
  note TEXT,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL
);
''';

double round2(num n) => (n * 100).roundToDouble() / 100;
double clampDouble(double v, double min, double max) =>
    v < min ? min : (v > max ? max : v);

String pad2(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
String monthKey(DateTime d) => '${d.year}-${pad2(d.month)}';

double calcFinalPrice({required double price, required double discountPercent}) {
  final p = price.isFinite ? price : 0;
  final d = clampDouble(discountPercent.isFinite ? discountPercent : 0, 0, 100);
  return round2(p * (1 - d / 100));
}

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
    this.createdAtMs,
    this.updatedAtMs,
  });

  double get finalPrice =>
      calcFinalPrice(price: price, discountPercent: discountPercent);

  Map<String, Object?> toMapForInsert() => {
    'name': name,
    'sku': sku,
    'serialNumber': serialNumber,
    'price': round2(price),
    'purchasePrice': purchasePrice == null ? null : round2(purchasePrice!),
    'stockQty': stockQty,
    'discountPercent': round2(discountPercent),
    'active': active ? 1 : 0,
    'imagePath': imagePath,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
  };

  static Product fromRow(Map<String, Object?> r) => Product(
    id: (r['id'] as int),
    name: (r['name'] as String?) ?? '',
    sku: r['sku'] as String?,
    serialNumber: r['serialNumber'] as String?,
    price: (r['price'] as num?)?.toDouble() ?? 0,
    purchasePrice: (r['purchasePrice'] as num?)?.toDouble(),
    stockQty: (r['stockQty'] as int?) ?? 0,
    discountPercent: (r['discountPercent'] as num?)?.toDouble() ?? 0,
    active: ((r['active'] as int?) ?? 1) == 1,
    imagePath: r['imagePath'] as String?,
    createdAtMs: r['createdAtMs'] as int?,
    updatedAtMs: r['updatedAtMs'] as int?,
  );
}

class ActivityItem {
  final String type; // SALE / INVEST / EXPENSE
  final int createdAtMs;
  final String title;
  final String sub;
  final double amount;

  const ActivityItem({
    required this.type,
    required this.createdAtMs,
    required this.title,
    required this.sub,
    required this.amount,
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

  const ExpenseDoc({
    required this.id,
    required this.category,
    required this.amount,
    this.note,
    required this.dayKey,
    required this.monthKey,
    required this.createdAtMs,
  });

  static ExpenseDoc fromRow(Map<String, Object?> r) => ExpenseDoc(
    id: (r['id'] as int),
    category: (r['category'] as String?) ?? '',
    amount: ((r['amount'] as num?) ?? 0).toDouble(),
    note: r['note'] as String?,
    dayKey: (r['dayKey'] as String?) ?? '',
    monthKey: (r['monthKey'] as String?) ?? '',
    createdAtMs: (r['createdAtMs'] as int?) ?? 0,
  );
}

class AdminStats {
  // TOTAL
  final double totalSalesAll;
  final double totalProfitAll;
  final int countSalesAll;
  final double totalInvestAll;
  final double totalExpensesAll;

  // MONTH (selected)
  final double totalSalesMonth;
  final double totalProfitMonth;
  final int countSalesMonth;
  final double totalInvestMonth;
  final double totalExpensesMonth;

  // TODAY
  final double totalSalesToday;
  final double totalProfitToday;
  final int countSalesToday;
  final double totalInvestToday;
  final double totalExpensesToday;

  // STOCK
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

    // Needed for desktop (Windows/macOS/Linux)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await _open();
    _ready = true;
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
        // ✅ sigurim: edhe nese db eshte e vjeter, krijo tabelat qe mungojne
        await d.execute(kSqlCreateProducts);
        await d.execute(kSqlCreateSales);
        await d.execute(kSqlCreateSaleItems);
        await d.execute(kSqlCreateInvestments);
        await d.execute(kSqlCreateExpenses);
      },
      onOpen: (d) async {
        // ✅ edhe nese versioni s’ndryshon (siguri ekstra)
        await d.execute(kSqlCreateExpenses);
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

  Future<List<Product>> getProducts({String orderBy = 'createdAtMs DESC'}) async {
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
    required int stockQty,
    required double discountPercent,
    required bool active,
    String? imagePath,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = {
      'name': name.trim(),
      'sku': (sku?.trim().isEmpty ?? true) ? null : sku!.trim(),
      'serialNumber': (serialNumber?.trim().isEmpty ?? true) ? null : serialNumber!.trim(),
      'price': round2(price),
      'purchasePrice': purchasePrice == null ? null : round2(purchasePrice),
      'stockQty': stockQty,
      'discountPercent': round2(discountPercent),
      'active': active ? 1 : 0,
      'imagePath': imagePath,
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
    required int stockQty,
    required double discountPercent,
    required bool active,
    String? imagePath,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final map = {
      'name': name.trim(),
      'sku': (sku?.trim().isEmpty ?? true) ? null : sku!.trim(),
      'serialNumber': (serialNumber?.trim().isEmpty ?? true) ? null : serialNumber!.trim(),
      'price': round2(price),
      'purchasePrice': purchasePrice == null ? null : round2(purchasePrice),
      'stockQty': stockQty,
      'discountPercent': round2(discountPercent),
      'active': active ? 1 : 0,
      'imagePath': imagePath,
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
      {'active': active ? 1 : 0, 'updatedAtMs': DateTime.now().millisecondsSinceEpoch},
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

  Future<SellResult> sellOne({required int productId}) async {
    final db = await _open();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    return db.transaction((tx) async {
      final prodRows =
      await tx.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      if (prodRows.isEmpty) {
        throw Exception('Produkti nuk ekziston.');
      }
      final p = Product.fromRow(prodRows.first);

      if (!p.active) throw Exception('Ky produkt është OFF.');
      if (p.stockQty <= 0) throw Exception('Stoku është 0. S’mund të shitet.');

      final unitPrice = p.finalPrice;
      final unitPurchase = (p.purchasePrice ?? 0);
      final profit = round2(unitPrice - unitPurchase);
      final total = round2(unitPrice);

      // update stock
      await tx.update(
        'products',
        {'stockQty': p.stockQty - 1, 'updatedAtMs': nowMs},
        where: 'id = ?',
        whereArgs: [p.id],
      );

      final invNo = 'INV-$nowMs';
      final saleId = await tx.insert('sales', {
        'invoiceNo': invNo,
        'total': total,
        'profitTotal': profit,
        'dayKey': dayKey(now),
        'monthKey': monthKey(now),
        'createdAtMs': nowMs,
      });

      await tx.insert('sale_items', {
        'saleId': saleId,
        'productId': p.id,
        'name': p.name,
        'sku': p.sku,
        'serialNumber': p.serialNumber,
        'qty': 1,
        'unitPrice': unitPrice,
        'unitPurchasePrice': unitPurchase,
        'discountPercent': p.discountPercent,
        'lineTotal': total,
        'lineProfit': profit,
      });

      return SellResult(saleId: saleId, invoiceNo: invNo, total: total, profit: profit);
    });
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
    });
  }

  Future<List<Map<String, Object?>>> getInvestments({String? monthKeyFilter}) async {
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
    final rows1 = await db.rawQuery('SELECT DISTINCT monthKey FROM sales ORDER BY monthKey DESC');
    final rows2 =
    await db.rawQuery('SELECT DISTINCT monthKey FROM investments ORDER BY monthKey DESC');
    final rows3 =
    await db.rawQuery('SELECT DISTINCT monthKey FROM expenses ORDER BY monthKey DESC');

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

    // -------- SALES (ALL) --------
    final sAll = await db.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp FROM sales');
    final countAll = (sAll.first['c'] as int?) ?? 0;
    final totalSalesAll = ((sAll.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitAll = ((sAll.first['tp'] as num?) ?? 0).toDouble();

    // -------- SALES (MONTH) --------
    final sM = await db.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp FROM sales WHERE monthKey = ?',
      [selectedMonth],
    );
    final countMonth = (sM.first['c'] as int?) ?? 0;
    final totalSalesMonth = ((sM.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitMonth = ((sM.first['tp'] as num?) ?? 0).toDouble();

    // -------- SALES (TODAY) --------
    final sT = await db.rawQuery(
      'SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp FROM sales WHERE dayKey = ?',
      [todayK],
    );
    final countToday = (sT.first['c'] as int?) ?? 0;
    final totalSalesToday = ((sT.first['ts'] as num?) ?? 0).toDouble();
    final totalProfitToday = ((sT.first['tp'] as num?) ?? 0).toDouble();

    // -------- INVEST (ALL / MONTH / TODAY) --------
    final iAll = await db.rawQuery('SELECT COALESCE(SUM(amount),0) s FROM investments');
    final totalInvestAll = ((iAll.first['s'] as num?) ?? 0).toDouble();

    final iM = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM investments WHERE monthKey = ?',
      [selectedMonth],
    );
    final totalInvestMonth = ((iM.first['s'] as num?) ?? 0).toDouble();

    final iT = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM investments WHERE dayKey = ?',
      [todayK],
    );
    final totalInvestToday = ((iT.first['s'] as num?) ?? 0).toDouble();

    // -------- EXPENSES (ALL / MONTH / TODAY) --------
    final eAll = await db.rawQuery('SELECT COALESCE(SUM(amount),0) s FROM expenses');
    final totalExpensesAll = ((eAll.first['s'] as num?) ?? 0).toDouble();

    final eM = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE monthKey = ?',
      [selectedMonth],
    );
    final totalExpensesMonth = ((eM.first['s'] as num?) ?? 0).toDouble();

    final eT = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE dayKey = ?',
      [todayK],
    );
    final totalExpensesToday = ((eT.first['s'] as num?) ?? 0).toDouble();

    // -------- STOCK totals + value final --------
    final pRows = await db.query('products',
        columns: ['stockQty', 'price', 'discountPercent', 'active']);
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
      // total
      totalSalesAll: round2(totalSalesAll),
      totalProfitAll: round2(totalProfitAll),
      countSalesAll: countAll,
      totalInvestAll: round2(totalInvestAll),
      totalExpensesAll: round2(totalExpensesAll),

      // month
      totalSalesMonth: round2(totalSalesMonth),
      totalProfitMonth: round2(totalProfitMonth),
      countSalesMonth: countMonth,
      totalInvestMonth: round2(totalInvestMonth),
      totalExpensesMonth: round2(totalExpensesMonth),

      // today
      totalSalesToday: round2(totalSalesToday),
      totalProfitToday: round2(totalProfitToday),
      countSalesToday: countToday,
      totalInvestToday: round2(totalInvestToday),
      totalExpensesToday: round2(totalExpensesToday),

      // stock
      totalStock: totalStock,
      totalStockValueFinal: round2(totalValueFinal),
    );
  }

  Future<List<ActivityItem>> getActivity({int limit = 40}) async {
    final db = await _open();

    final sales = await db.rawQuery('''
      SELECT createdAtMs, total, profitTotal, invoiceNo
      FROM sales
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''', [limit]);

    final inv = await db.rawQuery('''
      SELECT createdAtMs, amount, COALESCE(note,'') note
      FROM investments
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''', [limit]);

    final exp = await db.rawQuery('''
      SELECT createdAtMs, amount, COALESCE(note,'') note, category
      FROM expenses
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''', [limit]);

    final items = <ActivityItem>[];

    for (final r in sales) {
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final total = ((r['total'] as num?) ?? 0).toDouble();
      final profit = ((r['profitTotal'] as num?) ?? 0).toDouble();
      final invNo = (r['invoiceNo'] as String?) ?? '';
      items.add(ActivityItem(
        type: 'SALE',
        createdAtMs: ms,
        title: 'SHITJE',
        sub: 'Total: €${total.toStringAsFixed(2)} • Fitim: €${profit.toStringAsFixed(2)}${invNo.isEmpty ? '' : ' • $invNo'}',
        amount: total,
      ));
    }

    for (final r in inv) {
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final amount = ((r['amount'] as num?) ?? 0).toDouble();
      final note = (r['note'] as String?) ?? '';
      items.add(ActivityItem(
        type: 'INVEST',
        createdAtMs: ms,
        title: 'BLEJ MALL',
        sub: note.isEmpty ? '—' : note,
        amount: amount,
      ));
    }

    for (final r in exp) {
      final ms = (r['createdAtMs'] as int?) ?? 0;
      final amount = ((r['amount'] as num?) ?? 0).toDouble();
      final note = (r['note'] as String?) ?? '';
      final cat = (r['category'] as String?) ?? 'Expense';
      items.add(ActivityItem(
        type: 'EXPENSE',
        createdAtMs: ms,
        title: 'SHPENZIM',
        sub: '${cat.trim().isEmpty ? 'Tjera' : cat}${note.isEmpty ? '' : ' • $note'}',
        amount: amount,
      ));
    }

    items.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items.take(limit).toList();
  }
}
