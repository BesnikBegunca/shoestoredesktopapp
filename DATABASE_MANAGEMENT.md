# Database Management

## Komanda për Menaxhimin e Databazave

### 1. Fshi TË GJITHA databazat dhe fillo nga zero

```bash
dart lib/src/db/run_cleanup.dart clean_all
```

Kjo komandë:
- ✅ Fshi të gjitha databazat (admin dhe business)
- ✅ Krijon admin DB të re
- ✅ Krijon superadmin user (username: `superadmin`, password: `123123`)

### 2. Fshi vetëm bizneset (mbaj superadmin)

```bash
dart lib/src/db/run_cleanup.dart delete_businesses
```

Kjo komandë:
- ✅ Fshi të gjitha bizneset nga admin DB
- ✅ Fshi të gjitha licensat
- ✅ Fshi të gjitha databazat e bizneseve
- ✅ Mbaj superadmin user

### 3. Krijo një biznes test

```bash
dart lib/src/db/run_cleanup.dart create_test
```

Kjo komandë krijon një biznes test me:
- Emri: `Dyqani Test`
- Email: `test@test.com`
- Password: `test123`
- Licensa: 365 ditë
- Admin user: `test@test.com` / `test123`

### 4. Shfaq informacion mbi databazat

```bash
dart lib/src/db/run_cleanup.dart info
```

Kjo komandë shfaq:
- Lista e databazave dhe madhësitë e tyre
- Lista e bizneseve me status të licensave
- Lista e users në admin DB

## Probleme të Zakonshme dhe Zgjidhjet

### Problem: TextField nuk ka Material ancestor

**Zgjidhja**: Hot restart aplikacionin pas ndryshimeve:
```bash
# Në Flutter terminal, shtyp:
R  # për hot restart
```

### Problem: Bizneset e vjetra kanë probleme

**Zgjidhja**: Fshi të gjitha bizneset dhe fillo nga zero:
```bash
dart lib/src/db/run_cleanup.dart delete_businesses
```

### Problem: Databaza është korruptuar

**Zgjidhja**: Reset total i sistemit:
```bash
dart lib/src/db/run_cleanup.dart clean_all
```

## Workflow i Rekomanduar për Zhvillim

1. **Reset i plotë** (fillimi i zhvillimit):
   ```bash
   dart lib/src/db/run_cleanup.dart clean_all
   flutter run
   ```

2. **Fshi bizneset e vjetra** (test i ri):
   ```bash
   dart lib/src/db/run_cleanup.dart delete_businesses
   dart lib/src/db/run_cleanup.dart create_test
   ```

3. **Kontrollo statusin**:
   ```bash
   dart lib/src/db/run_cleanup.dart info
   ```

## Login Credentials

### Superadmin (Developer Panel)
- **Username**: `superadmin`
- **Password**: `123123`

### Biznes Test (nëse krijohet me create_test)
- **Username**: `test@test.com`
- **Password**: `test123`

## Databazat

### Admin Database: `shoe_store_admin.sqlite`
Përmban:
- Superadmin users
- Lista e bizneseve
- Licensat e bizneseve

### Business Databases: `business_{id}.sqlite`
Për çdo biznes:
- Admin dhe worker users
- Products & Variants
- Sales & Sale Items
- Investments & Expenses
- Settlements

## Siguria

⚠️ **KUJDES**: Këto komanda fshin të dhënat permanent!
- Bëj backup përpara se të ekzekutosh `clean_all`
- Në production, përdor vetëm përmes Developer Panel
- Mos shpërndaj superadmin credentials

## Support

Për probleme:
1. Kontrollo terminalet për error messages
2. Ekzekuto `info` për të parë statusin
3. Provo `clean_all` për reset total
