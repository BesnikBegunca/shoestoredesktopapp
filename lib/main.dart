import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shoe_store_manager/src/local/local_api.dart';
import 'package:shoe_store_manager/src/screens/boot_gate.dart';
import 'package:shoe_store_manager/src/theme/app_theme.dart';
import 'fullscreen/fullscreen_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FullscreenService fullscreenService = FullscreenService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalApi.I.init();
  await fullscreenService.initDesktopWindow();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const ToggleFullscreenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
            onInvoke: (ToggleFullscreenIntent intent) => fullscreenService.toggleFullscreen(),
          ),
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const BootGate(),
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: AppTheme.bg,
                  child: SafeArea(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: child!,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}
