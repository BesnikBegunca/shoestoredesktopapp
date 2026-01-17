import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../local/local_api.dart';

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
          child: Icon(Icons.broken_image, size: 58, color: Colors.black.withOpacity(0.35)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shitja'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _search(qC.text),
            icon: const Icon(Icons.refresh),
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
                  ? const Center(child: Text('S’ka rezultate.'))
                  : GridView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
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
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: qC,
                onChanged: (v) {
                  _onQueryChanged(v);
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Kërko me serial / SKU / emër...',
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
                icon: const Icon(Icons.close),
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
        elevation: 1.2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== PHOTO (big) =====
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _photoBox(p)), // ✅ REAL PHOTO

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
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ===== ATTRIBUTES (below) =====
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
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.serialNumber ?? p.sku ?? '—',
                              style: TextStyle(
                                color: Colors.grey.shade700,
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
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          Text(
                            '€${fp.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
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

                  Text(
                    'Kliko për detaje',
                    style: TextStyle(
                      color: Colors.grey.shade600,
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
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

/// ================= POPUP DIALOG =================

class _ProductDialog extends StatefulWidget {
  final Product product;
  final Future<void> Function() onSold;

  const _ProductDialog({
    required this.product,
    required this.onSold,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  bool selling = false;
  bool sold = false;
  String? soldInvoice;
  double? soldTotal;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasDisc = p.discountPercent > 0;
    final fp = p.finalPrice;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: selling ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _metaRow('Serial', p.serialNumber ?? '—'),
                _metaRow('SKU', p.sku ?? '—'),
                _metaRow('Status', p.active ? 'Active' : 'OFF'),
                _metaRow('Stok', '${p.stockQty}'),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.black.withOpacity(0.04),
                          border: Border.all(color: Colors.black.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Çmimi', style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            if (hasDisc)
                              Text(
                                '€${p.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Row(
                              children: [
                                Text(
                                  '€${fp.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                              ],
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
                        onPressed: (selling || !p.active || p.stockQty <= 0) ? null : _doSell,
                        icon: selling
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.point_of_sale),
                        label: Text(selling ? 'Duke shitur...' : 'BLEJ / SHIT 1'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (!p.active)
                      ? 'Ky produkt është OFF.'
                      : (p.stockQty <= 0)
                      ? 'S’ka stok për këtë produkt.'
                      : 'Kliko “BLEJ” për me e regjistru shitjen.',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                ),
              ],
            ),
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
            child: Text(k, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Future<void> _doSell() async {
    setState(() => selling = true);
    try {
      final res = await LocalApi.I.sellOne(productId: widget.product.id);

      await widget.onSold();

      if (!mounted) return;
      setState(() {
        sold = true;
        soldInvoice = res.invoiceNo;
        soldTotal = res.total;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('S’u shit: $e')));
      setState(() => selling = false);
    }
  }

  Widget _successView() {
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
        const Text('U shit me sukses ✅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (soldInvoice != null)
          Text('Invoice: $soldInvoice', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
        if (soldTotal != null)
          Text('Total: €${soldTotal!.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        const Text('Duke u mbyllur...', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
      ],
    );
  }
}
