import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

void main(List<String> args) async {
  if (args.isEmpty || args[0] == '--help') {
    print('Usage: dart keygen.dart <command>');
    print('');
    print('Commands:');
    print(
        '  generate-keys    Generate a new Ed25519 key pair and print public key');
    print(
        '  generate-license <customerId> <product> [issuedAt]  Generate license key');
    print('');
    print('Examples:');
    print('  dart keygen.dart generate-keys');
    print('  dart keygen.dart generate-license customer123 shoe_store_manager');
    return;
  }

  final command = args[0];

  switch (command) {
    case 'generate-keys':
      await generateKeys();
      break;
    case 'generate-license':
      if (args.length < 3) {
        print('Error: generate-license requires customerId and product');
        return;
      }
      final customerId = args[1];
      final product = args[2];
      final issuedAt = args.length > 3 ? int.tryParse(args[3]) : null;
      await generateLicense(customerId, product, issuedAt);
      break;
    default:
      print('Unknown command: $command');
  }
}

Future<void> generateKeys() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();

  final publicKeyBytes = publicKey.bytes;
  final publicKeyBase64Url = base64UrlEncode(publicKeyBytes);

  print('New Ed25519 Key Pair Generated:');
  print('');
  print('Public Key (embed in app): $publicKeyBase64Url');
  print('');
  print('Private Key (keep secret, use for signing):');
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
  final privateKeyBase64Url = base64UrlEncode(privateKeyBytes);
  print(privateKeyBase64Url);
  print('');
  print('⚠️  Keep the private key secure! Never share it.');
}

Future<void> generateLicense(
    String customerId, String product, int? issuedAt) async {
  print('Enter the private key (base64url):');
  final privateKeyInput = stdin.readLineSync();
  if (privateKeyInput == null || privateKeyInput.isEmpty) {
    print('Error: Private key required');
    return;
  }

  final privateKeyBytes = base64Url.decode(privateKeyInput);
  final keyPair = await Ed25519().newKeyPairFromSeed(privateKeyBytes);

  final payload = {
    'v': '1',
    'product': product,
    'customerId': customerId,
    'validDays': 1, // 1 minute
    if (issuedAt != null) 'issuedAt': issuedAt,
  };

  final payloadJson = jsonEncode(payload);
  final payloadBytes = utf8.encode(payloadJson);
  final payloadBase64Url = base64UrlEncode(payloadBytes);

  final signature = await Ed25519().sign(
    payloadBytes,
    keyPair: keyPair,
  );

  final signatureBase64Url = base64UrlEncode(signature.bytes);

  final licenseKey = '$payloadBase64Url.$signatureBase64Url';

  print('');
  print('License Key Generated:');
  print(licenseKey);
  print('');
  print('Payload: $payloadJson');
}
