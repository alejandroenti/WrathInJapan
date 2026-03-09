import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'gameplay_controller_base.dart';
import 'level_data.dart';
import 'libgdx_compat/math_types.dart';

class GameplayControllerTopDown extends GameplayControllerBase {
  static const double moveSpeedPerSecond = 95;
  static const double diagonalNormalize = 0.70710677;

  final IntArray blockedZoneIndices = IntArray();
  final IntArray arbreZoneIndices = IntArray();
  final IntArray futureBridgeZoneIndices = IntArray();
  final ObjectSet<String> collectibleArbreTileKeys = ObjectSet<String>();
  final ObjectSet<String> collectedArbreTileKeys = ObjectSet<String>();
  final Rectangle tileRectCache = Rectangle();

  late final int decorationsLayerIndex;
  late final int hiddenBridgeLayerIndex;
  bool wasInsideFutureBridgeZone = false;
  _Direction _direction = _Direction.down;
  bool moving = false;

  GameplayControllerTopDown(
    super.levelData,
    super.spriteRuntimeStates,
    super.layerVisibilityStates,
    super.zoneRuntimeStates,
    super.zonePreviousRuntimeStates,
  ) {
    decorationsLayerIndex = _findLayerIndexByName(<String>[
      'decoracions',
      'decorations',
    ]);
    hiddenBridgeLayerIndex = _findLayerIndexByName(<String>[
      'pont amagat',
      'hidden bridge',
    ]);

    _classifyZones();
    _buildCollectibleArbreTiles();
    _updatePlayerAnimationSelection();
    syncPlayerToSpriteRuntime();
  }

  int getCollectedArbresCount() {
    return collectedArbreTileKeys.size;
  }

  int getTotalArbresCount() {
    return collectibleArbreTileKeys.size;
  }

  bool isWin() {
    return collectibleArbreTileKeys.size > 0 &&
        collectedArbreTileKeys.size >= collectibleArbreTileKeys.size;
  }

  @override
  void handleInput() {
    if (Gdx.input.isKeyJustPressed(Input.keys.r)) {
      resetPlayerToSpawn();
    }
  }

  @override
  void fixedUpdate(double dtSeconds) {
    if (playerSpriteIndex < 0) {
      return;
    }

    double inputX = 0;
    double inputY = 0;
    final bool left =
        Gdx.input.isKeyPressed(Input.keys.left) ||
        Gdx.input.isKeyPressed(Input.keys.a);
    final bool right =
        Gdx.input.isKeyPressed(Input.keys.right) ||
        Gdx.input.isKeyPressed(Input.keys.d);
    final bool up =
        Gdx.input.isKeyPressed(Input.keys.up) ||
        Gdx.input.isKeyPressed(Input.keys.w);
    final bool down =
        Gdx.input.isKeyPressed(Input.keys.down) ||
        Gdx.input.isKeyPressed(Input.keys.s);

    if (left) {
      inputX -= 1;
    }
    if (right) {
      inputX += 1;
    }
    if (up) {
      inputY -= 1;
    }
    if (down) {
      inputY += 1;
    }

    if (inputX != 0 && inputY != 0) {
      inputX *= diagonalNormalize;
      inputY *= diagonalNormalize;
    }

    final double dx = inputX * moveSpeedPerSecond * dtSeconds;
    final double dy = inputY * moveSpeedPerSecond * dtSeconds;
    _updateDirection(up, down, left, right);

    if (dx != 0) {
      final double nextX = playerX + dx;
      if (!_wouldCollideBlocked(nextX, playerY)) {
        playerX = nextX;
      }
    }
    if (dy != 0) {
      final double nextY = playerY + dy;
      if (!_wouldCollideBlocked(playerX, nextY)) {
        playerY = nextY;
      }
    }

    moving = left || right || up || down;
    _updatePlayerAnimationSelection();

    _revealHiddenBridgeIfNeeded();
    _collectArbreTileIfNeeded();
    syncPlayerToSpriteRuntime();
  }

  @override
  void resetPlayerToSpawn() {
    super.resetPlayerToSpawn();
    wasInsideFutureBridgeZone = false;
    _direction = _Direction.down;
    moving = false;
    setPlayerFlip(false, false);
    _updatePlayerAnimationSelection();
  }

  void _classifyZones() {
    blockedZoneIndices.clear();
    arbreZoneIndices.clear();
    futureBridgeZoneIndices.clear();

    for (int i = 0; i < levelData.zones.size; i++) {
      final LevelZone zone = levelData.zones.get(i);
      final String type = normalize(zone.type);
      final String name = normalize(zone.name);
      final String gameplayData = normalize(zone.gameplayData);
      final bool isWall =
          containsAny(type, <String>['mur', 'wall']) ||
          containsAny(name, <String>['mur', 'wall']);
      final bool isWater =
          containsAny(type, <String>['aigua', 'water']) ||
          containsAny(name, <String>['aigua', 'water']);
      final bool isBridge =
          containsAny(type, <String>['pont', 'bridge']) ||
          containsAny(name, <String>['pont', 'bridge']);
      final bool isTemporary =
          containsAny(type, <String>['temporal']) ||
          containsAny(name, <String>['temporal']) ||
          gameplayData == 'futur pont' ||
          gameplayData == 'future bridge';

      if (isWall || (isWater && !isBridge && !isTemporary)) {
        blockedZoneIndices.add(i);
      }
      if (containsAny(type, <String>['arbre']) ||
          containsAny(name, <String>['arbre', 'tree'])) {
        arbreZoneIndices.add(i);
      }
      if (gameplayData == 'futur pont' || gameplayData == 'future bridge') {
        futureBridgeZoneIndices.add(i);
      }
    }
  }

  bool _wouldCollideBlocked(double nextX, double nextY) {
    return spriteOverlapsAnyZoneByHitBoxes(
      playerSpriteIndex,
      nextX,
      nextY,
      blockedZoneIndices,
    );
  }

  int _findLayerIndexByName(List<String> tokens) {
    for (int i = 0; i < levelData.layers.size; i++) {
      final String layerName = normalize(levelData.layers.get(i).name);
      if (containsAny(layerName, tokens)) {
        return i;
      }
    }
    return -1;
  }

  void _revealHiddenBridgeIfNeeded() {
    if (hiddenBridgeLayerIndex < 0 ||
        hiddenBridgeLayerIndex >= layerVisibilityStates.length ||
        futureBridgeZoneIndices.size <= 0) {
      return;
    }

    final bool insideFutureBridge = spriteOverlapsAnyZoneByHitBoxes(
      playerSpriteIndex,
      playerX,
      playerY,
      futureBridgeZoneIndices,
    );
    if (insideFutureBridge && !wasInsideFutureBridgeZone) {
      layerVisibilityStates[hiddenBridgeLayerIndex] = true;
    }
    wasInsideFutureBridgeZone = insideFutureBridge;
  }

  void _buildCollectibleArbreTiles() {
    collectibleArbreTileKeys.clear();
    if (decorationsLayerIndex < 0 ||
        decorationsLayerIndex >= levelData.layers.size ||
        arbreZoneIndices.size <= 0) {
      return;
    }

    final LevelLayer layer = levelData.layers.get(decorationsLayerIndex);
    if (layer.tileMap.isEmpty ||
        layer.tileWidth <= 0 ||
        layer.tileHeight <= 0) {
      return;
    }

    for (int tileY = 0; tileY < layer.tileMap.length; tileY++) {
      final List<int> row = layer.tileMap[tileY];
      for (int tileX = 0; tileX < row.length; tileX++) {
        if (row[tileX] < 0) {
          continue;
        }
        tileRectCache.set(
          layer.x + tileX * layer.tileWidth,
          layer.y + tileY * layer.tileHeight,
          layer.tileWidth.toDouble(),
          layer.tileHeight.toDouble(),
        );
        if (overlapsAnyZone(tileRectCache, arbreZoneIndices)) {
          collectibleArbreTileKeys.add(_tileKey(tileX, tileY));
        }
      }
    }
  }

  void _collectArbreTileIfNeeded() {
    if (decorationsLayerIndex < 0 ||
        decorationsLayerIndex >= levelData.layers.size ||
        arbreZoneIndices.size <= 0) {
      return;
    }
    if (!spriteOverlapsAnyZoneByHitBoxes(
      playerSpriteIndex,
      playerX,
      playerY,
      arbreZoneIndices,
    )) {
      return;
    }

    final LevelLayer layer = levelData.layers.get(decorationsLayerIndex);
    if (layer.tileMap.isEmpty ||
        layer.tileWidth <= 0 ||
        layer.tileHeight <= 0) {
      return;
    }

    final int tileX = floorToInt((playerX - layer.x) / layer.tileWidth);
    final int tileY = floorToInt((playerY - layer.y) / layer.tileHeight);
    if (tileY < 0 || tileY >= layer.tileMap.length) {
      return;
    }

    final List<int> row = layer.tileMap[tileY];
    if (tileX < 0 || tileX >= row.length) {
      return;
    }
    if (row[tileX] < 0) {
      return;
    }

    final String key = _tileKey(tileX, tileY);
    if (!collectibleArbreTileKeys.contains(key) ||
        collectedArbreTileKeys.contains(key)) {
      return;
    }

    row[tileX] = -1;
    collectedArbreTileKeys.add(key);
  }

  String _tileKey(int x, int y) {
    return '$x:$y';
  }

  void _updateDirection(bool up, bool down, bool left, bool right) {
    if (up && left) {
      _direction = _Direction.upLeft;
    } else if (up && right) {
      _direction = _Direction.upRight;
    } else if (down && left) {
      _direction = _Direction.downLeft;
    } else if (down && right) {
      _direction = _Direction.downRight;
    } else if (up) {
      _direction = _Direction.up;
    } else if (down) {
      _direction = _Direction.down;
    } else if (left) {
      _direction = _Direction.left;
    } else if (right) {
      _direction = _Direction.right;
    }
  }

  void _updatePlayerAnimationSelection() {
    if (playerSpriteIndex < 0) {
      return;
    }

    final String prefix = moving ? 'Heroi Camina ' : 'Heroi Aturat ';
    String suffix;
    bool flipX;
    switch (_direction) {
      case _Direction.upLeft:
        suffix = 'Amunt-Dreta';
        flipX = true;
        break;
      case _Direction.up:
        suffix = 'Amunt';
        flipX = false;
        break;
      case _Direction.upRight:
        suffix = 'Amunt-Dreta';
        flipX = false;
        break;
      case _Direction.left:
        suffix = 'Dreta';
        flipX = true;
        break;
      case _Direction.right:
        suffix = 'Dreta';
        flipX = false;
        break;
      case _Direction.downLeft:
        suffix = 'Avall-Dreta';
        flipX = true;
        break;
      case _Direction.downRight:
        suffix = 'Avall-Dreta';
        flipX = false;
        break;
      case _Direction.down:
        suffix = 'Avall';
        flipX = false;
        break;
    }

    setPlayerFlip(flipX, false);
    setPlayerAnimationOverrideByName('$prefix$suffix');
  }
}

enum _Direction { upLeft, up, upRight, left, right, downLeft, down, downRight }
