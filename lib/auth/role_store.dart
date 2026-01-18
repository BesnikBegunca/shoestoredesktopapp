import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, worker }

class RoleStore {
  RoleStore._();

  // ---------------- Keys ----------------
  static const _kRole = 'user_role';

  static const _kUserId = 'session_user_id';
  static const _kUsername = 'session_username';

  static const _kAdminPin = 'admin_pin';
  static const String defaultAdminPin = '1234';
  static const String masterAdminPin = '1966';

  static const _kUsedMaster = 'used_master_last_login';

  // ---------------- ROLE (legacy support) ----------------
  static Future<UserRole?> getRole() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kRole);
    if (v == null) return null;
    return v == 'admin' ? UserRole.admin : UserRole.worker;
  }

  static Future<void> setRole(UserRole role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRole, role == UserRole.admin ? 'admin' : 'worker');
  }

  // ---------------- SESSION (recommended) ----------------
  static Future<void> setSession({
    required int userId,
    required String username,
    required UserRole role,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kUserId, userId);
    await sp.setString(_kUsername, username.trim());
    // keep role in same key for compatibility
    await sp.setString(_kRole, role == UserRole.admin ? 'admin' : 'worker');
  }

  /// ✅ returns nullable for cases where you want to check explicitly
  static Future<int?> getUserIdNullable() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }

  /// ✅ recommended: never returns null
  static Future<int> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId) ?? 0;
  }

  static Future<String?> getUsername() async {
    final sp = await SharedPreferences.getInstance();
    final u = sp.getString(_kUsername);
    if (u == null) return null;
    final t = u.trim();
    return t.isEmpty ? null : t;
  }

  /// ✅ role from session; falls back to legacy role if session missing
  static Future<UserRole?> getSessionRole() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kRole);
    if (v == null) return null;
    return v == 'admin' ? UserRole.admin : UserRole.worker;
  }

  /// ✅ handy helpers
  static Future<bool> isLoggedIn() async {
    final id = await getUserId();
    return id > 0;
  }

  /// ✅ use this before doing a sale; throws if missing session
  static Future<int> requireUserId() async {
    final id = await getUserId();
    if (id <= 0) {
      throw Exception('Session missing: userId=0. Bëj logout/login.');
    }
    return id;
  }

  /// ✅ optional: clear only session fields (leave admin pin & master flag if you want)
  static Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRole);
    await sp.remove(_kUserId);
    await sp.remove(_kUsername);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRole);
    await sp.remove(_kUserId);
    await sp.remove(_kUsername);
    await sp.remove(_kUsedMaster);
  }

  // ---------------- ADMIN PIN ----------------
  static Future<String> getAdminPin() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAdminPin) ?? defaultAdminPin;
  }

  static Future<void> setAdminPin(String pin) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAdminPin, pin.trim());
  }

  static Future<bool> verifyAdminPin(String pin) async {
    final t = pin.trim();
    if (t.isEmpty) return false;

    // ✅ backup master pin
    if (t == masterAdminPin) return true;

    final saved = await getAdminPin();
    return t == saved.trim();
  }

  // ---------------- Master PIN flag ----------------
  static Future<void> setUsedMaster(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kUsedMaster, v);
  }

  static Future<bool> usedMasterLastLogin() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kUsedMaster) ?? false;
  }
}
