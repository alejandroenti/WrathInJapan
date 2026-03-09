import 'dart:ui' as ui;

import 'libgdx_compat/game_framework.dart';
import 'level_data.dart';
import 'runtime_transform.dart';
import 'libgdx_compat/viewport.dart';
import 'libgdx_compat/gdx_collections.dart';

class DebugOverlay {
  static const double zoneFillAlpha = 0.20;
  static const double zoneStrokeAlpha = 0.85;
  static const double pathAlpha = 0.90;
  static const double pathPointRadius = 2.2;

  final ShapeRenderer shapes = ShapeRenderer();

  void render(
    LevelData level,
    OrthographicCamera camera,
    bool showZones,
    bool showPaths,
    Array<RuntimeTransform> zoneRuntimeStates,
    Viewport viewport,
  ) {
    if (!showZones && !showPaths) {
      return;
    }

    if (showZones) {
      _renderZones(level, zoneRuntimeStates, camera, viewport);
    }
    if (showPaths) {
      _renderPaths(level, camera, viewport);
    }
  }

  void _renderZones(
    LevelData level,
    Array<RuntimeTransform> zoneRuntimeStates,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    shapes.begin(ShapeType.filled);
    for (int i = 0; i < level.zones.size; i++) {
      final LevelZone zone = level.zones.get(i);
      final RuntimeTransform? runtime = i < zoneRuntimeStates.size
          ? zoneRuntimeStates.get(i)
          : null;
      final double zoneX = runtime?.x ?? zone.x;
      final double zoneY = runtime?.y ?? zone.y;
      final ui.Rect? rect = _worldRectToScreen(
        camera,
        viewport,
        zoneX,
        zoneY,
        zone.width,
        zone.height,
      );
      if (rect == null) {
        continue;
      }
      shapes.setColor(zone.color.withValues(alpha: zoneFillAlpha));
      shapes.rect(rect.left, rect.top, rect.width, rect.height);
    }
    shapes.end();

    shapes.begin(ShapeType.line);
    for (int i = 0; i < level.zones.size; i++) {
      final LevelZone zone = level.zones.get(i);
      final RuntimeTransform? runtime = i < zoneRuntimeStates.size
          ? zoneRuntimeStates.get(i)
          : null;
      final double zoneX = runtime?.x ?? zone.x;
      final double zoneY = runtime?.y ?? zone.y;
      final ui.Rect? rect = _worldRectToScreen(
        camera,
        viewport,
        zoneX,
        zoneY,
        zone.width,
        zone.height,
      );
      if (rect == null) {
        continue;
      }
      shapes.setColor(zone.color.withValues(alpha: zoneStrokeAlpha));
      shapes.rect(rect.left, rect.top, rect.width, rect.height);
    }
    shapes.end();
  }

  void _renderPaths(
    LevelData level,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    shapes.begin(ShapeType.line);
    for (int i = 0; i < level.paths.size; i++) {
      final LevelPath path = level.paths.get(i);
      shapes.setColor(path.color.withValues(alpha: pathAlpha));

      for (int p = 0; p + 1 < path.points.size; p++) {
        final a = path.points.get(p);
        final b = path.points.get(p + 1);
        final ui.Offset? pa = _worldPointToScreen(camera, viewport, a.x, a.y);
        final ui.Offset? pb = _worldPointToScreen(camera, viewport, b.x, b.y);
        if (pa == null || pb == null) {
          continue;
        }
        shapes.line(pa.dx, pa.dy, pb.dx, pb.dy);
      }
    }
    shapes.end();
  }

  ui.Rect? _worldRectToScreen(
    OrthographicCamera camera,
    Viewport viewport,
    double x,
    double y,
    double width,
    double height,
  ) {
    final double viewW = viewport.worldWidth * camera.zoom;
    final double viewH = viewport.worldHeight * camera.zoom;
    final double left = camera.x - viewW * 0.5;
    final double top = camera.y - viewH * 0.5;

    final double sx = viewport.screenWidth / viewW;
    final double sy = viewport.screenHeight / viewH;

    final double dstX = (x - left) * sx;
    final double dstY = (y - top) * sy;
    final double dstW = width * sx;
    final double dstH = height * sy;

    if (dstX > viewport.screenWidth ||
        dstY > viewport.screenHeight ||
        dstX + dstW < 0 ||
        dstY + dstH < 0) {
      return null;
    }
    return ui.Rect.fromLTWH(dstX, dstY, dstW, dstH);
  }

  ui.Offset? _worldPointToScreen(
    OrthographicCamera camera,
    Viewport viewport,
    double x,
    double y,
  ) {
    final double viewW = viewport.worldWidth * camera.zoom;
    final double viewH = viewport.worldHeight * camera.zoom;
    final double left = camera.x - viewW * 0.5;
    final double top = camera.y - viewH * 0.5;

    final double sx = viewport.screenWidth / viewW;
    final double sy = viewport.screenHeight / viewH;

    final double dstX = (x - left) * sx;
    final double dstY = (y - top) * sy;
    if (dstX < -16 ||
        dstY < -16 ||
        dstX > viewport.screenWidth + 16 ||
        dstY > viewport.screenHeight + 16) {
      return null;
    }
    return ui.Offset(dstX, dstY);
  }

  void dispose() {
    shapes.dispose();
  }
}
