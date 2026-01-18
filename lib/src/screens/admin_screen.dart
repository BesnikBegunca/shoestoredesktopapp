// admin_screen.dart
import 'dart:typed_data';

import 'package:shoe_store_manager/auth/role_store.dart';

import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../local/local_api.dart';
import '../theme/app_theme.dart';

String monthKey(DateTime d) => '${d.year}-${(d.month).toString().padLeft(2, '0')}';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

enum _ReportScope { day, month, year, total }

class _AdminScreenState extends State<AdminScreen> {
  bool loading = true;

  List<String> monthOptions = [];
  String selectedMonth = monthKey(DateTime.now());

  AdminStats? stats;
  List<ActivityItem> activity = [];

  // INVEST
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  bool saving = false;

  // EXPENSE
  final expAmountC = TextEditingController();
  final expNoteC = TextEditingController();
  String expCategory = 'Rroga';
  bool expSaving = false;

  final List<String> expCategories = const [
    'Rroga',
    'Rryma',
    'Uji',
    'Mbeturinat',
    'Qeraja',
    'Shpenzime te pa planifikuara',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    amountC.dispose();
    noteC.dispose();
    expAmountC.dispose();
    expNoteC.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  String _money(num n) => '€${n.toDouble().toStringAsFixed(2)}';

  String _formatDayLabel(DateTime d) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${pad2(d.day)}.${pad2(d.month)}.${d.year}';
  }

  int _selectedYear() {
    final parts = selectedMonth.split('-');
    return int.tryParse(parts.first) ?? DateTime.now().year;
  }

  String _scopeTitle(_ReportScope s) {
    switch (s) {
      case _ReportScope.day:
        return 'Raport Ditor';
      case _ReportScope.month:
        return 'Raport Mujor';
      case _ReportScope.year:
        return 'Raport Vjetor';
      case _ReportScope.total:
        return 'Raport Total';
    }
  }

  Future<void> doLogout(BuildContext context) async {
    await RoleStore.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  String _pdfFileName(_ReportScope scope) {
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');

    final day = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    final mk = selectedMonth; // "YYYY-MM"
    final y = _selectedYear();

    switch (scope) {
      case _ReportScope.day:
        return 'raport-ditor-$day.pdf';
      case _ReportScope.month:
        return 'raport-mujor-$mk.pdf';
      case _ReportScope.year:
        return 'raport-vjetor-$y.pdf';
      case _ReportScope.total:
        return 'raport-total-$day.pdf';
    }
  }

  // ✅ success popup
  Future<void> _showSuccessDialog(String msg) async {
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'success',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _SuccessPopup(message: msg),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final months = await LocalApi.I.getMonthOptions();
      final chosen = months.contains(selectedMonth)
          ? selectedMonth
          : (months.isNotEmpty ? months.first : selectedMonth);

      final st = await LocalApi.I.getAdminStats(selectedMonth: chosen);
      final act = await LocalApi.I.getActivity(limit: 60);

      if (!mounted) return;
      setState(() {
        monthOptions = months;
        selectedMonth = chosen;
        stats = st;
        activity = act;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeMonth() async {
    if (monthOptions.isEmpty) return;

    final mk = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Zgjedh muajin',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in monthOptions)
                ListTile(
                  title: Text(
                    _formatMonthLabel(m),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: m == selectedMonth ? const Icon(Icons.check_circle) : null,
                  onTap: () => Navigator.pop(context, m),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
        ],
      ),
    );

    if (mk == null || mk == selectedMonth) return;

    setState(() => loading = true);
    try {
      final st = await LocalApi.I.getAdminStats(selectedMonth: mk);
      final act = await LocalApi.I.getActivity(limit: 60);
      if (!mounted) return;
      setState(() {
        selectedMonth = mk;
        stats = st;
        activity = act;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Gabim',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ confirm revert
  Future<bool> _confirmRevert(ActivityItem a) async {
    final title = a.type == 'SALE'
        ? 'Revert Shitjen?'
        : a.type == 'INVEST'
        ? 'Revert Investimin?'
        : 'Revert Shpenzimin?';

    final body = a.type == 'SALE'
        ? 'Me bo revert kësaj shitje? Stoku kthehet mbrapsht.'
        : 'Me bo revert këtij regjistrimi?';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.undo),
            label: const Text('Revert'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _doRevert(ActivityItem a) async {
    if (a.reverted) return;
    if (a.refId == null) {
      _showError('S’u gjet ID e regjistrimit.');
      return;
    }

    final ok = await _confirmRevert(a);
    if (!ok) return;

    setState(() => loading = true);
    try {
      if (a.type == 'SALE') {
        await LocalApi.I.revertSale(saleId: a.refId!);
        await _loadAll();
        await _showSuccessDialog('Shitja u revert-ua ✅ (stoku u kthye)');
      } else if (a.type == 'INVEST') {
        await LocalApi.I.revertInvestment(investId: a.refId!);
        await _loadAll();
        await _showSuccessDialog('Investimi u revert-ua ✅');
      } else if (a.type == 'EXPENSE') {
        await LocalApi.I.revertExpense(expenseId: a.refId!);
        await _loadAll();
        await _showSuccessDialog('Shpenzimi u revert-ua ✅');
      }
    } catch (e) {
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------- INVEST ALERT ----------
  Future<void> _openInvestDialog() async {
    amountC.clear();
    noteC.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Blej Mall (Investim)',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  labelText: 'Shënim (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulo'),
          ),
          FilledButton.icon(
            onPressed: saving
                ? null
                : () async {
              final raw = amountC.text.trim().replaceAll(',', '.');
              final amount = double.tryParse(raw) ?? 0;

              if (amount <= 0) {
                _showError('Shkruaj amount valid.');
                return;
              }

              setState(() => saving = true);
              try {
                await LocalApi.I.addInvestment(
                  amount: amount,
                  note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _loadAll();
                await _showSuccessDialog('Investimi u ruajt ✅');
              } catch (e) {
                _showError('Gabim: $e');
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
            icon: const Icon(Icons.add_circle),
            label: Text(saving ? 'Duke ruajt...' : 'RUJE'),
          ),
        ],
      ),
    );
  }

  // ---------- EXPENSE ALERT ----------
  Future<void> _openExpenseDialog() async {
    expAmountC.clear();
    expNoteC.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Shto Shpenzim',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: expCategory,
                  items: expCategories
                      .map(
                        (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => expCategory = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Kategoria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expAmountC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (€)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expNoteC,
                  decoration: InputDecoration(
                    labelText: expCategory == 'Rroga'
                        ? 'Emri i punëtorit / shënim'
                        : 'Shënim (opsional)',
                    hintText: expCategory == 'Rroga' ? 'p.sh. Arben - Rroga Janar' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulo'),
            ),
            FilledButton.icon(
              onPressed: expSaving
                  ? null
                  : () async {
                final raw = expAmountC.text.trim().replaceAll(',', '.');
                final amount = double.tryParse(raw) ?? 0;

                if (amount <= 0) {
                  _showError('Shkruaj amount valid.');
                  return;
                }

                setState(() => expSaving = true);
                try {
                  await LocalApi.I.addExpense(
                    category: expCategory,
                    amount: amount,
                    note: expNoteC.text.trim().isEmpty ? null : expNoteC.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadAll();
                  await _showSuccessDialog('Shpenzimi u ruajt ✅');
                } catch (e) {
                  _showError('Gabim: $e');
                } finally {
                  if (mounted) setState(() => expSaving = false);
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: Text(expSaving ? 'Duke ruajt...' : 'RUJE'),
            ),
          ],
        ),
      ),
    );
  }

  // =======================
  // ✅ PRINT / SAVE PDF
  // =======================

  Future<void> _printOrSaveReport(
      _ReportScope scope, {
        required bool saveAsPdf,
      }) async {
    final s = stats;
    if (s == null) {
      _showError('S’ka statistika për me bo raport.');
      return;
    }

    final year = _selectedYear();
    final today = DateTime.now();

    double sales = 0, profit = 0, invest = 0, exp = 0;
    int countSales = 0;

    switch (scope) {
      case _ReportScope.day:
        sales = s.totalSalesToday.toDouble();
        profit = s.totalProfitToday.toDouble();
        invest = s.totalInvestToday.toDouble();
        exp = s.totalExpensesToday.toDouble();
        countSales = s.countSalesToday;
        break;

      case _ReportScope.month:
        sales = s.totalSalesMonth.toDouble();
        profit = s.totalProfitMonth.toDouble();
        invest = s.totalInvestMonth.toDouble();
        exp = s.totalExpensesMonth.toDouble();
        countSales = s.countSalesMonth;
        break;

      case _ReportScope.total:
        sales = s.totalSalesAll.toDouble();
        profit = s.totalProfitAll.toDouble();
        invest = s.totalInvestAll.toDouble();
        exp = s.totalExpensesAll.toDouble();
        countSales = s.countSalesAll;
        break;

      case _ReportScope.year:
        sales = 0;
        profit = 0;
        invest = 0;
        exp = 0;
        countSales = 0;
        break;
    }

    final net = profit - exp;

    final bytes = await _buildPdfBytes(
      scope: scope,
      today: today,
      year: year,
      sales: sales,
      profit: profit,
      invest: invest,
      expenses: exp,
      countSales: countSales,
      net: net,
      activity: activity,
    );

    if (saveAsPdf) {
      await _savePdfFile(bytes, scope);
      return;
    }

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _pdfFileName(scope),
    );
  }

  Future<void> _savePdfFile(Uint8List bytes, _ReportScope scope) async {
    final suggestedName = _pdfFileName(scope);

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );

    if (location == null) return;

    final file = XFile.fromData(
      bytes,
      name: suggestedName,
      mimeType: 'application/pdf',
    );

    await file.saveTo(location.path);

    if (!mounted) return;
    await _showSuccessDialog('PDF u ruajt ✅');
  }

  Future<Uint8List> _buildPdfBytes({
    required _ReportScope scope,
    required DateTime today,
    required int year,
    required double sales,
    required double profit,
    required double invest,
    required double expenses,
    required int countSales,
    required double net,
    required List<ActivityItem> activity,
  }) async {
    final doc = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    String pad2(int n) => n.toString().padLeft(2, '0');
    final dateLabel = '${pad2(today.day)}.${pad2(today.month)}.${today.year}';

    String periodLabel;
    switch (scope) {
      case _ReportScope.day:
        periodLabel = 'Dita: $dateLabel';
        break;
      case _ReportScope.month:
        periodLabel = 'Muaji: ${_formatMonthLabel(selectedMonth)}';
        break;
      case _ReportScope.year:
        periodLabel = 'Viti: $year';
        break;
      case _ReportScope.total:
        periodLabel = 'Gjithsej (Total)';
        break;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _scopeTitle(scope),
                    style: pw.TextStyle(font: fontBold, fontSize: 18),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    periodLabel,
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Text(
                    'Gjeneruar: $dateLabel',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.8),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Shoe Store Manager',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Përmbledhje',
                  style: pw.TextStyle(font: fontBold, fontSize: 13),
                ),
                pw.SizedBox(height: 10),
                _pdfLine(font, fontBold, 'Shitje', _money(sales)),
                _pdfLine(font, fontBold, 'Fitim', _money(profit)),
                _pdfLine(font, fontBold, 'Investim', _money(invest)),
                _pdfLine(font, fontBold, 'Shpenzime', _money(expenses)),
                // ✅ SHTESA: Shpenzime + Investime
                _pdfLine(
                  font,
                  fontBold,
                  'Shpenzime + Investime',
                  _money(expenses + invest),
                ),
                _pdfLine(font, fontBold, 'Nr. shitjesh', '$countSales'),
                pw.Divider(),
                _pdfLine(font, fontBold, 'Neto (Fitim - Shpenzime)', _money(net)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Regjistrimet e fundit (si në Admin)',
            style: pw.TextStyle(font: fontBold, fontSize: 13),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(2.8),
              3: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                children: [
                  _pdfCellHeader(fontBold, 'Tipi'),
                  _pdfCellHeader(fontBold, 'Titulli'),
                  _pdfCellHeader(fontBold, 'Detaj'),
                  _pdfCellHeader(fontBold, 'Shuma'),
                ],
              ),
              ...activity.take(60).map((a) {
                final sign = (a.type == 'SALE') ? '+' : '-';
                final rev = a.reverted ? ' (REVERT)' : '';
                return pw.TableRow(
                  children: [
                    _pdfCell(font, '${a.type}$rev'),
                    _pdfCell(font, a.title),
                    _pdfCell(font, a.sub),
                    _pdfCell(font, '$sign${_money(a.amount)}'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfLine(pw.Font f, pw.Font fb, String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: pw.TextStyle(font: fb, fontSize: 11)),
          pw.Text(v, style: pw.TextStyle(font: f, fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _pdfCellHeader(pw.Font fb, String t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(t, style: pw.TextStyle(font: fb, fontSize: 10)),
    );
  }

  pw.Widget _pdfCell(pw.Font f, String t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(t, style: pw.TextStyle(font: f, fontSize: 9)),
    );
  }

  // ✅ Activity tile me SLIDE (Revert)
  Widget _activityTile(ActivityItem a) {
    final isSale = a.type == 'SALE';
    final isExpense = a.type == 'EXPENSE';

    final c = isSale ? Colors.green : (isExpense ? Colors.deepOrange : Colors.red);

    final isReverted = a.reverted;
    final bg = isReverted ? Colors.grey.withOpacity(0.12) : null;
    final fg = isReverted ? Colors.grey : c;

    final sign = isSale ? '+' : '-';

    final icon = isSale
        ? Icons.check_circle
        : (isExpense ? Icons.receipt_long : Icons.shopping_cart);

    final subtitle = isReverted ? '${a.sub}\n(REVERTED)' : a.sub;

    final canRevert = !isReverted && a.refId != null;

    Widget tile() => ListTile(
      leading: CircleAvatar(
        backgroundColor: fg.withOpacity(0.15),
        child: Icon(icon, color: fg),
      ),
      title: Text(
        a.title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isReverted ? Colors.grey.shade800 : null,
          decoration: isReverted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isReverted ? Colors.grey.shade700 : null,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${_money(a.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: fg,
              decoration: isReverted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateTime.fromMillisecondsSinceEpoch(a.createdAtMs).toLocal().toString(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (!canRevert) {
      return Card(color: bg, child: tile());
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey('${a.type}-${a.refId}-${a.createdAtMs}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (_) => _doRevert(a),
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              icon: Icons.undo,
              label: 'Revert',
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          color: bg,
          child: tile(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final today = DateTime.now();

    final salesToday = (s?.totalSalesToday ?? 0).toDouble();
    final salesMonth = (s?.totalSalesMonth ?? 0).toDouble();
    final salesAll = (s?.totalSalesAll ?? 0).toDouble();

    final profitToday = (s?.totalProfitToday ?? 0).toDouble();
    final profitMonth = (s?.totalProfitMonth ?? 0).toDouble();
    final profitAll = (s?.totalProfitAll ?? 0).toDouble();

    final countToday = (s?.countSalesToday ?? 0);
    final countMonth = (s?.countSalesMonth ?? 0);
    final countAll = (s?.countSalesAll ?? 0);

    final investToday = (s?.totalInvestToday ?? 0).toDouble();
    final investMonth = (s?.totalInvestMonth ?? 0).toDouble();
    final investAll = (s?.totalInvestAll ?? 0).toDouble();

    final expToday = (s?.totalExpensesToday ?? 0).toDouble();
    final expMonth = (s?.totalExpensesMonth ?? 0).toDouble();
    final expAll = (s?.totalExpensesAll ?? 0).toDouble();

    // ✅ SHTESA: Shpenzime + Investime
    final outToday = investToday + expToday;
    final outMonth = investMonth + expMonth;
    final outAll = investAll + expAll;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          PopupMenuButton<_ReportScope>(
            tooltip: 'Print / PDF',
            icon: const Icon(Icons.print),
            onSelected: (scope) async {
              await _printOrSaveReport(scope, saveAsPdf: false);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ReportScope.day,
                child: Text('Print Dita (Sot)'),
              ),
              PopupMenuItem(
                value: _ReportScope.month,
                child: Text('Print Muaji (i zgjedhur)'),
              ),
              PopupMenuItem(
                value: _ReportScope.year,
                child: Text('Print Viti (i zgjedhur)'),
              ),
              PopupMenuItem(
                value: _ReportScope.total,
                child: Text('Print Total (Gjithsej)'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Ruaj si PDF (Muaji)',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await _printOrSaveReport(_ReportScope.month, saveAsPdf: true);
            },
          ),
          IconButton(
            tooltip: 'Expenses',
            onPressed: _openExpenseDialog,
            icon: const Icon(Icons.receipt_long),
          ),
          IconButton(
            tooltip: 'Investim',
            onPressed: _openInvestDialog,
            icon: const Icon(Icons.add_circle),
          ),
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(
                  _formatMonthLabel(selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Filter për statistika mujore'),
                trailing: const Icon(Icons.expand_more),
                onTap: _changeMonth,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistikat (Sot / Muaj / Total)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _tripleHeader(
                      left: 'SOT • ${_formatDayLabel(today)}',
                      mid: _formatMonthLabel(selectedMonth),
                      right: 'TOTAL',
                    ),
                    const SizedBox(height: 10),
                    _tripleRow(
                      label: 'Shitje',
                      left: _money(salesToday),
                      mid: _money(salesMonth),
                      right: _money(salesAll),
                      leftColor: Colors.green,
                      midColor: Colors.blue,
                      rightColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 8),
                    _tripleRow(
                      label: 'Fitim',
                      left: _money(profitToday),
                      mid: _money(profitMonth),
                      right: _money(profitAll),
                      leftColor: Colors.green,
                      midColor: Colors.blue,
                      rightColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 8),
                    _tripleRow(
                      label: 'Nr. shitjesh',
                      left: '$countToday',
                      mid: '$countMonth',
                      right: '$countAll',
                      leftColor: Theme.of(context).colorScheme.onSurface,
                      midColor: Theme.of(context).colorScheme.onSurface,
                      rightColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 8),
                    _tripleRow(
                      label: 'Investim',
                      left: _money(investToday),
                      mid: _money(investMonth),
                      right: _money(investAll),
                      leftColor: Colors.red,
                      midColor: Colors.red,
                      rightColor: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _tripleRow(
                      label: 'Shpenzimet',
                      left: _money(expToday),
                      mid: _money(expMonth),
                      right: _money(expAll),
                      leftColor: Colors.deepOrange,
                      midColor: Colors.deepOrange,
                      rightColor: Colors.deepOrange,
                    ),

                    // ✅ SHTESA: Shpenzime + Investime
                    const SizedBox(height: 8),
                    _tripleRow(
                      label: 'Shpenzime + Investime',
                      left: _money(outToday),
                      mid: _money(outMonth),
                      right: _money(outAll),
                      leftColor: Colors.purple,
                      midColor: Colors.purple,
                      rightColor: Colors.purple,
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statCard(
                          'Stok Total (Copë)',
                          '${s?.totalStock ?? 0}',
                          Icons.inventory_2,
                        ),
                        _statCard(
                          'Vlera e Stokut (Final)',
                          _money((s?.totalStockValueFinal ?? 0).toDouble()),
                          Icons.euro,
                          tint: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openInvestDialog,
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Shto Investim'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _openExpenseDialog,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Shto Shpenzim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Regjistrimet e fundit',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  '(slide -> revert)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (activity.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('S’ka regjistrime ende.'),
                ),
              )
            else
              ...activity.map(_activityTile),
          ],
        ),
      ),
    );
  }

  Widget _tripleHeader({
    required String left,
    required String mid,
    required String right,
  }) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            textAlign: TextAlign.center,
            style: t.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.green,
            ),
          ),
        ),
        Expanded(
          child: Text(
            mid,
            textAlign: TextAlign.center,
            style: t.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
          ),
        ),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.center,
            style: t.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _tripleRow({
    required String label,
    required String left,
    required String mid,
    required String right,
    required Color leftColor,
    required Color midColor,
    required Color rightColor,
  }) {
    final t = Theme.of(context).textTheme;

    Widget cell(String v, Color c) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.7),
            ),
          ),
          child: Text(
            v,
            textAlign: TextAlign.center,
            style: t.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: c,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(
          children: [
            cell(left, leftColor),
            const SizedBox(width: 8),
            cell(mid, midColor),
            const SizedBox(width: 8),
            cell(right, rightColor),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, {Color? tint}) {
    final c = tint ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthLabel(String mk) {
    final parts = mk.split('-');
    if (parts.length != 2) return mk;
    final y = parts[0];
    final m = int.tryParse(parts[1]) ?? 1;
    const names = [
      'Janar',
      'Shkurt',
      'Mars',
      'Prill',
      'Maj',
      'Qershor',
      'Korrik',
      'Gusht',
      'Shtator',
      'Tetor',
      'Nëntor',
      'Dhjetor',
    ];
    final idx = (m - 1).clamp(0, 11);
    return '${names[idx]} $y';
  }
}

class _SuccessPopup extends StatelessWidget {
  final String message;
  const _SuccessPopup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
        ),
        boxShadow: const [
          BoxShadow(blurRadius: 18, spreadRadius: 2, color: Color(0x33000000)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 42,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
