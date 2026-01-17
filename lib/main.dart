import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shoe_store_manager/src/local/local_api.dart';
import 'package:shoe_store_manager/src/screens/boot_gate.dart';
import 'package:shoe_store_manager/src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ init database / local api
  await LocalApi.I.init();

  // ✅ init window manager (DESKTOP)
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: 'Shoe Store Manager',
    center: true,
    minimumSize: Size(1200, 800), // opsionale – mos u bo shumë i vogël
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize(); // 🔥 hapet full size
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const BootGate(),
    );
  }
}
