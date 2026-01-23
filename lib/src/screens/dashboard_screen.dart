import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../local/local_api.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  AdminStats? _stats;
  List<Map<String, dynamic>> _dailySalesData = [];
  List<Map<String, dynamic>> _recentSales = [];
  int _productCount = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final monthOptions = await LocalApi.I.getMonthOptions();
      final currentMonth = monthOptions.isNotEmpty ? monthOptions.first : _monthKey(DateTime.now());
      
      final stats = await LocalApi.I.getAdminStats(selectedMonth: currentMonth);
      final salesData = await LocalApi.I.getDailySalesData(days: 7);
      final recent = await LocalApi.I.getRecentSales(limit: 5);
      final products = await LocalApi.I.getProducts();
      
      final lowStock = products.where((p) => p.stockQty < 5).length;
      
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _dailySalesData = salesData;
        _recentSales = recent;
        _productCount = products.length;
        _lowStockCount = lowStock;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${(d.month).toString().padLeft(2, '0')}';

  String _formatCurrency(double amount) {
    return '€${amount.toStringAsFixed(2)}';
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // Simple Header
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.bgPage,
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/permbledhja.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Permbledhja',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.text,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rifresko',
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        if (_stats != null) _buildStatsCards(_stats!),
                        
                        const SizedBox(height: 24),
                        
                        // Charts and Tables Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column - Charts
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildSalesChart(),
                                  const SizedBox(height: 24),
                                  _buildCategoryChart(),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Right Column - Quick Info
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildQuickStats(),
                                  const SizedBox(height: 24),
                                  _buildRecentSales(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AdminStats stats) {
    return Row(
      children: [
        Expanded(
          child: _statsCard(
            title: 'Shitje Sot',
            value: _formatCurrency(stats.totalSalesToday),
            subtitle: '${stats.countSalesToday} transaksione',
            icon: Icons.shopping_cart,
            color: Colors.blue,
            trend: stats.totalSalesToday > 0 ? '+' : '',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statsCard(
            title: 'Fitimi Sot',
            value: _formatCurrency(stats.totalProfitToday),
            subtitle: 'Profit i ditës',
            icon: Icons.trending_up,
            color: Colors.green,
            trend: stats.totalProfitToday > 0 ? '+' : '',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statsCard(
            title: 'Shitje Muaji',
            value: _formatCurrency(stats.totalSalesMonth),
            subtitle: '${stats.countSalesMonth} transaksione',
            icon: Icons.calendar_month,
            color: Colors.purple,
            trend: '',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statsCard(
            title: 'Totali',
            value: _formatCurrency(stats.totalSalesAll),
            subtitle: '${stats.countSalesAll} total',
            icon: Icons.account_balance_wallet,
            color: Colors.orange,
            trend: '',
          ),
        ),
      ],
    );
  }

  Widget _statsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
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
            blurRadius: 10,
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
              if (trend.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
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
              fontSize: 24,
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

  Widget _buildSalesChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Shitjet e Javës së Fundit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '7 ditë',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            height: 250,
            child: _dailySalesData.isEmpty
                ? Center(
                    child: Text(
                      'S\'ka të dhëna',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final date = _dailySalesData[groupIndex]['dayKey'] ?? '';
                            final total = _dailySalesData[groupIndex]['total'] ?? 0.0;
                            return BarTooltipItem(
                              '$date\n${_formatCurrency(total)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _dailySalesData.length) {
                                final dayKey = _dailySalesData[index]['dayKey'] ?? '';
                                final parts = dayKey.split('-');
                                if (parts.length >= 3) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${parts[2]}/${parts[1]}',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '€${value.toInt()}',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppTheme.stroke,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        _dailySalesData.length,
                        (index) {
                          final total = (_dailySalesData[index]['total'] as num?)?.toDouble() ?? 0.0;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: total,
                                color: Colors.blue.shade700,
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    if (_dailySalesData.isEmpty) return 1000;
    final maxValue = _dailySalesData.map((d) => (d['total'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }

  Widget _buildCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Përmbledhje Financiare',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 24),
          
          if (_stats != null) ...[
            _financialRow('Shitje Totale', _stats!.totalSalesMonth, Colors.blue),
            const SizedBox(height: 12),
            _financialRow('Fitimi Bruto', _stats!.totalProfitMonth, Colors.green),
            const SizedBox(height: 12),
            _financialRow('Shpenzime', _stats!.totalExpensesMonth, Colors.red),
            const Divider(height: 32),
            _financialRow(
              'Fitimi Neto',
              _stats!.totalProfitMonth - _stats!.totalExpensesMonth,
              Colors.purple,
              isLarge: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _financialRow(String label, double amount, Color color, {bool isLarge = false}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: isLarge ? 40 : 30,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isLarge ? FontWeight.w900 : FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            fontSize: isLarge ? 18 : 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 20),
          
          _quickStatRow(
            'Produkte Totale',
            _productCount.toString(),
            Icons.inventory_2,
            Colors.blue,
          ),
          const Divider(height: 24),
          _quickStatRow(
            'Stok i Ulët',
            _lowStockCount.toString(),
            Icons.warning_amber,
            Colors.orange,
          ),
          const Divider(height: 24),
          _quickStatRow(
            'Shitje Sot',
            _stats?.countSalesToday.toString() ?? '0',
            Icons.shopping_bag,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _quickStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSales() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shitje të Fundit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_recentSales.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'S\'ka shitje ende',
                  style: TextStyle(color: AppTheme.muted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSales.length > 5 ? 5 : _recentSales.length,
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (_, i) {
                final sale = _recentSales[i];
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale['invoiceNo'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(sale['createdAtMs'] ?? 0),
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency((sale['total'] as num?)?.toDouble() ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
