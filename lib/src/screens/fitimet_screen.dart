import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../local/local_api.dart';
import '../theme/app_theme.dart';
import '../services/pdf_service.dart';
import '../services/file_save_service.dart';

class FitimetScreen extends StatefulWidget {
  const FitimetScreen({super.key});

  @override
  State<FitimetScreen> createState() => _FitimetScreenState();
}

class _FitimetScreenState extends State<FitimetScreen> {
  String _selectedPeriod = 'today'; // 'today', 'week', 'month'
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  Map<String, double> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sales = await LocalApi.I.getSalesForPeriod(period: _selectedPeriod);
      final summary = await LocalApi.I.getProfitSummary(period: _selectedPeriod);
      
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _summary = summary;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'today':
        return 'Sot';
      case 'week':
        return 'Kjo Javë';
      case 'month':
        return 'Këtë Muaj';
      default:
        return '';
    }
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  String _formatCurrency(double amount) {
    return '€${amount.toStringAsFixed(2)}';
  }

  Future<void> _printReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'Raporti i Fitimeve - ${_getPeriodLabel()}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Data e printimit: ${_formatDate(DateTime.now().millisecondsSinceEpoch)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Shitje Totale:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['totalSales'] ?? 0)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Fitim Bruto:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['totalProfit'] ?? 0)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Shpenzime:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['totalExpenses'] ?? 0)),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Fitim Neto:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['netProfit'] ?? 0), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Sales Table
              pw.Text(
                'Lista e Shitjeve (${(_summary['count'] ?? 0).toInt()} total)',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Invoice', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Data', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Totali', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Fitimi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  ..._sales.map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(sale['invoiceNo'] ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatDate(sale['createdAtMs'] ?? 0)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatCurrency(sale['total'] ?? 0)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatCurrency(sale['profitTotal'] ?? 0)),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.bgPage,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/fitimet.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fitimet',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _printReport,
                      icon: Icon(Icons.print, color: Colors.green.shade700),
                      tooltip: 'Printo Raportin',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Period filters
                Row(
                  children: [
                    _periodButton('Ditor', 'today'),
                    const SizedBox(width: 12),
                    _periodButton('Javor', 'week'),
                    const SizedBox(width: 12),
                    _periodButton('Mujor', 'month'),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: 'Shitje Totale',
                                value: _formatCurrency(_summary['totalSales'] ?? 0),
                                icon: Icons.shopping_cart,
                                color: Colors.blue,
                                subtitle: '${(_summary['count'] ?? 0).toInt()} transaksione',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                title: 'Fitim Bruto',
                                value: _formatCurrency(_summary['totalProfit'] ?? 0),
                                icon: Icons.attach_money,
                                color: Colors.green,
                                subtitle: 'Para shpenzimeve',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                title: 'Shpenzime',
                                value: _formatCurrency(_summary['totalExpenses'] ?? 0),
                                icon: Icons.money_off,
                                color: Colors.orange,
                                subtitle: 'Totali i shpenzimeve',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                title: 'Fitim Neto',
                                value: _formatCurrency(_summary['netProfit'] ?? 0),
                                icon: Icons.account_balance_wallet,
                                color: (_summary['netProfit'] ?? 0) >= 0 
                                    ? Colors.green.shade700 
                                    : Colors.red,
                                subtitle: 'Fitimi final',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Sales Table
                        Row(
                          children: [
                            const Icon(Icons.list_alt, size: 24, color: AppTheme.text),
                            const SizedBox(width: 8),
                            Text(
                              'Lista e Shitjeve - ${_getPeriodLabel()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.text,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (_sales.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(48),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.stroke),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: AppTheme.muted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'S\'ka shitje për këtë periudhë',
                                    style: TextStyle(
                                      color: AppTheme.muted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.stroke),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C3E50),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _tableHeader('Invoice'),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: _tableHeader('Data & Ora'),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _tableHeader('Totali'),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _tableHeader('Fitimi'),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: _tableHeader('Printo'),
                                      ),
                                    ],
                                  ),
                                ),

                                // Table Rows
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _sales.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final sale = _sales[i];
                                    final total = sale['total'] ?? 0.0;
                                    final profit = sale['profitTotal'] ?? 0.0;
                                    final margin = total > 0 ? (profit / total * 100) : 0.0;

                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              sale['invoiceNo'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _formatDate(sale['createdAtMs'] ?? 0),
                                              style: TextStyle(
                                                color: AppTheme.muted,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _formatCurrency(total),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _formatCurrency(profit),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: IconButton(
                                                onPressed: () async {
                                                  await _printInvoice(sale);
                                                },
                                                icon: const Icon(
                                                  Icons.print,
                                                  size: 20,
                                                ),
                                                color: AppTheme.textPrimary,
                                                tooltip: 'Printo Faturën',
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
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedPeriod = period);
            _loadData();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.green.shade700
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.green.shade700
                    : AppTheme.stroke,
                width: 2,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 13,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Print/Download invoice PDF
  Future<void> _printInvoice(Map<String, dynamic> sale) async {
    try {
      final invoiceNo = sale['invoiceNo'] as String? ?? '';
      if (invoiceNo.isEmpty) {
        _showError('Invoice number nuk u gjet');
        return;
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Merr invoice details dhe items
      final invoiceDetails = await LocalApi.I.getInvoiceDetails(invoiceNo);
      if (invoiceDetails == null) {
        if (mounted) Navigator.pop(context);
        _showError('Invoice nuk u gjet');
        return;
      }

      final items = await LocalApi.I.getInvoiceItems(invoiceNo);
      final storeName = await LocalApi.I.getCurrentBusinessName();

      // Gjenero PDF
      final pdfBytes = await PdfService.buildInvoicePdf(
        invoiceNo: invoiceDetails['invoiceNo'] as String,
        createdAtMs: invoiceDetails['createdAtMs'] as int,
        total: invoiceDetails['total'] as double,
        profitTotal: invoiceDetails['profitTotal'] as double,
        items: items,
        storeName: storeName,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      // Save PDF
      final fileName = 'Invoice_$invoiceNo.pdf';
      await FileSaveService.savePdfBytes(pdfBytes, fileName);

      if (!mounted) return;
      _showSuccess('Fatura u shpëtua me sukses');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading nëse është hapur
        _showError('Gabim gjatë printimit: $e');
      }
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
      ),
    );
  }
}
