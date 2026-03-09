import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'input_state.dart';

class Gdx {
  static final Input input = Input();
  static final Graphics graphics = Graphics();
  static final App app = App();
}

class App {
  void error(String tag, String message, [Object? error]) {
    // ignore: avoid_print
    print('[$tag] $message ${error ?? ''}');
  }

  void log(String tag, String message) {
    // ignore: avoid_print
    print('[$tag] $message');
  }
}

class Graphics {
  double _deltaTime = 0;
  int _width = 1;
  int _height = 1;
  ui.Canvas? _canvas;

  double getDeltaTime() => _deltaTime;

  int getWidth() => _width;

  int getHeight() => _height;

  ui.Canvas getCanvas() {
    final ui.Canvas? canvas = _canvas;
    if (canvas == null) {
      throw StateError('No active canvas in this frame');
    }
    return canvas;
  }

  void beginFrame(ui.Canvas canvas, int width, int height, double deltaTime) {
    _canvas = canvas;
    _width = width <= 0 ? 1 : width;
    _height = height <= 0 ? 1 : height;
    _deltaTime = deltaTime;
  }

  void endFrame() {
    _canvas = null;
  }
}

class Input {
  static final KeysData keys = KeysData();
  static final ButtonsData buttons = ButtonsData();

  final InputState _state = InputState();

  void onKeyDown(int keycode) {
    _state.onKeyDown(keycode);
  }

  void onKeyUp(int keycode) {
    _state.onKeyUp(keycode);
  }

  void onPointerDown(double x, double y) {
    _state.onPointerDown(x, y);
  }

  void onPointerMove(double x, double y) {
    _state.onPointerMove(x, y);
  }

  void onPointerUp(double x, double y) {
    _state.onPointerUp(x, y);
  }

  bool isKeyPressed(int keycode) => _state.isKeyPressed(keycode);

  bool isKeyJustPressed(int keycode) => _state.isKeyJustPressed(keycode);

  bool justTouched() => _state.justTouched();

  int getX() => _state.getX();

  int getY() => _state.getY();

  void endFrame() {
    _state.endFrame();
  }

  void setInputProcessor(Object? processor) {
    if (processor == null) {
      return;
    }
  }
}

class KeysData {
  final int up = 19;
  final int down = 20;
  final int left = 21;
  final int right = 22;
  final int w = 51;
  final int a = 29;
  final int s = 47;
  final int d = 32;
  final int enter = 66;
  final int space = 62;
  final int escape = 111;
  final int f3 = 292;
  final int shiftLeft = 59;
  final int shiftRight = 60;
  final int r = 46;
}

class ButtonsData {
  final int left = 0;
}

int? logicalKeyToGdxKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) {
    return Input.keys.up;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return Input.keys.down;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return Input.keys.left;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return Input.keys.right;
  }
  if (key == LogicalKeyboardKey.escape) {
    return Input.keys.escape;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return Input.keys.enter;
  }
  if (key == LogicalKeyboardKey.space) {
    return Input.keys.space;
  }
  if (key == LogicalKeyboardKey.f3) {
    return Input.keys.f3;
  }
  if (key == LogicalKeyboardKey.shiftLeft) {
    return Input.keys.shiftLeft;
  }
  if (key == LogicalKeyboardKey.shiftRight) {
    return Input.keys.shiftRight;
  }

  if (key == LogicalKeyboardKey.keyW) {
    return Input.keys.w;
  }
  if (key == LogicalKeyboardKey.keyA) {
    return Input.keys.a;
  }
  if (key == LogicalKeyboardKey.keyS) {
    return Input.keys.s;
  }
  if (key == LogicalKeyboardKey.keyD) {
    return Input.keys.d;
  }
  if (key == LogicalKeyboardKey.keyR) {
    return Input.keys.r;
  }
  return null;
}
