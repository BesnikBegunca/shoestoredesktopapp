const int kDbVersion = 6;

/* ======================= SQL ======================= */

const String kSqlCreateUsers = '''
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL,     -- 'worker' | 'admin'
  active INTEGER NOT NULL DEFAULT 1,
  createdAtMs INTEGER NOT NULL
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
  createdAtMs INTEGER,
  updatedAtMs INTEGER
);
''';

const String kSqlCreateSales = '''
CREATE TABLE IF NOT EXISTS sales (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 0,
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
  userId INTEGER NOT NULL DEFAULT 0,
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
  userId INTEGER NOT NULL DEFAULT 0,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  note TEXT,
  dayKey TEXT NOT NULL,
  monthKey TEXT NOT NULL,
  createdAtMs INTEGER NOT NULL,
  revertedAtMs INTEGER
);
''';

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
