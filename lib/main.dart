import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shoe_store_manager/src/license/license_service.dart';
import 'package:shoe_store_manager/src/local/local_api.dart';
import 'package:shoe_store_manager/src/screens/boot_gate.dart';
import 'package:shoe_store_manager/src/screens/license_screen.dart';
import 'package:shoe_store_manager/src/theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalApi.I.init();
  await LicenseService.I.init();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: 'Shoe Store Manager',
    center: true,
    minimumSize: Size(1200, 800),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<int>? _licenseSubscription;

  @override
  void initState() {
    super.initState();
    _startLicenseCheck();
  }

  @override
  void dispose() {
    _licenseSubscription?.cancel();
    super.dispose();
  }

  void _startLicenseCheck() {
    // First, check current status
    LicenseService.I.checkStatus().then((status) {
      if (status == LicenseMode.expired_readonly ||
          status == LicenseMode.unlicensed) {
        _navigateToLicenseScreen();
      }
    });

    // Then listen to countdown stream for real-time expiry detection
    _licenseSubscription = LicenseService.I.countdownStream().listen((seconds) {
      if (seconds == 0) {
        _navigateToLicenseScreen();
      }
    });
  }

  void _navigateToLicenseScreen() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LicenseScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const BootGate(),
    );
  }
}
