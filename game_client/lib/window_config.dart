import 'window_config_stub.dart'
    if (dart.library.io) 'window_config_desktop.dart';

Future<void> configureGameWindow(String title) =>
    configureGameWindowImpl(title);
