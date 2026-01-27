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

class ShpenzimetScreen extends StatefulWidget {
  const ShpenzimetScreen({super.key});

  @override
  State<ShpenzimetScreen> createState() => _ShpenzimetScreenState();
}

class _ShpenzimetScreenState extends State<ShpenzimetScreen> {
  String _selectedPeriod = 'today'; // 'today', 'week', 'month'
  String _selectedCategory = 'all'; // 'all', 'Rryma', 'Uji', 'Qiraja', 'Blerje Malli', 'Të tjera'
  bool _loading = true;
  bool _showAddForm = false;
  List<Map<String, dynamic>> _expenses = [];
  Map<String, double> _summary = {};

  // Form controllers
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategoryForm = 'Rryma';

  final List<String> _categories = [
    'Rryma',
    'Uji',
    'Qiraja',
    'Blerje Malli',
    'Pagat',
    'Transport',
    'Mirëmbajtje',
    'Të tjera',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final expenses = await LocalApi.I.getExpensesForPeriod(
        period: _selectedPeriod,
        categoryFilter: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      final summary = await LocalApi.I.getExpensesSummary(period: _selectedPeriod);
      
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
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

  Future<void> _addExpense() async {
    final amount = double.tryParse(_amountController.text.trim());
    
    if (amount == null || amount <= 0) {
      _showError('Shëno një shumë valide');
      return;
    }

    try {
      await LocalApi.I.addExpense(
        category: _selectedCategoryForm,
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (!mounted) return;
      
      _showSuccess('Shpenzimi u shtua me sukses');
      
      // Clear form
      _amountController.clear();
      _noteController.clear();
      setState(() => _showAddForm = false);
      
      // Reload data
      await _loadData();
    } catch (e) {
      _showError('Gabim: $e');
    }
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
                'Raporti i Shpenzimeve - ${_getPeriodLabel()}',
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
                        pw.Text('Shpenzime Operative:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['expensesTotal'] ?? 0)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Blerje Malli:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['investTotal'] ?? 0)),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Totali:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatCurrency(_summary['grandTotal'] ?? 0), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Expenses Table
              pw.Text(
                'Lista e Shpenzimeve (${(_summary['totalCount'] ?? 0).toInt()} total)',
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
                        child: pw.Text('Kategoria', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Data', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Shuma', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Shënim', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  ..._expenses.map((expense) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(expense['category'] ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatDate(expense['createdAtMs'] ?? 0)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(_formatCurrency(expense['amount'] ?? 0)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(expense['note'] ?? '—'),
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
                      'assets/icons/shpenzimet.svg',
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
                            'Shpenzimet',
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
                      onPressed: () {
                        setState(() => _showAddForm = !_showAddForm);
                      },
                      icon: Icon(
                        _showAddForm ? Icons.close : Icons.add_circle,
                        color: Colors.blue.shade700,
                      ),
                      tooltip: _showAddForm ? 'Mbyll' : 'Shto Shpenzim',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _printReport,
                      icon: Icon(Icons.print, color: Colors.red.shade700),
                      tooltip: 'Printo Raportin',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
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

          // Add Form (if visible)
          if (_showAddForm)
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
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
                      Icon(Icons.add_circle_outline, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Shto Shpenzim të Ri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kategoria',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.stroke),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategoryForm,
                                  isExpanded: true,
                                  items: _categories.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedCategoryForm = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Amount
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shuma (€)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.euro),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Note
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shënim (opsional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                hintText: 'Detaje shtesë...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.note),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Add Button
                      Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: FilledButton.icon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.check),
                          label: const Text('Shto'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
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
                                title: 'Shpenzime Operative',
                                value: _formatCurrency(_summary['expensesTotal'] ?? 0),
                                icon: Icons.receipt_long,
                                color: Colors.orange,
                                subtitle: '${(_summary['expensesCount'] ?? 0).toInt()} shpenzime',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                title: 'Blerje Malli',
                                value: _formatCurrency(_summary['investTotal'] ?? 0),
                                icon: Icons.shopping_cart,
                                color: Colors.purple,
                                subtitle: '${(_summary['investCount'] ?? 0).toInt()} investime',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _summaryCard(
                                title: 'Totali i Shpenzimeve',
                                value: _formatCurrency(_summary['grandTotal'] ?? 0),
                                icon: Icons.account_balance_wallet,
                                color: Colors.red.shade700,
                                subtitle: '${(_summary['totalCount'] ?? 0).toInt()} total',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Category filter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.filter_list, size: 24, color: AppTheme.text),
                                const SizedBox(width: 8),
                                const Text(
                                  'Filtro sipas kategorisë:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _categoryChip('Të gjitha', 'all'),
                                  const SizedBox(width: 8),
                                  ..._categories.map((cat) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _categoryChip(cat, cat),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Expenses Table
                        Row(
                          children: [
                            const Icon(Icons.list_alt, size: 24, color: AppTheme.text),
                            const SizedBox(width: 8),
                            Text(
                              'Lista e Shpenzimeve - ${_getPeriodLabel()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.text,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (_expenses.isEmpty)
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
                                    'S\'ka shpenzime për këtë periudhë',
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
                                        child: _tableHeader('Kategoria'),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: _tableHeader('Data & Ora'),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _tableHeader('Shuma'),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: _tableHeader('Shënim'),
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
                                  itemCount: _expenses.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final expense = _expenses[i];

                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getCategoryColor(expense['category']).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    expense['category'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                      color: _getCategoryColor(expense['category']),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _formatDate(expense['createdAtMs'] ?? 0),
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
                                              _formatCurrency(expense['amount'] ?? 0),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              expense['note'] ?? '—',
                                              style: TextStyle(
                                                color: AppTheme.muted,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: IconButton(
                                                onPressed: () async {
                                                  await _printExpense(expense);
                                                },
                                                icon: const Icon(
                                                  Icons.print,
                                                  size: 20,
                                                ),
                                                color: AppTheme.textPrimary,
                                                tooltip: 'Printo Shpenzimin',
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

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Rryma':
        return Colors.amber;
      case 'Uji':
        return Colors.blue;
      case 'Qiraja':
        return Colors.brown;
      case 'Blerje Malli':
        return Colors.purple;
      case 'Pagat':
        return Colors.green;
      case 'Transport':
        return Colors.orange;
      case 'Mirëmbajtje':
        return Colors.teal;
      default:
        return Colors.grey;
    }
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
                  ? Colors.red.shade700
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.red.shade700
                    : AppTheme.stroke,
                width: 2,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedCategory = value);
        _loadData();
      },
      selectedColor: Colors.red.withOpacity(0.2),
      checkmarkColor: Colors.red.shade700,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.red.shade700 : AppTheme.text,
        fontSize: 13,
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
              fontWeight: FontWeight.w700,
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

  /// Print/Download expense PDF
  Future<void> _printExpense(Map<String, dynamic> expense) async {
    try {
      final expenseId = expense['id'] as int?;
      if (expenseId == null) {
        _showError('Expense ID nuk u gjet');
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

      // Merr expense details
      final expenseDetails = await LocalApi.I.getExpenseDetails(expenseId);
      if (expenseDetails == null) {
        if (mounted) Navigator.pop(context);
        _showError('Shpenzimi nuk u gjet');
        return;
      }

      final storeName = await LocalApi.I.getCurrentBusinessName();

      // Gjenero PDF
      final pdfBytes = await PdfService.buildExpensePdf(
        category: expenseDetails['category'] as String,
        createdAtMs: expenseDetails['createdAtMs'] as int,
        amount: expenseDetails['amount'] as double,
        note: expenseDetails['note'] as String?,
        storeName: storeName,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      // Save PDF
      final category = expenseDetails['category'] as String;
      final date = DateTime.fromMillisecondsSinceEpoch(
        expenseDetails['createdAtMs'] as int,
      );
      final dateStr = DateFormat('yyyyMMdd').format(date);
      final fileName = 'Shpenzim_${category}_$dateStr.pdf';
      await FileSaveService.savePdfBytes(pdfBytes, fileName);

      if (!mounted) return;
      _showSuccess('Shpenzimi u shpëtua me sukses');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading nëse është hapur
        _showError('Gabim gjatë printimit: $e');
      }
    }
  }
}
