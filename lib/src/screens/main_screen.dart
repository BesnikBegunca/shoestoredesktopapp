// main_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/printing/receipt_builder.dart';
import 'package:shoe_store_manager/printing/receipt_pdf_80mm.dart';
import 'package:shoe_store_manager/printing/receipt_preview.dart';
import 'package:shoe_store_manager/src/screens/login_screen.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final qC = TextEditingController();

  Timer? _debounce;
  bool loading = false;
  String lastQuery = '';
  List<Product> results = [];

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

  // ✅ key 1000.. => label, ndryshe => numri i patikave
  String _labelForSizeKey(int key) {
    if (key >= 1000) {
      final idx = key - 1000;
      if (idx >= 0 && idx < _clothLabels.length) return _clothLabels[idx];
    }
    return key.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    qC.dispose();
    super.dispose();
  }

  bool _hasValidImage(String? path) {
    if (path == null) return false;
    final t = path.trim();
    if (t.isEmpty) return false;
    return File(t).existsSync();
  }

  Widget _photoBox(Product p) {
    final path = p.imagePath?.trim();
    final ok = _hasValidImage(path);

    if (ok) {
      return Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(
            Icons.broken_image,
            size: 58,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 58,
        color: Colors.black.withOpacity(0.35),
      ),
    );
  }

  Future<void> _loadRecent() async {
    setState(() => loading = true);
    try {
      final list = await LocalApi.I.getProducts(orderBy: 'createdAtMs DESC');
      if (!mounted) return;
      setState(() {
        results = list.take(30).toList();
        lastQuery = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search(v);
    });
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      _loadRecent();
      return;
    }
    if (query == lastQuery) return;

    setState(() {
      loading = true;
      lastQuery = query;
    });

    try {
      final list = await LocalApi.I.searchProductsBySerialOrName(query);
      if (!mounted) return;
      setState(() => results = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openProductDialog(Product p) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ProductDialog(
        product: p,
        onSold: () async {
          await _search(qC.text);
        },
        // ✅ i kalojmë mapper-in te dialogu
        labelForSizeKey: _labelForSizeKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        foregroundColor: AppTheme.text,
        title: const Text('Shitja', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _search(qC.text),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await RoleStore.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _searchBox(),
            const SizedBox(height: 10),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                  ? const Center(child: Text('S’ka rezultate.', style: TextStyle(color: AppTheme.text)))
                  : GridView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: results.length,
                itemBuilder: (_, i) => _productCard(results[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.text),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: qC,
                style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800),
                onChanged: (v) {
                  _onQueryChanged(v);
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Kërko me serial / SKU / emër...',
                  hintStyle: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (qC.text.isNotEmpty)
              IconButton(
                tooltip: 'Pastro',
                onPressed: () {
                  qC.clear();
                  _loadRecent();
                  setState(() {});
                },
                icon: const Icon(Icons.close, color: AppTheme.text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Product p) {
    final hasDisc = p.discountPercent > 0;
    final fp = p.finalPrice;

    final stockColor = p.stockQty > 0 ? Colors.green : Colors.red;
    final activeColor = p.active ? Colors.green : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openProductDialog(p),
      child: Card(
        color: AppTheme.surface,
        elevation: 1.2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.06)),
              child: Stack(
                children: [
                  Positioned.fill(child: _photoBox(p)),
                  if (hasDisc)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.90),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-${p.discountPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.serialNumber ?? p.sku ?? '—',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasDisc)
                            Text(
                              '€${p.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          Text(
                            '€${fp.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Stok: ${p.stockQty}', stockColor),
                      _pill(p.active ? 'Active' : 'OFF', activeColor),
                      if (hasDisc) _pill('-${p.discountPercent.toStringAsFixed(0)}%', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kliko për detaje',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

/// ================= POPUP DIALOG =================

class _ProductDialog extends StatefulWidget {
  final Product product;
  final Future<void> Function() onSold;

  // ✅ mapper që e kthen key -> label (p.sh 1000 -> 0-3M)
  final String Function(int key) labelForSizeKey;

  const _ProductDialog({
    required this.product,
    required this.onSold,
    required this.labelForSizeKey,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  bool selling = false;
  bool sold = false;
  String? soldInvoice;
  double? soldTotal;

  int? selectedSize;

  @override
  void initState() {
    super.initState();
    // auto select first available size
    final sizes = widget.product.sizesSorted;
    for (final s in sizes) {
      if (widget.product.qtyForSize(s) > 0) {
        selectedSize = s;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasDisc = p.discountPercent > 0;
    final fp = p.finalPrice;

    final sizes = p.sizesSorted;

    final selectedLabel = selectedSize == null ? null : widget.labelForSizeKey(selectedSize!);

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: sold
                ? _successView()
                : Column(
              key: const ValueKey('details'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: selling ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppTheme.text),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _metaRow('Serial', p.serialNumber ?? '—'),
                _metaRow('SKU', p.sku ?? '—'),
                _metaRow('Status', p.active ? 'Active' : 'OFF'),
                _metaRow('Total', '${p.stockQty}'),
                const SizedBox(height: 12),
                const Text(
                  'Numrat / Stoku',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.text),
                ),
                const SizedBox(height: 8),
                if (sizes.isEmpty)
                  const Text(
                    'S’ka numra të regjistrum.',
                    style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in sizes)
                        _sizeSelectChip(
                          size: s,
                          qty: p.qtyForSize(s),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.stroke),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppTheme.surface2.withOpacity(0.35),
                          border: Border.all(color: AppTheme.stroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Çmimi', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.text)),
                            const SizedBox(height: 8),
                            if (hasDisc)
                              Text(
                                '€${p.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Row(
                              children: [
                                Text(
                                  '€${fp.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.text,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (hasDisc)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.orange.withOpacity(0.35)),
                                    ),
                                    child: Text(
                                      '-${p.discountPercent.toStringAsFixed(0)}%',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.text),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedLabel == null
                                  ? 'Zgjedh masën për me shit.'
                                  : 'Masa e zgjedhun: $selectedLabel',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selling ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_return),
                        label: const Text('Mbyll'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: (selling ||
                            !p.active ||
                            selectedSize == null ||
                            (selectedSize != null && p.qtyForSize(selectedSize!) <= 0))
                            ? null
                            : _doSell,
                        icon: selling
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.point_of_sale),
                        label: Text(selling ? 'Duke shitur...' : 'Paguaj'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (!p.active)
                      ? 'Ky produkt është OFF.'
                      : (selectedSize == null)
                      ? 'Zgjedh masën (size).'
                      : (p.qtyForSize(selectedSize!) <= 0)
                      ? 'S’ka stok për masën ${widget.labelForSizeKey(selectedSize!)}.'
                      : 'Kliko “Paguaj” për me e regjistru shitjen.',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeSelectChip({required int size, required int qty}) {
    final ok = qty > 0;
    final c = ok ? Colors.green : Colors.red;
    final selected = selectedSize == size;

    final label = widget.labelForSizeKey(size); // ✅ 0-3M / 3-6M / 17 / 18...

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: ok ? () => setState(() => selectedSize = size) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.22) : c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? c.withOpacity(0.75) : c.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          '$label ($qty)', // ✅ s’del ma 1000
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              k,
              style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.text),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doSell() async {
    final p = widget.product;
    final size = selectedSize;
    if (size == null) return;

    setState(() => selling = true);
    try {
      final res = await LocalApi.I.sellOne(productId: p.id, size: size);

      await widget.onSold();

      if (!mounted) return;
      setState(() {
        sold = true;
        soldInvoice = res.invoiceNo;
        soldTotal = res.total;
      });

      // ✅ MOS e mbyll automatikisht.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('S’u shit: $e')));
      setState(() => selling = false);
    }
  }

  Widget _successView() {
    final p = widget.product;
    final sizeLabel = selectedSize == null ? null : widget.labelForSizeKey(selectedSize!);

    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.12),
            border: Border.all(color: Colors.green.withOpacity(0.35)),
          ),
          child: const Icon(Icons.check_circle, size: 46, color: Colors.green),
        ),
        const SizedBox(height: 14),
        const Text(
          'U shit me sukses ✅',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.text),
        ),
        const SizedBox(height: 10),
        if (soldInvoice != null)
          Text(
            'Invoice: $soldInvoice',
            style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
          ),
        if (soldTotal != null)
          Text(
            'Total: €${soldTotal!.toStringAsFixed(2)}',
            style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
          ),
        if (sizeLabel != null)
          Text(
            'Masa: $sizeLabel',
            style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
          ),
        const SizedBox(height: 12),

        // ✅ PREVIEW (nuk mbyllet dialogu)
        FilledButton.tonalIcon(
          onPressed: () {
            // NOTE:
            // Nëse buildReceiptLines e pranon "sizeLabel", përdore.
            // Nëse jo, e lë "size: selectedSize" si int.
            final lines = buildReceiptLines(
              invoiceNo: soldInvoice ?? 'INV-TEST',
              date: DateTime.now(),
              productName: p.name,
              qty: 1,
              size: selectedSize, // keep int for DB logic
              // sizeLabel: sizeLabel, // ✅ nëse e ke në receipt_builder, çoje këtë
              unitPriceFinal: p.finalPrice,
              totalFinal: soldTotal ?? p.finalPrice,
              unitPriceOriginal: p.price,
              discountPercent: p.discountPercent,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReceiptPreview(
                  title: 'SHOESTORE',
                  lines: lines,
                  widthMm: 80,
                ),
              ),
            );
          },
          icon: const Icon(Icons.receipt_long),
          label: const Text('Preview Fatura'),
        ),

        const SizedBox(height: 10),

        // ✅ PRINT (PDF 80mm) + pastaj e mbyll dialogun
        FilledButton.icon(
          onPressed: () async {
            final lines = buildReceiptLines(
              invoiceNo: soldInvoice ?? 'INV-TEST',
              date: DateTime.now(),
              productName: p.name,
              qty: 1,
              size: selectedSize,
              // sizeLabel: sizeLabel, // ✅ nëse e ke në receipt_builder, çoje këtë
              unitPriceFinal: p.finalPrice,
              totalFinal: soldTotal ?? p.finalPrice,
              unitPriceOriginal: p.price,
              discountPercent: p.discountPercent,
            );

            await ReceiptPdf80mm.printOrSave(
              title: 'SHOESTORE',
              lines: lines,
              jobName: soldInvoice ?? 'receipt',
            );

            if (mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.print),
          label: const Text('PRINTO FATUREN'),
        ),

        const SizedBox(height: 10),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mbyll'),
        ),
      ],
    );
  }
}
