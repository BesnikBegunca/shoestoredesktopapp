// daily_sale_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/printing/receipt_builder.dart';
import 'package:shoe_store_manager/printing/receipt_pdf_80mm.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

/// Parses discount input and returns the discount amount in EUR to subtract from subtotal.
/// - "10%" or "10.5%" => percentage of subtotal
/// - "10" (no % or €) => treat as 10%
/// - "€10" or "10€" => fixed 10 EUR
/// Empty or invalid => 0. Result is clamped so total never goes below 0.
double parseDiscountAmount(String input, double subtotal) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 0.0;
  final lower = trimmed.toLowerCase();
  final hasPercent = lower.contains('%');
  final hasEuro = lower.contains('€') || lower.contains('eur');
  if (hasEuro) {
    final numStr = trimmed
        .replaceAll(RegExp(r'[€\s]'), '')
        .replaceAll(RegExp(r'eur', caseSensitive: false), '')
        .trim();
    final value = double.tryParse(numStr);
    if (value == null || value < 0) return 0.0;
    return value.clamp(0.0, subtotal);
  }
  if (hasPercent || (!hasPercent && !hasEuro)) {
    final numStr = trimmed.replaceAll('%', '').trim();
    final value = double.tryParse(numStr);
    if (value == null || value < 0) return 0.0;
    final pct = value.clamp(0.0, 100.0) / 100.0;
    final discount = subtotal * pct;
    return discount.clamp(0.0, subtotal);
  }
  return 0.0;
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

class DailySaleScreen extends StatefulWidget {
  const DailySaleScreen({super.key});

  @override
  State<DailySaleScreen> createState() => _DailySaleScreenState();
}

class _DailySaleScreenState extends State<DailySaleScreen> {
  final barcodeController = TextEditingController();
  final amountController = TextEditingController();
  final amountFocus = FocusNode();
  final barcodeFocus = FocusNode(); // Focus node për barcode TextField
  final scrollController = ScrollController();
  final pageFocusNode =
      FocusNode(); // Focus node për page-level keyboard capture
  List<CartItem> cart = [];
  bool processing = false;
  bool checkingOut = false;

  // Barcode scanning buffer dhe timer
  String _barcodeBuffer = '';
  Timer? _barcodeTimer;
  static const Duration _barcodeTimeout = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // Auto-focus barcode field kur faqja hapet për cursor aktiv
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        barcodeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _barcodeTimer?.cancel();
    barcodeController.dispose();
    amountController.dispose();
    amountFocus.dispose();
    barcodeFocus.dispose();
    pageFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ✅ NEW: Handle keyboard events për barcode scanning
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Ignoro nëse është në procesim ose checkout
    if (processing || checkingOut) {
      return KeyEventResult.ignored;
    }

    // ✅ Ignoro TË GJITHA keyboard events nëse TextField i barcode është i fokusuar
    // Kjo lejon TextField të trajtojë normalisht shkrimin manual, paste, backspace, etj.
    // ENTER/TAB do të trajtohen nga TextField's onSubmitted callback
    if (barcodeFocus.hasFocus) {
      return KeyEventResult
          .ignored; // Lejo TextField të trajtojë të gjitha events
    }

    // Ignoro nëse amount field është i fokusuar
    if (amountFocus.hasFocus) {
      return KeyEventResult.ignored;
    }

    // Ignoro modifier keys
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      // Handle ENTER ose TAB - proceso barcode
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (_barcodeBuffer.isNotEmpty) {
          final barcode = _barcodeBuffer.trim();
          _barcodeBuffer = '';
          _barcodeTimer?.cancel();
          _barcodeTimer = null;
          if (barcode.isNotEmpty) {
            _handleBarcodeScan(barcode);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      // Handle backspace
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_barcodeBuffer.isNotEmpty) {
          _barcodeBuffer = _barcodeBuffer.substring(
            0,
            _barcodeBuffer.length - 1,
          );
          _resetBarcodeTimer();
        }
        return KeyEventResult.handled;
      }

      // Kap karakteret e printueshme
      final character = event.character;
      if (character != null && character.isNotEmpty && character.length == 1) {
        // Ignoro karakteret speciale që nuk janë alfanumerike ose simbol bazë
        if (RegExp(r'^[a-zA-Z0-9\-_\.\s]$').hasMatch(character)) {
          _barcodeBuffer += character;
          _resetBarcodeTimer();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  // ✅ NEW: Reset timer për barcode buffer
  void _resetBarcodeTimer() {
    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(_barcodeTimeout, () {
      // Nëse ka kaluar timeout dhe buffer është bosh ose shumë i shkurtër,
      // reset buffer (mund të jetë typing normal ose gabim)
      // Por nëse buffer ka karaktere, mbaje derisa të vijë ENTER/TAB
      // (barcode scanners zakonisht dërgojnë karaktere shumë shpejt)
      if (_barcodeBuffer.length < 2) {
        // Nëse buffer është shumë i shkurtër pas timeout, reset
        _barcodeBuffer = '';
      }
    });
  }

  // ✅ NEW: Restore focus pas procesimit të barcode
  void _restorePageFocus() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !processing && !checkingOut) {
        pageFocusNode.requestFocus();
      }
    });
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
        if (product.isSet) {
          final choice = await _showSetDecisionDialog(product);
          if (!mounted) return;
          if (choice == null) return;
          if (choice == true) {
            final existingIndex = cart.indexWhere(
              (item) => item.product.id == product.id && item.soldAsSet,
            );
            if (existingIndex >= 0) {
              setState(() => cart[existingIndex].quantity++);
            } else {
              setState(
                () => cart.add(
                  CartItem(product: product, size: 0, soldAsSet: true),
                ),
              );
            }
          } else {
            final splitItems = await _showSetSplitDialog(product);
            if (!mounted) return;
            if (splitItems != null && splitItems.isNotEmpty) {
              setState(() => cart.addAll(splitItems));
            }
          }
        } else {
          final existingIndex = cart.indexWhere(
            (item) =>
                item.product.id == product.id &&
                item.size == 0 &&
                !item.isVariant,
          );
          if (existingIndex >= 0) {
            setState(() => cart[existingIndex].quantity++);
          } else {
            setState(() => cart.add(CartItem(product: product, size: 0)));
          }
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
              content: Text(
                "S'ka stok për ${formatSizeLabel(int.tryParse(variant.size) ?? 0)}",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Nëse produkti është SET, shfaq dialog
        if (product.isSet) {
          final choice = await _showSetDecisionDialog(product);
          if (!mounted) return;
          if (choice == null) return;
          if (choice == true) {
            final existingIndex = cart.indexWhere(
              (item) => item.product.id == product.id && item.soldAsSet,
            );
            if (existingIndex >= 0) {
              setState(() => cart[existingIndex].quantity++);
            } else {
              setState(
                () => cart.add(
                  CartItem(product: product, size: 0, soldAsSet: true),
                ),
              );
            }
          } else {
            final splitItems = await _showSetSplitDialog(product);
            if (!mounted) return;
            if (splitItems != null && splitItems.isNotEmpty) {
              setState(() => cart.addAll(splitItems));
            }
          }
        } else {
          final sizeInt = int.tryParse(variant.size) ?? 0;
          final existingIndex = cart.indexWhere(
            (item) => item.isVariant && item.variantId == variant.id,
          );
          if (existingIndex >= 0) {
            if (cart[existingIndex].quantity >= variant.quantity) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Stoku maksimal për ${formatSizeLabel(sizeInt)} është ${variant.quantity}',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            setState(() => cart[existingIndex].quantity++);
          } else {
            setState(
              () => cart.add(
                CartItem(
                  product: product,
                  size: sizeInt,
                  variantId: variant.id,
                  variantSku: variant.sku,
                  variantSize: variant.size,
                ),
              ),
            );
          }
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

        // Nëse produkti është SET, shfaq dialog
        if (product.isSet) {
          final choice = await _showSetDecisionDialog(product);
          if (!mounted) return;
          if (choice == null) return;
          if (choice == true) {
            final existingIndex = cart.indexWhere(
              (item) => item.product.id == product.id && item.soldAsSet,
            );
            if (existingIndex >= 0) {
              setState(() => cart[existingIndex].quantity++);
            } else {
              setState(
                () => cart.add(
                  CartItem(product: product, size: 0, soldAsSet: true),
                ),
              );
            }
          } else {
            final splitItems = await _showSetSplitDialog(product);
            if (!mounted) return;
            if (splitItems != null && splitItems.isNotEmpty) {
              setState(() => cart.addAll(splitItems));
            }
          }
        } else {
          final sizeInt = int.tryParse(variant.size) ?? 0;
          final existingIndex = cart.indexWhere(
            (item) => item.isVariant && item.variantId == variant.id,
          );
          if (existingIndex >= 0) {
            if (cart[existingIndex].quantity >= variant.quantity) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Stoku maksimal për ${variant.size} është ${variant.quantity}',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            setState(() => cart[existingIndex].quantity++);
          } else {
            setState(
              () => cart.add(
                CartItem(
                  product: product,
                  size: sizeInt,
                  variantId: variant.id,
                  variantSku: variant.sku,
                  variantSize: variant.size,
                ),
              ),
            );
          }
        }
      }

      // ✅ Pastro barcode field dhe restore page focus
      // Sigurohu që TextField është i pastër dhe i unfocusuar
      barcodeController.clear();
      barcodeFocus.unfocus();
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _barcodeTimer = null;
      _restorePageFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  /// Dialog: Produkti është SET – shit si SET ose nda SET-in.
  /// Returns: true = shit si SET, false = nda SET-in, null = anulo
  Future<bool?> _showSetDecisionDialog(Product setProduct) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Produkti është SET'),
        content: const Text(
          'Dëshiron ta ndash setin?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Po, nda SET-in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Jo, shit si SET'),
          ),
        ],
      ),
    );
  }

  /// Dialog: Ndaje SET-in – shfaq komponentët (emër, sasi, variant) dhe shton linja shportë për çdo komponent.
  /// Returns list of CartItem (one per component) or null if cancelled.
  Future<List<CartItem>?> _showSetSplitDialog(Product setProduct) async {
    final components = await LocalApi.I.getSetComponents(setProduct.id);
    if (components.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ky SET nuk ka komponentë të konfiguruar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    final qtyControllers = <int, TextEditingController>{};
    for (int i = 0; i < components.length; i++) {
      qtyControllers[i] = TextEditingController(text: '${components[i].qty}');
    }

    List<CartItem>? result;
    final errorHolder = <String?>[null];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Ndaje SET-in'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorHolder[0] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorHolder[0]!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ...List.generate(components.length, (i) {
                      final c = components[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                c.name.isEmpty ? 'Komponent ${i + 1}' : c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (c.variant != null && c.variant!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '(${c.variant})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: qtyControllers[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Sasia',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Anulo'),
                ),
                FilledButton(
                  onPressed: () async {
                    errorHolder[0] = null;
                    final items = <CartItem>[];
                    int maxQty = 0;
                    for (int i = 0; i < components.length; i++) {
                      final c = components[i];
                      final qty =
                          int.tryParse(qtyControllers[i]!.text.trim()) ?? c.qty;
                      if (qty <= 0) {
                        errorHolder[0] = 'Sasia për "${c.name}" duhet > 0.';
                        setDialogState(() {});
                        return;
                      }
                      if (qty > maxQty) maxQty = qty;
                      items.add(
                        CartItem(
                          product: setProduct,
                          size: 0,
                          quantity: qty,
                          parentSetProductId: setProduct.id,
                          componentName: c.name.isEmpty ? null : c.name,
                        ),
                      );
                    }
                    final setStock =
                        setProduct.sizeStock[0] ?? setProduct.stockQty;
                    if (setStock < maxQty) {
                      errorHolder[0] =
                          'Nuk ka stok për SET (duhen $maxQty seta, ka $setStock).';
                      setDialogState(() {});
                      return;
                    }
                    result = items;
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Konfirmo'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final c in qtyControllers.values) {
      c.dispose();
    }
    return result;
  }

  // ✅ NEW: Shfaq dialog për zgjedhje mase
  Future<String?> _showSizeSelector(List<ProductVariant> variants) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Zgjedh Masa',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
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
                    color: hasStock ? Colors.white : Colors.grey.shade100,
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
                      'Masa: ${formatSizeLabel(int.tryParse(v.size) ?? 0)}',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Anulo',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              content: Text(
                'Stoku maksimal për ${item.variantSize != null ? formatSizeLabel(int.tryParse(item.variantSize!) ?? 0) : item.variantSku} është ${variant.quantity}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() => cart[index].quantity = quantity);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gabim: $e')));
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
    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final amountGiven = double.tryParse(amountController.text) ?? 0.0;
    if (amountGiven <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendosni shumën e dhënë'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final discountController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final discountInput = discountController.text;
          final discountAmount = parseDiscountAmount(discountInput, subtotal);
          final discountedTotal = (subtotal - discountAmount).clamp(
            0.0,
            double.infinity,
          );
          final change = amountGiven - discountedTotal;
          final canPay = amountGiven >= discountedTotal;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550, minWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Konfirmo Pagesën',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _paymentRow(
                            'Totali (para zbritjes):',
                            '€${subtotal.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: discountController,
                            onChanged: (_) => setDialogState(() {}),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Apliko zbritje',
                              labelStyle: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              hintText: '10% ose 5 ose €10',
                              hintStyle: TextStyle(
                                color: Colors.black87.withOpacity(0.4),
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _paymentRow(
                            'Totali:',
                            '€${discountedTotal.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 10),
                          _paymentRow(
                            'Para të dhëna:',
                            '€${amountGiven.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 10),
                          _paymentRow(
                            change >= 0 ? 'Kthim:' : 'Mungon:',
                            '€${change.abs().toStringAsFixed(2)}',
                            isHighlight: true,
                            isNegative: change < 0,
                          ),
                          if (!canPay && amountGiven > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Shuma e dhënë është më e vogël se totali',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                          },
                          child: const Text(
                            'Anulo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: null,
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
                            ElevatedButton(
                              onPressed: canPay
                                  ? () {
                                      Navigator.pop(dCtx);
                                      _processPayment(
                                        amountGiven,
                                        change,
                                        discountAmount: discountAmount,
                                      );
                                    }
                                  : null,
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
                                'Paguaj',
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    discountController.dispose();
  }

  Widget _paymentRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isNegative = false,
  }) {
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
            color: isHighlight
                ? (isNegative ? Colors.red : Colors.green)
                : Colors.black,
          ),
        ),
      ],
    );
  }

  // ✅ OLD: _showPaymentDialog - ruajtur për referencë (mund të fshihet më vonë)
  Future<void> _showPaymentDialog_OLD() async {
    final total = cart.fold<double>(0, (sum, item) => sum + item.lineTotal);

    final amountController = TextEditingController();
    final amountFocus = FocusNode();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                            final amountGiven =
                                double.tryParse(amountController.text) ?? 0.0;
                            final change = amountGiven - total;
                            if (amountGiven >= total) {
                              _processPayment(amountGiven, change);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Shuma e dhënë është më e vogël se totali',
                                  ),
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

  Future<void> _processPayment(
    double amountGiven,
    double change, {
    double? discountAmount,
  }) async {
    setState(() => checkingOut = true);
    try {
      final uid = await RoleStore.getUserId();
      if (uid <= 0) {
        throw Exception('UserId s\'osht i logum (uid=$uid). Bëj logout/login.');
      }

      final res = await LocalApi.I.sellMany(
        cartItems: cart,
        userId: uid,
        discountAmount: discountAmount,
      );

      // Store cart items for receipt before clearing
      final cartItemsForReceipt = List<CartItem>.from(cart);

      // Clear cart
      setState(() => cart.clear());
      barcodeController.clear();
      amountController.clear();
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _barcodeTimer = null;

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
            constraints: BoxConstraints(maxWidth: 550, minWidth: 450),
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
                        _successRow(
                          'Totali:',
                          '€${res.total.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 10),
                        _successRow(
                          'Para të dhëna:',
                          '€${amountGiven.toStringAsFixed(2)}',
                        ),
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
                      // Print Button - DISABLED
                      OutlinedButton.icon(
                        onPressed:
                            null, // ✅ DISABLED: Print button është çaktivizuar
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
                          _restorePageFocus();
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
                          'Paguaj',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gabim gjatë checkout: $e')));
    } finally {
      if (mounted) {
        setState(() => checkingOut = false);
        _restorePageFocus();
      }
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
    final total = cart.fold<double>(0, (sum, item) => sum + item.lineTotal);

    return Focus(
      focusNode: pageFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: GestureDetector(
          onTap: () => barcodeFocus.requestFocus(),
          child: Column(
            children: [
              // Header - Single Row: Titull majtas, Barcode actions djathtas
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(color: AppTheme.bgPage),
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
                            fontWeight: FontWeight.w500,
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(
                              color: AppTheme.borderLight,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: barcodeController,
                            focusNode: barcodeFocus,
                            autofocus:
                                false, // Opsional: përdoruesi mund të klikojë për manual entry
                            textAlignVertical: TextAlignVertical.center,
                            cursorColor: Colors.black,
                            // ✅ Opsional: Lejo të gjitha operacionet normale të TextField
                            // (shkrim, paste, backspace, delete, arrow keys, etj.)
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
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
                            onSubmitted: (value) {
                              // ✅ Manual submit me ENTER: proceso barcode dhe rikthe fokusin te page-level
                              if (value.trim().isNotEmpty) {
                                _handleBarcodeScan(value);
                                // Pastro TextField dhe rikthe fokusin pas procesimit
                                barcodeController.clear();
                                barcodeFocus.unfocus();
                                _restorePageFocus();
                              } else {
                                // Nëse është bosh, thjesht rikthe fokusin te page-level
                                barcodeFocus.unfocus();
                                _restorePageFocus();
                              }
                            },
                            onTap: () {
                              // ✅ Kur përdoruesi klikon TextField për manual entry:
                              // 1. Hiq focus nga page-level listener
                              // 2. Pastro buffer të global listener për të shmangur konfliktin
                              pageFocusNode.unfocus();
                              _barcodeBuffer = '';
                              _barcodeTimer?.cancel();
                              _barcodeTimer = null;
                            },
                            // ✅ Lejo të gjitha operacionet normale: paste, select all, etj.
                            enableInteractiveSelection: true,
                            enableSuggestions: false,
                            autocorrect: false,
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // ✅ Manual submit nga butoni "+": proceso barcode dhe rikthe fokusin
                                  final barcode = barcodeController.text.trim();
                                  if (barcode.isNotEmpty) {
                                    _handleBarcodeScan(barcode);
                                    // Pastro TextField dhe rikthe fokusin pas procesimit
                                    barcodeController.clear();
                                    barcodeFocus.unfocus();
                                    _restorePageFocus();
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
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
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Skano barcode për të shtuar produkte',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
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
                                              color: Colors.grey.withOpacity(
                                                0.08,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item.componentName !=
                                                                null &&
                                                            item
                                                                .componentName!
                                                                .isNotEmpty
                                                        ? '${item.product.name} - ${item.componentName}'
                                                        : '${item.product.name}${item.soldAsSet ? ' (SET)' : ''}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                      color: Colors.black87,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  // ✅ NEW: Shfaq SKU ose Masa nëse është variant
                                                  Text(
                                                    item.isVariant &&
                                                            item.variantSize !=
                                                                null
                                                        ? 'Masa: ${formatSizeLabel(int.tryParse(item.variantSize!) ?? 0)}'
                                                        : (item.isVariant &&
                                                                  item.variantSku !=
                                                                      null
                                                              ? 'SKU: ${item.variantSku}'
                                                              : (item.product.sku !=
                                                                        null
                                                                    ? 'SKU: ${item.product.sku}'
                                                                    : '')),
                                                    style: TextStyle(
                                                      color: Colors.black87
                                                          .withOpacity(0.6),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _updateQuantity(
                                                            index,
                                                            item.quantity - 1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        child: const Icon(
                                                          Icons.remove,
                                                          color: Colors.black87,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    child: Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _updateQuantity(
                                                            index,
                                                            item.quantity + 1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
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
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
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
        ),
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
      decoration: const BoxDecoration(color: AppTheme.bgPage),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '€${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                  borderSide: const BorderSide(color: Colors.black87, width: 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasItems
                  ? (change >= 0 ? Colors.green.shade50 : Colors.red.shade50)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasItems
                    ? (change >= 0
                          ? Colors.green.shade300
                          : Colors.red.shade300)
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
                        ? (change >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800)
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '€${change.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: hasItems
                        ? (change >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800)
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
                          color: canConfirm
                              ? Colors.white
                              : Colors.grey.shade600,
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
