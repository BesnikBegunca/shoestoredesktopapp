import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

enum ProductKind { shoes, clothes }

class InventoryScreen extends StatefulWidget {
  final Product? editing;
  const InventoryScreen({super.key, this.editing});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameC;
  late final TextEditingController descriptionC;
  late final TextEditingController skuC;
  late final TextEditingController serialC;
  late final TextEditingController priceC;
  late final TextEditingController purchaseC;
  late final TextEditingController discountC;
  late final TextEditingController discountTypeC;
  late final TextEditingController quantityC;
  late final TextEditingController variationTypeC;
  late final TextEditingController skuVariationC;
  late final TextEditingController imagePathC;
  late final TextEditingController categoryC;
  late final TextEditingController tagsC;

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

  final List<String> categories = [
    'Bebe',
    'Vajza',
    'Djem',
    'Patika',
    'Rroba Stinore',
    'Rroba Sportive',
    'Rroba Gjumi',
    'Aksesorë',
  ];

  // Map category to its tags
  final Map<String, List<String>> categoryTags = {
    'Bebe': [
      'Bodysuit / Onesies',
      'Sete bebe',
      'Pizhama bebe',
      'Kapele & çorape',
      'Patika bebe',
    ],
    'Vajza': [
      'Fustane',
      'Bluza vajza',
      'Pantallona vajza',
      'Funde',
      'Xhaketa vajza',
      'Patika vajza',
    ],
    'Djem': [
      'Bluza djem',
      'Këmisha',
      'Pantallona djem',
      'Trenerka',
      'Xhaketa djem',
      'Patika djem',
    ],
    'Patika': [
      'Patika sportive',
      'Patika shkollore',
      'Patika verore',
      'Patika dimërore',
    ],
    'Rroba Stinore': ['Verore', 'Dimërore', 'Pranverë / Vjeshtë'],
    'Rroba Sportive': ['Trenerka', 'Sete sportive'],
    'Rroba Gjumi': ['Pizhama', 'Robe gjumi'],
    'Aksesorë': ['Kapele', 'Çorape', 'Shami'],
  };

  // Get tags for selected category
  List<String> getTagsForCategory(String? category) {
    if (category == null || category.isEmpty) {
      return [];
    }
    return categoryTags[category] ?? [];
  }

  int _clothKey(int index) => 1000 + index;

  @override
  void initState() {
    super.initState();
    final p0 = widget.editing;

    nameC = TextEditingController(text: p0?.name ?? '');
    descriptionC = TextEditingController(text: '');
    skuC = TextEditingController(text: p0?.sku ?? '');
    serialC = TextEditingController(text: p0?.serialNumber ?? '');
    priceC = TextEditingController(text: p0 == null ? '' : p0.price.toString());
    purchaseC = TextEditingController(
      text: p0?.purchasePrice?.toString() ?? '',
    );
    discountC = TextEditingController(
      text: p0?.discountPercent.toString() ?? '0',
    );
    discountTypeC = TextEditingController();
    quantityC = TextEditingController(text: p0?.stockQty.toString() ?? '0');
    variationTypeC = TextEditingController();
    skuVariationC = TextEditingController();
    imagePathC = TextEditingController(text: p0?.imagePath ?? '');
    categoryC = TextEditingController(text: p0?.category ?? '');
    tagsC = TextEditingController(text: p0?.subcategory ?? '');
    active = p0?.active ?? true;

    final existing = p0?.sizeStock ?? {};

    // ✅ nese ka keys 1000+ ose jashtë 17–30, e trajtojmë si TESHA
    final hasClothLike = existing.keys.any(
      (k) => k >= 1000 || k < minSize || k > maxSize,
    );
    kind = hasClothLike ? ProductKind.clothes : ProductKind.shoes;

    sizeCtrls = {
      for (int s = minSize; s <= maxSize; s++)
        s: TextEditingController(text: (existing[s] ?? 0).toString()),
    };

    clothCtrls = {
      for (int i = 0; i < clothSizes.length; i++)
        clothSizes[i]: TextEditingController(
          text: (existing[_clothKey(i)] ?? 0).toString(),
        ),
    };
  }

  @override
  void dispose() {
    nameC.dispose();
    descriptionC.dispose();
    skuC.dispose();
    serialC.dispose();
    priceC.dispose();
    purchaseC.dispose();
    discountC.dispose();
    discountTypeC.dispose();
    quantityC.dispose();
    variationTypeC.dispose();
    skuVariationC.dispose();
    imagePathC.dispose();
    categoryC.dispose();
    tagsC.dispose();

    for (final c in sizeCtrls.values) {
      c.dispose();
    }
    for (final c in clothCtrls.values) {
      c.dispose();
    }

    super.dispose();
  }

  double _parseDouble(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =========================
  // ✅ IMAGES: save inside app
  // =========================

  Future<Directory> _imagesDir() async {
    final base = await getApplicationSupportDirectory();
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
      throw "Foto s'u gjet: $pickedPath";
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
    if (!_looksLikeInsideAppImages(t)) return;
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
        allowMultiple: true,
        dialogTitle: 'Zgjedh fotot e produktit',
      );
      if (res == null || res.files.isEmpty) return;
      final picked = res.files.first.path;
      if (picked == null || picked.isEmpty) return;

      final storedPath = await _savePickedImageToApp(picked);

      final old = imagePathC.text.trim();
      if (old.isNotEmpty &&
          _looksLikeInsideAppImages(old) &&
          old != storedPath) {
        await _deleteIfAppImage(old);
      }

      setState(() => imagePathC.text = storedPath);
    } catch (e) {
      _snack("S'u zgjodh foto: $e");
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
        if (q < 0) continue;
        out[_clothKey(i)] = q > 0 ? q : 0;
      }
    }

    return out;
  }

  int _totalStock(Map<int, int> m) => m.values.fold(0, (a, b) => a + b);

  /// Gjeneron preview të SKU-ve për variantet
  List<String> _generateSkuPreview() {
    final name = nameC.text.trim();
    final category = categoryC.text.trim();
    final subcategory = tagsC.text.trim().isEmpty ? null : tagsC.text.trim();
    final sizeStock = _collectSizeStock();

    if (name.isEmpty || category.isEmpty) {
      return [];
    }

    final previews = <String>[];

    if (kind == ProductKind.shoes) {
      // Për patika: masat janë numra (17-30)
      for (final entry in sizeStock.entries) {
        final size = entry.key;
        final qty = entry.value;
        if (qty > 0 && size >= minSize && size <= maxSize) {
          try {
            final sku = generateVariantSku(
              category: category,
              subcategory: subcategory,
              productName: name,
              size: size.toString(),
            );
            previews.add('$sku (Masa: $size, Sasia: $qty)');
          } catch (e) {
            previews.add('Gabim: $e');
          }
        }
      }
    } else {
      // Për rroba: masat janë string (0-3M, 3-6M, etj.)
      for (int i = 0; i < clothSizes.length; i++) {
        final sizeKey = _clothKey(i);
        final qty = sizeStock[sizeKey] ?? 0;
        if (qty > 0) {
          try {
            final sku = generateVariantSku(
              category: category,
              subcategory: subcategory,
              productName: name,
              size: clothSizes[i],
            );
            previews.add('$sku (Masa: ${clothSizes[i]}, Sasia: $qty)');
          } catch (e) {
            previews.add('Gabim: $e');
          }
        }
      }
    }

    return previews;
  }

  Future<void> _save() async {
    if (saving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = nameC.text.trim();
    final serial = serialC.text.trim().isEmpty ? null : serialC.text.trim();
    final price = _parseDouble(priceC.text);
    final purchase = purchaseC.text.trim().isEmpty
        ? null
        : _parseDouble(purchaseC.text);
    final disc = _parseDouble(discountC.text);

    final imgRaw = imagePathC.text.trim();
    final img = imgRaw.isEmpty ? null : imgRaw;

    final category = categoryC.text.trim();
    final subcategory = tagsC.text.trim().isEmpty ? null : tagsC.text.trim();

    final sizeStock = _collectSizeStock();
    final total = _totalStock(sizeStock);

    // Validime
    if (name.isEmpty) {
      _snack('Emri i produktit është i detyrueshëm.');
      return;
    }
    if (category.isEmpty) {
      _snack('Kategoria e produktit është e detyrueshme.');
      return;
    }
    if (price <= 0) {
      _snack('Çmimi duhet > 0.');
      return;
    }
    if (disc < 0 || disc > 100) {
      _snack('Zbritja duhet 0–100.');
      return;
    }

    if (kind == ProductKind.shoes) {
      for (final e in sizeCtrls.entries) {
        final q = _parseInt(e.value.text);
        if (q < 0) {
          _snack("Numri ${e.key}: sasia s'mund me qenë negative.");
          return;
        }
      }
    } else {
      for (final label in clothSizes) {
        final q = _parseInt(clothCtrls[label]!.text);
        if (q < 0) {
          _snack("Masa $label: sasia s'mund me qenë negative.");
          return;
        }
      }
    }

    if (total <= 0) {
      _snack('Duhet me pas të paktën 1 copë në stok (në ndonjë masë).');
      return;
    }

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
          sku: null, // SKU gjenerohet automatikisht për variantet
          serialNumber: serial,
          price: price,
          purchasePrice: purchase,
          discountPercent: disc,
          active: active,
          imagePath: finalImg,
          sizeStock: sizeStock,
          category: category,
          subcategory: subcategory,
          autoGenerateVariants: true,
        );
        _snack('Produkti u shtua me sukses ✅');
        // Reset form
        nameC.clear();
        descriptionC.clear();
        skuC.clear();
        serialC.clear();
        priceC.clear();
        purchaseC.clear();
        discountC.text = '0';
        quantityC.text = '0';
        imagePathC.clear();
        categoryC.clear();
        tagsC.clear();
        for (final ctrl in sizeCtrls.values) {
          ctrl.text = '0';
        }
        for (final ctrl in clothCtrls.values) {
          ctrl.text = '0';
        }
      } else {
        final old = (editing.imagePath ?? '').trim();
        if (old.isNotEmpty &&
            old != (finalImg ?? '') &&
            _looksLikeInsideAppImages(old)) {
          await _deleteIfAppImage(old);
        }

        await LocalApi.I.updateProduct(
          id: editing.id,
          name: name,
          sku: null, // SKU gjenerohet automatikisht për variantet
          serialNumber: serial,
          price: price,
          purchasePrice: purchase,
          discountPercent: disc,
          active: active,
          imagePath: finalImg,
          sizeStock: sizeStock,
          category: category,
          subcategory: subcategory,
          autoGenerateVariants: true,
        );
        _snack('Produkti u përditësua me sukses ✅');
      }

      if (!mounted) return;
      setState(() => saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _snack('Gabim: $e');
    }
  }

  Widget _buildPanel({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool isNumber = false,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : (isMultiline ? TextInputType.multiline : TextInputType.text),
        maxLines: isMultiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black87, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required TextEditingController controller,
    required String label,
    required List<String> items,
    String? hint,
    bool isCategory = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black87, width: 2),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            controller.text = value;
            // Auto-detect product kind based on category or tag
            if (isCategory || label == 'Product Tags') {
              final selectedValue = value.toLowerCase();
              if (selectedValue.contains('patika')) {
                setState(() => kind = ProductKind.shoes);
              } else {
                setState(() => kind = ProductKind.clothes);
              }
            }
            // If category changed, clear and update tags
            if (isCategory) {
              tagsC.clear();
            }
            setState(() {});
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final imgPath = imagePathC.text.trim();
    final hasImg = _isValidImagePath(imgPath);
    final sizeStockPreview = _collectSizeStock();
    final totalStock = _totalStock(sizeStockPreview);

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(color: AppTheme.bgPage),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/stoku.svg',
                    width: 36,
                    height: 36,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Regjistrimi i Mallit',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // General Information
                          _buildPanel(
                            title: 'Informacioni i Përgjithshëm',
                            children: [
                              _buildTextField(
                                controller: nameC,
                                label: 'Emri i Produktit',
                              ),
                              _buildTextField(
                                controller: descriptionC,
                                label: 'Përshkrimi',
                                isMultiline: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Pricing
                          _buildPanel(
                            title: 'Çmimi',
                            children: [
                              _buildTextField(
                                controller: priceC,
                                label: 'Çmimi Bazë',
                                isNumber: true,
                              ),
                              _buildTextField(
                                controller: discountC,
                                label: 'Përqindja e Zbritjes (%)',
                                isNumber: true,
                              ),
                              _buildDropdown(
                                controller: discountTypeC,
                                label: 'Lloji i Zbritjes',
                                items: const ['Përqindje', 'Shumë Fikse'],
                                hint: 'Zgjedh llojin e zbritjes',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Inventory
                          _buildPanel(
                            title: 'Inventari',
                            children: [
                              // SKU Preview (read-only) - reaktive për të gjitha ndryshimet
                              Builder(
                                builder: (context) {
                                  final previews = _generateSkuPreview();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SKU (Auto-gjeneruar)',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (previews.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: const Text(
                                              'Plotëso Emri i Produktit dhe Kategoria për preview',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blue.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: previews.map((preview) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 4,
                                                      ),
                                                  child: Text(
                                                    preview,
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              _buildTextField(
                                controller: serialC,
                                label: 'Barkod',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Right Column
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Product Media
                          _buildPanel(
                            title: 'Media e Produktit',
                            children: [
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    style: BorderStyle.solid,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: hasImg
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(imgPath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                                child: Icon(Icons.broken_image),
                                              ),
                                        ),
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 8),
                                            TextButton.icon(
                                              onPressed: _pickImage,
                                              icon: const Icon(Icons.add),
                                              label: const Text(
                                                'Shto Foto Tjetër',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: _pickImage,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_open,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Zgjedh Foto',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Category
                          _buildPanel(
                            title: 'Kategoria',
                            children: [
                              _buildDropdown(
                                controller: categoryC,
                                label: 'Kategoria e Produktit',
                                items: categories,
                                hint: 'Zgjedh kategori',
                                isCategory: true,
                              ),
                              // Tags dropdown - reactive to category changes
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: categoryC,
                                builder: (context, categoryValue, child) {
                                  final selectedCategory =
                                      categoryValue.text.isEmpty
                                      ? null
                                      : categoryValue.text;
                                  final availableTags = getTagsForCategory(
                                    selectedCategory,
                                  );
                                  // Clear tag if it's not in the new list
                                  if (tagsC.text.isNotEmpty &&
                                      !availableTags.contains(tagsC.text)) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) tagsC.clear();
                                        });
                                  }
                                  return _buildDropdown(
                                    controller: tagsC,
                                    label: 'Etiketat e Produktit',
                                    items: availableTags,
                                    hint: selectedCategory == null
                                        ? 'Zgjedh kategori fillimisht'
                                        : 'Zgjedh etiketa',
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Stock by Sizes
                          _buildPanel(
                            title: 'Stock by Sizes',
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Stoku sipas masave',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.black87.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Totali: $totalStock',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Auto-show grid based on category/tag selection
                              SizedBox(
                                height:
                                    300, // 🔒 lartësi fikse për TË DYJA rastet
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: kind == ProductKind.shoes
                                      ? _sizesGrid()
                                      : _clothSizesGrid(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer with Save Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: const BoxDecoration(color: AppTheme.bgPage),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: saving ? null : _save,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        child: Text(
                          saving
                              ? 'Duke ruajt...'
                              : (isEdit ? 'Ruaj Ndryshimet' : 'Ruaj Produktin'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? Colors.black87 : Colors.black87.withOpacity(0.05),
            border: Border.all(
              color: selected
                  ? Colors.black87
                  : Colors.black87.withOpacity(0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizesGrid() {
    final keys = sizeCtrls.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 6 : (c.maxWidth >= 600 ? 5 : 4);
        final rows = <Widget>[];

        for (final size in keys) {
          final ctrl = sizeCtrls[size]!;
          final q = _parseInt(ctrl.text);

          rows.add(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Size number - simple
                Text(
                  '$size',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 0),
                // Quantity controls - simple: - value +
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minus button - simple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final current = _parseInt(ctrl.text);
                          if (current > 0) {
                            ctrl.text = (current - 1).toString();
                            setState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Value - simple
                    SizedBox(
                      width: 40,
                      child: Text(
                        ctrl.text.isEmpty ? '0' : ctrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Plus button - simple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final current = _parseInt(ctrl.text);
                          ctrl.text = (current + 1).toString();
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 6,
          mainAxisSpacing: 0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: rows,
        );
      },
    );
  }

  Widget _clothSizesGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 4 : (c.maxWidth >= 600 ? 3 : 2);
        final tiles = <Widget>[];

        for (final label in clothSizes) {
          final ctrl = clothCtrls[label]!;
          final q = _parseInt(ctrl.text);

          tiles.add(
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Size label - simple
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 0),
                // Quantity controls - simple: - value +
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minus button - simple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final current = _parseInt(ctrl.text);
                          if (current > 0) {
                            ctrl.text = (current - 1).toString();
                            setState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Value - simple
                    SizedBox(
                      width: 40,
                      child: Text(
                        ctrl.text.isEmpty ? '0' : ctrl.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Plus button - simple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final current = _parseInt(ctrl.text);
                          ctrl.text = (current + 1).toString();
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 6,
          mainAxisSpacing: 0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: tiles,
        );
      },
    );
  }
}
