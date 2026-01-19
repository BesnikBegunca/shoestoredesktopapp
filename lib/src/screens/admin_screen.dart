// admin_screen.dart
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shoe_store_manager/auth/role_store.dart';
import 'package:shoe_store_manager/models/app_user.dart';

import '../local/local_api.dart';
import '../../printing/receipt_builder.dart';
import '../../printing/receipt_pdf_80mm.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

String monthKey(DateTime d) =>
    '${d.year}-${(d.month).toString().padLeft(2, '0')}';

enum _ReportScope { day, month, year, total }

enum _AdminTab { dashboard, users }

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool loading = true;

  // tabs
  _AdminTab tab = _AdminTab.dashboard;

  // DASHBOARD DATA
  List<String> monthOptions = [];
  String selectedMonth = monthKey(DateTime.now());
  AdminStats? stats;
  List<ActivityItem> activity = [];

  // USERS DATA
  bool usersLoading = false;
  List<AppUser> users = [];
  bool userStatsLoading = false;
  WorkerStats? selectedUserStats;
  String selectedUserStatsScope = 'total';
  bool settlingWorker = false;

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

  String _pdfFileName(_ReportScope scope) {
    final now = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    final day = '${now.year}-${pad2(now.month)}-${pad2(now.day)}';
    final mk = selectedMonth;
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

  // ✅ NEW: group container for stats (Sot / Muaji / Total)
  Widget _statsGroup(String title, List<Widget> cards) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...cards.map(
            (c) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
          ),
        ],
      ),
    );
  }

  // ---------- dialogs ----------
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

  Future<void> doLogout(BuildContext context) async {
    await RoleStore.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ---------- load ----------
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

  Future<void> _loadUsers() async {
    setState(() => usersLoading = true);
    try {
      final list = await LocalApi.I.getAllUsers();
      if (!mounted) return;
      setState(() => users = list);
    } catch (e) {
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => usersLoading = false);
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
                  trailing: m == selectedMonth
                      ? const Icon(Icons.check_circle)
                      : null,
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

  // ---------- revert ----------
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

  // ---------- invest ----------
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                        note: noteC.text.trim().isEmpty
                            ? null
                            : noteC.text.trim(),
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

  // ---------- expense ----------
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
                          child: Text(
                            c,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    hintText: expCategory == 'Rroga'
                        ? 'p.sh. Arben - Rroga Janar'
                        : null,
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
                        // nëse s’po e përdor userId te expenses -> lëre 0
                        await LocalApi.I.addExpense(
                          userId: 0,
                          category: expCategory,
                          amount: amount,
                          note: expNoteC.text.trim().isEmpty
                              ? null
                              : expNoteC.text.trim(),
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
  // PRINT / SAVE PDF
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

    if (scope == _ReportScope.year) {
      final ys = await LocalApi.I.getYearStats(year);
      sales = ys.totalSales;
      profit = ys.totalProfit;
      invest = ys.totalInvest;
      exp = ys.totalExpenses;
      countSales = ys.countSales;
    } else {
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
          break;
      }
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
                _pdfLine(
                  font,
                  fontBold,
                  'Shpenzime + Investime',
                  _money(expenses + invest),
                ),
                _pdfLine(font, fontBold, 'Nr. shitjesh', '$countSales'),
                pw.Divider(),
                _pdfLine(
                  font,
                  fontBold,
                  'Neto (Fitim - Shpenzime)',
                  _money(net),
                ),
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

  // ---------- activity tile ----------
  Widget _activityTile(ActivityItem a) {
    final isSale = a.type == 'SALE';
    final isExpense = a.type == 'EXPENSE';

    final c = isSale
        ? Colors.green
        : (isExpense ? Colors.deepOrange : Colors.red);

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
        style: TextStyle(color: isReverted ? Colors.grey.shade700 : null),
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
            DateTime.fromMillisecondsSinceEpoch(
              a.createdAtMs,
            ).toLocal().toString(),
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
        child: Card(margin: EdgeInsets.zero, color: bg, child: tile()),
      ),
    );
  }

  // =======================
  // USERS CRUD UI
  // =======================

  Future<void> _openCreateUserDialog() async {
    final userC = TextEditingController();
    final passC = TextEditingController();
    String role = 'worker';
    bool hide = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Shto User',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userC,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passC,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setLocal(() => hide = !hide),
                      icon: Icon(
                        hide ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('worker')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? 'worker'),
                  decoration: const InputDecoration(
                    labelText: 'Role',
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
              onPressed: () async {
                try {
                  await LocalApi.I.createUser(
                    username: userC.text,
                    password: passC.text,
                    role: role,
                  );
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadUsers();
                  await _showSuccessDialog('User u kriju ✅');
                } catch (e) {
                  _showError('$e');
                }
              },
              icon: const Icon(Icons.person_add),
              label: const Text('KRIJO'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditUserDialog(AppUser u0) async {
    final userC = TextEditingController(text: u0.username);
    final passC = TextEditingController();
    String role = u0.role;
    bool hide = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Edit User',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userC,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passC,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'Password (opsional)',
                    hintText: 'lëre zbrazët nëse s’do me ndrru',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setLocal(() => hide = !hide),
                      icon: Icon(
                        hide ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('worker')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? u0.role),
                  decoration: const InputDecoration(
                    labelText: 'Role',
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
              onPressed: () async {
                try {
                  final newUser = userC.text.trim();
                  if (newUser.isEmpty) {
                    _showError('Username s’bon me kon zbrazët.');
                    return;
                  }

                  await LocalApi.I.updateUser(
                    userId: u0.id,
                    username: newUser,
                    password: passC.text.trim().isEmpty
                        ? null
                        : passC.text.trim(),
                    role: role,
                  );

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadUsers();
                  await _showSuccessDialog('User u përditësu ✅');
                } catch (e) {
                  _showError('$e');
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('RUAJ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteUser(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Fshij user?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('Je i sigurt qe do me fshi "${u.username}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Fshij'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteUser(AppUser u) async {
    final ok = await _confirmDeleteUser(u);
    if (!ok) return;

    setState(() => usersLoading = true);
    try {
      await LocalApi.I.deleteUser(u.id);
      await _loadUsers();
      await _showSuccessDialog('User u fshi ✅');
    } catch (e) {
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => usersLoading = false);
    }
  }

  Future<void> _openUserStatsDialog(AppUser u) async {
    setState(() => userStatsLoading = true);
    try {
      final dayStats = await LocalApi.I.getWorkerStats(
        userId: u.id,
        scope: 'day',
      );
      final monthStats = await LocalApi.I.getWorkerStats(
        userId: u.id,
        scope: 'month',
        monthKeyFilter: selectedMonth,
      );
      final totalStats = await LocalApi.I.getWorkerStats(
        userId: u.id,
        scope: 'total',
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Statistikat e ${u.username}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 900, // ✅ MA E GJERË
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8, // ✅ MA E LARTË
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _statsGroup('Sot', [
                      _statCard(
                        'Shitje Sot',
                        _money(dayStats.totalSales),
                        Icons.payments,
                        Colors.green,
                      ),
                      _statCard(
                        'Nr. Shitjesh Sot',
                        '${dayStats.countSales}',
                        Icons.confirmation_number,
                        Colors.green,
                      ),
                      _statCard(
                        'Fitim Sot',
                        _money(dayStats.totalProfit),
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _statsGroup('Muaji', [
                      _statCard(
                        'Shitje Muaji',
                        _money(monthStats.totalSales),
                        Icons.calendar_month,
                        Colors.blue,
                      ),
                      _statCard(
                        'Nr. Shitjesh Muaji',
                        '${monthStats.countSales}',
                        Icons.confirmation_number,
                        Colors.blue,
                      ),
                      _statCard(
                        'Fitim Muaji',
                        _money(monthStats.totalProfit),
                        Icons.assessment,
                        Colors.blue,
                      ),
                    ]),
                    const SizedBox(height: 14),

                    _statsGroup('Total', [
                      _statCard(
                        'Shitje Total',
                        _money(totalStats.totalSales),
                        Icons.all_inclusive,
                        Colors.teal,
                      ),
                      _statCard(
                        'Nr. Shitjesh Total',
                        '${totalStats.countSales}',
                        Icons.confirmation_number,
                        Colors.teal,
                      ),
                      _statCard(
                        'Fitim Total',
                        _money(totalStats.totalProfit),
                        Icons.star,
                        Colors.teal,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('MBYLL'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Gabim: $e');
    } finally {
      if (mounted) setState(() => userStatsLoading = false);
    }
  }

  Future<void> _openActivityDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Aktiviteti i fundit',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 800,
          height: 600,
          child: activity.isEmpty
              ? Center(
                  child: Text(
                    'S\'ka aktivitet.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: activity.length,
                  itemBuilder: (_, i) => _activityTile(activity[i]),
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MBYLL'),
          ),
        ],
      ),
    );
  }

  // =======================
  // UI
  // =======================

  @override
  Widget build(BuildContext context) {
    final s = stats;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppTheme.surface2,
              border: Border(
                right: BorderSide(color: AppTheme.stroke, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ADMIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppTheme.text,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.stroke, height: 1),
                  const SizedBox(height: 10),
                  _sideBtn(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    active: tab == _AdminTab.dashboard,
                    onTap: () => setState(() => tab = _AdminTab.dashboard),
                  ),
                  const SizedBox(height: 8),
                  _sideBtn(
                    icon: Icons.people_alt_rounded,
                    label: 'Users',
                    active: tab == _AdminTab.users,
                    onTap: () async {
                      setState(() => tab = _AdminTab.users);
                      if (users.isEmpty) {
                        await _loadUsers();
                      }
                    },
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: const BorderSide(color: AppTheme.stroke),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => doLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(18),
                    child: tab == _AdminTab.dashboard
                        ? _dashboardView(s)
                        : _usersView(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sideBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.surface.withOpacity(0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppTheme.primaryPurple.withOpacity(0.6)
                : AppTheme.stroke,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppTheme.primaryPurple : AppTheme.text),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- DASHBOARD VIEW ----------
  Widget _dashboardView(AdminStats? s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // top bar
        Row(
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const Spacer(),

            // month picker
            OutlinedButton.icon(
              onPressed: _changeMonth,
              icon: const Icon(Icons.calendar_month),
              label: Text(_formatMonthLabel(selectedMonth)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.text,
                side: const BorderSide(color: AppTheme.stroke),
              ),
            ),
            const SizedBox(width: 10),

            // invest / expense
            FilledButton.icon(
              onPressed: _openInvestDialog,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Investim'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: _openExpenseDialog,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Shpenzim'),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // report buttons
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _reportBtn(
              'Print Ditor',
              Icons.print,
              () => _printOrSaveReport(_ReportScope.day, saveAsPdf: false),
            ),
            _reportBtn(
              'Save Ditor PDF',
              Icons.save_alt,
              () => _printOrSaveReport(_ReportScope.day, saveAsPdf: true),
            ),
            _reportBtn(
              'Print Mujor',
              Icons.print,
              () => _printOrSaveReport(_ReportScope.month, saveAsPdf: false),
            ),
            _reportBtn(
              'Save Mujor PDF',
              Icons.save_alt,
              () => _printOrSaveReport(_ReportScope.month, saveAsPdf: true),
            ),
            _reportBtn(
              'Print Vjetor',
              Icons.print,
              () => _printOrSaveReport(_ReportScope.year, saveAsPdf: false),
            ),
            _reportBtn(
              'Save Vjetor PDF',
              Icons.save_alt,
              () => _printOrSaveReport(_ReportScope.year, saveAsPdf: true),
            ),
            _reportBtn(
              'Print Total',
              Icons.print,
              () => _printOrSaveReport(_ReportScope.total, saveAsPdf: false),
            ),
            _reportBtn(
              'Save Total PDF',
              Icons.save_alt,
              () => _printOrSaveReport(_ReportScope.total, saveAsPdf: true),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ✅ summary cards -> 3 columns (LEFT=Sot, MID=Muaji, RIGHT=Total) + responsive
        if (s != null)
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;

              final todayCards = <Widget>[
                _statCard(
                  'Sot Shitje',
                  _money(s.totalSalesToday),
                  Icons.payments,
                  Colors.green,
                ),

                // ✅ COUNT SHITJESH
                _statCard(
                  'Sot Nr. Shitjesh',
                  '${s.countSalesToday}',
                  Icons.confirmation_number,
                  Colors.green.shade700,
                ),

                _statCard(
                  'Sot Fitim',
                  _money(s.totalProfitToday),
                  Icons.trending_up,
                  Colors.green.shade800,
                ),
                _statCard(
                  'Sot Investim',
                  _money(s.totalInvestToday),
                  Icons.shopping_cart_checkout,
                  Colors.red,
                ),
                _statCard(
                  'Sot Shpenzime (Inv + Shp)',
                  _money(s.totalInvestToday + s.totalExpensesToday),
                  Icons.money_off,
                  Colors.deepOrange,
                ),
              ];

              final monthCards = <Widget>[
                _statCard(
                  'Muji Shitje',
                  _money(s.totalSalesMonth),
                  Icons.calendar_month,
                  Colors.blue,
                ),

                // ✅ COUNT SHITJESH
                _statCard(
                  'Muji Nr. Shitjesh',
                  '${s.countSalesMonth}',
                  Icons.confirmation_number,
                  Colors.blue.shade700,
                ),

                _statCard(
                  'Muji Fitim',
                  _money(s.totalProfitMonth),
                  Icons.assessment,
                  Colors.blue.shade800,
                ),
                _statCard(
                  'Muji Investim',
                  _money(s.totalInvestMonth),
                  Icons.shopping_cart_checkout,
                  Colors.red,
                ),
                _statCard(
                  'Muji Shpenzime (Inv + Shp)',
                  _money(s.totalInvestMonth + s.totalExpensesMonth),
                  Icons.money_off,
                  Colors.deepOrange,
                ),
              ];

              final totalCards = <Widget>[
                _statCard(
                  'Total Shitje',
                  _money(s.totalSalesAll),
                  Icons.all_inclusive,
                  Colors.teal,
                ),

                // ✅ COUNT SHITJESH
                _statCard(
                  'Total Nr. Shitjesh',
                  '${s.countSalesAll}',
                  Icons.confirmation_number,
                  Colors.teal.shade700,
                ),

                _statCard(
                  'Total Fitim',
                  _money(s.totalProfitAll),
                  Icons.star,
                  Colors.teal.shade800,
                ),

                _statCard(
                  'Total Investim',
                  _money(s.totalInvestAll),
                  Icons.shopping_cart_checkout,
                  Colors.red,
                ),

                _statCard(
                  'Total Shpenzime (Inv + Shp)',
                  _money(s.totalInvestAll + s.totalExpensesAll),
                  Icons.money_off,
                  Colors.deepOrange,
                ),
              ];

              // 1 column stack
              if (w < 700) {
                return Column(
                  children: [
                    _statsGroup('Sot', todayCards),
                    const SizedBox(height: 12),
                    _statsGroup('Muaji', monthCards),
                    const SizedBox(height: 12),
                    _statsGroup('Total', totalCards),
                  ],
                );
              }

              // 2 columns: left has Sot+Muaji, right has Total
              if (w < 1050) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _statsGroup('Sot', todayCards),
                          const SizedBox(height: 12),
                          _statsGroup('Muaji', monthCards),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _statsGroup('Total', totalCards)),
                  ],
                );
              }

              // 3 columns
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _statsGroup('Sot', todayCards)),
                  const SizedBox(width: 12),
                  Expanded(child: _statsGroup('Muaji', monthCards)),
                  const SizedBox(width: 12),
                  Expanded(child: _statsGroup('Total', totalCards)),
                ],
              );
            },
          ),

        const SizedBox(height: 14),

        // ✅ INVENTORY METRICS - separate grid below the main stats
        if (s != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface2.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Inventari',
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _statCard(
                          'Total Stock',
                          '${s.totalStock} pcs',
                          Icons.inventory,
                          Colors.purple,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _statCard(
                          'Stock Value',
                          _money(s.totalStockValueFinal),
                          Icons.attach_money,
                          Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // activity
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Aktiviteti i fundit',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _openActivityDialog,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('See full size'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: const BorderSide(color: AppTheme.stroke),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: activity.isEmpty
                      ? Center(
                          child: Text(
                            'S’ka aktivitet.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: activity.length,
                          itemBuilder: (_, i) => _activityTile(activity[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- USERS VIEW ----------
  Widget _usersView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Users',
              style: TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Shto user'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: usersLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                ? Center(
                    child: Text(
                      'S’ka usera.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final u = users[i];

                      return Slidable(
                        key: ValueKey('user-${u.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.42,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _openEditUserDialog(u),
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              icon: Icons.edit,
                              label: 'Edit',
                            ),
                            SlidableAction(
                              onPressed: (_) => _deleteUser(u),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_forever,
                              label: 'Fshij',
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryPurple
                                  .withOpacity(0.15),
                              child: Icon(
                                u.role == 'admin' ? Icons.shield : Icons.person,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            title: Text(
                              u.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              'Role: ${u.role}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Stats',
                                  onPressed: () => _openUserStatsDialog(u),
                                  icon: const Icon(Icons.bar_chart),
                                ),
                                IconButton(
                                  tooltip: 'Settle Worker',
                                  onPressed: settlingWorker
                                      ? null
                                      : () async {
                                          setState(() => settlingWorker = true);
                                          try {
                                            await LocalApi.I.settleWorkerToday(
                                              u.id,
                                              u.username,
                                            );
                                            await _showSuccessDialog(
                                              'Punëtori ${u.username} u pagua për sot ✅',
                                            );
                                          } catch (e) {
                                            _showError('$e');
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => settlingWorker = false,
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.payment),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _openEditUserDialog(u),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Fshij',
                                  onPressed: () => _deleteUser(u),
                                  icon: const Icon(Icons.delete_forever),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ---------- UI helpers ----------
  Widget _reportBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.text,
        side: const BorderSide(color: AppTheme.stroke),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.35)),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// SUCCESS POPUP WIDGET
// =======================
class _SuccessPopup extends StatelessWidget {
  final String message;
  const _SuccessPopup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface, // ✅ jo white
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 2,
            color: Colors.black.withOpacity(0.35),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withOpacity(0.35)),
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.text, // ✅ tekst i dukshëm
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
