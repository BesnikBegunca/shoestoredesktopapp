import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shoe_store_manager/src/local/local_api.dart';
import 'package:shoe_store_manager/src/screens/boot_gate.dart';
import 'package:shoe_store_manager/src/theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalApi.I.init();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: 'Shoe Store Manager',
    center: true,
    fullScreen: false,
    skipTaskbar: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Set window size to a reasonable default
    await windowManager.setSize(const Size(1400, 900));
    await windowManager.center();
    
    // Enable window controls (close, minimize, maximize)
    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setClosable(true);
    
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const BootGate(),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppTheme.bg,
          child: child,
        );
      },
    );
  }
}
