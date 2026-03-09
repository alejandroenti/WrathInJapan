import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_data.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'loading_screen.dart';
import 'network_config.dart';

class GameApp extends Game {
  static const int multiplayerLevelIndex = 0;

  final NetworkConfig networkConfig;
  final AppData appData;
  final AssetManager assetManager = AssetManager();
  final Array<String> levelNames = Array<String>();
  final Array<Array<String>> referencedImageFilesByLevel =
      Array<Array<String>>();
  final ObjectSet<String> queuedAssets = ObjectSet<String>();
  final ObjectMap<String, String> animationMediaById =
      ObjectMap<String, String>();
  final ObjectMap<String, String> animationGroupById =
      ObjectMap<String, String>();
  final ObjectMap<String, Array<String>> animationMediaByGroup =
      ObjectMap<String, Array<String>>();
  final Array<_AnimationMediaEntry> _animationMediaEntries =
      Array<_AnimationMediaEntry>();

  SpriteBatch? batch;
  ShapeRenderer? shapeRenderer;
  BitmapFont? font;

  GameApp({required this.networkConfig})
    : appData = AppData(initialConfig: networkConfig);

  Future<void> create() async {
    batch = SpriteBatch();
    shapeRenderer = ShapeRenderer();
    font = BitmapFont();
    font!.getData().markupEnabled = false;
    await _loadProjectData();
    setScreen(LoadingScreen(this, multiplayerLevelIndex));
  }

  SpriteBatch getBatch() => batch!;

  ShapeRenderer getShapeRenderer() => shapeRenderer!;

  BitmapFont getFont() => font!;

  AssetManager getAssetManager() => assetManager;

  String getLevelName(int levelIndex) {
    if (levelIndex < 0 || levelIndex >= levelNames.size) {
      return 'Unknown';
    }
    return levelNames.get(levelIndex);
  }

  String getPlayerName() => networkConfig.playerName;

  String getSelectedServerLabel() => networkConfig.serverLabel;

  AppData getAppData() => appData;

  void queueReferencedAssetsForLevel(int levelIndex) {
    if (levelIndex < 0 || levelIndex >= referencedImageFilesByLevel.size) {
      return;
    }

    final Array<String> levelFiles = referencedImageFilesByLevel.get(
      levelIndex,
    );
    for (final String relativePath in levelFiles.iterable()) {
      final String assetPath = 'levels/$relativePath';
      if (!queuedAssets.contains(assetPath)) {
        assetManager.load(assetPath, Texture);
        queuedAssets.add(assetPath);
      }
    }
    assetManager.load('other/enrrere.png', Texture);
  }

  @override
  void dispose() {
    appData.dispose();
    assetManager.dispose();
    font?.dispose();
    shapeRenderer?.dispose();
    super.dispose();
  }

  void unloadReferencedAssetsForLevel(int levelIndex) {
    if (levelIndex < 0 || levelIndex >= referencedImageFilesByLevel.size) {
      return;
    }

    final Array<String> levelFiles = referencedImageFilesByLevel.get(
      levelIndex,
    );
    for (final String relativePath in levelFiles.iterable()) {
      final String assetPath = 'levels/$relativePath';
      if (assetManager.isLoaded(assetPath, Texture)) {
        assetManager.unload(assetPath);
      }
      queuedAssets.remove(assetPath);
    }
  }

  Future<void> _loadProjectData() async {
    levelNames.clear();
    referencedImageFilesByLevel.clear();
    animationMediaById.clear();
    animationGroupById.clear();
    animationMediaByGroup.clear();
    _animationMediaEntries.clear();

    try {
      final String gameDataRaw = await rootBundle.loadString(
        'assets/levels/game_data.json',
      );
      final Map<String, dynamic> root =
          jsonDecode(gameDataRaw) as Map<String, dynamic>;
      final List<dynamic>? levels = root['levels'] as List<dynamic>?;
      if (levels == null || levels.isEmpty) {
        _addFallbackLevels();
        return;
      }

      await _loadAnimationsFile(root);

      int index = 0;
      for (final dynamic rawLevel in levels) {
        final Map<String, dynamic>? level = rawLevel as Map<String, dynamic>?;
        if (level == null) {
          continue;
        }

        final String levelName = (level['name'] as String?) ?? 'Level $index';
        levelNames.add(levelName);
        final Array<String> levelImageFiles = Array<String>();
        _collectImageFiles(level, levelImageFiles);
        _collectAnimationMediaForLevel(level, levelImageFiles);
        referencedImageFilesByLevel.add(levelImageFiles);
        index++;
      }
    } catch (ex) {
      Gdx.app.error('GameApp', 'Failed to parse levels/game_data.json', ex);
      _addFallbackLevels();
    }
  }

  void _addFallbackLevels() {
    levelNames.add('Level 0');
    levelNames.add('Level 1');
    referencedImageFilesByLevel.add(Array<String>());
    referencedImageFilesByLevel.add(Array<String>());
  }

  Future<void> _loadAnimationsFile(Map<String, dynamic> root) async {
    final String? animationsFilePath = root['animationsFile'] as String?;
    if (animationsFilePath == null || animationsFilePath.isEmpty) {
      return;
    }

    try {
      final String raw = await rootBundle.loadString(
        'assets/levels/$animationsFilePath',
      );
      final Map<String, dynamic> animationsRoot =
          jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic>? animations =
          animationsRoot['animations'] as List<dynamic>?;
      if (animations == null) {
        return;
      }

      for (final dynamic rawAnimation in animations) {
        final Map<String, dynamic>? animation =
            rawAnimation as Map<String, dynamic>?;
        if (animation == null) {
          continue;
        }
        final String? id = animation['id'] as String?;
        final String? name = animation['name'] as String?;
        final String? mediaFile = animation['mediaFile'] as String?;
        final String groupId = (animation['groupId'] as String?) ?? '';
        if (id == null ||
            mediaFile == null ||
            !_looksLikeImageFile(mediaFile)) {
          continue;
        }

        animationMediaById.put(id, mediaFile);
        animationGroupById.put(id, groupId);

        if (groupId.isNotEmpty) {
          Array<String>? groupMedia = animationMediaByGroup.get(groupId);
          groupMedia ??= Array<String>();
          animationMediaByGroup.put(groupId, groupMedia);
          if (!groupMedia.contains(mediaFile, false)) {
            groupMedia.add(mediaFile);
          }
        }

        _animationMediaEntries.add(
          _AnimationMediaEntry(_normalize(name ?? ''), mediaFile),
        );
      }
    } catch (ex) {
      Gdx.app.error('GameApp', 'Failed to parse animations file', ex);
    }
  }

  void _collectAnimationMediaForLevel(
    Map<String, dynamic> level,
    Array<String> levelImageFiles,
  ) {
    final List<dynamic>? sprites = level['sprites'] as List<dynamic>?;
    if (sprites == null) {
      return;
    }

    final ObjectSet<String> spriteTokens = ObjectSet<String>();
    final ObjectSet<String> animationGroups = ObjectSet<String>();
    bool hasPlayerLikeSprite = false;

    for (final dynamic rawSprite in sprites) {
      final Map<String, dynamic>? sprite = rawSprite as Map<String, dynamic>?;
      if (sprite == null) {
        continue;
      }

      final String animationId = (sprite['animationId'] as String?) ?? '';
      final String? mediaFile = animationMediaById.get(animationId);
      if (mediaFile != null && !levelImageFiles.contains(mediaFile, false)) {
        levelImageFiles.add(mediaFile);
      }

      final String? groupId = animationGroupById.get(animationId);
      if (groupId != null && groupId.isNotEmpty) {
        animationGroups.add(groupId);
      }

      final String spriteType = (sprite['type'] as String?) ?? '';
      final String spriteName = (sprite['name'] as String?) ?? '';
      _addTokens(spriteTokens, spriteType);
      _addTokens(spriteTokens, spriteName);
      if (_looksPlayerLike(spriteType) || _looksPlayerLike(spriteName)) {
        hasPlayerLikeSprite = true;
      }
    }

    for (final String groupId in animationGroups.iterable()) {
      final Array<String>? groupMedia = animationMediaByGroup.get(groupId);
      if (groupMedia == null || groupMedia.size <= 0) {
        continue;
      }
      for (final String mediaFile in groupMedia.iterable()) {
        if (!levelImageFiles.contains(mediaFile, false)) {
          levelImageFiles.add(mediaFile);
        }
      }
    }

    if (spriteTokens.size <= 0 || _animationMediaEntries.size <= 0) {
      return;
    }

    for (final _AnimationMediaEntry entry
        in _animationMediaEntries.iterable()) {
      if (entry.normalizedName.isEmpty) {
        continue;
      }
      if (!_containsAnyToken(entry.normalizedName, spriteTokens)) {
        continue;
      }
      if (!levelImageFiles.contains(entry.mediaFile, false)) {
        levelImageFiles.add(entry.mediaFile);
      }
    }

    if (!hasPlayerLikeSprite) {
      return;
    }

    final ObjectSet<String> playerAnimationTokens = ObjectSet<String>();
    _addTokens(playerAnimationTokens, 'character hero heroi player foxy');
    for (final _AnimationMediaEntry entry
        in _animationMediaEntries.iterable()) {
      if (entry.normalizedName.isEmpty) {
        continue;
      }
      if (!_containsAnyToken(entry.normalizedName, playerAnimationTokens)) {
        continue;
      }
      if (!levelImageFiles.contains(entry.mediaFile, false)) {
        levelImageFiles.add(entry.mediaFile);
      }
    }
  }

  void _collectImageFiles(dynamic node, Array<String> output) {
    if (node == null) {
      return;
    }

    if (node is List<dynamic>) {
      for (final dynamic value in node) {
        _collectImageFiles(value, output);
      }
      return;
    }

    if (node is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in node.entries) {
        final String fieldName = entry.key;
        final dynamic value = entry.value;
        if (value is String &&
            _looksLikeImageField(fieldName) &&
            _looksLikeImageFile(value)) {
          if (!output.contains(value, false)) {
            output.add(value);
          }
        }
        _collectImageFiles(value, output);
      }
    }
  }

  bool _looksLikeImageField(String fieldName) {
    return fieldName.endsWith('File');
  }

  bool _looksLikeImageFile(String path) {
    final String normalized = path.toLowerCase();
    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.bmp');
  }

  bool _containsAnyToken(String normalizedValue, ObjectSet<String> tokens) {
    if (normalizedValue.isEmpty || tokens.size <= 0) {
      return false;
    }

    for (final String token in tokens.iterable()) {
      if (token.isNotEmpty && normalizedValue.contains(token)) {
        return true;
      }
    }
    return false;
  }

  void _addTokens(ObjectSet<String> tokens, String raw) {
    final String normalized = _normalize(raw);
    if (normalized.isEmpty) {
      return;
    }
    final List<String> split = normalized.split(RegExp(r'[^a-z0-9]+'));
    for (final String token in split) {
      if (token.length >= 3) {
        tokens.add(token);
      }
    }
  }

  bool _looksPlayerLike(String rawValue) {
    final String normalized = _normalize(rawValue);
    return normalized.contains('player') ||
        normalized.contains('hero') ||
        normalized.contains('heroi') ||
        normalized.contains('foxy');
  }

  String _normalize(String value) => value.trim().toLowerCase();
}

class _AnimationMediaEntry {
  final String normalizedName;
  final String mediaFile;

  _AnimationMediaEntry(this.normalizedName, this.mediaFile);
}
