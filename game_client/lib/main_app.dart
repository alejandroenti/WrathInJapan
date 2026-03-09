import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/gdx.dart';
import 'level_loader.dart';
import 'network_config.dart';
import 'play_screen.dart';
import 'window_config.dart';

class MainApp {
  MainApp._();

  static Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await configureGameWindow('Game Example - Flutter');
    runApp(const _GameRoot());
  }
}

class _GameRoot extends StatefulWidget {
  const _GameRoot();

  @override
  State<_GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<_GameRoot> {
  NetworkConfig? _networkConfig;

  void _handleStartGame(NetworkConfig config) {
    setState(() {
      _networkConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Example - Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: Scaffold(
        body: SafeArea(
          child: _networkConfig == null
              ? _ConfigurationScreen(onStart: _handleStartGame)
              : _GameView(networkConfig: _networkConfig!),
        ),
      ),
    );
  }
}

class _GameView extends StatefulWidget {
  final NetworkConfig networkConfig;

  const _GameView({required this.networkConfig});

  @override
  State<_GameView> createState() => _GameViewState();
}

class _ConfigurationScreen extends StatefulWidget {
  final ValueChanged<NetworkConfig> onStart;

  const _ConfigurationScreen({required this.onStart});

  @override
  State<_ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<_ConfigurationScreen> {
  ServerOption _serverOption = NetworkConfig.defaults.serverOption;
  final TextEditingController _playerNameController = TextEditingController(
    text: NetworkConfig.defaults.playerName,
  );
  String? _nameError;

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  void _startGame() {
    final String playerName = _playerNameController.text.trim();
    if (playerName.isEmpty) {
      setState(() {
        _nameError = 'Player name is required';
      });
      return;
    }

    setState(() {
      _nameError = null;
    });
    widget.onStart(
      NetworkConfig(serverOption: _serverOption, playerName: playerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Game Configuration',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Server',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ServerOption>(
                    segments: const <ButtonSegment<ServerOption>>[
                      ButtonSegment<ServerOption>(
                        value: ServerOption.local,
                        label: Text('Local'),
                      ),
                      ButtonSegment<ServerOption>(
                        value: ServerOption.remote,
                        label: Text('Remote'),
                      ),
                    ],
                    selected: <ServerOption>{_serverOption},
                    onSelectionChanged: (Set<ServerOption> selected) {
                      if (selected.isEmpty) {
                        return;
                      }
                      setState(() {
                        _serverOption = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _serverOption == ServerOption.local
                        ? 'ws://127.0.0.1:3000'
                        : 'wss://${NetworkConfig.remoteServer}:443',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _playerNameController,
                    decoration: InputDecoration(
                      labelText: 'Player name',
                      errorText: _nameError,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _startGame(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _startGame,
                    child: const Text('Start Game'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameViewState extends State<_GameView>
    with SingleTickerProviderStateMixin {
  static const double _virtualWidth = 1280;
  static const double _virtualHeight = 720;

  final FocusNode _focusNode = FocusNode();
  late final GameApp _game;

  Ticker? _ticker;
  Duration? _lastTick;
  double _delta = 1 / 60;
  bool _ready = false;
  Size _surfaceSize = Size.zero;
  double _scale = 1;
  double _offsetX = 0;
  double _offsetY = 0;
  int _lastGameWidth = -1;
  int _lastGameHeight = -1;
  bool _lastLetterboxedMode = true;

  @override
  void initState() {
    super.initState();
    _game = GameApp(networkConfig: widget.networkConfig);
    _initialize();
  }

  Future<void> _initialize() async {
    await LevelLoader.initialize();
    await _game.create();
    _ticker = createTicker((Duration elapsed) {
      if (_lastTick == null) {
        _lastTick = elapsed;
      } else {
        final double dt = (elapsed - _lastTick!).inMicroseconds / 1000000.0;
        _delta = dt.isFinite && dt > 0 ? dt : (1 / 60);
        _lastTick = elapsed;
      }
      if (mounted) {
        setState(() {});
      }
    });
    _ticker!.start();

    if (mounted) {
      setState(() {
        _ready = true;
      });
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _game.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final int? keycode = logicalKeyToGdxKey(event.logicalKey);
    if (keycode == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      Gdx.input.onKeyDown(keycode);
    } else if (event is KeyUpEvent) {
      Gdx.input.onKeyUp(keycode);
    }
    return KeyEventResult.handled;
  }

  bool _isLetterboxedMode() {
    return _game.getScreen() is! PlayScreen;
  }

  Offset? _toGameOffset(Offset localPosition) {
    if (_surfaceSize == Size.zero) {
      return null;
    }

    if (!_isLetterboxedMode()) {
      if (localPosition.dx < 0 ||
          localPosition.dy < 0 ||
          localPosition.dx > _surfaceSize.width ||
          localPosition.dy > _surfaceSize.height) {
        return null;
      }
      return localPosition;
    }

    final double x = (localPosition.dx - _offsetX) / _scale;
    final double y = (localPosition.dy - _offsetY) / _scale;
    if (x < 0 || y < 0 || x > _virtualWidth || y > _virtualHeight) {
      return null;
    }
    return Offset(x, y);
  }

  void _updateLetterbox(Size size) {
    final double sx = size.width / _virtualWidth;
    final double sy = size.height / _virtualHeight;
    _scale = math.min(sx, sy);
    final double drawWidth = _virtualWidth * _scale;
    final double drawHeight = _virtualHeight * _scale;
    _offsetX = (size.width - drawWidth) * 0.5;
    _offsetY = (size.height - drawHeight) * 0.5;
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) {
      return;
    }
    Gdx.input.onPointerDown(gameOffset.dx, gameOffset.dy);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) {
      return;
    }
    Gdx.input.onPointerMove(gameOffset.dx, gameOffset.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) {
      return;
    }
    Gdx.input.onPointerUp(gameOffset.dx, gameOffset.dy);
  }

  void _resizeGameIfNeeded(int width, int height, bool letterboxedMode) {
    if (width == _lastGameWidth &&
        height == _lastGameHeight &&
        letterboxedMode == _lastLetterboxedMode) {
      return;
    }
    _lastGameWidth = width;
    _lastGameHeight = height;
    _lastLetterboxedMode = letterboxedMode;
    _game.resize(width, height);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(color: Colors.black);
    }

    final AppData appData = _game.getAppData();
    final bool showRestartOverlay =
        _game.getScreen() is PlayScreen && appData.phase == MatchPhase.finished;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, KeyEvent event) => _onKeyEvent(event),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _surfaceSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_isLetterboxedMode()) {
            _updateLetterbox(_surfaceSize);
          } else {
            _scale = 1;
            _offsetX = 0;
            _offsetY = 0;
          }
          final double reservedRightWidth =
              constraints.maxWidth > (PlayScreen.leaderboardWidth + 180)
              ? PlayScreen.leaderboardWidth
              : 0;
          final double overlayAreaWidth = math.max(
            0,
            constraints.maxWidth - reservedRightWidth,
          );
          final double restartButtonWidth = math.min(
            280,
            math.max(180, overlayAreaWidth - 48),
          );
          final double restartButtonLeft = math.max(
            24,
            (overlayAreaWidth - restartButtonWidth) * 0.5,
          );
          final double restartButtonTop = math.min(
            constraints.maxHeight - 84,
            constraints.maxHeight * 0.64,
          );
          return Listener(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: CustomPaint(
                    painter: _GamePainter(
                      onPaint: (Canvas canvas, Size size) {
                        final bool letterboxedMode = _isLetterboxedMode();
                        final int gameWidth;
                        final int gameHeight;

                        if (letterboxedMode) {
                          _updateLetterbox(size);
                          gameWidth = _virtualWidth.round();
                          gameHeight = _virtualHeight.round();
                        } else {
                          _scale = 1;
                          _offsetX = 0;
                          _offsetY = 0;
                          gameWidth = math.max(1, size.width.round());
                          gameHeight = math.max(1, size.height.round());
                        }

                        _resizeGameIfNeeded(
                          gameWidth,
                          gameHeight,
                          letterboxedMode,
                        );

                        if (letterboxedMode) {
                          canvas.drawRect(
                            Offset.zero & size,
                            Paint()..color = Colors.black,
                          );
                          canvas.save();
                          canvas.translate(_offsetX, _offsetY);
                          canvas.scale(_scale, _scale);
                          Gdx.graphics.beginFrame(
                            canvas,
                            gameWidth,
                            gameHeight,
                            _delta,
                          );
                          _game.render(_delta);
                          Gdx.graphics.endFrame();
                          canvas.restore();
                        } else {
                          Gdx.graphics.beginFrame(
                            canvas,
                            gameWidth,
                            gameHeight,
                            _delta,
                          );
                          _game.render(_delta);
                          Gdx.graphics.endFrame();
                        }
                        Gdx.input.endFrame();
                      },
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (showRestartOverlay)
                  Positioned(
                    left: restartButtonLeft,
                    top: restartButtonTop,
                    width: restartButtonWidth,
                    child: FilledButton(
                      onPressed: appData.canRequestMatchRestart
                          ? appData.requestMatchRestart
                          : null,
                      child: const Text('Restart Match'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final void Function(Canvas canvas, Size size) onPaint;

  _GamePainter({required this.onPaint});

  @override
  void paint(Canvas canvas, Size size) {
    onPaint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
