import 'receipt_preview.dart';
import '../src/local/local_api.dart';

// ✅ labels për TESHA (key 1000..)
const List<String> _clothLabels = [
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

List<ReceiptLine> buildReceiptLines({
  required String invoiceNo,
  required DateTime date,
  required String productName,
  required int qty,
  required double unitPriceFinal,
  required double totalFinal,
  double unitPriceOriginal = 0,
  double discountPercent = 0,
  int? size,
}) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  String dateStr =
      '${pad2(date.day)}.${pad2(date.month)}.${date.year} ${pad2(date.hour)}:${pad2(date.minute)}';

  String money(double v) => '€${v.toStringAsFixed(2)}';

  final lines = <ReceiptLine>[];

  lines.add(ReceiptLine('FATURA', invoiceNo, bold: true));
  lines.add(ReceiptLine('Data', dateStr));

  // ✅ FIX: mos e shfaq 1000,1001… por 0-3M,3-6M…
  if (size != null) {
    final sizeLabel = _labelForSizeKey(size);
    lines.add(ReceiptLine('Numri', sizeLabel));
  }

  lines.add(const ReceiptLine('----------------', ''));

  // Item
  lines.add(const ReceiptLine('Artikulli', '', bold: true));
  lines.add(ReceiptLine(productName, 'x$qty'));

  lines.add(const ReceiptLine('----------------', ''));

  // Pricing
  final hasDiscount = discountPercent > 0 && unitPriceOriginal > 0;

  if (hasDiscount) {
    lines.add(ReceiptLine('Cmimi origjinal', money(unitPriceOriginal)));
    lines.add(
      ReceiptLine('Zbritja', '-${discountPercent.toStringAsFixed(0)}%'),
    );
    lines.add(ReceiptLine('Cmimi final', money(unitPriceFinal), bold: true));
  } else {
    lines.add(ReceiptLine('Cmimi', money(unitPriceFinal), bold: true));
  }

  lines.add(const ReceiptLine('----------------', ''));

  lines.add(ReceiptLine('TOTAL', money(totalFinal), bold: true));

  return lines;
}

List<ReceiptLine> buildReceiptLinesForCart({
  required String invoiceNo,
  required DateTime date,
  required List<CartItem> cartItems,
}) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  String dateStr =
      '${pad2(date.day)}.${pad2(date.month)}.${date.year} ${pad2(date.hour)}:${pad2(date.minute)}';

  String money(double v) => '€${v.toStringAsFixed(2)}';

  final lines = <ReceiptLine>[];

  lines.add(ReceiptLine('FATURA', invoiceNo, bold: true));
  lines.add(ReceiptLine('Data', dateStr));

  lines.add(const ReceiptLine('----------------', ''));

  // Items
  lines.add(const ReceiptLine('Artikujt', '', bold: true));

  double total = 0;
  for (final item in cartItems) {
    final sizeLabel = _labelForSizeKey(item.size);
    lines.add(
      ReceiptLine(item.product.name, 'x${item.quantity} (${sizeLabel})'),
    );
    lines.add(ReceiptLine('', money(item.lineTotal)));
    total += item.lineTotal;
  }

  lines.add(const ReceiptLine('----------------', ''));

  lines.add(ReceiptLine('TOTAL', money(total), bold: true));

  return lines;
}
