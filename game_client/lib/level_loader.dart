import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'level_data.dart';
import 'libgdx_compat/math_types.dart';

class LevelLoader {
  static const String gameDataPath = 'levels/game_data.json';
  static const double defaultViewportWidth = 320;
  static const double defaultViewportHeight = 180;
  static const String defaultViewportAdaptation = 'letterbox';
  static const double defaultDepthSensitivity = 0.08;

  static Map<String, dynamic>? _gameDataRoot;
  static Map<String, dynamic>? _animationsRoot;
  static final Map<String, dynamic> _jsonByPath = <String, dynamic>{};

  static Future<void> initialize() async {
    final String gameDataRaw = await rootBundle.loadString(
      'assets/$gameDataPath',
    );
    _gameDataRoot = jsonDecode(gameDataRaw) as Map<String, dynamic>;
    _jsonByPath[gameDataPath] = _gameDataRoot!;

    final String? animationsFilePath =
        _gameDataRoot!['animationsFile'] as String?;
    if (animationsFilePath != null && animationsFilePath.isNotEmpty) {
      try {
        final String fullAnimationsPath = 'levels/$animationsFilePath';
        final String animationsRaw = await rootBundle.loadString(
          'assets/$fullAnimationsPath',
        );
        _animationsRoot = jsonDecode(animationsRaw) as Map<String, dynamic>;
        _jsonByPath[fullAnimationsPath] = _animationsRoot!;
      } catch (_) {
        _animationsRoot = null;
      }
    }

    final List<dynamic>? levels = _gameDataRoot!['levels'] as List<dynamic>?;
    if (levels == null) {
      return;
    }
    for (final dynamic rawLevel in levels) {
      final Map<String, dynamic>? level = rawLevel as Map<String, dynamic>?;
      if (level == null) {
        continue;
      }
      final String? zonesFile = level['zonesFile'] as String?;
      if (zonesFile != null && zonesFile.isNotEmpty) {
        await _preloadJsonFile('levels/$zonesFile');
      }
      final String? pathsFile = level['pathsFile'] as String?;
      if (pathsFile != null && pathsFile.isNotEmpty) {
        await _preloadJsonFile('levels/$pathsFile');
      }

      final List<dynamic>? layers = level['layers'] as List<dynamic>?;
      if (layers == null) {
        continue;
      }
      for (final dynamic rawLayer in layers) {
        final Map<String, dynamic>? layer = rawLayer as Map<String, dynamic>?;
        if (layer == null) {
          continue;
        }
        final String? tileMapFile = layer['tileMapFile'] as String?;
        if (tileMapFile != null && tileMapFile.isNotEmpty) {
          await _preloadJsonFile('levels/$tileMapFile');
        }
      }
    }
  }

  static LevelData loadLevel(int levelIndex) {
    final Map<String, dynamic>? root = _gameDataRoot;
    if (root == null) {
      return _emptyLevel('Load error');
    }

    final List<dynamic>? levels = root['levels'] as List<dynamic>?;
    if (levels == null || levels.isEmpty) {
      return _emptyLevel('No levels');
    }

    final int safeIndex = clampInt(levelIndex, 0, levels.length - 1);
    final Map<String, dynamic>? levelNode =
        levels[safeIndex] as Map<String, dynamic>?;
    if (levelNode == null) {
      return _emptyLevel('Invalid level');
    }

    final ObjectMap<String, _MediaFrameSize> mediaFrameSizes =
        _loadMediaFrameSizes(root);
    final ObjectMap<String, AnimationClip> animationClips = _loadAnimationClips(
      mediaFrameSizes,
    );
    return _parseLevel(levelNode, animationClips, mediaFrameSizes);
  }

  static LevelData _parseLevel(
    Map<String, dynamic> levelNode,
    ObjectMap<String, AnimationClip> animationClips,
    ObjectMap<String, _MediaFrameSize> mediaFrameSizes,
  ) {
    final String name = (levelNode['name'] as String?) ?? 'Untitled Level';
    final uiColor = colorValueOf(
      (levelNode['backgroundColorHex'] as String?) ?? '#000000',
    );
    final double viewportWidth = _positiveFiniteOrDefault(
      levelNode['viewportWidth'],
      defaultViewportWidth,
    );
    final double viewportHeight = _positiveFiniteOrDefault(
      levelNode['viewportHeight'],
      defaultViewportHeight,
    );
    final double viewportX = _finiteOrDefault(levelNode['viewportX'], 0);
    final double viewportY = _finiteOrDefault(levelNode['viewportY'], 0);
    final double depthSensitivity = _nonNegativeFiniteOrDefault(
      levelNode['depthSensitivity'],
      defaultDepthSensitivity,
    );
    final String viewportAdaptation = _normalizeViewportAdaptation(
      (levelNode['viewportAdaptation'] as String?) ?? defaultViewportAdaptation,
    );

    final Array<LevelLayer> layers = Array<LevelLayer>();
    final List<dynamic>? layersNode = levelNode['layers'] as List<dynamic>?;
    if (layersNode != null) {
      for (final dynamic rawLayerNode in layersNode) {
        final Map<String, dynamic>? layerNode =
            rawLayerNode as Map<String, dynamic>?;
        if (layerNode == null) {
          continue;
        }
        final LevelLayer? layer = _parseLayer(layerNode);
        if (layer != null) {
          layers.add(layer);
        }
      }
    }

    final Array<LevelSprite> sprites = Array<LevelSprite>();
    final List<dynamic>? spritesNode = levelNode['sprites'] as List<dynamic>?;
    if (spritesNode != null) {
      for (final dynamic rawSpriteNode in spritesNode) {
        final Map<String, dynamic>? spriteNode =
            rawSpriteNode as Map<String, dynamic>?;
        if (spriteNode == null) {
          continue;
        }
        final LevelSprite? sprite = _parseSprite(
          spriteNode,
          animationClips,
          mediaFrameSizes,
        );
        if (sprite != null) {
          sprites.add(sprite);
        }
      }
    }

    final String? zonesFile = levelNode['zonesFile'] as String?;
    final String? pathsFile = levelNode['pathsFile'] as String?;
    final Array<LevelZone> zones = _loadZones(
      zonesFile == null ? null : 'levels/$zonesFile',
    );
    final _PathData pathData = _loadPathData(
      pathsFile == null ? null : 'levels/$pathsFile',
    );
    final Array<LevelPath> paths = pathData.paths;
    final Array<LevelPathBinding> pathBindings = pathData.bindings;

    double worldWidth = viewportX + viewportWidth;
    double worldHeight = viewportY + viewportHeight;

    for (final LevelLayer layer in layers.iterable()) {
      final int rows = layer.tileMap.length;
      final int cols = rows == 0 ? 0 : _maxRowLength(layer.tileMap);
      final double layerRight = layer.x + cols * layer.tileWidth;
      final double layerBottom = layer.y + rows * layer.tileHeight;
      worldWidth = math.max(worldWidth, layerRight);
      worldHeight = math.max(worldHeight, layerBottom);
    }

    for (final LevelSprite sprite in sprites.iterable()) {
      final double spriteLeft = sprite.x - sprite.width * sprite.anchorX;
      final double spriteTop = sprite.y - sprite.height * sprite.anchorY;
      worldWidth = math.max(worldWidth, spriteLeft + sprite.width);
      worldHeight = math.max(worldHeight, spriteTop + sprite.height);
    }

    for (final LevelZone zone in zones.iterable()) {
      worldWidth = math.max(worldWidth, zone.x + zone.width);
      worldHeight = math.max(worldHeight, zone.y + zone.height);
    }

    for (final LevelPath path in paths.iterable()) {
      for (final Vector2 point in path.points.iterable()) {
        worldWidth = math.max(worldWidth, point.x);
        worldHeight = math.max(worldHeight, point.y);
      }
    }

    worldWidth = math.max(worldWidth, defaultViewportWidth);
    worldHeight = math.max(worldHeight, defaultViewportHeight);

    return LevelData(
      name,
      uiColor,
      viewportWidth,
      viewportHeight,
      viewportX,
      viewportY,
      viewportAdaptation,
      depthSensitivity,
      worldWidth,
      worldHeight,
      layers,
      sprites,
      zones,
      paths,
      pathBindings,
      animationClips,
    );
  }

  static LevelLayer? _parseLayer(Map<String, dynamic> layerNode) {
    final String? tilesFile = layerNode['tilesSheetFile'] as String?;
    final String? tileMapFile = layerNode['tileMapFile'] as String?;
    final int tileWidth = (layerNode['tilesWidth'] as num?)?.toInt() ?? 0;
    final int tileHeight = (layerNode['tilesHeight'] as num?)?.toInt() ?? 0;
    if (tilesFile == null ||
        tilesFile.isEmpty ||
        tileMapFile == null ||
        tileMapFile.isEmpty) {
      return null;
    }
    if (tileWidth <= 0 || tileHeight <= 0) {
      return null;
    }

    return LevelLayer(
      (layerNode['name'] as String?) ?? 'Layer',
      (layerNode['visible'] as bool?) ?? true,
      (layerNode['depth'] as num?)?.toDouble() ?? 0,
      (layerNode['x'] as num?)?.toDouble() ?? 0,
      (layerNode['y'] as num?)?.toDouble() ?? 0,
      'levels/$tilesFile',
      tileWidth,
      tileHeight,
      _loadTileMap('levels/$tileMapFile'),
    );
  }

  static LevelSprite? _parseSprite(
    Map<String, dynamic> spriteNode,
    ObjectMap<String, AnimationClip> animationClips,
    ObjectMap<String, _MediaFrameSize> mediaFrameSizes,
  ) {
    final String? imageFile = spriteNode['imageFile'] as String?;
    if (imageFile == null || imageFile.isEmpty) {
      return null;
    }

    double width = (spriteNode['width'] as num?)?.toDouble() ?? 0;
    double height = (spriteNode['height'] as num?)?.toDouble() ?? 0;

    final String? animationId = spriteNode['animationId'] as String?;
    int frameIndex = 0;
    double anchorX = 0.5;
    double anchorY = 0.5;
    String texturePath = 'levels/$imageFile';

    if (animationId != null) {
      final AnimationClip? clip = animationClips.get(animationId);
      if (clip != null) {
        if (clip.texturePath != null && clip.texturePath!.isNotEmpty) {
          texturePath = clip.texturePath!;
        }
        frameIndex = math.max(0, clip.startFrame);
        final FrameRig? startRig = clip.frameRigs.get(frameIndex);
        if (startRig != null) {
          anchorX = startRig.anchorX;
          anchorY = startRig.anchorY;
        } else {
          anchorX = clip.anchorX;
          anchorY = clip.anchorY;
        }
      }
    }

    final _MediaFrameSize? mediaSize = mediaFrameSizes.get(texturePath);
    if (mediaSize != null && mediaSize.width > 0 && mediaSize.height > 0) {
      width = mediaSize.width;
      height = mediaSize.height;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }

    return LevelSprite(
      (spriteNode['name'] as String?) ?? 'Sprite',
      (spriteNode['type'] as String?) ?? '',
      (spriteNode['depth'] as num?)?.toDouble() ?? 0,
      (spriteNode['x'] as num?)?.toDouble() ?? 0,
      (spriteNode['y'] as num?)?.toDouble() ?? 0,
      width,
      height,
      anchorX,
      anchorY,
      (spriteNode['flipX'] as bool?) ?? false,
      (spriteNode['flipY'] as bool?) ?? false,
      frameIndex,
      texturePath,
      animationId,
    );
  }

  static ObjectMap<String, _MediaFrameSize> _loadMediaFrameSizes(
    Map<String, dynamic> root,
  ) {
    final ObjectMap<String, _MediaFrameSize> mapping =
        ObjectMap<String, _MediaFrameSize>();
    final List<dynamic>? assets = root['mediaAssets'] as List<dynamic>?;
    if (assets == null) {
      return mapping;
    }

    for (final dynamic rawAsset in assets) {
      final Map<String, dynamic>? asset = rawAsset as Map<String, dynamic>?;
      if (asset == null) {
        continue;
      }
      final String? fileName = asset['fileName'] as String?;
      if (fileName == null || fileName.isEmpty) {
        continue;
      }
      final int tileWidth = (asset['tileWidth'] as num?)?.toInt() ?? 0;
      final int tileHeight = (asset['tileHeight'] as num?)?.toInt() ?? 0;
      if (tileWidth <= 0 || tileHeight <= 0) {
        continue;
      }
      mapping.put(
        'levels/$fileName',
        _MediaFrameSize(tileWidth.toDouble(), tileHeight.toDouble()),
      );
    }
    return mapping;
  }

  static ObjectMap<String, AnimationClip> _loadAnimationClips(
    ObjectMap<String, _MediaFrameSize> mediaFrameSizes,
  ) {
    final ObjectMap<String, AnimationClip> mapping =
        ObjectMap<String, AnimationClip>();
    final List<dynamic>? animations =
        _animationsRoot?['animations'] as List<dynamic>?;
    if (animations == null) {
      return mapping;
    }

    for (final dynamic rawAnimation in animations) {
      final Map<String, dynamic>? animation =
          rawAnimation as Map<String, dynamic>?;
      if (animation == null) {
        continue;
      }
      final String? id = animation['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }

      final int startFrame = math.max(
        0,
        (animation['startFrame'] as num?)?.toInt() ?? 0,
      );
      final String? mediaFile = animation['mediaFile'] as String?;
      final String? texturePath = mediaFile == null || mediaFile.isEmpty
          ? null
          : 'levels/$mediaFile';
      final _MediaFrameSize? mediaSize = texturePath == null
          ? null
          : mediaFrameSizes.get(texturePath);
      final int frameWidth = mediaSize == null
          ? 0
          : math.max(0, mediaSize.width.round());
      final int frameHeight = mediaSize == null
          ? 0
          : math.max(0, mediaSize.height.round());
      final double anchorX = _anchorOrDefault(
        (animation['anchorX'] as num?)?.toDouble(),
        0.5,
      );
      final double anchorY = _anchorOrDefault(
        (animation['anchorY'] as num?)?.toDouble(),
        0.5,
      );
      final int endFrame = math.max(
        startFrame,
        (animation['endFrame'] as num?)?.toInt() ?? startFrame,
      );
      final double fps = _positiveFiniteOrDefault(animation['fps'], 8);
      final bool loop = (animation['loop'] as bool?) ?? true;
      final ObjectMap<int, FrameRig> frameRigByFrame =
          ObjectMap<int, FrameRig>();
      final Array<HitBox> clipHitBoxes = _parseHitBoxes(
        animation['hitBoxes'] as List<dynamic>?,
      );

      final List<dynamic>? frameRigsNode =
          animation['frameRigs'] as List<dynamic>?;
      if (frameRigsNode != null) {
        for (final dynamic rawFrameRig in frameRigsNode) {
          final Map<String, dynamic>? frameRigNode =
              rawFrameRig as Map<String, dynamic>?;
          if (frameRigNode == null) {
            continue;
          }
          final int frame = (frameRigNode['frame'] as num?)?.toInt() ?? -1;
          if (frame < 0) {
            continue;
          }
          final double rigAnchorX = _anchorOrDefault(
            (frameRigNode['anchorX'] as num?)?.toDouble(),
            anchorX,
          );
          final double rigAnchorY = _anchorOrDefault(
            (frameRigNode['anchorY'] as num?)?.toDouble(),
            anchorY,
          );
          final Array<HitBox> rigHitBoxes = _parseHitBoxes(
            frameRigNode['hitBoxes'] as List<dynamic>?,
          );
          frameRigByFrame.put(
            frame,
            FrameRig(rigAnchorX, rigAnchorY, rigHitBoxes),
          );
        }
      }

      mapping.put(
        id,
        AnimationClip(
          id,
          (animation['name'] as String?) ?? id,
          texturePath,
          frameWidth,
          frameHeight,
          startFrame,
          endFrame,
          fps,
          loop,
          anchorX,
          anchorY,
          clipHitBoxes,
          frameRigByFrame,
        ),
      );
    }

    return mapping;
  }

  static Array<LevelZone> _loadZones(String? zonesPath) {
    final Array<LevelZone> zones = Array<LevelZone>();
    if (zonesPath == null || zonesPath.isEmpty) {
      return zones;
    }

    try {
      final Map<String, dynamic>? root =
          _jsonByPath[zonesPath] as Map<String, dynamic>?;
      if (root == null) {
        return zones;
      }
      final List<dynamic>? zonesNode = root['zones'] as List<dynamic>?;
      if (zonesNode == null) {
        return zones;
      }

      for (final dynamic rawZoneNode in zonesNode) {
        final Map<String, dynamic>? zoneNode =
            rawZoneNode as Map<String, dynamic>?;
        if (zoneNode == null) {
          continue;
        }
        final double x = _finiteOrDefault(zoneNode['x'], double.nan);
        final double y = _finiteOrDefault(zoneNode['y'], double.nan);
        final double width = _finiteOrDefault(zoneNode['width'], double.nan);
        final double height = _finiteOrDefault(zoneNode['height'], double.nan);
        if (!x.isFinite || !y.isFinite || !width.isFinite || !height.isFinite) {
          continue;
        }
        if (width <= 0 || height <= 0) {
          continue;
        }

        zones.add(
          LevelZone(
            (zoneNode['name'] as String?) ?? 'Zone',
            (zoneNode['type'] as String?) ?? '',
            (zoneNode['gameplayData'] as String?) ?? '',
            (zoneNode['groupId'] as String?) ?? '',
            x,
            y,
            width,
            height,
            colorValueOf((zoneNode['color'] as String?) ?? 'yellow'),
          ),
        );
      }
    } catch (ex) {
      Gdx.app.error('LevelLoader', 'Failed to parse zones file $zonesPath', ex);
    }

    return zones;
  }

  static _PathData _loadPathData(String? pathsPath) {
    final _PathData output = _PathData();
    if (pathsPath == null || pathsPath.isEmpty) {
      return output;
    }

    try {
      final Map<String, dynamic>? root =
          _jsonByPath[pathsPath] as Map<String, dynamic>?;
      if (root == null) {
        return output;
      }

      final List<dynamic>? pathsNode = root['paths'] as List<dynamic>?;
      if (pathsNode != null) {
        for (final dynamic rawPathNode in pathsNode) {
          final Map<String, dynamic>? pathNode =
              rawPathNode as Map<String, dynamic>?;
          if (pathNode == null) {
            continue;
          }
          final Array<Vector2> points = Array<Vector2>();
          final List<dynamic>? pointsNode =
              pathNode['points'] as List<dynamic>?;
          if (pointsNode != null) {
            for (final dynamic rawPointNode in pointsNode) {
              final Map<String, dynamic>? pointNode =
                  rawPointNode as Map<String, dynamic>?;
              if (pointNode == null) {
                continue;
              }
              final double x = _finiteOrDefault(pointNode['x'], double.nan);
              final double y = _finiteOrDefault(pointNode['y'], double.nan);
              if (!x.isFinite || !y.isFinite) {
                continue;
              }
              points.add(Vector2(x, y));
            }
          }
          if (points.size <= 0) {
            continue;
          }
          output.paths.add(
            LevelPath(
              (pathNode['id'] as String?) ?? '',
              (pathNode['name'] as String?) ?? 'Path',
              colorValueOf((pathNode['color'] as String?) ?? 'yellow'),
              points,
            ),
          );
        }
      }

      final List<dynamic>? bindingsNode =
          root['pathBindings'] as List<dynamic>?;
      if (bindingsNode != null) {
        for (final dynamic rawBindingNode in bindingsNode) {
          final Map<String, dynamic>? bindingNode =
              rawBindingNode as Map<String, dynamic>?;
          if (bindingNode == null) {
            continue;
          }
          final String pathId = ((bindingNode['pathId'] as String?) ?? '')
              .trim();
          final String targetType =
              ((bindingNode['targetType'] as String?) ?? '')
                  .trim()
                  .toLowerCase();
          final int targetIndex =
              (bindingNode['targetIndex'] as num?)?.toInt() ?? -1;
          if (pathId.isEmpty || targetIndex < 0) {
            continue;
          }
          final int durationMs =
              (bindingNode['durationMs'] as num?)?.toInt() ?? 2000;
          final double durationSeconds = durationMs > 0 ? durationMs / 1000 : 2;
          output.bindings.add(
            LevelPathBinding(
              (bindingNode['id'] as String?) ?? '',
              pathId,
              targetType,
              targetIndex,
              ((bindingNode['behavior'] as String?) ?? 'restart')
                  .trim()
                  .toLowerCase(),
              (bindingNode['enabled'] as bool?) ?? true,
              (bindingNode['relativeToInitialPosition'] as bool?) ?? true,
              durationSeconds,
            ),
          );
        }
      }
    } catch (ex) {
      Gdx.app.error('LevelLoader', 'Failed to parse paths file $pathsPath', ex);
    }

    return output;
  }

  static List<List<int>> _loadTileMap(String tileMapPath) {
    try {
      final Map<String, dynamic>? root =
          _jsonByPath[tileMapPath] as Map<String, dynamic>?;
      if (root == null) {
        return <List<int>>[];
      }
      final List<dynamic>? rowsNode = root['tileMap'] as List<dynamic>?;
      if (rowsNode == null) {
        return <List<int>>[];
      }

      final List<List<int>> rows = <List<int>>[];
      for (final dynamic rawRowNode in rowsNode) {
        final List<dynamic>? rowNode = rawRowNode as List<dynamic>?;
        if (rowNode == null) {
          rows.add(<int>[]);
          continue;
        }
        rows.add(
          rowNode.map((dynamic value) => (value as num).toInt()).toList(),
        );
      }
      return rows;
    } catch (ex) {
      Gdx.app.error('LevelLoader', 'Failed to parse tile map $tileMapPath', ex);
      return <List<int>>[];
    }
  }

  static LevelData _emptyLevel(String name) {
    return LevelData(
      name,
      colorValueOf('#000000'),
      defaultViewportWidth,
      defaultViewportHeight,
      0,
      0,
      defaultViewportAdaptation,
      defaultDepthSensitivity,
      defaultViewportWidth,
      defaultViewportHeight,
      Array<LevelLayer>(),
      Array<LevelSprite>(),
      Array<LevelZone>(),
      Array<LevelPath>(),
      Array<LevelPathBinding>(),
      ObjectMap<String, AnimationClip>(),
    );
  }

  static int _maxRowLength(List<List<int>> rows) {
    int max = 0;
    for (final List<int> row in rows) {
      max = math.max(max, row.length);
    }
    return max;
  }

  static double _positiveFiniteOrDefault(dynamic rawValue, double fallback) {
    final double value = (rawValue as num?)?.toDouble() ?? fallback;
    if (!value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  static double _finiteOrDefault(dynamic rawValue, double fallback) {
    final double value = (rawValue as num?)?.toDouble() ?? fallback;
    if (!value.isFinite) {
      return fallback;
    }
    return value;
  }

  static double _nonNegativeFiniteOrDefault(dynamic rawValue, double fallback) {
    final double value = (rawValue as num?)?.toDouble() ?? fallback;
    if (!value.isFinite || value < 0) {
      return fallback;
    }
    return value;
  }

  static double _anchorOrDefault(double? value, double fallback) {
    if (value == null || !value.isFinite) {
      return fallback;
    }
    return clampDouble(value, 0, 1);
  }

  static Array<HitBox> _parseHitBoxes(List<dynamic>? hitBoxesNode) {
    final Array<HitBox> hitBoxes = Array<HitBox>();
    if (hitBoxesNode == null) {
      return hitBoxes;
    }

    for (final dynamic rawHitBoxNode in hitBoxesNode) {
      final Map<String, dynamic>? hitBoxNode =
          rawHitBoxNode as Map<String, dynamic>?;
      if (hitBoxNode == null) {
        continue;
      }
      final double x = _finiteOrDefault(hitBoxNode['x'], double.nan);
      final double y = _finiteOrDefault(hitBoxNode['y'], double.nan);
      final double width = _finiteOrDefault(hitBoxNode['width'], double.nan);
      final double height = _finiteOrDefault(hitBoxNode['height'], double.nan);
      if (!x.isFinite || !y.isFinite || !width.isFinite || !height.isFinite) {
        continue;
      }
      if (width <= 0 || height <= 0) {
        continue;
      }
      hitBoxes.add(
        HitBox(
          (hitBoxNode['id'] as String?) ?? '',
          (hitBoxNode['name'] as String?) ?? '',
          x,
          y,
          width,
          height,
        ),
      );
    }

    return hitBoxes;
  }

  static String _normalizeViewportAdaptation(String raw) {
    final String normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'fit':
      case 'contain':
      case 'letterbox':
        return 'letterbox';
      case 'expand':
        return 'expand';
      case 'stretch':
      case 'strech':
        return 'stretch';
      default:
        return defaultViewportAdaptation;
    }
  }

  static Future<void> _preloadJsonFile(String path) async {
    if (_jsonByPath.containsKey(path)) {
      return;
    }
    try {
      final String raw = await rootBundle.loadString('assets/$path');
      _jsonByPath[path] = jsonDecode(raw);
    } catch (ex) {
      Gdx.app.error('LevelLoader', 'Failed to preload $path', ex);
    }
  }
}

class _MediaFrameSize {
  final double width;
  final double height;

  _MediaFrameSize(this.width, this.height);
}

class _PathData {
  final Array<LevelPath> paths = Array<LevelPath>();
  final Array<LevelPathBinding> bindings = Array<LevelPathBinding>();
}
