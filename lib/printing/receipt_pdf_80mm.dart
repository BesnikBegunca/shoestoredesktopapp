import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'receipt_preview.dart';

class ReceiptPdf80mm {
  static Future<void> printOrSave({
    required String title,
    required List<ReceiptLine> lines,
    required String jobName,
  }) async {
    final bytes = await _buildPdf(title: title, lines: lines);

    await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> _buildPdf({
    required String title,
    required List<ReceiptLine> lines,
  }) async {
    final doc = pw.Document();

    // ✅ Font që e mbështet €
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (_) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: font, fontSize: 9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(),

                for (final l in lines)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            l.left,
                            style: pw.TextStyle(font: l.bold ? fontBold : font),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          l.right,
                          style: pw.TextStyle(font: l.bold ? fontBold : font),
                        ),
                      ],
                    ),
                  ),

                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Faleminderit!',
                    style: pw.TextStyle(font: fontBold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
