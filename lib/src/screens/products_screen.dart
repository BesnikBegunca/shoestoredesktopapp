import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  final bool readonly;
  const ProductsScreen({super.key, this.readonly = false});

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
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(path!),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderThumb(),
        ),
      );
    }
    return _placeholderThumb();
  }

  Widget _placeholderThumb() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
          ],
        ),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.black87.withOpacity(0.4),
        size: 28,
      ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openStockDialog(Product product) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StockBySizeDialog(product: product),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    // Konfirmimi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fshi Produktin'),
        content: Text('A jeni të sigurt që dëshironi të fshini "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await LocalApi.I.deleteProduct(product.id);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produkti "${product.name}" u fshi me sukses'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload list
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gabim në fshirje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openRegistrationMethodDialog() async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Zgjedh mënyrën e regjistrimit',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              // Skanim Barcode Option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _openBarcodeScanForm();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black87.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black87.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.black87,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Skanim Barcode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Regjistro produktin duke skanuar barcode',
                                style: TextStyle(
                                  color: Colors.black87.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black87,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Regjistrim Manual Option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _openForm();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black87.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black87.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: Colors.black87,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Regjistrim Manual',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Regjistro produktin manualisht',
                                style: TextStyle(
                                  color: Colors.black87.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black87,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Anulo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBarcodeScanForm() async {
    final barcodeController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Skano Barcode',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: barcodeController,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Barcode / SKU / Serial Number',
                  labelStyle: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'Skano ose shkruaj barcode',
                  hintStyle: TextStyle(
                    color: Colors.black87.withOpacity(0.4),
                  ),
                  prefixIcon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.black87,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black87.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black87.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.black87,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (value) async {
                  if (value.trim().isNotEmpty) {
                    Navigator.pop(context);
                    await _handleBarcodeScan(value.trim());
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Anulo',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () async {
                        final barcode = barcodeController.text.trim();
                        if (barcode.isEmpty) return;
                        Navigator.pop(context);
                        await _handleBarcodeScan(barcode);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: const Text(
                          'Vazhdo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    barcodeController.dispose();
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    try {
      // Kërko produktin me këtë barcode/SKU/Serial
      final products = await LocalApi.I.getProducts();
      Product? foundProduct;
      
      for (final product in products) {
        if (product.sku?.toLowerCase() == barcode.toLowerCase() ||
            product.serialNumber?.toLowerCase() == barcode.toLowerCase()) {
          foundProduct = product;
          break;
        }
      }

      if (foundProduct != null) {
        // Produkti ekziston, hape për editim
        await _openForm(editing: foundProduct);
      } else {
        // Produkti nuk ekziston, hape formë të re me barcode të plotësuar
        await _openFormWithBarcode(barcode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim: $e')),
      );
    }
  }

  Future<void> _openFormWithBarcode(String barcode) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(
        editing: null,
        prefillBarcode: barcode,
      ),
    );
    if (res == true) _load();
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
        title: const Text(
          'Fshij produktin?',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'A je i sigurt me fshi "${p0.name}"?',
          style: const TextStyle(color: AppTheme.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fshije'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await LocalApi.I.deleteProduct(p0.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produkti u fshi.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  Future<void> _toggleActive(Product p0) async {
    try {
      await LocalApi.I.toggleActive(p0.id, !p0.active);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            // Header - Identik me Shtija Ditore
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/regjistrimi_mallit.svg',
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
                          'Stoku/Produktet',
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
            // Body Content
            Expanded(
              child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'S’ka produkte ende.',
                style: TextStyle(color: AppTheme.text),
              ),
            )
          : Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _tableHeader('Produkti'),
                        ),
                        Expanded(
                          flex: 2,
                          child: _tableHeader('Barcode'),
                        ),
                        Expanded(
                          flex: 1,
                          child: _tableHeader('Çmimi'),
                        ),
                        Expanded(
                          flex: 1,
                          child: _tableHeader('Sasia'),
                        ),
                        const SizedBox(width: 100), // Space for Shto and delete buttons
                      ],
                    ),
                  ),
                  // Table Rows
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.withOpacity(0.15),
                      ),
                      itemBuilder: (_, i) {
                        final p0 = _items[i];
                        final hasDisc = p0.discountPercent > 0;
                        return _tableRow(p0, hasDisc);
                      },
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in sizes) _sizeChip(_labelForSizeKey(s), p0.qtyForSize(s)),
      ],
    );
  }

  Widget _sizeChip(String label, int qty) {
    final ok = qty > 0;
    final c = ok ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: c.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$qty',
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w400,
        color: Colors.black87,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _tableRow(Product p0, bool hasDisc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Produkti
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p0.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          // Barcode
          Expanded(
            flex: 2,
            child: Text(
              p0.serialNumber ?? p0.sku ?? '—',
              style: TextStyle(
                color: Colors.black87.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // Çmimi
          Expanded(
            flex: 1,
            child: Text(
              '€${p0.finalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
          // Sasia (vetëm shfaqje)
          Expanded(
            flex: 1,
            child: Text(
              '${p0.stockQty}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
          // Shto Button
          if (!widget.readonly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _openStockDialog(p0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Shto',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Delete Button
          SizedBox(
            width: 60,
            child: IconButton(
              onPressed: widget.readonly ? null : () => _deleteProduct(p0),
              icon: Icon(
                Icons.delete_outline,
                color: widget.readonly ? Colors.grey : Colors.red.shade700,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============================
// ✅ DIALOG: STOCK BY SIZE
// ============================

class _StockBySizeDialog extends StatefulWidget {
  final Product product;
  const _StockBySizeDialog({required this.product});

  @override
  State<_StockBySizeDialog> createState() => _StockBySizeDialogState();
}

class _StockBySizeDialogState extends State<_StockBySizeDialog> {
  // shoes
  late Map<int, TextEditingController> sizeCtrls;

  // clothes
  late Map<String, TextEditingController> clothCtrls;

  ProductKind kind = ProductKind.shoes;
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
    final p0 = widget.product;
    final existing = p0.sizeStock;

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
    for (final c in sizeCtrls.values) {
      c.dispose();
    }
    for (final c in clothCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

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

  Future<void> _save() async {
    if (saving) return;

    final sizeStock = _collectSizeStock();

    // Validate negatives
    if (kind == ProductKind.shoes) {
      for (final e in sizeCtrls.entries) {
        final q = _parseInt(e.value.text);
        if (q < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Numri ${e.key}: sasia s\'mund me qenë negative.')),
          );
          return;
        }
      }
    } else {
      for (final label in clothSizes) {
        final q = _parseInt(clothCtrls[label]!.text);
        if (q < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Masa $label: sasia s\'mund me qenë negative.')),
          );
          return;
        }
      }
    }

    setState(() => saving = true);
    try {
      final p0 = widget.product;
      await LocalApi.I.updateProduct(
        id: p0.id,
        name: p0.name,
        sku: p0.sku,
        serialNumber: p0.serialNumber,
        price: p0.price,
        purchasePrice: p0.purchasePrice,
        discountPercent: p0.discountPercent,
        active: p0.active,
        imagePath: p0.imagePath,
        sizeStock: sizeStock,
        category: p0.category,
        subcategory: p0.subcategory,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim: $e')),
      );
    }
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
              color: selected ? Colors.black87 : Colors.black87.withOpacity(0.2),
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
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
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
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
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
          physics: const AlwaysScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: tiles,
        );
      },
    );
  }

  Widget _totalPill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black87.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeStockPreview = _collectSizeStock();
    final totalStock = _totalStock(sizeStockPreview);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stoku sipas masave - ${widget.product.name}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 600),
              child: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (kind == ProductKind.shoes)
                      _sizesGrid()
                    else
                      SizedBox(
                        height: 300,
                        child: _clothSizesGrid(),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Anulo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                saving ? 'Duke ruajt...' : 'Ruaj',
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
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
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
  final String? prefillBarcode;
  const _ProductFormDialog({required this.editing, this.prefillBarcode});

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
    skuC = TextEditingController(text: p0?.sku ?? widget.prefillBarcode ?? '');
    serialC = TextEditingController(text: p0?.serialNumber ?? widget.prefillBarcode ?? '');
    priceC = TextEditingController(text: p0 == null ? '' : p0.price.toString());
    purchaseC = TextEditingController(
      text: p0?.purchasePrice?.toString() ?? '',
    );
    discountC = TextEditingController(
      text: p0?.discountPercent.toString() ?? '0',
    );
    imagePathC = TextEditingController(text: p0?.imagePath ?? '');
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
      if (old.isNotEmpty &&
          _looksLikeInsideAppImages(old) &&
          old != storedPath) {
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
    final purchase = purchaseC.text.trim().isEmpty
        ? null
        : _parseDouble(purchaseC.text);
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
        if (old.isNotEmpty &&
            old != (finalImg ?? '') &&
            _looksLikeInsideAppImages(old)) {
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Ndrysho produkt' : 'Shto produkt',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 680,
              height: 600,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameC,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Emri i produktit',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: 'p.sh. Nike Air Max',
                          hintStyle: TextStyle(
                            color: Colors.black87.withOpacity(0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Shkruje emrin.' : null,
                      ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: skuC,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'SKU (opsionale)',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: serialC,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nr. Serik (opsionale, UNIQUE)',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
                        ),
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
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Çmimi i shitjes (€)',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: purchaseC,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Çmimi i blerjes (€) (ops.)',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: discountC,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Zbritja (%)',
                    labelStyle: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black87.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black87.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.black87,
                        width: 2,
                      ),
                    ),
                  ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              fontSize: 17,
                            ),
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
                            onTap: () =>
                                setState(() => kind = ProductKind.shoes),
                          ),
                          _kindBtn(
                            label: 'TESHA',
                            selected: kind == ProductKind.clothes,
                            onTap: () =>
                                setState(() => kind = ProductKind.clothes),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (kind == ProductKind.shoes)
                  _sizesGrid()
                else
                  SizedBox(
                    height: 300,
                    child: _clothSizesGrid(),
                  ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: imagePathC,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Foto (ruhet automatikisht në app)',
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: r'C:\...\foto.png',
                          hintStyle: TextStyle(
                            color: Colors.black87.withOpacity(0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black87.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black87,
                              width: 2,
                            ),
                          ),
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
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  )
                else if (imgPath.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '⚠️ Foto s’u gjet në këtë path.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Active',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving ? null : () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Anulo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                  saving ? 'Duke ruajt...' : (isEdit ? 'Ruaj' : 'Shto'),
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
                    ],
                  ),
                ),
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
              color: selected ? Colors.black87 : Colors.black87.withOpacity(0.2),
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
        final cols = c.maxWidth >= 620 ? 6 : 4;
        final rows = <Widget>[];

        for (final size in keys) {
          final ctrl = sizeCtrls[size]!;
          final q = _parseInt(ctrl.text);
          final ok = q > 0;
          final color = ok ? Colors.green : Colors.red;

          rows.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ok ? Colors.black87.withOpacity(0.2) : Colors.black87.withOpacity(0.1),
                  width: 1,
                ),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: ok ? Colors.black87.withOpacity(0.05) : Colors.black87.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$size',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.black87.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.black87.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.black87,
                            width: 2,
                          ),
                        ),
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: Colors.black87.withOpacity(0.4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ok ? Colors.black87.withOpacity(0.2) : Colors.black87.withOpacity(0.1),
                  width: 1,
                ),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: ok ? Colors.black87.withOpacity(0.05) : Colors.black87.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.black87.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.black87.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.black87,
                            width: 2,
                          ),
                        ),
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: Colors.black87.withOpacity(0.4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
          shrinkWrap: false,
          physics: const AlwaysScrollableScrollPhysics(),
          children: tiles,
        );
      },
    );
  }

  Widget _totalPill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black87.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}
