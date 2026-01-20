import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum LicenseMode { unlicensed, active, expired_readonly, tampered }

class LicensePayload {
  final String v;
  final String product;
  final String customerId;

  /// ✅ PËR TEST: këtu e përdorim si MINUTA (jo ditë)
  final int validDays;

  final int? issuedAt;

  LicensePayload({
    required this.v,
    required this.product,
    required this.customerId,
    required this.validDays,
    this.issuedAt,
  });

  factory LicensePayload.fromJson(Map<String, dynamic> json) {
    return LicensePayload(
      v: json['v'] as String,
      product: json['product'] as String,
      customerId: json['customerId'] as String,
      validDays: json['validDays'] as int,
      issuedAt: json['issuedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'v': v,
      'product': product,
      'customerId': customerId,
      'validDays': validDays,
      if (issuedAt != null) 'issuedAt': issuedAt,
    };
  }
}

class LicenseState {
  final String key;
  final LicensePayload payload;
  final int activatedAt;
  final int expiresAt;
  final int lastSeen;

  LicenseState({
    required this.key,
    required this.payload,
    required this.activatedAt,
    required this.expiresAt,
    required this.lastSeen,
  });

  factory LicenseState.fromJson(Map<String, dynamic> json) {
    return LicenseState(
      key: json['key'] as String,
      payload: LicensePayload.fromJson(json['payload'] as Map<String, dynamic>),
      activatedAt: json['activatedAt'] as int,
      expiresAt: json['expiresAt'] as int,
      lastSeen: json['lastSeen'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'payload': payload.toJson(),
      'activatedAt': activatedAt,
      'expiresAt': expiresAt,
      'lastSeen': lastSeen,
    };
  }
}

class LicenseService {
  static const String _publicKeyBase64Url =
      '9GVfFLFS1CIldcLpudJneS-8STI3ZlJ4VAV6ujQQWlE='; // replace with real public key

  // ✅ DEV credentials (mos i le qeshtu n production)
  static const String _devUsername = 'dev';
  static const String _devPassword = 'dev123';

  // ✅ Private key (duhet me kon veç te developer-at / server)
  static const String _privateKeyBase64Url =
      'WC_VcsdfzWFGHZxGtNYtQFEVn6Pq256dbIR4rdUiinE='; // replace with real private key

  static final LicenseService I = LicenseService._();
  LicenseService._();

  late final Ed25519 _algorithm;
  late final SimplePublicKey _publicKey;

  Future<void> init() async {
    _algorithm = Ed25519();
    _publicKey = SimplePublicKey(
      base64Url.decode(_publicKeyBase64Url),
      type: KeyPairType.ed25519,
    );
  }

  Future<String> _getLicenseFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'license_state.json');
  }

  Future<LicenseState?> _loadLicenseState() async {
    try {
      final path = await _getLicenseFilePath();
      final file = File(path);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return LicenseState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLicenseState(LicenseState state) async {
    final path = await _getLicenseFilePath();
    final file = File(path);
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  /// ✅ Fshi licencën e ruajtur (për me leju key të ri)
  Future<void> clearLicense() async {
    try {
      final path = await _getLicenseFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<bool> verifyLicenseKey(String key) async {
    try {
      final parts = key.split('.');
      if (parts.length != 2) return false;

      final payloadBase64Url = parts[0];
      final signatureBase64Url = parts[1];

      final payloadBytes = base64Url.decode(payloadBase64Url);
      final signatureBytes = base64Url.decode(signatureBase64Url);

      final isValid = await _algorithm.verify(
        payloadBytes,
        signature: Signature(signatureBytes, publicKey: _publicKey),
      );
      if (!isValid) return false;

      final payloadJson = jsonDecode(utf8.decode(payloadBytes));
      final payload = LicensePayload.fromJson(payloadJson);

      // ✅ Validime (për test: 1 minutë)
      if (payload.v != '1') return false;
      if (payload.product != 'shoe_store_manager') return false;

      // ✅ Për 1 minutë test
      if (payload.validDays != 1) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  /// ✅ Aktivizo licencën
  /// - Nëse ke licencë të skaduar/tampered, e fshin dhe lejon key të ri.
  Future<void> activate(String key) async {
    // Nëse ekziston licencë e skaduar apo tampered, e pastrojmë
    final mode = await checkStatus();
    if (mode == LicenseMode.expired_readonly || mode == LicenseMode.tampered) {
      await clearLicense();
    }

    final isValid = await verifyLicenseKey(key);
    if (!isValid) throw Exception('Invalid license key');

    final parts = key.split('.');
    final payloadBase64Url = parts[0];
    final payloadBytes = base64Url.decode(payloadBase64Url);
    final payloadJson = jsonDecode(utf8.decode(payloadBytes));
    final payload = LicensePayload.fromJson(payloadJson);

    final now = DateTime.now().millisecondsSinceEpoch;

    /// ✅ payload.validDays = MINUTA (për test)
    final durationMs = payload.validDays * 60 * 1000;

    final expiresAt = now + durationMs;

    final state = LicenseState(
      key: key,
      payload: payload,
      activatedAt: now,
      expiresAt: expiresAt,
      lastSeen: now,
    );

    await _saveLicenseState(state);
  }

  /// ✅ Status + anti-tamper + refresh lastSeen
  Future<LicenseMode> checkStatus() async {
    final state = await _loadLicenseState();
    if (state == null) return LicenseMode.unlicensed;

    final now = DateTime.now().millisecondsSinceEpoch;

    // ✅ Anti-tamper: nëse e kthen kohën mbrapa ma shumë se 2 orë
    if (now < state.lastSeen - (2 * 60 * 60 * 1000)) {
      return LicenseMode.tampered;
    }

    // Nëse ka skaduar
    if (now > state.expiresAt) {
      return LicenseMode.expired_readonly;
    }

    // ✅ Update lastSeen vetëm kur është aktive
    final updatedState = LicenseState(
      key: state.key,
      payload: state.payload,
      activatedAt: state.activatedAt,
      expiresAt: state.expiresAt,
      lastSeen: now,
    );
    await _saveLicenseState(updatedState);

    return LicenseMode.active;
  }

  Future<LicenseState?> getLicenseState() async => _loadLicenseState();

  /// ✅ Sa ms kanë mbet deri në skadim (0 nëse s’ka ose ka skadu)
  Future<int> remainingMs() async {
    final state = await _loadLicenseState();
    if (state == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rem = state.expiresAt - now;
    return rem > 0 ? rem : 0;
  }

  /// ✅ Sa sekonda kanë mbet (0 nëse ka skadu)
  Future<int> remainingSeconds() async {
    final ms = await remainingMs();
    return (ms / 1000).ceil();
  }

  /// ✅ Countdown stream (tick çdo 1 sekondë)
  /// Kthen secondsLeft: 60..0
  Stream<int> countdownStream({
    Duration tick = const Duration(seconds: 1),
  }) async* {
    while (true) {
      final mode = await checkStatus();
      if (mode != LicenseMode.active) {
        yield 0;
        break;
      }

      final left = await remainingSeconds();
      yield left;

      if (left <= 0) break;

      await Future.delayed(tick);
    }
  }

  /// ✅ Format mm:ss për UI
  Future<String> remainingFormatted() async {
    final totalSec = await remainingSeconds();
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ✅ Developer authentication
  bool authenticateDeveloper(String username, String password) {
    return username == _devUsername && password == _devPassword;
  }

  // ✅ Generate license key (për test: 1 minutë)
  Future<String> generateLicenseKey(String customerId, {int? issuedAt}) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(
      base64Url.decode(_privateKeyBase64Url),
    );

    final payload = <String, dynamic>{
      'v': '1',
      'product': 'shoe_store_manager',
      'customerId': customerId,
      'validDays': 1, // ✅ 1 MINUTË
      if (issuedAt != null) 'issuedAt': issuedAt,
    };

    final payloadJson = jsonEncode(payload);
    final payloadBytes = utf8.encode(payloadJson);

    final payloadBase64Url = base64UrlEncode(payloadBytes);
    final signature = await _algorithm.sign(payloadBytes, keyPair: keyPair);
    final signatureBase64Url = base64UrlEncode(signature.bytes);

    return '$payloadBase64Url.$signatureBase64Url';
  }
}
