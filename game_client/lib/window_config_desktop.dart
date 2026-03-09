import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

Future<void> configureGameWindowImpl(String title) async {
  if (!_isDesktopPlatform() || title.isEmpty) {
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(title: title),
    () async {
      await windowManager.setTitle(title);
    },
  );
}

bool _isDesktopPlatform() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return false;
  }
}
