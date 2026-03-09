import 'dart:math' as math;
import 'dart:ui' as ui;

import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'level_data.dart';
import 'runtime_transform.dart';
import 'libgdx_compat/viewport.dart';

class LevelRenderer {
  static const double minDepthProjectionFactor = 0.25;
  static const double maxDepthProjectionFactor = 4.0;

  final ObjectMap<String, List<List<TextureRegion>>> splitCache =
      ObjectMap<String, List<List<TextureRegion>>>();

  void render(
    LevelData level,
    AssetManager assets,
    SpriteBatch batch,
    OrthographicCamera camera,
    Array<SpriteRuntimeState> spriteRuntimeStates,
    List<bool> layerVisibilityStates,
    Array<RuntimeTransform> layerRuntimeStates,
    Viewport viewport,
  ) {
    final List<double> depths = _collectDepths(level);
    depths.sort((double a, double b) => b.compareTo(a));

    final double baseZoom = camera.zoom;
    for (final double depth in depths) {
      final double projectionFactor = _depthProjectionFactorForDepth(
        depth,
        level.depthSensitivity,
      );
      camera.zoom = baseZoom / projectionFactor;
      camera.update();

      _renderLayersAtDepth(
        level.layers,
        depth,
        assets,
        batch,
        layerVisibilityStates,
        layerRuntimeStates,
        camera,
        viewport,
      );
      _renderSpritesAtDepth(
        level.sprites,
        spriteRuntimeStates,
        depth,
        assets,
        batch,
        camera,
        viewport,
      );
    }

    camera.zoom = baseZoom;
    camera.update();
  }

  List<double> _collectDepths(LevelData level) {
    final List<double> values = <double>[];
    for (final LevelLayer layer in level.layers.iterable()) {
      if (layer.visible && !values.contains(layer.depth)) {
        values.add(layer.depth);
      }
    }
    for (final LevelSprite sprite in level.sprites.iterable()) {
      if (!values.contains(sprite.depth)) {
        values.add(sprite.depth);
      }
    }
    return values;
  }

  void _renderLayersAtDepth(
    Array<LevelLayer> layers,
    double depth,
    AssetManager assets,
    SpriteBatch batch,
    List<bool> layerVisibilityStates,
    Array<RuntimeTransform> layerRuntimeStates,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    for (int i = layers.size - 1; i >= 0; i--) {
      final LevelLayer layer = layers.get(i);
      bool visible = layer.visible;
      if (i >= 0 && i < layerVisibilityStates.length) {
        visible = layerVisibilityStates[i];
      }
      if (!visible || !_sameDepth(layer.depth, depth)) {
        continue;
      }

      RuntimeTransform? runtime;
      if (i >= 0 && i < layerRuntimeStates.size) {
        runtime = layerRuntimeStates.get(i);
      }
      _drawLayer(layer, runtime, assets, batch, camera, viewport);
    }
  }

  void _drawLayer(
    LevelLayer layer,
    RuntimeTransform? runtime,
    AssetManager assets,
    SpriteBatch batch,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    if (!assets.isLoaded(layer.tilesTexturePath, Texture)) {
      return;
    }

    final Texture texture = assets.get(layer.tilesTexturePath, Texture);
    final List<List<TextureRegion>> regions = _getSplitRegions(
      layer.tilesTexturePath,
      texture,
      layer.tileWidth,
      layer.tileHeight,
    );
    if (regions.isEmpty || regions.first.isEmpty) {
      return;
    }

    final int cols = regions.first.length;
    final double layerX = runtime?.x ?? layer.x;
    final double layerY = runtime?.y ?? layer.y;

    for (int row = 0; row < layer.tileMap.length; row++) {
      final List<int> rowData = layer.tileMap[row];
      for (int col = 0; col < rowData.length; col++) {
        final int tileIndex = rowData[col];
        if (tileIndex < 0) {
          continue;
        }

        final int srcRow = tileIndex ~/ cols;
        final int srcCol = tileIndex % cols;
        if (srcRow < 0 ||
            srcRow >= regions.length ||
            srcCol < 0 ||
            srcCol >= regions[srcRow].length) {
          continue;
        }

        final TextureRegion region = regions[srcRow][srcCol];
        final double x = layerX + col * layer.tileWidth;
        final double y = layerY + row * layer.tileHeight;
        final ui.Rect? dst = _worldRectToScreen(
          camera,
          viewport,
          x,
          y,
          layer.tileWidth.toDouble(),
          layer.tileHeight.toDouble(),
        );
        if (dst == null) {
          continue;
        }
        batch.drawRegion(region.texture, region.srcRect, _snapTileDstRect(dst));
      }
    }
  }

  void _renderSpritesAtDepth(
    Array<LevelSprite> sprites,
    Array<SpriteRuntimeState> spriteRuntimeStates,
    double depth,
    AssetManager assets,
    SpriteBatch batch,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    for (int i = 0; i < sprites.size; i++) {
      final LevelSprite sprite = sprites.get(i);
      if (!_sameDepth(sprite.depth, depth)) {
        continue;
      }
      final SpriteRuntimeState? runtimeState = i < spriteRuntimeStates.size
          ? spriteRuntimeStates.get(i)
          : null;
      _drawSprite(sprite, runtimeState, assets, batch, camera, viewport);
    }
  }

  void _drawSprite(
    LevelSprite sprite,
    SpriteRuntimeState? runtimeState,
    AssetManager assets,
    SpriteBatch batch,
    OrthographicCamera camera,
    Viewport viewport,
  ) {
    if (runtimeState != null && !runtimeState.visible) {
      return;
    }

    final String texturePath = runtimeState?.texturePath ?? sprite.texturePath;
    if (!assets.isLoaded(texturePath, Texture)) {
      return;
    }

    final int frameIndex = runtimeState?.frameIndex ?? sprite.frameIndex;
    final double anchorX = runtimeState?.anchorX ?? sprite.anchorX;
    final double anchorY = runtimeState?.anchorY ?? sprite.anchorY;
    final double worldX = runtimeState?.worldX ?? sprite.x;
    final double worldY = runtimeState?.worldY ?? sprite.y;
    final bool flipX = runtimeState?.flipX ?? sprite.flipX;
    final bool flipY = runtimeState?.flipY ?? sprite.flipY;

    final Texture texture = assets.get(texturePath, Texture);
    final int frameWidth = math.min(
      runtimeState?.frameWidth ?? sprite.width.round(),
      texture.width,
    );
    final int frameHeight = math.min(
      runtimeState?.frameHeight ?? sprite.height.round(),
      texture.height,
    );
    final List<List<TextureRegion>> regions = _getSplitRegions(
      texturePath,
      texture,
      frameWidth,
      frameHeight,
    );
    if (regions.isEmpty || regions.first.isEmpty) {
      return;
    }

    final int cols = regions.first.length;
    final int rows = regions.length;
    final int total = rows * cols;
    final int frame = math.max(0, math.min(total - 1, frameIndex));
    final int srcCol = frame % cols;
    final int srcRow = frame ~/ cols;
    if (srcRow < 0 || srcRow >= rows || srcCol < 0 || srcCol >= cols) {
      return;
    }

    final TextureRegion region = regions[srcRow][srcCol];
    final double left = worldX - sprite.width * anchorX;
    final double top = worldY - sprite.height * anchorY;
    final ui.Rect? dst = _worldRectToScreen(
      camera,
      viewport,
      left,
      top,
      sprite.width,
      sprite.height,
    );
    if (dst == null) {
      return;
    }

    batch.drawRegion(
      region.texture,
      region.srcRect,
      dst,
      flipX: flipX,
      flipY: flipY,
      pivotX: anchorX,
      pivotY: anchorY,
    );
  }

  List<List<TextureRegion>> _getSplitRegions(
    String texturePath,
    Texture texture,
    int tileWidth,
    int tileHeight,
  ) {
    final String key = '$texturePath#$tileWidth x $tileHeight';
    final List<List<TextureRegion>>? cached = splitCache.get(key);
    if (cached != null) {
      return cached;
    }
    final List<List<TextureRegion>> split = splitTexture(
      texture,
      tileWidth,
      tileHeight,
    );
    splitCache.put(key, split);
    return split;
  }

  bool _sameDepth(double a, double b) {
    return (a - b).abs() <= 0.000001;
  }

  double _depthProjectionFactorForDepth(double depth, double sensitivity) {
    final double safeSensitivity = sensitivity.isFinite && sensitivity >= 0
        ? sensitivity
        : 0.08;
    final double factor = math.exp(-depth * safeSensitivity);
    return math.max(
      minDepthProjectionFactor,
      math.min(maxDepthProjectionFactor, factor),
    );
  }

  ui.Rect _snapTileDstRect(ui.Rect rect) {
    final double left = rect.left.floorToDouble();
    final double top = rect.top.floorToDouble();
    final double right = rect.right.ceilToDouble();
    final double bottom = rect.bottom.ceilToDouble();
    if (right <= left || bottom <= top) {
      return rect;
    }
    return ui.Rect.fromLTRB(left, top, right, bottom);
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
}

class SpriteRuntimeState {
  int frameIndex;
  double anchorX;
  double anchorY;
  double worldX;
  double worldY;
  bool visible;
  bool flipX;
  bool flipY;
  int frameWidth;
  int frameHeight;
  String texturePath;
  String? animationId;

  SpriteRuntimeState(
    this.frameIndex,
    this.anchorX,
    this.anchorY,
    this.worldX,
    this.worldY,
    this.visible,
    this.flipX,
    this.flipY,
    this.frameWidth,
    this.frameHeight,
    this.texturePath,
    this.animationId,
  );
}
