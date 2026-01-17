import 'receipt_preview.dart';

List<ReceiptLine> buildReceiptLines({
  required String invoiceNo,
  required DateTime date,
  required String productName,
  required int qty,
  required double unitPriceFinal,        // final (pas zbritjes)
  required double totalFinal,            // total final
  double unitPriceOriginal = 0,          // origjinal para zbritjes
  double discountPercent = 0,            // p.sh 10
  int? size,                             // opsionale
}) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  String dateStr = '${pad2(date.day)}.${pad2(date.month)}.${date.year} ${pad2(date.hour)}:${pad2(date.minute)}';

  String money(double v) => '€${v.toStringAsFixed(2)}';

  final lines = <ReceiptLine>[];

  lines.add(ReceiptLine('FATURA', invoiceNo, bold: true));
  lines.add(ReceiptLine('Data', dateStr));
  if (size != null) lines.add(ReceiptLine('Numri', '$size'));
  lines.add(const ReceiptLine('----------------', ''));

  // Item
  lines.add(const ReceiptLine('Artikulli', '', bold: true));
  lines.add(ReceiptLine(productName, 'x$qty'));

  lines.add(const ReceiptLine('----------------', ''));

  // Pricing
  final hasDiscount = discountPercent > 0 && unitPriceOriginal > 0;

  if (hasDiscount) {
    lines.add(ReceiptLine('Cmimi origjinal', money(unitPriceOriginal)));
    lines.add(ReceiptLine('Zbritja', '-${discountPercent.toStringAsFixed(0)}%'));
    lines.add(ReceiptLine('Cmimi final', money(unitPriceFinal), bold: true));
  } else {
    lines.add(ReceiptLine('Cmimi', money(unitPriceFinal), bold: true));
  }

  lines.add(const ReceiptLine('----------------', ''));

  lines.add(ReceiptLine('TOTAL', money(totalFinal), bold: true));

  return lines;
}
