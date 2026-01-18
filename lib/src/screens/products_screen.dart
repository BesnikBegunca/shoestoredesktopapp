import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _loading = true;
  List<Product> _items = [];

  // ✅ labels për tesha (key 1000..)
  static const List<String> _clothLabels = [
    '0-3M',
    '3-6M',
    '6-9M',
    '9-12M',
    '12-18M',
    '18-24M',
    '2Y',
    '3Y',
    '4Y',
    '5Y',
    '6Y',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _hasValidImage(String? path) {
    if (path == null) return false;
    final t = path.trim();
    if (t.isEmpty) return false;
    return File(t).existsSync();
  }

  Widget _thumb(Product p0) {
    final path = p0.imagePath?.trim();
    final ok = _hasValidImage(path);

    if (ok) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderThumb(),
        ),
      );
    }
    return _placeholderThumb();
  }

  Widget _placeholderThumb() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface2.withOpacity(0.45),
        border: Border.all(color: AppTheme.stroke),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: AppTheme.text),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await LocalApi.I.getProducts();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Product? editing}) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(editing: editing),
    );
    if (res == true) _load();
  }

  Future<void> _confirmDelete(Product p0) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Fshij produktin?', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w900)),
        content: Text('A je i sigurt me fshi "${p0.name}"?', style: const TextStyle(color: AppTheme.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Fshije')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await LocalApi.I.deleteProduct(p0.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produkti u fshi.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  Future<void> _toggleActive(Product p0) async {
    try {
      await LocalApi.I.toggleActive(p0.id, !p0.active);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        foregroundColor: AppTheme.text,
        title: const Text('Produktet', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        label: const Text('Shto'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('S’ka produkte ende.', style: TextStyle(color: AppTheme.text)))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p0 = _items[i];
          final hasDisc = p0.discountPercent > 0;

          return Card(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.stroke),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _thumb(p0),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p0.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p0.serialNumber ?? p0.sku ?? '—',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _pill('Stok: ${p0.stockQty}', p0.stockQty > 0 ? Colors.green : Colors.red),
                            _pill(p0.active ? 'Active' : 'OFF', p0.active ? Colors.green : Colors.grey),
                            if (hasDisc) _pill('-${p0.discountPercent.toStringAsFixed(0)}%', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _sizesInline(p0), // ✅ shfaq edhe 0-3M...
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasDisc)
                        Text(
                          '€${p0.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppTheme.muted,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        '€${p0.finalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Active',
                            onPressed: () => _toggleActive(p0),
                            icon: Icon(p0.active ? Icons.toggle_on : Icons.toggle_off, color: AppTheme.text),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _openForm(editing: p0),
                            icon: const Icon(Icons.edit, color: AppTheme.text),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(p0),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.text),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ key 1000.. => label, ndryshe => numri i patikave
  String _labelForSizeKey(int key) {
    if (key >= 1000) {
      final idx = key - 1000;
      if (idx >= 0 && idx < _clothLabels.length) {
        return _clothLabels[idx];
      }
    }
    return key.toString();
  }

  Widget _sizesInline(Product p0) {
    final sizes = p0.sizesSorted; // keys int
    if (sizes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in sizes) _sizeChip(_labelForSizeKey(s), p0.qtyForSize(s)),
      ],
    );
  }

  Widget _sizeChip(String label, int qty) {
    final ok = qty > 0;
    final c = ok ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        '$label: $qty',
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _pill(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// ============================
// ✅ DIALOG: PATIKA / TESHA
// ============================

enum ProductKind { shoes, clothes }

class _ProductFormDialog extends StatefulWidget {
  final Product? editing;
  const _ProductFormDialog({required this.editing});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameC;
  late final TextEditingController skuC;
  late final TextEditingController serialC;
  late final TextEditingController priceC;
  late final TextEditingController purchaseC;
  late final TextEditingController discountC;
  late final TextEditingController imagePathC;

  // shoes
  late Map<int, TextEditingController> sizeCtrls;

  // clothes
  late Map<String, TextEditingController> clothCtrls;

  ProductKind kind = ProductKind.shoes;

  bool active = true;
  bool saving = false;

  static const int minSize = 17;
  static const int maxSize = 30;

  static const List<String> clothSizes = [
    '0-3M',
    '3-6M',
    '6-9M',
    '9-12M',
    '12-18M',
    '18-24M',
    '2Y',
    '3Y',
    '4Y',
    '5Y',
    '6Y',
  ];

  int _clothKey(int index) => 1000 + index;

  @override
  void initState() {
    super.initState();
    final p0 = widget.editing;

    nameC = TextEditingController(text: p0?.name ?? '');
    skuC = TextEditingController(text: p0?.sku ?? '');
    serialC = TextEditingController(text: p0?.serialNumber ?? '');
    priceC = TextEditingController(text: p0 == null ? '' : p0.price.toString());
    purchaseC = TextEditingController(text: p0?.purchasePrice?.toString() ?? '');
    discountC = TextEditingController(text: p0?.discountPercent.toString() ?? '0');
    imagePathC = TextEditingController(text: p0?.imagePath ?? '');
    active = p0?.active ?? true;

    final existing = p0?.sizeStock ?? {};

    // ✅ nese ka keys 1000+ ose jashtë 17–30, e trajtojmë si TESHA
    final hasClothLike = existing.keys.any((k) => k >= 1000 || k < minSize || k > maxSize);
    kind = hasClothLike ? ProductKind.clothes : ProductKind.shoes;

    sizeCtrls = {
      for (int s = minSize; s <= maxSize; s++)
        s: TextEditingController(text: (existing[s] ?? 0).toString()),
    };

    clothCtrls = {
      for (int i = 0; i < clothSizes.length; i++)
        clothSizes[i]: TextEditingController(text: (existing[_clothKey(i)] ?? 0).toString()),
    };
  }

  @override
  void dispose() {
    nameC.dispose();
    skuC.dispose();
    serialC.dispose();
    priceC.dispose();
    purchaseC.dispose();
    discountC.dispose();
    imagePathC.dispose();

    for (final c in sizeCtrls.values) {
      c.dispose();
    }
    for (final c in clothCtrls.values) {
      c.dispose();
    }

    super.dispose();
  }

  double _parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =========================
  // ✅ IMAGES: save inside app
  // =========================

  Future<Directory> _imagesDir() async {
    final base = await getApplicationSupportDirectory(); // desktop safe
    final dir = Directory(p.join(base.path, 'shoe_store_manager', 'images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  bool _looksLikeInsideAppImages(String path) {
    final t = path.replaceAll('\\', '/').toLowerCase();
    return t.contains('/shoe_store_manager/images/');
  }

  Future<String> _savePickedImageToApp(String pickedPath) async {
    final src = File(pickedPath);
    if (!await src.exists()) {
      throw 'Foto s’u gjet: $pickedPath';
    }

    final images = await _imagesDir();
    final ext = p.extension(pickedPath).toLowerCase();
    final safeExt = (ext.isEmpty) ? '.jpg' : ext;

    final fileName = 'p_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final dstPath = p.join(images.path, fileName);

    await src.copy(dstPath);
    return dstPath;
  }

  Future<void> _deleteIfAppImage(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final t = path.trim();
    if (!_looksLikeInsideAppImages(t)) return; // ✅ mos prek foto jashtë app-it
    final f = File(t);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Zgjedh foton e produktit',
      );
      if (res == null) return;
      final picked = res.files.single.path;
      if (picked == null || picked.isEmpty) return;

      // ✅ kopjo brenda app-it
      final storedPath = await _savePickedImageToApp(picked);

      // ✅ nese jemi tu editu dhe ka pas foto te app-it, fshije (opsionale)
      final old = imagePathC.text.trim();
      if (old.isNotEmpty && _looksLikeInsideAppImages(old) && old != storedPath) {
        await _deleteIfAppImage(old);
      }

      setState(() => imagePathC.text = storedPath);
    } catch (e) {
      _snack('S’u zgjodh foto: $e');
    }
  }

  bool _isValidImagePath(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    return File(path.trim()).existsSync();
  }

  Map<int, int> _collectSizeStock() {
    final out = <int, int>{};

    if (kind == ProductKind.shoes) {
      for (final entry in sizeCtrls.entries) {
        final size = entry.key;
        final ctrl = entry.value;
        final q = _parseInt(ctrl.text);
        if (q < 0) continue;
        out[size] = q > 0 ? q : 0;
      }
    } else {
      for (int i = 0; i < clothSizes.length; i++) {
        final label = clothSizes[i];
        final ctrl = clothCtrls[label]!;
        final q = _parseInt(ctrl.text);
        if (q < 0) continue; // ✅ FIX
        out[_clothKey(i)] = q > 0 ? q : 0;
      }
    }

    return out;
  }

  int _totalStock(Map<int, int> m) => m.values.fold(0, (a, b) => a + b);

  Future<void> _save() async {
    if (saving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = nameC.text.trim();
    final sku = skuC.text.trim().isEmpty ? null : skuC.text.trim();
    final serial = serialC.text.trim().isEmpty ? null : serialC.text.trim();
    final price = _parseDouble(priceC.text);
    final purchase = purchaseC.text.trim().isEmpty ? null : _parseDouble(purchaseC.text);
    final disc = _parseDouble(discountC.text);

    final imgRaw = imagePathC.text.trim();
    final img = imgRaw.isEmpty ? null : imgRaw;

    final sizeStock = _collectSizeStock();
    final total = _totalStock(sizeStock);

    if (price <= 0) {
      _snack('Çmimi duhet > 0.');
      return;
    }
    if (disc < 0 || disc > 100) {
      _snack('Zbritja duhet 0–100.');
      return;
    }

    // ✅ validate negatives (sipas kind)
    if (kind == ProductKind.shoes) {
      for (final e in sizeCtrls.entries) {
        final q = _parseInt(e.value.text);
        if (q < 0) {
          _snack('Numri ${e.key}: sasia s’mund me qenë negative.');
          return;
        }
      }
    } else {
      for (final label in clothSizes) {
        final q = _parseInt(clothCtrls[label]!.text);
        if (q < 0) {
          _snack('Masa $label: sasia s’mund me qenë negative.');
          return;
        }
      }
    }

    if (total <= 0) {
      _snack('Duhet me pas të paktën 1 copë në stok (në ndonjë masë).');
      return;
    }

    // ✅ extra safety: nese dikush e ka shkru manualisht path jashtë app-it,
    // e kopjojmë brenda app-it para se me e ruajt në DB
    String? finalImg = img;
    if (finalImg != null && finalImg.isNotEmpty) {
      if (!_looksLikeInsideAppImages(finalImg) && File(finalImg).existsSync()) {
        final stored = await _savePickedImageToApp(finalImg);
        finalImg = stored;
        imagePathC.text = stored;
      }
    }

    setState(() => saving = true);
    try {
      final editing = widget.editing;

      if (editing == null) {
        await LocalApi.I.addProduct(
          name: name,
          sku: sku,
          serialNumber: serial,
          price: price,
          purchasePrice: purchase,
          discountPercent: disc,
          active: active,
          imagePath: finalImg,
          sizeStock: sizeStock,
        );
      } else {
        // nese e ndrron foton, mundesh me fshi te vjetren (vetëm nëse është e app-it)
        final old = (editing.imagePath ?? '').trim();
        if (old.isNotEmpty && old != (finalImg ?? '') && _looksLikeInsideAppImages(old)) {
          await _deleteIfAppImage(old);
        }

        await LocalApi.I.updateProduct(
          id: editing.id,
          name: name,
          sku: sku,
          serialNumber: serial,
          price: price,
          purchasePrice: purchase,
          discountPercent: disc,
          active: active,
          imagePath: finalImg,
          sizeStock: sizeStock,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _snack('Gabim: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;

    final imgPath = imagePathC.text.trim();
    final hasImg = _isValidImagePath(imgPath);

    final sizeStockPreview = _collectSizeStock();
    final totalStock = _totalStock(sizeStockPreview);

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        isEdit ? 'Ndrysho produkt' : 'Shto produkt',
        style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameC,
                  style: const TextStyle(color: AppTheme.text),
                  decoration: const InputDecoration(
                    labelText: 'Emri i produktit',
                    hintText: 'p.sh. Nike Air Max',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Shkruje emrin.' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: skuC,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(labelText: 'SKU (opsionale)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: serialC,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(labelText: 'Nr. Serik (opsionale, UNIQUE)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceC,
                        style: const TextStyle(color: AppTheme.text),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Çmimi i shitjes (€)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: purchaseC,
                        style: const TextStyle(color: AppTheme.text),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Çmimi i blerjes (€) (ops.)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: discountC,
                  style: const TextStyle(color: AppTheme.text),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Zbritja (%)'),
                ),
                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Stoku sipas masave',
                            style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.text),
                          ),
                          const Spacer(),
                          _totalPill('Total: $totalStock'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _kindBtn(
                            label: 'PATIKA',
                            selected: kind == ProductKind.shoes,
                            onTap: () => setState(() => kind = ProductKind.shoes),
                          ),
                          _kindBtn(
                            label: 'TESHA',
                            selected: kind == ProductKind.clothes,
                            onTap: () => setState(() => kind = ProductKind.clothes),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (kind == ProductKind.shoes) _sizesGrid() else _clothSizesGrid(),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: imagePathC,
                        style: const TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          labelText: 'Foto (ruhet automatikisht në app)',
                          hintText: r'C:\...\foto.png',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose file'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (hasImg)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 140,
                        height: 140,
                        color: AppTheme.surface2.withOpacity(0.35),
                        child: Image.file(
                          File(imgPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  )
                else if (imgPath.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '⚠️ Foto s’u gjet në këtë path.',
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w800),
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Active', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.text)),
                    const Spacer(),
                    Switch(value: active, onChanged: (v) => setState(() => active = v)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Duke ruajt...' : (isEdit ? 'Ruaj' : 'Shto')),
        ),
      ],
    );
  }

  Widget _kindBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? AppTheme.primaryPurple.withOpacity(0.22) : AppTheme.surface2.withOpacity(0.35),
          border: Border.all(color: selected ? AppTheme.primaryPurple : AppTheme.stroke),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _sizesGrid() {
    final keys = sizeCtrls.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 6 : 4;
        final rows = <Widget>[];

        for (final size in keys) {
          final ctrl = sizeCtrls[size]!;
          final q = _parseInt(ctrl.text);
          final ok = q > 0;
          final color = ok ? Colors.green : Colors.red;

          rows.add(
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.35)),
                color: color.withOpacity(0.08),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$size',
                      style: TextStyle(fontWeight: FontWeight.w900, color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: rows,
        );
      },
    );
  }

  Widget _clothSizesGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 4 : 2;
        final tiles = <Widget>[];

        for (final label in clothSizes) {
          final ctrl = clothCtrls[label]!;
          final q = _parseInt(ctrl.text);
          final ok = q > 0;
          final color = ok ? Colors.green : Colors.red;

          tiles.add(
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.35)),
                color: color.withOpacity(0.08),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w900, color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        );
      },
    );
  }
  Widget _totalPill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.35)),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: AppTheme.text,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
