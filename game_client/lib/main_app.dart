import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'game_app.dart';
import 'libgdx_compat/gdx.dart';
import 'level_loader.dart';
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

class _GameRoot extends StatelessWidget {
  const _GameRoot();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Game Example - Flutter',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SafeArea(child: _GameView())),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView();

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView>
    with SingleTickerProviderStateMixin {
  static const double _virtualWidth = 1280;
  static const double _virtualHeight = 720;

  final FocusNode _focusNode = FocusNode();
  final GameApp _game = GameApp();

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
          return Listener(
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

                  _resizeGameIfNeeded(gameWidth, gameHeight, letterboxedMode);

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
