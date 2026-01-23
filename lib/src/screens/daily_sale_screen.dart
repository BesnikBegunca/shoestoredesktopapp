// daily_sale_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/printing/receipt_builder.dart';
import 'package:shoe_store_manager/printing/receipt_pdf_80mm.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

class DailySaleScreen extends StatefulWidget {
  const DailySaleScreen({super.key});

  @override
  State<DailySaleScreen> createState() => _DailySaleScreenState();
}

class _DailySaleScreenState extends State<DailySaleScreen> {
  final barcodeController = TextEditingController();
  final amountController = TextEditingController();
  final amountFocus = FocusNode();
  final scrollController = ScrollController();
  List<CartItem> cart = [];
  bool processing = false;
  bool checkingOut = false;

  @override
  void dispose() {
    barcodeController.dispose();
    amountController.dispose();
    amountFocus.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    if (barcode.trim().isEmpty) return;

    setState(() => processing = true);
    try {
      // ✅ NEW: Kërko variante me këtë barcode
      final variants = await LocalApi.I.getVariantsByBarcode(barcode);
      
      if (variants.isEmpty) {
        // ✅ Fallback: Kërko produktin me këtë barcode/SKU/Serial (legacy)
        final products = await LocalApi.I.getProducts();
        Product? foundProduct;

        for (final product in products) {
          if (product.sku?.toLowerCase() == barcode.toLowerCase() ||
              product.serialNumber?.toLowerCase() == barcode.toLowerCase()) {
            foundProduct = product;
            break;
          }
        }

        if (foundProduct == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkti nuk u gjet me këtë barcode'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Legacy: Shto produktin në shportë
        final product = foundProduct!;
        final existingIndex = cart.indexWhere(
          (item) => item.product.id == product.id && item.size == 0 && !item.isVariant,
        );

        if (existingIndex >= 0) {
          setState(() => cart[existingIndex].quantity++);
        } else {
          setState(() => cart.add(CartItem(product: product, size: 0)));
        }
      } else if (variants.length == 1) {
        // ✅ Vetëm 1 variant -> shtoje direkt
        final variant = variants.first;
        final product = await LocalApi.I.getProductByVariantId(variant.id);
        if (product == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkti për këtë variant nuk u gjet'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Kontrollo stokun
        if (variant.quantity <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("S'ka stok për ${variant.size}"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Shto në cart
        final sizeInt = int.tryParse(variant.size) ?? 0;
        final existingIndex = cart.indexWhere(
          (item) => item.isVariant && item.variantId == variant.id,
        );

        if (existingIndex >= 0) {
          // Kontrollo stokun para se të rritesh sasinë
          if (cart[existingIndex].quantity >= variant.quantity) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stoku maksimal për ${variant.size} është ${variant.quantity}'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          setState(() => cart[existingIndex].quantity++);
        } else {
          setState(() => cart.add(CartItem(
            product: product,
            size: sizeInt,
            variantId: variant.id,
            variantSku: variant.sku,
            variantSize: variant.size,
          )));
        }
      } else {
        // ✅ Më shumë se 1 variant -> shfaq zgjedhje mase
        if (!mounted) return;
        final selectedSize = await _showSizeSelector(variants);
        if (selectedSize == null) return; // User anuloi

        final variant = variants.firstWhere((v) => v.size == selectedSize);
        final product = await LocalApi.I.getProductByVariantId(variant.id);
        if (product == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produkti për këtë variant nuk u gjet'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Kontrollo stokun
        if (variant.quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("S'ka stok për ${variant.size}"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Shto në cart
        final sizeInt = int.tryParse(variant.size) ?? 0;
        final existingIndex = cart.indexWhere(
          (item) => item.isVariant && item.variantId == variant.id,
        );

        if (existingIndex >= 0) {
          if (cart[existingIndex].quantity >= variant.quantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stoku maksimal për ${variant.size} është ${variant.quantity}'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          setState(() => cart[existingIndex].quantity++);
        } else {
          setState(() => cart.add(CartItem(
            product: product,
            size: sizeInt,
            variantId: variant.id,
            variantSku: variant.sku,
            variantSize: variant.size,
          )));
        }
      }

      // Pastro barcode field dhe fokusohu përsëri
      barcodeController.clear();
      FocusScope.of(context).requestFocus(FocusNode());
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim: $e')),
      );
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  // ✅ NEW: Shfaq dialog për zgjedhje mase
  Future<String?> _showSizeSelector(List<ProductVariant> variants) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Zgjedh Masa',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 550,
            maxWidth: 650,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: variants.map((v) {
                final hasStock = v.quantity > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: hasStock 
                        ? Colors.white 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasStock 
                          ? Colors.grey.shade300 
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      'Masa: ${v.size}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: hasStock ? Colors.black : Colors.grey.shade600,
                      ),
                    ),
                    subtitle: Text(
                      hasStock ? 'Stoku: ${v.quantity}' : "S'ka stok",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasStock ? Colors.grey.shade700 : Colors.red,
                      ),
                    ),
                    trailing: hasStock
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          )
                        : Icon(
                            Icons.cancel,
                            color: Colors.red.shade400,
                            size: 28,
                          ),
                    enabled: hasStock,
                    onTap: hasStock ? () => Navigator.pop(ctx, v.size) : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Anulo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => cart.removeAt(index));
  }

  Future<void> _updateQuantity(int index, int quantity) async {
    if (quantity <= 0) {
      _removeItem(index);
      return;
    }

    final item = cart[index];
    
    // ✅ NEW: Nëse është variant, kontrollo stokun e variantit
    if (item.isVariant && item.variantId != null) {
      try {
        final variant = await LocalApi.I.getVariantById(item.variantId!);
        if (variant == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Varianti nuk u gjet'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (quantity > variant.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stoku maksimal për ${item.variantSize ?? item.variantSku} është ${variant.quantity}'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() => cart[index].quantity = quantity);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gabim: $e')),
        );
      }
    } else {
      // Legacy: kontrollo sizeStock
      final map = Map<int, int>.from(item.product.sizeStock);
      final q = map[item.size] ?? 0;
      if (quantity > q) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stoku maksimal për numrin ${item.size} është $q'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() => cart[index].quantity = quantity);
    }
  }


  Future<void> _confirmPayment() async {
    final total = cart.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    final amountGiven = double.tryParse(amountController.text) ?? 0.0;
    if (amountGiven < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shuma e dhënë është më e vogël se totali'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _processPayment(amountGiven, amountGiven - total);
  }

  // ✅ OLD: _showPaymentDialog - ruajtur për referencë (mund të fshihet më vonë)
  Future<void> _showPaymentDialog_OLD() async {
    final total = cart.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    final amountController = TextEditingController();
    final amountFocus = FocusNode();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final amountGiven = double.tryParse(amountController.text) ?? 0.0;
              final change = amountGiven - total;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Pagesa',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Total Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Totali:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '€${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Amount Input
                  TextField(
                    controller: amountController,
                    focusNode: amountFocus,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Para të dhëna',
                      labelStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: Colors.black87.withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black87.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black87,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppTheme.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) {
                      if (amountGiven >= total) {
                        _processPayment(amountGiven, change);
                      }
                    },
                  ),
                  if (amountGiven > 0) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: change >= 0
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: change >= 0 ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            change >= 0 ? 'Kthim:' : 'Mungon:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: change >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          Text(
                            '€${change.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: change >= 0 ? Colors.green : Colors.red,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Anulo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            final amountGiven = double.tryParse(amountController.text) ?? 0.0;
                            final change = amountGiven - total;
                            if (amountGiven >= total) {
                              _processPayment(amountGiven, change);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Shuma e dhënë është më e vogël se totali'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            child: const Text(
                              'Paguaj',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(double amountGiven, double change) async {
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
      barcodeController.clear();
      amountController.clear();

      if (!mounted) return;

      // Show success dialog - Compact Design
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 550,
              minWidth: 450,
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
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Shitja u krye me sukses!',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Details
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _successRow('Fatura:', res.invoiceNo),
                        const SizedBox(height: 10),
                        _successRow('Totali:', '€${res.total.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        _successRow('Para të dhëna:', '€${amountGiven.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        _successRow(
                          'Kthim:',
                          '€${change.toStringAsFixed(2)}',
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Actions - Print dhe OK djathtas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Print Button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final lines = buildReceiptLinesForCart(
                            invoiceNo: res.invoiceNo,
                            date: DateTime.now(),
                            cartItems: cartItemsForReceipt,
                          );

                          await ReceiptPdf80mm.printOrSave(
                            title: 'SHOESTORE',
                            lines: lines,
                            jobName: res.invoiceNo,
                          );

                          if (dCtx.mounted) Navigator.pop(dCtx);
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text(
                          'Print',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // OK Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dCtx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  // ✅ NEW: Build checkout inline section

  Widget _successRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: isHighlight ? Colors.green : Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = cart.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header - Single Row: Titull majtas, Barcode actions djathtas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: const BoxDecoration(
              color: AppTheme.bgPage,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // MAJTAS: Icon + Titull
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/shitja_ditore.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Shitja Ditore',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                
                // DJATHTAS: Barcode Actions (Ikona + Input + Butoni)
                Row(
                  children: [
                    // Ikona Barcode
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.btnPrimary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    
                    // Barcode Input
                    Container(
                      height: 48,
                      width: 350,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: barcodeController,
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: Colors.black,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Skano ose vendos barcode',
                          hintStyle: TextStyle(
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          isDense: false,
                        ),
                        onSubmitted: _handleBarcodeScan,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    
                    // Butoni "+"
                    if (processing)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.btnPrimary,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleBarcodeScan(barcodeController.text),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            child: const Center(
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
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

            // Cart Table - Advanced Design
            Expanded(
              child: cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.shopping_cart_outlined,
                              size: 100,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Shporta është bosh',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Skano barcode për të shtuar produkte',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          // Table Container - Clean Design like reference
                          Container(
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Table Header - Minimal Design
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Produkti',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Çmimi',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Sasia',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Totali',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.black87,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      SizedBox(width: 48),
                                    ],
                                  ),
                                ),
                                // Table Body - Clean Rows
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: cart.length,
                                  itemBuilder: (context, index) {
                                    final item = cart[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.withOpacity(0.08),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                // ✅ NEW: Shfaq SKU ose Masa nëse është variant
                                                Text(
                                                  item.isVariant && item.variantSize != null
                                                      ? 'Masa: ${item.variantSize}'
                                                      : (item.isVariant && item.variantSku != null
                                                          ? 'SKU: ${item.variantSku}'
                                                          : (item.product.sku != null
                                                              ? 'SKU: ${item.product.sku}'
                                                              : '')),
                                                  style: TextStyle(
                                                    color: Colors.black87.withOpacity(0.6),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '€${item.unitPrice.toStringAsFixed(2)}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Colors.black87,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () => _updateQuantity(
                                                      index,
                                                      item.quantity - 1,
                                                    ),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(
                                                        Icons.remove,
                                                        color: Colors.black87,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  margin: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                                  child: Text(
                                                    '${item.quantity}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () => _updateQuantity(
                                                      index,
                                                      item.quantity + 1,
                                                    ),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(
                                                        Icons.add,
                                                        color: Colors.black87,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '€${item.lineTotal.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _removeItem(index),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.black87,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                            // Padding për të shmangur mbulimin nga bottom bar
                            const SizedBox(height: 120),
                          ],
                        ),
                    ),
            ),

            // ✅ FIXED BOTTOM BAR: Gjithmonë i dukshëm, të gjitha në një rresht
            _buildCompactBottomBar(total),
          ],
        ),
    );
  }

  // ✅ NEW: Compact Bottom Bar - Të gjitha elementet në një rresht
  Widget _buildCompactBottomBar(double total) {
    final amountGiven = double.tryParse(amountController.text) ?? 0.0;
    final change = amountGiven - total;
    final canConfirm = cart.isNotEmpty && amountGiven >= total && !checkingOut;
    final hasItems = cart.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgPage,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          // 1. Totali (content-width, majtas)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Totali:',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '€${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // 2. Para të dhëna (input, djathtas)
          SizedBox(
            width: 160,
            child: TextField(
              controller: amountController,
              focusNode: amountFocus,
              enabled: hasItems,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: hasItems ? Colors.black87 : Colors.grey,
              ),
              decoration: InputDecoration(
                labelText: 'Para të dhëna',
                labelStyle: TextStyle(
                  color: hasItems ? Colors.black87 : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: Colors.grey.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.euro,
                  color: hasItems ? Colors.black87 : Colors.grey,
                  size: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.black87,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: hasItems ? AppTheme.bg : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canConfirm) {
                  _confirmPayment();
                }
              },
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 3. Kusuri/Mungon (readonly, kompakt)
          Container(
            width: 160,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: hasItems 
                  ? (change >= 0 ? Colors.green.shade50 : Colors.red.shade50)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasItems
                    ? (change >= 0 ? Colors.green.shade300 : Colors.red.shade300)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  change >= 0 ? 'Kusuri:' : 'Mungon:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasItems
                        ? (change >= 0 ? Colors.green.shade800 : Colors.red.shade800)
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '€${change.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: hasItems
                        ? (change >= 0 ? Colors.green.shade800 : Colors.red.shade800)
                        : Colors.grey.shade600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 4. Butoni Konfirmo
          Material(
            color: canConfirm ? Colors.black87 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: canConfirm ? _confirmPayment : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: checkingOut
                    ? const SizedBox(
                        width: 120,
                        height: 18,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Text(
                        'Konfirmo Pagesën',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: canConfirm ? Colors.white : Colors.grey.shade600,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
