import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, worker }

class RoleStore {
  static const _kRole = 'user_role';

  static const _kAdminPin = 'admin_pin';
  static const String defaultAdminPin = '1234';
  static const String masterAdminPin = '1966';

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

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRole);
  }

  static Future<String> getAdminPin() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAdminPin) ?? defaultAdminPin;
  }

  static Future<void> setAdminPin(String pin) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAdminPin, pin);
  }

  static Future<bool> verifyAdminPin(String pin) async {
    final t = pin.trim();
    if (t == masterAdminPin) return true; // ✅ backup
    final saved = await getAdminPin();
    return t == saved.trim();
  }

  static const _kUsedMaster = 'used_master_last_login';

  static Future<void> setUsedMaster(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kUsedMaster, v);
  }

  static Future<bool> usedMasterLastLogin() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kUsedMaster) ?? false;
  }
}
