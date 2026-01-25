# Global Design System Documentation

Ky dokument shpjegon sistemin global të dizajnit për aplikacionin. Të gjitha stilet janë të centralizuara në `lib/src/theme/app_theme.dart`.

## 🎨 1. TYPOGRAPHY (Fonti)

### Font Family
- **Font Default**: `Roboto` (Variable Font)
- **Vendodhja**: `assets/fonts/Roboto-VariableFont_wdth,wght.ttf`
- **Përdorimi**: Aplikohet automatikisht në të gjitha tekstet

```dart
// NOPE - Mos e përdor më:
Text('Hello', style: TextStyle(fontFamily: 'Arial'))

// YES - Fonti aplikohet automatikisht:
Text('Hello')

// Ose eksplicite:
Text('Hello', style: TextStyle(fontFamily: AppTheme.fontFamily))
```

---

## 🎨 2. COLORS (Ngjyrat)

### Background Colors
```dart
AppTheme.bgPage       // #F5F7FA - Sfondi i faqes (very light gray)
AppTheme.bgSurface    // #FFFFFF - Karta/kontejnerë (white)
AppTheme.bgInput      // #F8FAFC - Sfondi i input-eve (light gray)
```

### Text Colors
```dart
AppTheme.textPrimary    // #0F172A - Tekst i errët (primary text)
AppTheme.textSecondary  // #64748B - Tekst gri (muted/secondary)
AppTheme.textTertiary   // #94A3B8 - Tekst i lehtë (subtle)
```

### Border Colors
```dart
AppTheme.borderLight   // #E2E8F0 - Border i lehtë
AppTheme.borderMedium  // #CBD5E1 - Border mesatar
AppTheme.borderDark    // #94A3B8 - Border i errët
```

### Button Colors
```dart
AppTheme.btnPrimary          // #1E293B - Butoni kryesor (dark/black)
AppTheme.btnPrimaryHover     // #334155 - Hover state
AppTheme.btnSecondary        // #FFFFFF - Butoni sekondar (white)
AppTheme.btnSecondaryBorder  // #E2E8F0 - Border për butonin sekondar
```

### Status Colors
```dart
AppTheme.success   // #10B981 - E gjelbër (success)
AppTheme.error     // #EF4444 - E kuqe (error)
AppTheme.warning   // #F59E0B - Portokalli (warning)
AppTheme.info      // #3B82F6 - Blu (info)
```

### Shembull Përdorimi:
```dart
// NOPE - Mos përdor ngjyra të hardcoded:
Container(color: Color(0xFFFFFFFF))

// YES - Përdor nga tema:
Container(color: AppTheme.bgSurface)
```

---

## 📐 3. BORDER RADIUS

```dart
AppTheme.radiusSmall   // 8.0  - Elemente të vogla
AppTheme.radiusMedium  // 10.0 - Butona, inputs (STANDARD)
AppTheme.radiusLarge   // 12.0 - Karta, kontejnerë
AppTheme.radiusXLarge  // 16.0 - Modals, dialoge
```

### Shembull:
```dart
// NOPE:
BorderRadius.circular(12)

// YES:
BorderRadius.circular(AppTheme.radiusLarge)
```

---

## 🌑 4. SHADOWS (Hijet)

```dart
AppTheme.shadowSoft    // Shadow i butë për elemente të vogla
AppTheme.shadowMedium  // Shadow mesatar për karta
AppTheme.shadowLarge   // Shadow i madh për modals/dialoge
```

### Shembull:
```dart
// NOPE:
boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]

// YES:
boxShadow: AppTheme.shadowMedium
```

---

## 📏 5. SPACING (Hapësirat)

Sistemi i spacing-ut për padding dhe margin:

```dart
AppTheme.space4   // 4.0
AppTheme.space8   // 8.0
AppTheme.space12  // 12.0
AppTheme.space16  // 16.0
AppTheme.space20  // 20.0
AppTheme.space24  // 24.0
AppTheme.space32  // 32.0
AppTheme.space40  // 40.0
AppTheme.space48  // 48.0
```

### Shembull:
```dart
// NOPE:
padding: EdgeInsets.all(16)

// YES:
padding: EdgeInsets.all(AppTheme.space16)
```

---

## 🔘 6. BUTTONS

Tema globale e butonave:

### Primary Button (Dark/Black)
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('Kliko'),
)
// Stili aplikohet automatikisht
```

### Secondary Button (White with border)
```dart
OutlinedButton(
  onPressed: () {},
  child: Text('Anulo'),
)
// Stili aplikohet automatikisht
```

### Text Button
```dart
TextButton(
  onPressed: () {},
  child: Text('Link'),
)
```

---

## 📝 7. INPUT FIELDS

Tema globale për të gjitha TextField/TextFormField:

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Emri',
    hintText: 'Shkruaj emrin...',
  ),
)
// Border radius, ngjyrat, padding aplikohen automatikisht
```

---

## 🎴 8. CARDS

```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(AppTheme.space16),
    child: Text('Përmbajtja'),
  ),
)
// Border radius, shadow, ngjyrat aplikohen automatikisht
```

---

## 📋 9. BEST PRACTICES

### ✅ DO (Bëj):
1. Përdor gjithmonë konstanta nga `AppTheme`
2. Përdor `AppTheme.space*` për padding/margin
3. Përdor `AppTheme.radius*` për border radius
4. Përdor `AppTheme.shadowMedium` për shadows
5. Le temën globale të aplikojë stilet automatikisht

### ❌ DON'T (Mos bëj):
1. Mos përdor ngjyra të hardcoded: `Color(0xFF...)`
2. Mos përdor border radius të hardcoded: `BorderRadius.circular(12)`
3. Mos përdor fonts të tjerë përveç Roboto
4. Mos krijon stilet manualisht kur tema i ofron automatikisht

---

## 📱 10. CONSISTENCY CHECKLIST

Para se të pushosh, kontrollo:

- [ ] Të gjitha tekstet përdorin Roboto (automatikisht)
- [ ] Të gjitha ngjyrat vijnë nga `AppTheme.***`
- [ ] Të gjitha border radius vijnë nga `AppTheme.radius*`
- [ ] Të gjitha shadows vijnë nga `AppTheme.shadow*`
- [ ] Të gjitha spacing vijnë nga `AppTheme.space*`
- [ ] Butonët, inputs, cards përdorin temën globale

---

## 🔄 MIGRATION GUIDE

Për të migruar kod ekzistues:

### Before:
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
      ),
    ],
  ),
  padding: EdgeInsets.all(16),
  child: Text(
    'Hello',
    style: TextStyle(
      color: Color(0xFF000000),
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

### After:
```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.bgSurface,
    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    boxShadow: AppTheme.shadowMedium,
  ),
  padding: EdgeInsets.all(AppTheme.space16),
  child: Text(
    'Hello',
    style: TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

---

**Sistemi i dizajnit është single source of truth për të gjitha stilet!**
