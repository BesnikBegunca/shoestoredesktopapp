import 'package:flutter/material.dart';

class ReceiptLine {
  final String left;
  final String right;
  final bool bold;

  const ReceiptLine(this.left, this.right, {this.bold = false});
}

class ReceiptPreview extends StatelessWidget {
  final String title;
  final List<ReceiptLine> lines;
  final int widthMm;

  const ReceiptPreview({
    super.key,
    required this.title,
    required this.lines,
    this.widthMm = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Fatura')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widthMm * 4.2), // approx px/mm
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 13, height: 1.25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      for (final l in lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.left,
                                  style: TextStyle(
                                    fontWeight:
                                    l.bold ? FontWeight.w900 : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l.right,
                                style: TextStyle(
                                  fontWeight:
                                  l.bold ? FontWeight.w900 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'Faleminderit!',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
