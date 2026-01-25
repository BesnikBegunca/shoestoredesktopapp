import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Menaxhon databazat e shumta për sistemin multi-tenancy
/// - Admin DB: përmban superadmin users, businesses, dhe business_licenses
/// - Business DBs: një databazë e veçantë për çdo biznes me të gjitha të dhënat operative
class DatabaseManager {
  DatabaseManager._();
  
  static Database? _adminDb;
  static final Map<int, Database> _businessDbs = {};
  static int? _currentBusinessId;
  static bool _isInitialized = false;
  
  static const int kAdminDbVersion = 1;
  static const int kBusinessDbVersion = 11; // same as current version
  
  /// Inicializo sqflite FFI në mënyrë të sigurt (vetëm një herë)
  /// Ky funksion mund të përdoret nga çdo vend në aplikacion
  /// për të siguruar që sqflite është inicializuar pa shkaktuar paralajmërime
  static void ensureSqfliteInitialized() {
    if (_isInitialized) return;
    
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _isInitialized = true;
  }
  
  /// Inicializo sqflite një herë në fillim (përdoret internalisht)
  static void _ensureInitialized() {
    ensureSqfliteInitialized();
  }
  
  /// Merr databazën admin (qendrore)
  static Future<Database> getAdminDb() async {
    if (_adminDb != null) return _adminDb!;
    
    _ensureInitialized();
    
    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final String dbPath = p.join(dir.path, 'shoe_store_admin.sqlite');
    
    final db = await openDatabase(
      dbPath,
      version: kAdminDbVersion,
      onCreate: (d, v) async {
        await _createAdminSchema(d);
      },
      onUpgrade: (d, oldV, newV) async {
        await _createAdminSchema(d);
      },
      onOpen: (d) async {
        await _createAdminSchema(d);
      },
    );
    
    _adminDb = db;
    return db;
  }
  
  /// Merr databazën e një biznesi specifik
  static Future<Database> getBusinessDb(int businessId) async {
    if (_businessDbs.containsKey(businessId)) {
      return _businessDbs[businessId]!;
    }
    
    _ensureInitialized();
    
    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final String dbPath = p.join(dir.path, 'business_$businessId.sqlite');
    
    final db = await openDatabase(
      dbPath,
      version: kBusinessDbVersion,
      onCreate: (d, v) async {
        await _createBusinessSchema(d);
      },
      onUpgrade: (d, oldV, newV) async {
        await _createBusinessSchema(d);
        await _migrateBusinessDb(d, oldV, newV);
      },
      onOpen: (d) async {
        await _createBusinessSchema(d);
      },
    );
    
    _businessDbs[businessId] = db;
    return db;
  }
  
  /// Switch tek databaza e një biznesi (për përdorim të shpejtë)
  static Future<void> switchToBusiness(int businessId) async {
    _currentBusinessId = businessId;
    await getBusinessDb(businessId);
  }
  
  /// Merr databazën e biznesit aktual (nëse është bërë switch)
  static Future<Database?> getCurrentBusinessDb() async {
    if (_currentBusinessId == null) return null;
    return getBusinessDb(_currentBusinessId!);
  }
  
  /// Merr ID-në e biznesit aktual
  static int? getCurrentBusinessId() => _currentBusinessId;
  
  /// Krijo një databazë të re për një biznes
  static Future<void> createBusinessDatabase(int businessId) async {
    final db = await getBusinessDb(businessId);
    // Databaza krijohet automatikisht me schema nga onCreate
    await db.execute('SELECT 1'); // Dummy query për të siguruar që është e hapur
  }
  
  /// Kontrollo nëse databaza e një biznesi ekziston
  static Future<bool> businessDatabaseExists(int businessId) async {
    final Directory dir = await getApplicationSupportDirectory();
    final String dbPath = p.join(dir.path, 'business_$businessId.sqlite');
    return File(dbPath).exists();
  }
  
  /// Fshi databazën e një biznesi
  static Future<void> deleteBusinessDatabase(int businessId) async {
    // Mbyll databazën nëse është e hapur
    if (_businessDbs.containsKey(businessId)) {
      await _businessDbs[businessId]!.close();
      _businessDbs.remove(businessId);
    }
    
    final Directory dir = await getApplicationSupportDirectory();
    final String dbPath = p.join(dir.path, 'business_$businessId.sqlite');
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Mbyll të gjitha databazat
  static Future<void> closeAll() async {
    if (_adminDb != null) {
      await _adminDb!.close();
      _adminDb = null;
    }
    
    for (final db in _businessDbs.values) {
      await db.close();
    }
    _businessDbs.clear();
    _currentBusinessId = null;
    // Mos e resetoni _isInitialized - sqflite FFI duhet të inicializohet vetëm një herë
    // _isInitialized = false;
  }
  
  // ================= SCHEMA CREATION =================
  
  static Future<void> _createAdminSchema(Database db) async {
    // Users table (vetëm superadmin)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        createdAtMs INTEGER NOT NULL
      )
    ''');
    
    // Businesses table
    await db.execute('''
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
      )
    ''');
    
    // Business Licenses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_licenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId INTEGER NOT NULL,
        licenseKey TEXT NOT NULL UNIQUE,
        validDays INTEGER NOT NULL,
        issuedAtMs INTEGER NOT NULL,
        expiresAtMs INTEGER NOT NULL,
        activatedAtMs INTEGER,
        lastCheckedMs INTEGER,
        active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE
      )
    ''');
  }
  
  static Future<void> _createBusinessSchema(Database db) async {
    // Users table (admin dhe workers të biznesit)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        createdAtMs INTEGER NOT NULL,
        businessId INTEGER
      )
    ''');
    
    // Products table
    await db.execute('''
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
      )
    ''');
    
    // Product Variants table
    await db.execute('''
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
      )
    ''');
    
    // Sales table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNo TEXT NOT NULL,
        userId INTEGER,
        total REAL NOT NULL,
        profitTotal REAL NOT NULL,
        dayKey TEXT NOT NULL,
        monthKey TEXT NOT NULL,
        createdAtMs INTEGER NOT NULL,
        revertedAtMs INTEGER,
        settledAtMs INTEGER
      )
    ''');
    
    // Sale Items table
    await db.execute('''
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
      )
    ''');
    
    // Investments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT,
        dayKey TEXT NOT NULL,
        monthKey TEXT NOT NULL,
        createdAtMs INTEGER NOT NULL,
        revertedAtMs INTEGER
      )
    ''');
    
    // Expenses table
    await db.execute('''
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
      )
    ''');
    
    // Settlements table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        dayKey TEXT NOT NULL,
        totalSales REAL NOT NULL,
        settledAtMs INTEGER NOT NULL,
        UNIQUE(userId, dayKey)
      )
    ''');
  }
  
  static Future<void> _migrateBusinessDb(Database db, int oldVersion, int newVersion) async {
    // Migration logic për databazat e bizneseve (nëse nevojitet)
    if (oldVersion < 11) {
      // Add any missing columns
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE products ADD COLUMN subcategory TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN settledAtMs INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN businessId INTEGER');
      } catch (_) {}
    }
  }
}
