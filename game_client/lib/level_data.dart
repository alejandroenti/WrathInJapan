import 'dart:ui' as ui;

import 'libgdx_compat/gdx_collections.dart';
import 'libgdx_compat/math_types.dart';

class LevelData {
  final String name;
  final ui.Color backgroundColor;
  final double viewportWidth;
  final double viewportHeight;
  final double viewportX;
  final double viewportY;
  final String viewportAdaptation;
  final double depthSensitivity;
  final double worldWidth;
  final double worldHeight;
  final Array<LevelLayer> layers;
  final Array<LevelSprite> sprites;
  final Array<LevelZone> zones;
  final Array<LevelPath> paths;
  final Array<LevelPathBinding> pathBindings;
  final ObjectMap<String, AnimationClip> animationClips;

  LevelData(
    this.name,
    this.backgroundColor,
    this.viewportWidth,
    this.viewportHeight,
    this.viewportX,
    this.viewportY,
    this.viewportAdaptation,
    this.depthSensitivity,
    this.worldWidth,
    this.worldHeight,
    this.layers,
    this.sprites,
    this.zones,
    this.paths,
    this.pathBindings,
    this.animationClips,
  );
}

class LevelLayer {
  final String name;
  final bool visible;
  final double depth;
  final double x;
  final double y;
  final String tilesTexturePath;
  final int tileWidth;
  final int tileHeight;
  final List<List<int>> tileMap;

  LevelLayer(
    this.name,
    this.visible,
    this.depth,
    this.x,
    this.y,
    this.tilesTexturePath,
    this.tileWidth,
    this.tileHeight,
    this.tileMap,
  );
}

class LevelSprite {
  final String name;
  final String type;
  final double depth;
  final double x;
  final double y;
  final double width;
  final double height;
  final double anchorX;
  final double anchorY;
  final bool flipX;
  final bool flipY;
  final int frameIndex;
  final String texturePath;
  final String? animationId;

  LevelSprite(
    this.name,
    this.type,
    this.depth,
    this.x,
    this.y,
    this.width,
    this.height,
    this.anchorX,
    this.anchorY,
    this.flipX,
    this.flipY,
    this.frameIndex,
    this.texturePath,
    this.animationId,
  );
}

class LevelZone {
  final String name;
  final String type;
  final String gameplayData;
  final String groupId;
  final double x;
  final double y;
  final double width;
  final double height;
  final ui.Color color;

  LevelZone(
    this.name,
    this.type,
    this.gameplayData,
    this.groupId,
    this.x,
    this.y,
    this.width,
    this.height,
    this.color,
  );
}

class LevelPath {
  final String id;
  final String name;
  final ui.Color color;
  final Array<Vector2> points;

  LevelPath(this.id, this.name, this.color, this.points);
}

class LevelPathBinding {
  final String id;
  final String pathId;
  final String targetType;
  final int targetIndex;
  final String behavior;
  final bool enabled;
  final bool relativeToInitialPosition;
  final double durationSeconds;

  LevelPathBinding(
    this.id,
    this.pathId,
    this.targetType,
    this.targetIndex,
    this.behavior,
    this.enabled,
    this.relativeToInitialPosition,
    this.durationSeconds,
  );
}

class AnimationClip {
  final String id;
  final String name;
  final String? texturePath;
  final int frameWidth;
  final int frameHeight;
  final int startFrame;
  final int endFrame;
  final double fps;
  final bool loop;
  final double anchorX;
  final double anchorY;
  final Array<HitBox> hitBoxes;
  final ObjectMap<int, FrameRig> frameRigs;

  AnimationClip(
    this.id,
    this.name,
    this.texturePath,
    this.frameWidth,
    this.frameHeight,
    this.startFrame,
    this.endFrame,
    this.fps,
    this.loop,
    this.anchorX,
    this.anchorY,
    this.hitBoxes,
    this.frameRigs,
  );
}

class FrameRig {
  final double anchorX;
  final double anchorY;
  final Array<HitBox> hitBoxes;

  FrameRig(this.anchorX, this.anchorY, this.hitBoxes);
}

class HitBox {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;

  HitBox(this.id, this.name, this.x, this.y, this.width, this.height);
}
