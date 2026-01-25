import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FullscreenService {
  bool _isFullscreen = false;

  bool get isFullscreen => _isFullscreen;

  Future<void> initDesktopWindow() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: 'Shoe Store Manager',
      center: true,
      skipTaskbar: false,
      fullScreen: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setSize(Size(1400, 900));
      await windowManager.center();
      await windowManager.setResizable(true);
      await windowManager.setMinimizable(true);
      await windowManager.setMaximizable(true);
      await windowManager.setClosable(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
      _isFullscreen = true;
    });
  }

  Future<void> setFullscreen(bool value) async {
    await windowManager.setFullScreen(value);
    if (value) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
    _isFullscreen = value;
  }

  Future<void> toggleFullscreen() async {
    await setFullscreen(!_isFullscreen);
  }
}
