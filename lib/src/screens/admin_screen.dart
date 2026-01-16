import 'package:flutter/material.dart';
import '../local/local_api.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

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
    'Berloku',
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

  // ✅ simple “success animation” (check icon pop)
  Future<void> _showSuccessDialog(String msg) async {
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
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

    // auto close after a moment
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
        title: const Text('Zgjedh muajin', style: TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in monthOptions)
                ListTile(
                  title: Text(_formatMonthLabel(m), style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: m == selectedMonth ? const Icon(Icons.check_circle) : null,
                  onTap: () => Navigator.pop(context, m),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
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
        title: const Text('Gabim', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(msg),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  // ---------- INVEST ALERT ----------
  Future<void> _openInvestDialog() async {
    amountC.clear();
    noteC.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Blej Mall (Investim)', style: TextStyle(fontWeight: FontWeight.w900)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulo')),
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
          title: const Text('Shto Shpenzim', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: expCategory,
                  items: expCategories
                      .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ))
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
                    labelText: expCategory == 'Rroga' ? 'Emri i punëtorit / shënim' : 'Shënim (opsional)',
                    hintText: expCategory == 'Rroga' ? 'p.sh. Arben - Rroga Janar' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulo')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
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
            // Month chooser
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(_formatMonthLabel(selectedMonth),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('Filter për statistika mujore'),
                trailing: const Icon(Icons.expand_more),
                onTap: _changeMonth,
              ),
            ),

            const SizedBox(height: 10),

            // Stats (SOT / MUAJ / TOTAL)
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

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statCard('Stok Total (Copë)', '${s?.totalStock ?? 0}', Icons.inventory_2),
                        _statCard('Vlera e Stokut (Final)', _money((s?.totalStockValueFinal ?? 0).toDouble()),
                            Icons.euro, tint: Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Quick actions (buttons)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
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

            // Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Regjistrimet e fundit',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('(shitje=gj.) (invest=kuqe) (exp=portokalli)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
              ...activity.map((a) {
                final isSale = a.type == 'SALE';
                final isInvest = a.type == 'INVEST';
                final isExpense = a.type == 'EXPENSE';

                final c = isSale ? Colors.green : (isExpense ? Colors.deepOrange : Colors.red);
                final sign = isSale ? '+' : '-';

                final icon = isSale
                    ? Icons.check_circle
                    : (isExpense ? Icons.receipt_long : Icons.shopping_cart);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.withOpacity(0.15),
                      child: Icon(icon, color: c),
                    ),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(a.sub),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$sign${_money(a.amount)}',
                          style: TextStyle(fontWeight: FontWeight.w900, color: c),
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
                  ),
                );
              }),
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
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.7)),
          ),
          child: Text(
            v,
            textAlign: TextAlign.center,
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: c),
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
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: c)),
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
      'Dhjetor'
    ];
    final idx = (m - 1).clamp(0, 11);
    return '${names[idx]} $y';
  }
}

// ✅ Success popup widget with tiny animation feel
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6)),
        boxShadow: const [BoxShadow(blurRadius: 18, spreadRadius: 2, color: Color(0x33000000))],
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
            child: const Icon(Icons.check_circle, color: Colors.green, size: 42),
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
