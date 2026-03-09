import 'dart:math' as math;
import 'dart:ui';

import 'math_types.dart';

class OrthographicCamera {
  double x = 0;
  double y = 0;
  double zoom = 1;
  Object? combined;

  void setPosition(double nextX, double nextY) {
    x = nextX;
    y = nextY;
  }

  void update() {}
}

abstract class Viewport {
  final double baseWorldWidth;
  final double baseWorldHeight;
  final OrthographicCamera camera;

  double _screenWidth = 1;
  double _screenHeight = 1;
  double _worldWidth = 1;
  double _worldHeight = 1;

  Viewport(this.baseWorldWidth, this.baseWorldHeight, this.camera) {
    _worldWidth = baseWorldWidth;
    _worldHeight = baseWorldHeight;
  }

  void update(double width, double height, bool centerCamera) {
    _screenWidth = width <= 0 ? 1 : width;
    _screenHeight = height <= 0 ? 1 : height;
    _updateWorldSize();
    if (centerCamera) {
      camera.setPosition(_worldWidth * 0.5, _worldHeight * 0.5);
    }
  }

  void _updateWorldSize();

  double get worldWidth => _worldWidth;

  double get worldHeight => _worldHeight;

  double get screenWidth => _screenWidth;

  double get screenHeight => _screenHeight;

  void setWorldSize(double width, double height) {
    _worldWidth = width;
    _worldHeight = height;
  }

  Rect worldToScreenRect(
    double worldX,
    double worldY,
    double worldWidth,
    double worldHeight,
  ) {
    final Rect worldBounds = _worldBounds();
    final double sx = screenWidth / worldBounds.width;
    final double sy = screenHeight / worldBounds.height;
    return Rect.fromLTWH(
      (worldX - worldBounds.left) * sx,
      (worldY - worldBounds.top) * sy,
      worldWidth * sx,
      worldHeight * sy,
    );
  }

  Offset worldToScreenPoint(double worldX, double worldY) {
    final Rect worldBounds = _worldBounds();
    final double sx = screenWidth / worldBounds.width;
    final double sy = screenHeight / worldBounds.height;
    return Offset(
      (worldX - worldBounds.left) * sx,
      (worldY - worldBounds.top) * sy,
    );
  }

  Rect _worldBounds() {
    final double halfW = worldWidth * 0.5 * camera.zoom;
    final double halfH = worldHeight * 0.5 * camera.zoom;
    return Rect.fromLTWH(
      camera.x - halfW,
      camera.y - halfH,
      halfW * 2,
      halfH * 2,
    );
  }

  void apply() {}

  OrthographicCamera getCamera() => camera;

  Vector3 unproject(Vector3 vector) {
    final Rect worldBounds = _worldBounds();
    final double sx = worldBounds.width / screenWidth;
    final double sy = worldBounds.height / screenHeight;
    vector.x = worldBounds.left + vector.x * sx;
    vector.y = worldBounds.top + vector.y * sy;
    return vector;
  }
}

class FitViewport extends Viewport {
  FitViewport(super.worldWidth, super.worldHeight, super.camera);

  @override
  void _updateWorldSize() {
    final double aspect = screenWidth / screenHeight;
    final double baseAspect = baseWorldWidth / baseWorldHeight;
    if (aspect > baseAspect) {
      setWorldSize(baseWorldHeight * aspect, baseWorldHeight);
    } else {
      setWorldSize(baseWorldWidth, baseWorldWidth / aspect);
    }
  }
}

class ExtendViewport extends Viewport {
  ExtendViewport(super.worldWidth, super.worldHeight, super.camera);

  @override
  void _updateWorldSize() {
    final double aspect = screenWidth / screenHeight;
    final double baseAspect = baseWorldWidth / baseWorldHeight;
    if (aspect > baseAspect) {
      setWorldSize(baseWorldWidth * (aspect / baseAspect), baseWorldHeight);
    } else {
      setWorldSize(baseWorldWidth, baseWorldHeight * (baseAspect / aspect));
    }
  }
}

class StretchViewport extends Viewport {
  StretchViewport(super.worldWidth, super.worldHeight, super.camera);

  @override
  void _updateWorldSize() {
    setWorldSize(baseWorldWidth, baseWorldHeight);
  }
}

class ScreenViewport extends Viewport {
  ScreenViewport(OrthographicCamera camera) : super(1, 1, camera);

  @override
  void _updateWorldSize() {
    setWorldSize(math.max(1, screenWidth), math.max(1, screenHeight));
  }
}
