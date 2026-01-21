class AppUser {
  final int id;
  final String username;
  final String role; // 'superadmin' | 'admin' | 'worker'
  final bool active;
  final int createdAtMs;
  final int? businessId; // nullable - NULL për superadmin, ID e biznesit për user-at e biznesit

  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.active,
    required this.createdAtMs,
    this.businessId,
  });

  bool get isSuperadmin => role == 'superadmin';
  bool get isAdmin => role == 'admin';
  bool get isWorker => role == 'worker';

  static AppUser fromRow(Map<String, Object?> r) => AppUser(
    id: (r['id'] as int?) ?? 0,
    username: (r['username'] as String?) ?? '',
    role: (r['role'] as String?) ?? 'worker',
    active: ((r['active'] as int?) ?? 1) == 1,
    createdAtMs: (r['createdAtMs'] as int?) ?? 0,
    businessId: r['businessId'] as int?,
  );
}
