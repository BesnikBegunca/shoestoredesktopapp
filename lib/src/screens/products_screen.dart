import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // ✅ add this
import '../local/local_api.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _loading = true;
  List<Product> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij produktin?'),
        content: Text('A je i sigurt me fshi "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fshije'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await LocalApi.I.deleteProduct(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produkti u fshi.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  Future<void> _toggleActive(Product p) async {
    try {
      await LocalApi.I.toggleActive(p.id, !p.active);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produktet'),
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
          ? const Center(child: Text('S’ka produkte ende.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = _items[i];
          final hasDisc = p.discountPercent > 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black12,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          p.serialNumber ?? p.sku ?? '—',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _pill('Stok: ${p.stockQty}', p.stockQty > 0 ? Colors.green : Colors.red),
                            _pill(p.active ? 'Active' : 'OFF', p.active ? Colors.green : Colors.grey),
                            if (hasDisc) _pill('-${p.discountPercent.toStringAsFixed(0)}%', Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasDisc)
                        Text(
                          '€${p.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        '€${p.finalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Active',
                            onPressed: () => _toggleActive(p),
                            icon: Icon(p.active ? Icons.toggle_on : Icons.toggle_off),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _openForm(editing: p),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(p),
                            icon: const Icon(Icons.delete_outline),
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
  late final TextEditingController stockC;
  late final TextEditingController discountC;
  late final TextEditingController imagePathC;

  bool active = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    nameC = TextEditingController(text: p?.name ?? '');
    skuC = TextEditingController(text: p?.sku ?? '');
    serialC = TextEditingController(text: p?.serialNumber ?? '');
    priceC = TextEditingController(text: p == null ? '' : p.price.toString());
    purchaseC = TextEditingController(text: p?.purchasePrice?.toString() ?? '');
    stockC = TextEditingController(text: p?.stockQty.toString() ?? '0');
    discountC = TextEditingController(text: p?.discountPercent.toString() ?? '0');
    imagePathC = TextEditingController(text: p?.imagePath ?? '');
    active = p?.active ?? true;
  }

  @override
  void dispose() {
    nameC.dispose();
    skuC.dispose();
    serialC.dispose();
    priceC.dispose();
    purchaseC.dispose();
    stockC.dispose();
    discountC.dispose();
    imagePathC.dispose();
    super.dispose();
  }

  double _parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ✅ OPEN FILE PICKER (desktop window + mobile gallery chooser)
  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Zgjedh foton e produktit',
      );
      if (res == null) return;
      final path = res.files.single.path;
      if (path == null || path.isEmpty) return;

      setState(() {
        imagePathC.text = path;
      });
    } catch (e) {
      _snack('S’u hap file picker: $e');
    }
  }

  bool _isValidImagePath(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    final f = File(path);
    return f.existsSync();
  }

  Future<void> _save() async {
    if (saving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = nameC.text.trim();
    final sku = skuC.text.trim().isEmpty ? null : skuC.text.trim();
    final serial = serialC.text.trim().isEmpty ? null : serialC.text.trim();
    final price = _parseDouble(priceC.text);
    final purchase = purchaseC.text.trim().isEmpty ? null : _parseDouble(purchaseC.text);
    final stock = _parseInt(stockC.text);
    final disc = _parseDouble(discountC.text);

    // ✅ store as NULL if empty
    final imgRaw = imagePathC.text.trim();
    final img = imgRaw.isEmpty ? null : imgRaw;

    if (price <= 0) {
      _snack('Çmimi duhet > 0.');
      return;
    }
    if (stock < 0) {
      _snack('Stoku s’mund me qenë negativ.');
      return;
    }
    if (disc < 0 || disc > 100) {
      _snack('Zbritja duhet 0–100.');
      return;
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
          stockQty: stock,
          discountPercent: disc,
          active: active,
          imagePath: img,
        );
      } else {
        await LocalApi.I.updateProduct(
          id: editing.id,
          name: name,
          sku: sku,
          serialNumber: serial,
          price: price,
          purchasePrice: purchase,
          stockQty: stock,
          discountPercent: disc,
          active: active,
          imagePath: img,
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

    return AlertDialog(
      title: Text(isEdit ? 'Ndrysho produkt' : 'Shto produkt'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Emri i produktit'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Shkruje emrin.' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: skuC,
                        decoration: const InputDecoration(labelText: 'SKU (opsionale)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: serialC,
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Çmimi i shitjes (€)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: purchaseC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Çmimi i blerjes (€) (ops.)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stockC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stoku (copë)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: discountC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Zbritja (%)'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ ImagePath + Choose file button + preview
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: imagePathC,
                        decoration: const InputDecoration(
                          labelText: 'Foto (ImagePath) (opsionale)',
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
                        color: Colors.black12,
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
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700),
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Active', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Switch(value: active, onChanged: (v) => setState(() => active = v)),
                  ],
                ),
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final price = _parseDouble(priceC.text);
                  final disc = _parseDouble(discountC.text);
                  final fp = calcFinalPrice(price: price, discountPercent: disc);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preview: ${disc.toStringAsFixed(0)}% → Final €${fp.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                    ),
                  );
                }),
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
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Duke ruajt...' : (isEdit ? 'Ruaj' : 'Shto')),
        ),
      ],
    );
  }
}
