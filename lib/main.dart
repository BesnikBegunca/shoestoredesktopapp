import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shoe_store_manager/src/local/local_api.dart';
import 'package:shoe_store_manager/src/screens/app_shell.dart';
import 'package:shoe_store_manager/src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalApi.I.init();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
