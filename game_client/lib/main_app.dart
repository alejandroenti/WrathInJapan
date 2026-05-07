import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'app_data.dart';
import 'bg_music.dart';
import 'game_app.dart';
import 'libgdx_compat/gdx.dart';
import 'level_loader.dart';
import 'network_config.dart';
import 'play_screen.dart';
import 'waiting_room_view.dart';
import 'window_config.dart';

class MainApp {
  MainApp._();

  static Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await configureGameWindow('Wrath in Japan - The Game');
    runApp(const _GameRoot());
  }
}

class _GameRoot extends StatefulWidget {
  const _GameRoot();

  @override
  State<_GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<_GameRoot> {
  AppData? _pendingAppData;
  GameApp? _gameApp;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    BgMusic.instance.play();
  }

  @override
  void dispose() {
    _pendingAppData?.removeListener(_onPendingAppDataChanged);
    _pendingAppData?.dispose();
    BgMusic.instance.disposePlayer();
    super.dispose();
  }

  void _handleStartGame(NetworkConfig config) {
    final AppData appData = AppData(initialConfig: config);
    appData.addListener(_onPendingAppDataChanged);
    setState(() {
      _pendingAppData = appData;
      _isConnecting = true;
    });
  }

  void _cancelConnection() {
    _pendingAppData?.removeListener(_onPendingAppDataChanged);
    _pendingAppData?.dispose();
    setState(() {
      _pendingAppData = null;
      _isConnecting = false;
    });
  }

  void _onPendingAppDataChanged() {
    final AppData? appData = _pendingAppData;
    if (appData == null) return;

    if (appData.isRegistered) {
      final GameApp gameApp = GameApp(
        networkConfig: appData.networkConfig,
        appData: appData,
      );
      appData.removeListener(_onPendingAppDataChanged);
      setState(() {
        _pendingAppData = null;
        _isConnecting = false;
        _gameApp = gameApp;
      });
      return;
    }

    if (appData.rejectedName != null) {
      final String name = appData.rejectedName!;
      appData.rejectedName = null;
      appData.removeListener(_onPendingAppDataChanged);
      appData.dispose();
      setState(() {
        _pendingAppData = null;
        _isConnecting = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Nombre en uso'),
            content: Text(
              'El nombre "$name" ya está siendo usado por otro jugador. Por favor, elige otro nombre.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      });
    }
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
          child: _gameApp == null
              ? _ConfigurationScreen(
                  onStart: _handleStartGame,
                  isConnecting: _isConnecting,
                  onCancel: _cancelConnection,
                )
              : _GameView(
                  game: _gameApp!,
                  onBack: () => setState(() => _gameApp = null),
                ),
        ),
      ),
    );
  }
}

class _GameView extends StatefulWidget {
  final GameApp game;
  final VoidCallback onBack;

  const _GameView({required this.game, required this.onBack});

  @override
  State<_GameView> createState() => _GameViewState();
}

class _ScrollingBackground extends StatefulWidget {
  const _ScrollingBackground();

  @override
  State<_ScrollingBackground> createState() => _ScrollingBackgroundState();
}

class _ScrollingBackgroundState extends State<_ScrollingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double offset = -_controller.value * width;
            return OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: width,
                      height: height,
                      child: Image.asset(
                        'assets/media/menu_background.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      height: height,
                      child: Image.asset(
                        'assets/media/menu_background.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConfigurationScreen extends StatefulWidget {
  final ValueChanged<NetworkConfig> onStart;
  final bool isConnecting;
  final VoidCallback onCancel;

  const _ConfigurationScreen({
    required this.onStart,
    required this.isConnecting,
    required this.onCancel,
  });

  @override
  State<_ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<_ConfigurationScreen> {
  final TextEditingController _playerNameController = TextEditingController();
  String? _nameError;

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  void _startGame() {
    if (widget.isConnecting) return;
    final String playerName = _playerNameController.text.trim();
    if (playerName.isEmpty) {
      setState(() {
        _nameError = 'El nombre es obligatorio';
      });
      return;
    }

    setState(() {
      _nameError = null;
    });
    widget.onStart(
      NetworkConfig(
        serverOption: NetworkConfig.defaults.serverOption,
        playerName: playerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _ScrollingBackground(),
        Container(
          color: Colors.black.withValues(alpha: 0.35),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Text(
                        'Wrath in Japan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 6
                            ..color = Colors.yellow,
                        ),
                      ),
                      Text(
                        'Wrath in Japan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _playerNameController,
                    enabled: !widget.isConnecting,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tu nombre',
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: _nameError,
                      errorStyle: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      border: const OutlineInputBorder(),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _startGame(),
                    autofocus: true,
                  ),
                  const SizedBox(height: 24),
                  if (widget.isConnecting) ...<Widget>[
                    ElevatedButton(
                      onPressed: widget.onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Conectando...', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.white38),
                      ),
                      child: const Text('Jugar', style: TextStyle(fontSize: 18)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
  OverlayEntry? _waitingRoomEntry;
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
    _game = widget.game;
    _game.getAppData().addListener(_onAppDataChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await LevelLoader.initialize();
    } catch (_) {
      // Level assets not found; game canvas will use fallback level data.
    }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _insertWaitingRoomOverlay();
        }
      });
    }
  }

  void _insertWaitingRoomOverlay() {
    final AppData appData = _game.getAppData();
    _waitingRoomEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        final bool show = appData.phase == MatchPhase.waiting;
        if (!show) return const SizedBox.shrink();
        return WaitingRoomView(appData: appData);
      },
    );
    Overlay.of(context).insert(_waitingRoomEntry!);
  }

  @override
  void dispose() {
    _game.getAppData().removeListener(_onAppDataChanged);
    _ticker?.dispose();
    _focusNode.dispose();
    _waitingRoomEntry?.remove();
    _waitingRoomEntry = null;
    _game.dispose();
    super.dispose();
  }

  void _onAppDataChanged() {
    _waitingRoomEntry?.markNeedsBuild();
    final AppData appData = _game.getAppData();
    if (appData.phase == MatchPhase.playing) {
      BgMusic.instance.stop();
      BgMusic.instance.playGameplay();
    } else if (appData.phase == MatchPhase.results ||
        appData.phase == MatchPhase.finished) {
      BgMusic.instance.stopGameplay();
      BgMusic.instance.play();
    }
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
      return ListenableBuilder(
        listenable: _game.getAppData(),
        builder: (BuildContext context, Widget? _) {
          return WaitingRoomView(appData: _game.getAppData());
        },
      );
    }

    final AppData appData = _game.getAppData();
    // Fallback: show inline while overlay isn't inserted yet (single frame)
    final bool showWaitingRoom = _waitingRoomEntry == null &&
        appData.phase == MatchPhase.waiting;
    final bool showRestartOverlay =
        _game.getScreen() is PlayScreen &&
        (appData.phase == MatchPhase.finished || appData.phase == MatchPhase.results);

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
                if (showWaitingRoom)
                  Positioned.fill(
                    child: WaitingRoomView(appData: appData),
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
