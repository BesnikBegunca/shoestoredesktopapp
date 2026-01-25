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

/// Cart Item for display
class CartDisplayItem {
  final CartItem cartItem;
  final int index;

  CartDisplayItem(this.cartItem, this.index);
}

/// ✅ SIZE LABEL FORMATTER (same logic as ProductScreen)
String formatSizeLabel(int size) {
  switch (size) {
    case 1000:
      return '0-3M';
    case 1001:
      return '3-6M';
    case 1002:
      return '6-9M';
    case 1003:
      return '9-12M';
    case 1004:
      return '12-18M';
    case 1005:
      return '18-24M';
    case 1006:
      return '2Y';
    case 1007:
      return '3Y';
    case 1008:
      return '4Y';
    case 1009:
      return '5Y';
    case 1010:
      return '6Y';
    default:
      return size.toString(); // normal shoe sizes (36,37..)
  }
}

class MainScreen extends StatefulWidget {
  final bool readonly;
  const MainScreen({super.key, this.readonly = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final qC = TextEditingController();

  Timer? _debounce;
  bool loading = false;
  String lastQuery = '';
  List<Product> results = [];

  // Cart functionality
  List<CartItem> cart = [];
  bool checkingOut = false;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
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
        readonly: widget.readonly,
        onSold: () async {
          await _search(qC.text);
        },
        onAddToCart: (product, size) {
          // Check if item already in cart
          final existingIndex = cart.indexWhere(
            (item) => item.product.id == product.id && item.size == size,
          );
          if (existingIndex >= 0) {
            setState(() => cart[existingIndex].quantity++);
          } else {
            setState(() => cart.add(CartItem(product: product, size: size)));
          }
          Navigator.pop(context); // Close dialog
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
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Shporta (${cart.length})',
              onPressed: widget.readonly ? null : _showCartDialog,
              icon: Badge(
                label: Text(cart.length.toString()),
                child: const Icon(Icons.shopping_cart),
              ),
            ),
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
      body: Column(
        children: [
          if (widget.readonly)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'READ-ONLY MODE: License expired. You can view data but cannot make changes.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                // Sidebar for workers
                FutureBuilder<UserRole?>(
                  future: RoleStore.getSessionRole(),
                  builder: (context, snapshot) {
                    if (snapshot.data == UserRole.worker) {
                      return Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border(
                            right: BorderSide(color: AppTheme.stroke, width: 1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Punëtor',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: widget.readonly ? null : _barazohu,
                                icon: const Icon(Icons.assignment_turned_in),
                                label: const Text('Barazohu'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Main content
                Expanded(
                  child: Padding(
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
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.9,
                                      ),
                                  itemCount: results.length,
                                  itemBuilder: (_, i) =>
                                      _productCard(results[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                              ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
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
                      if (hasDisc)
                        _pill(
                          '-${p.discountPercent.toStringAsFixed(0)}%',
                          Colors.orange,
                        ),
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
      child: Text(
        t,
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (_) => _CartDialog(
        cart: cart,
        onCheckout: _checkoutCart,
        onRemoveItem: (index) {
          setState(() => cart.removeAt(index));
        },
        onUpdateQuantity: (index, qty) {
          if (qty <= 0) {
            setState(() => cart.removeAt(index));
          } else {
            setState(() => cart[index].quantity = qty);
          }
        },
      ),
    );
  }

  Future<void> _checkoutCart() async {
    if (cart.isEmpty) return;

    setState(() => checkingOut = true);
    try {
      final uid = await RoleStore.getUserId();
      if (uid <= 0) {
        throw Exception('UserId s\'osht i logum (uid=$uid). Bëj logout/login.');
      }

      final res = await LocalApi.I.sellMany(cartItems: cart, userId: uid);

      // Store cart items for receipt before clearing
      final cartItemsForReceipt = List<CartItem>.from(cart);

      // Clear cart
      setState(() => cart.clear());

      // Refresh products
      await _search(qC.text);

      if (!mounted) return;

      // Get business name for receipt
      final businessName = await LocalApi.I.getCurrentBusinessName();

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => _CheckoutSuccessDialog(
          invoiceNo: res.invoiceNo,
          total: res.total,
          cartItems: cartItemsForReceipt,
          onPrint: () async {
            final lines = buildReceiptLinesForCart(
              invoiceNo: res.invoiceNo,
              date: DateTime.now(),
              cartItems: cartItemsForReceipt,
            );

            await ReceiptPdf80mm.printOrSave(
              title: businessName,
              lines: lines,
              jobName: res.invoiceNo,
            );

            // ✅ mbyll success dialog-un + cart dialog-un
            if (dCtx.mounted) Navigator.of(dCtx).pop(); // close success
            if (context.mounted) Navigator.of(context).pop(); // close cart
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim gjatë checkout: $e')));
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  Future<void> _barazohu() async {
    try {
      final uid = await RoleStore.getUserId();
      if (uid <= 0) {
        throw Exception('UserId s\'osht i logum (uid=$uid). Bëj logout/login.');
      }

      final username = await RoleStore.getUsername();
      if (username == null) {
        throw Exception('Username nuk u gjet.');
      }

      final stats = await LocalApi.I.getWorkerStats(userId: uid, scope: 'day');

      if (stats.totalSales <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('S’ka shitje për sot.')));
        return;
      }

      final lines = <ReceiptLine>[
        ReceiptLine('DAILY SALES STATUS', '', bold: true),
        ReceiptLine('Worker', username, bold: true),
        ReceiptLine('Date', DateTime.now().toString().split(' ')[0]),
        ReceiptLine('Total Sales', '€${stats.totalSales.toStringAsFixed(2)}'),
        ReceiptLine('Number of Sales', '${stats.countSales}'),
      ];

      await ReceiptPdf80mm.printOrSave(
        title: 'DAILY STATUS',
        lines: lines,
        jobName:
            'daily-status-$username-${DateTime.now().toString().split(' ')[0]}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statusi ditor u printua ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    }
  }
}

/// ================= CART DIALOG =================

class _CartDialog extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onCheckout;
  final Function(int) onRemoveItem;
  final Function(int, int) onUpdateQuantity;

  const _CartDialog({
    required this.cart,
    required this.onCheckout,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
  });

  @override
  State<_CartDialog> createState() => _CartDialogState();
}

class _CartDialogState extends State<_CartDialog> {
  @override
  Widget build(BuildContext context) {
    final total = widget.cart.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Shporta',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.cart.isEmpty)
                const Text('Shporta është bosh.')
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final item = widget.cart[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Numri: ${formatSizeLabel(item.size)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Çmimi: €${item.unitPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: item.quantity > 1
                                        ? () => widget.onUpdateQuantity(
                                            index,
                                            item.quantity - 1,
                                          )
                                        : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => widget.onUpdateQuantity(
                                      index,
                                      item.quantity + 1,
                                    ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => widget.onRemoveItem(index),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: €${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: widget.cart.isNotEmpty
                        ? widget.onCheckout
                        : null,
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================= CHECKOUT SUCCESS DIALOG =================

class _CheckoutSuccessDialog extends StatelessWidget {
  final String invoiceNo;
  final double total;
  final List<CartItem> cartItems;
  final VoidCallback onPrint;

  const _CheckoutSuccessDialog({
    required this.invoiceNo,
    required this.total,
    required this.cartItems,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
              child: const Icon(
                Icons.check_circle,
                size: 46,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Shitja u krye me sukses ✅',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'Invoice: $invoiceNo',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Total: €${total.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                onPrint();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.print),
              label: const Text('Printo Faturen'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mbyll'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= POPUP DIALOG =================

class _ProductDialog extends StatefulWidget {
  final Product product;
  final Future<void> Function() onSold;
  final Function(Product, int) onAddToCart;
  final bool readonly;

  const _ProductDialog({
    required this.product,
    required this.onSold,
    required this.onAddToCart,
    this.readonly = false,
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: sold
                ? _successView()
                : SingleChildScrollView(
                    child: Column(
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
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: selling
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
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
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),

                        if (sizes.isEmpty)
                          Text(
                            'S’ka numra të regjistrum.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in sizes)
                                _sizeSelectChip(size: s, qty: p.qtyForSize(s)),
                            ],
                          ),

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
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Çmimi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (hasDisc)
                                      Text(
                                        '€${p.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          decoration:
                                              TextDecoration.lineThrough,
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
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (hasDisc)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.orange
                                                    .withOpacity(0.35),
                                              ),
                                            ),
                                            child: Text(
                                              '-${p.discountPercent.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedSize == null
                                          ? 'Zgjedh numrin për me shit.'
                                          : 'Numri i zgjedhun: ${formatSizeLabel(selectedSize!)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
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

                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: selling
                                        ? null
                                        : () => Navigator.pop(context),
                                    icon: const Icon(Icons.keyboard_return),
                                    label: const Text('Mbyll'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        (selling ||
                                            !p.active ||
                                            selectedSize == null ||
                                            (selectedSize != null &&
                                                p.qtyForSize(selectedSize!) <=
                                                    0))
                                        ? null
                                        : () {
                                            widget.onAddToCart(
                                              p,
                                              selectedSize!,
                                            );
                                          },
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('Shto në Shportë'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  (widget.readonly ||
                                      selling ||
                                      !p.active ||
                                      selectedSize == null ||
                                      (selectedSize != null &&
                                          p.qtyForSize(selectedSize!) <= 0))
                                  ? null
                                  : _doSell,
                              icon: selling
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.point_of_sale),
                              label: Text(
                                selling ? 'Duke shitur...' : 'Paguaj',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (!p.active)
                              ? 'Ky produkt është OFF.'
                              : (selectedSize == null)
                              ? 'Zgjedh numrin (size).'
                              : (p.qtyForSize(selectedSize!) <= 0)
                              ? 'S’ka stok për numrin ${formatSizeLabel(selectedSize!)}.'
                              : 'Kliko “BLEJ” për me e regjistru shitjen.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
          // ✅ HERE is the fix:
          '${formatSizeLabel(size)} ($qty)',
          style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
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
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
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
      // ✅ MERRE USER ID NGA LOGIN
      final uid =
          await RoleStore.getUserId(); // <- e shtojmë këtë funksion poshtë
      if (uid <= 0) {
        throw Exception('UserId s’osht i logum (uid=$uid). Bëj logout/login.');
      }

      final res = await LocalApi.I.sellOne(
        userId: uid, // ✅ JO 0
        productId: p.id,
        size: size,
      );

      await widget.onSold();

      if (!mounted) return;
      setState(() {
        sold = true;
        soldInvoice = res.invoiceNo;
        soldTotal = res.total;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('S’u shit: $e')));
      setState(() => selling = false);
    }
  }

  Widget _successView() {
    final p = widget.product;

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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),

        if (soldInvoice != null)
          Text(
            'Invoice: $soldInvoice',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),

        if (soldTotal != null)
          Text(
            'Total: €${soldTotal!.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),

        if (selectedSize != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Numri: ${formatSizeLabel(selectedSize!)}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ✅ PREVIEW (nuk mbyllet dialogu)
        FilledButton.tonalIcon(
          onPressed: () async {
            final businessName = await LocalApi.I.getCurrentBusinessName();
            final lines = buildReceiptLines(
              invoiceNo: soldInvoice ?? 'INV-TEST',
              date: DateTime.now(),
              productName: p.name,
              qty: 1,
              size: selectedSize,
              unitPriceFinal: p.finalPrice,
              totalFinal: soldTotal ?? p.finalPrice,
              unitPriceOriginal: p.price,
              discountPercent: p.discountPercent,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReceiptPreview(
                  title: businessName,
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
            final businessName = await LocalApi.I.getCurrentBusinessName();
            final lines = buildReceiptLines(
              invoiceNo: soldInvoice ?? 'INV-TEST',
              date: DateTime.now(),
              productName: p.name,
              qty: 1,
              size: selectedSize,
              unitPriceFinal: p.finalPrice,
              totalFinal: soldTotal ?? p.finalPrice,
              unitPriceOriginal: p.price,
              discountPercent: p.discountPercent,
            );

            await ReceiptPdf80mm.printOrSave(
              title: businessName,
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
