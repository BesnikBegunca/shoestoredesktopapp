class Sale {
  final int id;
  final String invoiceNo;
  final int? userId;
  final double total;
  final double profitTotal;
  final String dayKey;
  final String monthKey;
  final int createdAtMs;
  final int? revertedAtMs;
  final int? settledAtMs;

  const Sale({
    required this.id,
    required this.invoiceNo,
    this.userId,
    required this.total,
    required this.profitTotal,
    required this.dayKey,
    required this.monthKey,
    required this.createdAtMs,
    this.revertedAtMs,
    this.settledAtMs,
  });

  bool get isReverted => revertedAtMs != null;
  bool get isSettled => settledAtMs != null;

  static Sale fromRow(Map<String, Object?> r) => Sale(
        id: (r['id'] as int?) ?? 0,
        invoiceNo: (r['invoiceNo'] as String?) ?? '',
        userId: r['userId'] as int?,
        total: ((r['total'] as num?) ?? 0).toDouble(),
        profitTotal: ((r['profitTotal'] as num?) ?? 0).toDouble(),
        dayKey: (r['dayKey'] as String?) ?? '',
        monthKey: (r['monthKey'] as String?) ?? '',
        createdAtMs: (r['createdAtMs'] as int?) ?? 0,
        revertedAtMs: r['revertedAtMs'] as int?,
        settledAtMs: r['settledAtMs'] as int?,
      );
}
