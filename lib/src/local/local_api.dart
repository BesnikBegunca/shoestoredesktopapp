// local_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shoe_store_manager/models/app_user.dart';
import 'package:shoe_store_manager/models/business.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../printing/receipt_pdf_80mm.dart';
import '../../printing/receipt_preview.dart';
import '../db/database_manager.dart';
import '../license/license_service.dart';

/// ✅ DB VERSION
/// IMPORTANT: Kur shton tabela/kolona, rrite version-in
const int kDbVersion = 11;

/* ======================= SQL ======================= */

const String kSqlCreateUsers = '''
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL,               -- 'superadmin' | 'admin' | 'worker'
  active INTEGER NOT NULL DEFAULT 1,
  createdAtMs INTEGER NOT NULL,
  businessId INTEGER                -- nullable - NULL për superadmin, ID e biznesit për user-at e biznesit
);
''';

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
  category TEXT,
  subcategory TEXT,
  createdAtMs INTEGER,
  updatedAtMs INTEGER
);
''';

const String kSqlCreateProductVariants = '''
CREATE TABLE IF NOT EXISTS product_variants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  sku TEXT NOT NULL UNIQUE,
  size TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  barcode TEXT,
  createdAtMs INTEGER,
  updatedAtMs INTEGER,
  FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
);
''';

/// ✅ sales: userId + revertedAtMs + settledAtMs
const String kSqlCreateSales = '''
CREATE TABLE IF NOT EXISTS sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceNo TEXT NOT NULL,
  userId INTEGER,                 -- kush e ka bo shitjen
  total REAL NOT NULL,
  profitTotal REAL NOT NULL,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER,
  settledAtMs INTEGER             -- ✅ NEW: kur u barazua (mbyll dita)
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
  userId INTEGER,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER
);
''';

/// ✅ NEW: settlements table
/// UNIQUE(userId, dayKey) -> s'lejon barazim dy her ne dite per te njejtin punetor
const String kSqlCreateSettlements = '''
CREATE TABLE IF NOT EXISTS settlements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL,
  dayKey TEXT NOT NULL,
  totalSales REAL NOT NULL,
  settledAtMs INTEGER NOT NULL,
  UNIQUE(userId, dayKey)
);
''';

/// ✅ NEW: businesses table
const String kSqlCreateBusinesses = '''
CREATE TABLE IF NOT EXISTS businesses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  address TEXT,
  city TEXT,
  postalCode TEXT,
  phone TEXT,
  email TEXT,
  ownerName TEXT,
  taxId TEXT,
  registrationNumber TEXT,
  contactPerson TEXT,
  website TEXT,
  notes TEXT,
  createdByUserId INTEGER NOT NULL,
  createdAtMs INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 1
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
  final p0 = price.isFinite ? price : 0;
  final d0 = clampDouble(
    discountPercent.isFinite ? discountPercent : 0,
    0,
    100,
  );
  return round2(p0 * (1 - d0 / 100));
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

/* ======================= SKU GENERATION ======================= */

// Mapping për kategori dhe subkategori
final Map<String, String> _categoryCodes = {
  'Patika': 'PAT',
  'Rroba Stinore': 'ROB',
  'Rroba Sportive': 'ROB',
  'Rroba Gjumi': 'ROB',
  'Bebe': 'BEB',
  'Vajza': 'VAJ',
  'Djem': 'DJE',
  'Aksesorë': 'AKS',
};

final Map<String, String> _subcategoryCodes = {
  'Bebe': 'BEB',
  'Vajza': 'VAJ',
  'Djem': 'DJE',
  'Patika bebe': 'BEB',
  'Patika vajza': 'VAJ',
  'Patika djem': 'DJE',
  'Patika sportive': 'SPO',
  'Patika shkollore': 'SHK',
  'Patika verore': 'VER',
  'Patika dimërore': 'DIM',
};

/// Normalizim i tekstit për SKU: uppercase, pa hapësira, hiq karaktere speciale
String _normalizeForSku(String text) {
  return text
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .trim();
}

/// Gjeneron SKU për variant: [CAT]-[SUBCAT]-[NAME]-[SIZE]
String generateVariantSku({
  required String? category,
  required String? subcategory,
  required String productName,
  required String size,
}) {
  final catCode = category != null && _categoryCodes.containsKey(category)
      ? _categoryCodes[category]!
      : 'UNK';
  
  String subCode = 'UNK';
  if (subcategory != null) {
    // Provo fillimisht në subcategoryCodes
    if (_subcategoryCodes.containsKey(subcategory)) {
      subCode = _subcategoryCodes[subcategory]!;
    } else {
      // Nëse nuk gjet, provo në categoryCodes
      subCode = _categoryCodes[subcategory] ?? 'UNK';
    }
  } else if (category != null) {
    // Nëse nuk ka subcategory, përdor category si subcategory
    subCode = _categoryCodes[category] ?? 'UNK';
  }
  
  final nameNormalized = _normalizeForSku(productName);
  final sizeNormalized = _normalizeForSku(size);
  
  if (nameNormalized.isEmpty) {
    throw Exception('Emri i produktit nuk mund të jetë bosh për SKU');
  }
  
  return '$catCode-$subCode-$nameNormalized-$sizeNormalized';
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
  final Map<int, int> sizeStock;
  final String? category;
  final String? subcategory;
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
    this.category,
    this.subcategory,
    this.createdAtMs,
    this.updatedAtMs,
  });

  double get finalPrice =>
      calcFinalPrice(price: price, discountPercent: discountPercent);

  List<int> get sizesSorted {
    final s = sizeStock.keys.toList()..sort();
    return s;
  }

  List<int> get sizeSorted => sizesSorted;

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
      category: r['category'] as String?,
      subcategory: r['subcategory'] as String?,
      createdAtMs: r['createdAtMs'] as int?,
      updatedAtMs: r['updatedAtMs'] as int?,
    );
  }
}

class ProductVariant {
  final int id;
  final int productId;
  final String sku;
  final String size;
  final int quantity;
  final String? barcode;
  final int? createdAtMs;
  final int? updatedAtMs;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    required this.size,
    required this.quantity,
    this.barcode,
    this.createdAtMs,
    this.updatedAtMs,
  });

  static ProductVariant fromRow(Map<String, Object?> r) {
    return ProductVariant(
      id: (r['id'] as int),
      productId: (r['productId'] as int),
      sku: (r['sku'] as String?) ?? '',
      size: (r['size'] as String?) ?? '',
      quantity: (r['quantity'] as int?) ?? 0,
      barcode: r['barcode'] as String?,
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
  final int? userId;
  final String category;
  final double amount;
  final String? note;
  final String dayKey;
  final String monthKey;
  final int createdAtMs;
  final int? revertedAtMs;

  const ExpenseDoc({
    required this.id,
    required this.userId,
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
    userId: r['userId'] as int?,
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

class YearStats {
  final int year;
  final double sales;
  final double profit;
  final double investments;
  final double expenses;
  final int countSales;

  const YearStats({
    required this.year,
    required this.sales,
    required this.profit,
    required this.investments,
    required this.expenses,
    required this.countSales,
  });

  double get totalSales => sales;
  double get totalProfit => profit;
  double get totalInvest => investments;
  double get totalExpenses => expenses;
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

class CartItem {
  final Product product;
  final int size; // Për backward compatibility
  int quantity;
  
  // ✅ NEW: Variant info
  final int? variantId; // ID e variantit (SKU) në product_variants
  final String? variantSku; // SKU e variantit
  final String? variantSize; // Masa e variantit si string

  CartItem({
    required this.product,
    required this.size,
    this.quantity = 1,
    this.variantId,
    this.variantSku,
    this.variantSize,
  });

  double get unitPrice => product.finalPrice;
  double get lineTotal => unitPrice * quantity;
  double get lineProfit =>
      (unitPrice - (product.purchasePrice ?? 0)) * quantity;
  
  // ✅ Helper për të identifikuar nëse është variant
  bool get isVariant => variantId != null;
}

/// ✅ Stats per punëtor
class WorkerStats {
  final int countSales;
  final double totalSales;
  final double totalProfit;

  const WorkerStats({
    required this.countSales,
    required this.totalSales,
    required this.totalProfit,
  });
}

/* ======================= LOCAL API ======================= */

class LocalApi {
  LocalApi._();
  static final LocalApi I = LocalApi._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    DatabaseManager.ensureSqfliteInitialized();
    
    // Initialize DatabaseManager (opens admin DB)
    await DatabaseManager.getAdminDb();
    
    _ready = true;
  }

  Future<void> close() async {
    await DatabaseManager.closeAll();
  }

  // ================= USERS / AUTH =================

  Future<void> ensureDefaultAdmin() async {
    final db = await DatabaseManager.getAdminDb();
    // ✅ Kontrollo nëse ka superadmin me username 'superadmin'
    final superadminRows = await db.rawQuery(
      "SELECT id FROM users WHERE username='superadmin' AND role='superadmin' LIMIT 1",
    );
    if (superadminRows.isNotEmpty) {
      // ✅ Sigurohu që password është '123123'
      await db.update(
        'users',
        {'password': '123123'},
        where: 'username = ? AND role = ?',
        whereArgs: ['superadmin', 'superadmin'],
      );
      return;
    }

    // ✅ Kontrollo nëse ka admin ekzistues me username 'admin' (për migrim)
    final adminRows = await db.rawQuery(
      "SELECT id FROM users WHERE username='admin' LIMIT 1",
    );
    
    if (adminRows.isNotEmpty) {
      // ✅ Konverto admin ekzistues në superadmin
      final adminId = adminRows.first['id'] as int;
      await db.update(
        'users',
        {
          'username': 'superadmin',
          'password': '123123',
          'role': 'superadmin',
        },
        where: 'id = ?',
        whereArgs: [adminId],
      );
      return;
    }

    // ✅ Krijo superadmin i ri
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await db.insert('users', {
        'username': 'superadmin',
        'password': '123123',
        'role': 'superadmin',
        'active': 1,
        'createdAtMs': now,
      });
    } catch (e) {
      // Nëse username 'superadmin' ekziston tashmë, përditëso atë
      if (e.toString().contains('UNIQUE constraint')) {
        await db.update(
          'users',
          {
            'password': '123123',
            'role': 'superadmin',
            'active': 1,
          },
          where: 'username = ?',
          whereArgs: ['superadmin'],
        );
      } else {
        rethrow;
      }
    }
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p0 = password;
    if (u.isEmpty) throw Exception('Shkruaj username ose email.');
    if (p0.isEmpty) throw Exception('Shkruaj password.');

    // ✅ Provo fillimisht në admin DB (për superadmin)
    final adminDb = await DatabaseManager.getAdminDb();
    var rows = await adminDb.query(
      'users',
      where: 'username = ? AND password = ? AND active = 1',
      whereArgs: [u, p0],
      limit: 1,
    );

    // Nëse gjet superadmin, ktheje
    if (rows.isNotEmpty) {
      return AppUser.fromRow(rows.first);
    }

    // ✅ Nëse nuk gjet, provo me email/password nga businesses
    final businessRows = await adminDb.query(
      'businesses',
      where: '(email = ? OR name = ?) AND password = ? AND active = 1',
      whereArgs: [u, u, p0],
      limit: 1,
    );
    
    if (businessRows.isNotEmpty) {
      final businessId = businessRows.first['id'] as int;
      
      // ✅ Hap databazën e biznesit dhe gjej admin user
      final businessDb = await DatabaseManager.getBusinessDb(businessId);
      rows = await businessDb.query(
        'users',
        where: 'businessId = ? AND role = ? AND active = 1',
        whereArgs: [businessId, 'admin'],
        limit: 1,
      );
      
      if (rows.isNotEmpty) {
        return AppUser.fromRow(rows.first);
      }
    }

    throw Exception('User nuk ekziston ose password gabim.');
  }

  Future<List<AppUser>> getUsers({bool onlyActive = true, int? businessId}) async {
    // Nëse businessId është specifikuar, merri nga business DB
    // Përndryshe, merri nga admin DB (superadmin users)
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();
        
    final rows = await db.query(
      'users',
      where: onlyActive ? 'active = 1' : null,
      orderBy: 'createdAtMs DESC',
    );
    return rows.map(AppUser.fromRow).toList();
  }

  Future<List<AppUser>> getAllUsers() async {
    // Merr të gjithë users nga admin DB + të gjitha business DBs
    final adminDb = await DatabaseManager.getAdminDb();
    final adminUsers = await adminDb.query('users', orderBy: 'createdAtMs DESC');
    
    final allUsers = <AppUser>[];
    allUsers.addAll(adminUsers.map(AppUser.fromRow));
    
    return allUsers;
  }

  Future<int> createUser({
    required String username,
    required String password,
    required String role,
    int? businessId,
  }) async {
    final u = username.trim();
    if (u.isEmpty) throw Exception('Username i zbrazët.');
    if (password.isEmpty) throw Exception('Password i zbrazët.');
    if (role != 'worker' && role != 'admin' && role != 'superadmin') {
      throw Exception('Role invalid.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Përcakto cilin DB të përdorësh
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();

    try {
      return await db.insert('users', {
        'username': u,
        'password': password,
        'role': role,
        'active': 1,
        'createdAtMs': now,
        'businessId': businessId,
      });
    } catch (_) {
      throw Exception('Username ekziston already.');
    }
  }

  Future<void> updateUser({
    required int userId,
    required String username,
    String? password,
    required String role,
    int? businessId,
  }) async {
    final u = username.trim();
    final r = role.trim();
    if (u.isEmpty) throw Exception('Username i zbrazët.');
    if (r != 'worker' && r != 'admin' && r != 'superadmin') {
      throw Exception('Role invalid.');
    }

    final data = <String, Object?>{'username': u, 'role': r};
    final p0 = password?.trim();
    if (p0 != null && p0.isNotEmpty) data['password'] = p0;
    if (businessId != null) data['businessId'] = businessId;

    // Përdor businessId për të përcaktuar DB
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();

    try {
      await db.update('users', data, where: 'id = ?', whereArgs: [userId]);
    } catch (_) {
      throw Exception('Username ekziston already.');
    }
  }

  Future<void> setUserActive(int userId, bool active, {int? businessId}) async {
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();
        
    await db.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUser(int userId, {int? businessId}) async {
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();
        
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<AppUser?> getUserById(int userId, {int? businessId}) async {
    final db = businessId != null 
        ? await DatabaseManager.getBusinessDb(businessId)
        : await DatabaseManager.getAdminDb();
        
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromRow(rows.first);
  }

  // ================= BUSINESSES =================

  Future<int> createBusiness({
    required String name,
    required String password,
    String? address,
    String? city,
    String? postalCode,
    String? phone,
    String? email,
    String? ownerName,
    String? taxId,
    String? registrationNumber,
    String? contactPerson,
    String? website,
    String? notes,
    required int createdByUserId,
    int validDays = 365, // Default 365 ditë
  }) async {
    final adminDb = await DatabaseManager.getAdminDb();
    final n = name.trim();
    if (n.isEmpty) throw Exception('Emri i biznesit i zbrazët.');
    if (password.isEmpty) throw Exception('Password i zbrazët.');

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Krijo biznesin në admin DB
      final businessId = await adminDb.insert('businesses', {
        'name': n,
        'password': password,
        'address': address?.trim(),
        'city': city?.trim(),
        'postalCode': postalCode?.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'ownerName': ownerName?.trim(),
        'taxId': taxId?.trim(),
        'registrationNumber': registrationNumber?.trim(),
        'contactPerson': contactPerson?.trim(),
        'website': website?.trim(),
        'notes': notes?.trim(),
        'createdByUserId': createdByUserId,
        'createdAtMs': now,
        'active': 1,
      });

      // 2. ✅ Krijo databazën e biznesit
      await DatabaseManager.createBusinessDatabase(businessId);
      final businessDb = await DatabaseManager.getBusinessDb(businessId);

      // 3. ✅ Krijo admin user në business DB
      final usernameForUser = email?.trim().isNotEmpty == true ? email!.trim() : n;
      await businessDb.insert('users', {
        'username': usernameForUser,
        'password': password,
        'role': 'admin',
        'active': 1,
        'createdAtMs': now,
        'businessId': businessId,
      });

      // 4. ✅ AUTO-KRIJO LICENSËN (365 ditë by default)
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
        'notes': 'Auto-krijuar gjatë regjistrimit të biznesit',
      });

      return businessId;
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint')) {
        throw Exception('Emri i biznesit ekziston already.');
      }
      rethrow;
    }
  }

  Future<List<Business>> getBusinesses({int? createdByUserId}) async {
    final adminDb = await DatabaseManager.getAdminDb();
    final rows = createdByUserId != null
        ? await adminDb.query(
            'businesses',
            where: 'createdByUserId = ?',
            whereArgs: [createdByUserId],
            orderBy: 'createdAtMs DESC',
          )
        : await adminDb.query(
            'businesses',
            orderBy: 'createdAtMs DESC',
          );
    return rows.map(Business.fromRow).toList();
  }

  Future<Business?> getBusinessById(int businessId) async {
    final adminDb = await DatabaseManager.getAdminDb();
    final rows = await adminDb.query(
      'businesses',
      where: 'id = ?',
      whereArgs: [businessId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Business.fromRow(rows.first);
  }

  Future<void> updateBusiness({
    required int businessId,
    required String name,
    String? password,
    String? address,
    String? city,
    String? postalCode,
    String? phone,
    String? email,
    String? ownerName,
    String? taxId,
    String? registrationNumber,
    String? contactPerson,
    String? website,
    String? notes,
  }) async {
    final adminDb = await DatabaseManager.getAdminDb();
    final n = name.trim();
    if (n.isEmpty) throw Exception('Emri i biznesit i zbrazët.');

    final data = <String, Object?>{'name': n};
    if (password != null && password.isNotEmpty) {
      data['password'] = password;
    }
    if (address != null) data['address'] = address.trim().isEmpty ? null : address.trim();
    if (city != null) data['city'] = city.trim().isEmpty ? null : city.trim();
    if (postalCode != null) data['postalCode'] = postalCode.trim().isEmpty ? null : postalCode.trim();
    if (phone != null) data['phone'] = phone.trim().isEmpty ? null : phone.trim();
    if (email != null) data['email'] = email.trim().isEmpty ? null : email.trim();
    if (ownerName != null) data['ownerName'] = ownerName.trim().isEmpty ? null : ownerName.trim();
    if (taxId != null) data['taxId'] = taxId.trim().isEmpty ? null : taxId.trim();
    if (registrationNumber != null) data['registrationNumber'] = registrationNumber.trim().isEmpty ? null : registrationNumber.trim();
    if (contactPerson != null) data['contactPerson'] = contactPerson.trim().isEmpty ? null : contactPerson.trim();
    if (website != null) data['website'] = website.trim().isEmpty ? null : website.trim();
    if (notes != null) data['notes'] = notes.trim().isEmpty ? null : notes.trim();

    try {
      await adminDb.update('businesses', data, where: 'id = ?', whereArgs: [businessId]);

      // ✅ Nëse password u ndryshua, përditëso edhe user-in e biznesit
      if (password != null && password.isNotEmpty) {
        final businessDb = await DatabaseManager.getBusinessDb(businessId);
        await businessDb.update(
          'users',
          {'password': password},
          where: 'businessId = ? AND role = ?',
          whereArgs: [businessId, 'admin'],
        );
      }
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint')) {
        throw Exception('Emri i biznesit ekziston already.');
      }
      rethrow;
    }
  }

  Future<void> deleteBusiness(int businessId) async {
    final adminDb = await DatabaseManager.getAdminDb();
    
    // ✅ Fshi licensat
    await adminDb.delete('business_licenses', where: 'businessId = ?', whereArgs: [businessId]);
    
    // ✅ Fshi biznesin nga admin DB
    await adminDb.delete('businesses', where: 'id = ?', whereArgs: [businessId]);
    
    // ✅ Fshi databazën e biznesit
    await DatabaseManager.deleteBusinessDatabase(businessId);
  }

  Future<void> setBusinessActive(int businessId, bool active) async {
    final adminDb = await DatabaseManager.getAdminDb();
    await adminDb.update(
      'businesses',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [businessId],
    );
    
    // ✅ Deaktivizo edhe user-at e biznesit në business DB
    final businessDb = await DatabaseManager.getBusinessDb(businessId);
    await businessDb.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'businessId = ?',
      whereArgs: [businessId],
    );
  }

  // ================= BUSINESS LICENSES =================

  /// Shto një licensë të re për një biznes
  Future<int> addBusinessLicense({
    required int businessId,
    required String licenseKey,
    required int validDays,
    String? notes,
  }) async {
    final adminDb = await DatabaseManager.getAdminDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = now + (validDays * 24 * 60 * 60 * 1000);

    return await adminDb.insert('business_licenses', {
      'businessId': businessId,
      'licenseKey': licenseKey,
      'validDays': validDays,
      'issuedAtMs': now,
      'expiresAtMs': expiresAtMs,
      'activatedAtMs': now,
      'lastCheckedMs': now,
      'active': 1,
      'notes': notes,
    });
  }

  /// Merr të gjitha licensat e një biznesi
  Future<List<Map<String, Object?>>> getBusinessLicenses(int businessId) async {
    final adminDb = await DatabaseManager.getAdminDb();
    return await adminDb.query(
      'business_licenses',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'issuedAtMs DESC',
    );
  }

  /// Deaktivizo një licensë
  Future<void> deactivateLicense(int licenseId) async {
    final adminDb = await DatabaseManager.getAdminDb();
    await adminDb.update(
      'business_licenses',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [licenseId],
    );
  }

  // ================= PRODUCTS =================

  Future<List<Product>> getProducts({
    String orderBy = 'createdAtMs DESC',
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final rows = await db.query('products', orderBy: orderBy);
    return rows.map(Product.fromRow).toList();
  }

  /// Kontrollon nëse SKU ekziston tashmë
  Future<bool> skuExists(String sku) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final rows = await db.query(
      'product_variants',
      where: 'sku = ?',
      whereArgs: [sku.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Merr variantet e një produkti
  Future<List<ProductVariant>> getProductVariants(int productId) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final rows = await db.query(
      'product_variants',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'size ASC',
    );
    return rows.map(ProductVariant.fromRow).toList();
  }

  /// Merr variantet që kanë një barcode të caktuar
  Future<List<ProductVariant>> getVariantsByBarcode(String barcode) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final b = barcode.trim();
    if (b.isEmpty) return [];
    
    final rows = await db.query(
      'product_variants',
      where: 'barcode = ?',
      whereArgs: [b],
      orderBy: 'size ASC',
    );
    return rows.map(ProductVariant.fromRow).toList();
  }

  /// Merr një variant specifik me ID
  Future<ProductVariant?> getVariantById(int variantId) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final rows = await db.query(
      'product_variants',
      where: 'id = ?',
      whereArgs: [variantId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProductVariant.fromRow(rows.first);
  }

  /// Merr produktin për një variant
  Future<Product?> getProductByVariantId(int variantId) async {
    final variant = await getVariantById(variantId);
    if (variant == null) return null;
    
    final products = await getProducts();
    return products.firstWhere(
      (p) => p.id == variant.productId,
      orElse: () => throw Exception('Produkti nuk u gjet për variant ID: $variantId'),
    );
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
    String? category,
    String? subcategory,
    bool autoGenerateVariants = true,
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = _totalStock(sizeStock);

    return db.transaction((tx) async {
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
        'category': category?.trim().isEmpty == true ? null : category?.trim(),
        'subcategory': subcategory?.trim().isEmpty == true ? null : subcategory?.trim(),
        'createdAtMs': now,
        'updatedAtMs': now,
      };

      final productId = await tx.insert('products', map);

      // Krijo variantet automatikisht nëse autoGenerateVariants = true
      if (autoGenerateVariants && (category != null || subcategory != null)) {
        for (final entry in sizeStock.entries) {
          final size = entry.key;
          final qty = entry.value;
          if (qty > 0) {
            final variantSku = generateVariantSku(
              category: category,
              subcategory: subcategory,
              productName: name,
              size: size.toString(),
            );

            // Kontrollo uniqueness
            final existing = await tx.query(
              'product_variants',
              where: 'sku = ?',
              whereArgs: [variantSku],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              throw Exception('SKU ekziston tashmë: $variantSku');
            }

            await tx.insert('product_variants', {
              'productId': productId,
              'sku': variantSku,
              'size': size.toString(),
              'quantity': qty,
              'barcode': serialNumber,
              'createdAtMs': now,
              'updatedAtMs': now,
            });
          }
        }
      }

      return productId;
    });
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
    String? category,
    String? subcategory,
    bool autoGenerateVariants = true,
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = _totalStock(sizeStock);

    await db.transaction((tx) async {
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
        'category': category?.trim().isEmpty == true ? null : category?.trim(),
        'subcategory': subcategory?.trim().isEmpty == true ? null : subcategory?.trim(),
        'updatedAtMs': now,
      };

      await tx.update('products', map, where: 'id = ?', whereArgs: [id]);

      // Fshi variantet e vjetra dhe krijo të rejat
      if (autoGenerateVariants && (category != null || subcategory != null)) {
        await tx.delete('product_variants', where: 'productId = ?', whereArgs: [id]);

        for (final entry in sizeStock.entries) {
          final size = entry.key;
          final qty = entry.value;
          if (qty > 0) {
            final variantSku = generateVariantSku(
              category: category,
              subcategory: subcategory,
              productName: name,
              size: size.toString(),
            );

            // Kontrollo uniqueness (përveç variantet e këtij produkti që po fshihen)
            final existing = await tx.query(
              'product_variants',
              where: 'sku = ? AND productId != ?',
              whereArgs: [variantSku, id],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              throw Exception('SKU ekziston tashmë: $variantSku');
            }

            await tx.insert('product_variants', {
              'productId': id,
              'sku': variantSku,
              'size': size.toString(),
              'quantity': qty,
              'barcode': serialNumber,
              'createdAtMs': now,
              'updatedAtMs': now,
            });
          }
        }
      }
    });
  }

  Future<void> deleteProduct(int id) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    await db.transaction((tx) async {
      // Fshi variantet (CASCADE do ta bëjë automatikisht, por e bëjmë eksplicit)
      await tx.delete('product_variants', where: 'productId = ?', whereArgs: [id]);
      await tx.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> toggleActive(int id, bool active) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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

  // ================= SELL (one item) =================

  Future<SellResult> sellOne({
    required int productId,
    required int size,
    required int userId,
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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
        'userId': userId,
        'total': total,
        'profitTotal': profit,
        'dayKey': dayKey(now),
        'monthKey': monthKey(now),
        'createdAtMs': nowMs,
        'revertedAtMs': null,
        'settledAtMs': null, // ✅ NEW
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

  // ================= SELL (multiple) =================

  Future<SellResult> sellMany({
    required List<CartItem> cartItems,
    required int userId,
  }) async {
    if (cartItems.isEmpty) throw Exception('Cart is empty.');

    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    return db.transaction((tx) async {
      double total = 0;
      double totalProfit = 0;

      // Validate stock + totals
      for (final item in cartItems) {
        final prodRows = await tx.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.product.id],
          limit: 1,
        );
        if (prodRows.isEmpty) {
          throw Exception('Produkti nuk ekziston: ${item.product.name}');
        }

        final p0 = Product.fromRow(prodRows.first);
        if (!p0.active)
          throw Exception('Ky produkt është OFF: ${item.product.name}');

        final map = Map<int, int>.from(p0.sizeStock);
        final q = map[item.size] ?? 0;
        if (q < item.quantity) {
          throw Exception(
            'S’ka stok për numrin ${item.size} (${item.product.name}).',
          );
        }

        total += item.lineTotal;
        totalProfit += item.lineProfit;
      }

      // Update stock
      for (final item in cartItems) {
        // ✅ NEW: Nëse është variant, zbrit stokun te variant
        if (item.isVariant && item.variantId != null) {
          final variantRows = await tx.query(
            'product_variants',
            where: 'id = ?',
            whereArgs: [item.variantId],
            limit: 1,
          );
          if (variantRows.isNotEmpty) {
            final variant = ProductVariant.fromRow(variantRows.first);
            final newQty = variant.quantity - item.quantity;
            
            await tx.update(
              'product_variants',
              {
                'quantity': newQty,
                'updatedAtMs': nowMs,
              },
              where: 'id = ?',
              whereArgs: [item.variantId],
            );
            
            // ✅ Përditëso edhe produktin bazë (sizeStockJson) për backward compatibility
            final prodRows = await tx.query(
              'products',
              where: 'id = ?',
              whereArgs: [item.product.id],
              limit: 1,
            );
            if (prodRows.isNotEmpty) {
              final p0 = Product.fromRow(prodRows.first);
              final map = Map<int, int>.from(p0.sizeStock);
              final sizeInt = int.tryParse(variant.size) ?? item.size;
              map[sizeInt] = (map[sizeInt] ?? 0) - item.quantity;
              final newTotal = _totalStock(map);
              
              await tx.update(
                'products',
                {
                  'sizeStockJson': _encodeSizeStock(map),
                  'stockQty': newTotal,
                  'updatedAtMs': nowMs,
                },
                where: 'id = ?',
                whereArgs: [item.product.id],
              );
            }
          }
        } else {
          // Legacy: zbrit nga sizeStock
          final prodRows = await tx.query(
            'products',
            where: 'id = ?',
            whereArgs: [item.product.id],
            limit: 1,
          );
          final p0 = Product.fromRow(prodRows.first);
          final map = Map<int, int>.from(p0.sizeStock);
          map[item.size] = (map[item.size] ?? 0) - item.quantity;
          final newTotal = _totalStock(map);

          await tx.update(
            'products',
            {
              'sizeStockJson': _encodeSizeStock(map),
              'stockQty': newTotal,
              'updatedAtMs': nowMs,
            },
            where: 'id = ?',
            whereArgs: [item.product.id],
          );
        }
      }

      total = round2(total);
      totalProfit = round2(totalProfit);

      final invNo = 'INV-$nowMs';
      final saleId = await tx.insert('sales', {
        'invoiceNo': invNo,
        'userId': userId,
        'total': total,
        'profitTotal': totalProfit,
        'dayKey': dayKey(now),
        'monthKey': monthKey(now),
        'createdAtMs': nowMs,
        'revertedAtMs': null,
        'settledAtMs': null, // ✅ NEW
      });

      // Insert sale items
      for (final item in cartItems) {
        await tx.insert('sale_items', {
          'saleId': saleId,
          'productId': item.product.id,
          'name': item.product.name,
          'sku': item.product.sku,
          'serialNumber': item.product.serialNumber,
          'qty': item.quantity,
          'unitPrice': item.unitPrice,
          'unitPurchasePrice': item.product.purchasePrice ?? 0,
          'discountPercent': item.product.discountPercent,
          'lineTotal': item.lineTotal,
          'lineProfit': item.lineProfit,
          'shoeSize': item.size,
        });
      }

      return SellResult(
        saleId: saleId,
        invoiceNo: invNo,
        total: total,
        profit: totalProfit,
      );
    });
  }

  // ================= REVERT =================

  Future<void> revertSale({required int saleId}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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
        if (prodRows.isEmpty) continue;

        final p0 = Product.fromRow(prodRows.first);

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
          await tx.update(
            'products',
            {'stockQty': p0.stockQty + qty, 'updatedAtMs': nowMs},
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
      }

      await tx.update(
        'sales',
        {'revertedAtMs': nowMs},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<void> revertInvestment({required int investId}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'investments',
      where: 'id = ?',
      whereArgs: [investId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Investimi nuk ekziston.');
    if (rows.first['revertedAtMs'] != null) {
      throw Exception('Ky investim veç është revert-uar.');
    }

    await db.update(
      'investments',
      {'revertedAtMs': nowMs},
      where: 'id = ?',
      whereArgs: [investId],
    );
  }

  Future<void> revertExpense({required int expenseId}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Shpenzimi nuk ekziston.');
    if (rows.first['revertedAtMs'] != null) {
      throw Exception('Ky shpenzim veç është revert-uar.');
    }

    await db.update(
      'expenses',
      {'revertedAtMs': nowMs},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  // ================= INVESTMENTS =================

  Future<void> addInvestment({required double amount, String? note}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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

  // ================= EXPENSES =================

  Future<void> addExpense({
    int? userId,
    required String category,
    required double amount,
    String? note,
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final cat = category.trim();
    if (cat.isEmpty) throw Exception('Kategoria është e zbrazët.');
    if (!amount.isFinite || amount <= 0) throw Exception('Amount invalid.');

    await db.insert('expenses', {
      'userId': userId,
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
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
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

  // ================= ADMIN / STATS =================

  Future<List<String>> getMonthOptions() async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');

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
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final todayK = dayKey(DateTime.now());

    // SALES (no reverted)
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

    // INVEST (no reverted)
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

    // EXPENSE (no reverted)
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

  Future<List<ActivityItem>> getActivity({int limit = 60}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');

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

  Future<YearStats> getYearStats(int year) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final yPrefix = '$year-';

    final s = await db.rawQuery(
      '''
      SELECT COUNT(*) c, COALESCE(SUM(total),0) ts, COALESCE(SUM(profitTotal),0) tp
      FROM sales
      WHERE dayKey LIKE ? AND revertedAtMs IS NULL
      ''',
      ['$yPrefix%'],
    );

    final inv = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount),0) s
      FROM investments
      WHERE dayKey LIKE ? AND revertedAtMs IS NULL
      ''',
      ['$yPrefix%'],
    );

    final exp = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount),0) s
      FROM expenses
      WHERE dayKey LIKE ? AND revertedAtMs IS NULL
      ''',
      ['$yPrefix%'],
    );

    return YearStats(
      year: year,
      sales: round2(((s.first['ts'] as num?) ?? 0).toDouble()),
      profit: round2(((s.first['tp'] as num?) ?? 0).toDouble()),
      investments: round2(((inv.first['s'] as num?) ?? 0).toDouble()),
      expenses: round2(((exp.first['s'] as num?) ?? 0).toDouble()),
      countSales: (s.first['c'] as int?) ?? 0,
    );
  }

  // ================= WORKER STATS =================

  /// ✅ scope:
  /// - 'day'  -> vetem sot, dhe VETEM ato qe s'jane settled (pra dita "bohet 0" pas barazimit)
  /// - 'month'/'total' -> i merr krejt (edhe settled), se për raport mujor/total e don historinë
  Future<WorkerStats> getWorkerStats({
    required int userId,
    required String scope, // 'day' | 'month' | 'total'
    String? monthKeyFilter,
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');

    final where = <String>['revertedAtMs IS NULL', 'userId = ?'];
    final args = <Object?>[userId];

    if (scope == 'day') {
      where.add('dayKey = ?');
      args.add(dayKey(DateTime.now()));

      // ✅ kjo e bon "dita = 0" pas settlement
      where.add('settledAtMs IS NULL');
    } else if (scope == 'month') {
      where.add('monthKey = ?');
      args.add(monthKeyFilter ?? monthKey(DateTime.now()));
    } else {
      // total -> pa filter date
    }

    final rows = await db.rawQuery('''
SELECT
  COUNT(*) as c,
  COALESCE(SUM(total),0) as ts,
  COALESCE(SUM(profitTotal),0) as tp
FROM sales
WHERE ${where.join(' AND ')}
''', args);

    final r = rows.first;
    return WorkerStats(
      countSales: (r['c'] as int?) ?? 0,
      totalSales: ((r['ts'] as num?) ?? 0).toDouble(),
      totalProfit: ((r['tp'] as num?) ?? 0).toDouble(),
    );
  }

  // ================= SETTLEMENTS =================

  /// ✅ A eshte barazu sot?
  Future<bool> isWorkerSettledToday(int userId) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final today = dayKey(DateTime.now());

    // Prefer: settlements table
    final rows = await db.query(
      'settlements',
      where: 'userId = ? AND dayKey = ?',
      whereArgs: [userId, today],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// ✅ Barazo punëtorin sot:
  /// - merr totalin e sotëm (unsettled)
  /// - printon POS80
  /// - pastaj shënon sales si settled + inserton settlement record
  Future<void> settleWorkerToday(int userId, String workerName) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final today = dayKey(DateTime.now());
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // 1) check already settled
    if (await isWorkerSettledToday(userId)) {
      throw Exception('Punëtori është tashmë i barazuar për sot.');
    }

    // 2) get today's UNSETTLED sales
    final stats = await getWorkerStats(userId: userId, scope: 'day');
    if (stats.totalSales <= 0) {
      throw Exception('S’ka shitje për sot (ose veç është barazu).');
    }

    // 3) PRINT first (nese print fails -> mos e sheno settled)
    String money(double v) => '€${v.toStringAsFixed(2)}';
    String dtStr() {
      String pad2(int n) => n.toString().padLeft(2, '0');
      return '${pad2(now.day)}.${pad2(now.month)}.${now.year} ${pad2(now.hour)}:${pad2(now.minute)}';
    }

    final lines = <ReceiptLine>[
      ReceiptLine('BARAZIM PUNETORI', '', bold: true),
      ReceiptLine('Punetori', workerName, bold: true),
      ReceiptLine('Data', today),
      ReceiptLine('Ora', dtStr()),
      const ReceiptLine('----------------', ''),
      ReceiptLine('Total Shitje (Sot)', money(stats.totalSales), bold: true),
      const ReceiptLine('----------------', ''),
      ReceiptLine('ME I DOREZU PRONARIT', money(stats.totalSales), bold: true),
      const ReceiptLine('----------------', ''),
      const ReceiptLine('Faleminderit', ''),
    ];

    await ReceiptPdf80mm.printOrSave(
      title: 'SETTLEMENT',
      lines: lines,
      jobName: 'settlement-$workerName-$today',
    );

    // 4) After successful print -> mark settled + insert settlements record
    await db.transaction((tx) async {
      // re-check inside transaction for safety
      final already = await tx.query(
        'settlements',
        where: 'userId = ? AND dayKey = ?',
        whereArgs: [userId, today],
        limit: 1,
      );
      if (already.isNotEmpty) {
        // someone settled in parallel
        return;
      }

      // mark today's sales as settled
      await tx.update(
        'sales',
        {'settledAtMs': nowMs},
        where:
            'userId = ? AND dayKey = ? AND revertedAtMs IS NULL AND settledAtMs IS NULL',
        whereArgs: [userId, today],
      );

      // insert settlement record
      await tx.insert('settlements', {
        'userId': userId,
        'dayKey': today,
        'totalSales': round2(stats.totalSales),
        'settledAtMs': nowMs,
      });
    });
  }

  // ================= DASHBOARD HELPERS =================

  /// Get daily sales data for the last N days
  Future<List<Map<String, dynamic>>> getDailySalesData({int days = 7}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    final data = <Map<String, dynamic>>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayK = dayKey(date);
      
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) as total, COUNT(*) as count '
        'FROM sales WHERE dayKey = ? AND revertedAtMs IS NULL',
        [dayK],
      );
      
      final total = ((rows.first['total'] as num?) ?? 0).toDouble();
      final count = (rows.first['count'] as int?) ?? 0;
      
      data.add({
        'date': date,
        'dayKey': dayK,
        'total': total,
        'count': count,
      });
    }

    return data;
  }

  /// Get best selling products
  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 10}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    
    final rows = await db.rawQuery('''
      SELECT 
        si.productId,
        p.name,
        p.imagePath,
        p.price,
        p.discountPercent,
        p.stockQty,
        SUM(si.qty) as totalSold
      FROM sale_items si
      INNER JOIN products p ON si.productId = p.id
      INNER JOIN sales s ON si.saleId = s.id
      WHERE s.revertedAtMs IS NULL
      GROUP BY si.productId
      ORDER BY totalSold DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) => {
      'productId': r['productId'] as int,
      'name': r['name'] as String? ?? '',
      'imagePath': r['imagePath'] as String?,
      'price': ((r['price'] as num?) ?? 0).toDouble(),
      'discountPercent': ((r['discountPercent'] as num?) ?? 0).toDouble(),
      'stockQty': (r['stockQty'] as int?) ?? 0,
      'totalSold': (r['totalSold'] as int?) ?? 0,
    }).toList();
  }

  /// Get recent sales for payments list
  Future<List<Map<String, dynamic>>> getRecentSales({int limit = 5}) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    
    final rows = await db.rawQuery('''
      SELECT 
        id,
        invoiceNo,
        total,
        createdAtMs,
        userId
      FROM sales
      WHERE revertedAtMs IS NULL
      ORDER BY createdAtMs DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) => {
      'id': r['id'] as int,
      'invoiceNo': r['invoiceNo'] as String? ?? '',
      'total': ((r['total'] as num?) ?? 0).toDouble(),
      'createdAtMs': (r['createdAtMs'] as int?) ?? 0,
      'userId': r['userId'] as int?,
    }).toList();
  }

  // ================= FITIMET / SALES LIST =================
  
  Future<List<Map<String, dynamic>>> getSalesForPeriod({
    required String period, // 'today', 'week', 'month'
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    
    String whereClause = 'revertedAtMs IS NULL';
    List<dynamic> args = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      whereClause += ' AND dayKey = ?';
      args.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      whereClause += ' AND createdAtMs >= ?';
      args.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      whereClause += ' AND monthKey = ?';
      args.add(monthK);
    }
    
    final rows = await db.rawQuery('''
      SELECT 
        id,
        invoiceNo,
        total,
        profitTotal,
        createdAtMs,
        userId
      FROM sales
      WHERE $whereClause
      ORDER BY createdAtMs DESC
    ''', args);

    return rows.map((r) => {
      'id': r['id'] as int,
      'invoiceNo': r['invoiceNo'] as String? ?? '',
      'total': ((r['total'] as num?) ?? 0).toDouble(),
      'profitTotal': ((r['profitTotal'] as num?) ?? 0).toDouble(),
      'createdAtMs': (r['createdAtMs'] as int?) ?? 0,
      'userId': r['userId'] as int?,
    }).toList();
  }

  Future<Map<String, double>> getProfitSummary({
    required String period, // 'today', 'week', 'month'
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    
    String whereClause = 'revertedAtMs IS NULL';
    List<dynamic> args = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      whereClause += ' AND dayKey = ?';
      args.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      whereClause += ' AND createdAtMs >= ?';
      args.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      whereClause += ' AND monthKey = ?';
      args.add(monthK);
    }
    
    // Get sales totals
    final salesRows = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total),0) as totalSales,
        COALESCE(SUM(profitTotal),0) as totalProfit,
        COUNT(*) as count
      FROM sales
      WHERE $whereClause
    ''', args);
    
    final totalSales = ((salesRows.first['totalSales'] as num?) ?? 0).toDouble();
    final totalProfit = ((salesRows.first['totalProfit'] as num?) ?? 0).toDouble();
    final count = (salesRows.first['count'] as int?) ?? 0;
    
    // Get expenses for period
    String expenseWhere = '1=1';
    List<dynamic> expenseArgs = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      expenseWhere += ' AND dayKey = ?';
      expenseArgs.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      expenseWhere += ' AND createdAtMs >= ?';
      expenseArgs.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      expenseWhere += ' AND monthKey = ?';
      expenseArgs.add(monthK);
    }
    
    final expenseRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount),0) as totalExpenses
      FROM expenses
      WHERE $expenseWhere
    ''', expenseArgs);
    
    final totalExpenses = ((expenseRows.first['totalExpenses'] as num?) ?? 0).toDouble();
    final netProfit = totalProfit - totalExpenses;
    
    return {
      'totalSales': totalSales,
      'totalProfit': totalProfit,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'count': count.toDouble(),
    };
  }

  // ================= SHPENZIMET =================
  
  Future<List<Map<String, dynamic>>> getExpensesForPeriod({
    required String period, // 'today', 'week', 'month'
    String? categoryFilter, // null = all, or specific category
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    
    String whereClause = 'revertedAtMs IS NULL';
    List<dynamic> args = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      whereClause += ' AND dayKey = ?';
      args.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      whereClause += ' AND createdAtMs >= ?';
      args.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      whereClause += ' AND monthKey = ?';
      args.add(monthK);
    }
    
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      whereClause += ' AND category = ?';
      args.add(categoryFilter);
    }
    
    final expenseRows = await db.rawQuery('''
      SELECT 
        id,
        category,
        amount,
        note,
        createdAtMs,
        'expense' as type
      FROM expenses
      WHERE $whereClause
      ORDER BY createdAtMs DESC
    ''', args);
    
    // Get investments (blerje malli)
    String invWhere = 'revertedAtMs IS NULL';
    List<dynamic> invArgs = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      invWhere += ' AND dayKey = ?';
      invArgs.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      invWhere += ' AND createdAtMs >= ?';
      invArgs.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      invWhere += ' AND monthKey = ?';
      invArgs.add(monthK);
    }
    
    final investRows = await db.rawQuery('''
      SELECT 
        id,
        amount,
        note,
        createdAtMs,
        'investment' as type
      FROM investments
      WHERE $invWhere
      ORDER BY createdAtMs DESC
    ''', invArgs);

    // Combine both lists
    final allExpenses = <Map<String, dynamic>>[];
    
    // Add expenses
    for (final row in expenseRows) {
      if (categoryFilter == null || categoryFilter == 'all' || categoryFilter.isEmpty) {
        allExpenses.add({
          'id': row['id'] as int,
          'category': row['category'] as String,
          'amount': ((row['amount'] as num?) ?? 0).toDouble(),
          'note': row['note'] as String?,
          'createdAtMs': (row['createdAtMs'] as int?) ?? 0,
          'type': 'expense',
        });
      } else if (row['category'] == categoryFilter) {
        allExpenses.add({
          'id': row['id'] as int,
          'category': row['category'] as String,
          'amount': ((row['amount'] as num?) ?? 0).toDouble(),
          'note': row['note'] as String?,
          'createdAtMs': (row['createdAtMs'] as int?) ?? 0,
          'type': 'expense',
        });
      }
    }
    
    // Add investments if no category filter or if filter is 'Blerje Malli'
    if (categoryFilter == null || categoryFilter == 'all' || categoryFilter.isEmpty || categoryFilter == 'Blerje Malli') {
      for (final row in investRows) {
        allExpenses.add({
          'id': row['id'] as int,
          'category': 'Blerje Malli',
          'amount': ((row['amount'] as num?) ?? 0).toDouble(),
          'note': row['note'] as String?,
          'createdAtMs': (row['createdAtMs'] as int?) ?? 0,
          'type': 'investment',
        });
      }
    }
    
    // Sort by date descending
    allExpenses.sort((a, b) => (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int));
    
    return allExpenses;
  }

  Future<Map<String, double>> getExpensesSummary({
    required String period, // 'today', 'week', 'month'
  }) async {
    final db = await DatabaseManager.getCurrentBusinessDb();
    if (db == null) throw Exception('Nuk është zgjedhur asnjë biznes.');
    final now = DateTime.now();
    
    String whereClause = 'revertedAtMs IS NULL';
    List<dynamic> args = [];
    
    if (period == 'today') {
      final todayK = dayKey(now);
      whereClause += ' AND dayKey = ?';
      args.add(todayK);
    } else if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoMs = weekAgo.millisecondsSinceEpoch;
      whereClause += ' AND createdAtMs >= ?';
      args.add(weekAgoMs);
    } else if (period == 'month') {
      final monthK = monthKey(now);
      whereClause += ' AND monthKey = ?';
      args.add(monthK);
    }
    
    // Get expenses
    final expenseRows = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount),0) as total,
        COUNT(*) as count
      FROM expenses
      WHERE $whereClause
    ''', args);
    
    // Get investments
    final investRows = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount),0) as total,
        COUNT(*) as count
      FROM investments
      WHERE $whereClause
    ''', args);
    
    final expensesTotal = ((expenseRows.first['total'] as num?) ?? 0).toDouble();
    final expensesCount = (expenseRows.first['count'] as int?) ?? 0;
    
    final investTotal = ((investRows.first['total'] as num?) ?? 0).toDouble();
    final investCount = (investRows.first['count'] as int?) ?? 0;
    
    return {
      'expensesTotal': expensesTotal,
      'expensesCount': expensesCount.toDouble(),
      'investTotal': investTotal,
      'investCount': investCount.toDouble(),
      'grandTotal': expensesTotal + investTotal,
      'totalCount': (expensesCount + investCount).toDouble(),
    };
  }
}
