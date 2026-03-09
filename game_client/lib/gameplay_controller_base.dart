import 'libgdx_compat/gdx_collections.dart';
import 'gameplay_controller.dart';
import 'level_data.dart';
import 'level_renderer.dart';
import 'libgdx_compat/math_types.dart';
import 'runtime_transform.dart';

abstract class GameplayControllerBase implements GameplayController {
  final LevelData levelData;
  final Array<SpriteRuntimeState> spriteRuntimeStates;
  final List<bool> layerVisibilityStates;
  final Array<RuntimeTransform> zoneRuntimeStates;
  final Array<RuntimeTransform> zonePreviousRuntimeStates;
  final List<String?> animationOverrideBySpriteIndex;
  final ObjectMap<String, String> animationIdByName =
      ObjectMap<String, String>();
  final Rectangle rectCacheA = Rectangle();
  final Rectangle rectCacheB = Rectangle();

  late final int playerSpriteIndex;
  double spawnX = 0;
  double spawnY = 0;
  double playerX = 0;
  double playerY = 0;

  GameplayControllerBase(
    this.levelData,
    this.spriteRuntimeStates,
    this.layerVisibilityStates,
    this.zoneRuntimeStates,
    this.zonePreviousRuntimeStates,
  ) : animationOverrideBySpriteIndex = List<String?>.filled(
        levelData.sprites.size,
        null,
      ) {
    for (final MapEntry<String, AnimationClip> entry
        in levelData.animationClips.entries()) {
      final AnimationClip clip = entry.value;
      if (clip.name.trim().isEmpty) {
        continue;
      }
      animationIdByName.put(_normalize(clip.name), clip.id);
    }

    playerSpriteIndex = _findPlayerSpriteIndex();
    if (_hasPlayer()) {
      final SpriteRuntimeState state = _playerState();
      spawnX = state.worldX;
      spawnY = state.worldY;
      playerX = spawnX;
      playerY = spawnY;
    }
  }

  @override
  bool hasCameraTarget() {
    return _hasPlayer();
  }

  @override
  double getCameraTargetX() {
    return playerX;
  }

  @override
  double getCameraTargetY() {
    return playerY;
  }

  @override
  String? animationOverrideForSprite(int spriteIndex) {
    if (spriteIndex < 0 ||
        spriteIndex >= animationOverrideBySpriteIndex.length) {
      return null;
    }
    return animationOverrideBySpriteIndex[spriteIndex];
  }

  bool _hasPlayer() {
    return playerSpriteIndex >= 0 &&
        playerSpriteIndex < levelData.sprites.size &&
        playerSpriteIndex < spriteRuntimeStates.size;
  }

  SpriteRuntimeState _playerState() {
    return spriteRuntimeStates.get(playerSpriteIndex);
  }

  void syncPlayerToSpriteRuntime() {
    if (!_hasPlayer()) {
      return;
    }
    final SpriteRuntimeState runtime = _playerState();
    runtime.worldX = playerX;
    runtime.worldY = playerY;
  }

  void resetPlayerToSpawn() {
    playerX = spawnX;
    playerY = spawnY;
    syncPlayerToSpriteRuntime();
  }

  void setPlayerFlip(bool flipX, bool flipY) {
    if (!_hasPlayer()) {
      return;
    }
    final SpriteRuntimeState runtime = _playerState();
    runtime.flipX = flipX;
    runtime.flipY = flipY;
  }

  Rectangle playerRectAt(double worldX, double worldY, Rectangle out) {
    return spriteRectAt(playerSpriteIndex, worldX, worldY, out);
  }

  Rectangle playerRect(Rectangle out) {
    return playerRectAt(playerX, playerY, out);
  }

  Rectangle spriteRectAt(
    int spriteIndex,
    double worldX,
    double worldY,
    Rectangle out,
  ) {
    if (spriteIndex < 0 ||
        spriteIndex >= levelData.sprites.size ||
        spriteIndex >= spriteRuntimeStates.size) {
      out.set(0, 0, 0, 0);
      return out;
    }

    final LevelSprite sprite = levelData.sprites.get(spriteIndex);
    final SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
    final Array<HitBox>? hitBoxes = _activeHitBoxes(spriteIndex);
    if (hitBoxes == null || hitBoxes.size <= 0) {
      _setFullSpriteRect(sprite, runtime, worldX, worldY, out);
      return out;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final HitBox hitBox in hitBoxes.iterable()) {
      if (hitBox.width <= 0 || hitBox.height <= 0) {
        continue;
      }
      _hitBoxRectAt(sprite, runtime, worldX, worldY, hitBox, rectCacheB);
      minX = minX < rectCacheB.x ? minX : rectCacheB.x;
      minY = minY < rectCacheB.y ? minY : rectCacheB.y;
      maxX = maxX > rectCacheB.x + rectCacheB.width
          ? maxX
          : rectCacheB.x + rectCacheB.width;
      maxY = maxY > rectCacheB.y + rectCacheB.height
          ? maxY
          : rectCacheB.y + rectCacheB.height;
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      _setFullSpriteRect(sprite, runtime, worldX, worldY, out);
      return out;
    }

    out.set(minX, minY, maxX - minX, maxY - minY);
    return out;
  }

  Rectangle spriteRectAtCurrent(int spriteIndex, Rectangle out) {
    if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
      out.set(0, 0, 0, 0);
      return out;
    }
    final SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
    return spriteRectAt(spriteIndex, runtime.worldX, runtime.worldY, out);
  }

  Rectangle zoneRect(LevelZone zone, Rectangle out) {
    final int zoneIndex = levelData.zones.indexOf(zone, true);
    if (zoneIndex >= 0) {
      return zoneRectAtIndex(zoneIndex, out);
    }
    out.set(zone.x, zone.y, zone.width, zone.height);
    return out;
  }

  Rectangle zoneRectAtIndex(int zoneIndex, Rectangle out) {
    if (zoneIndex < 0 || zoneIndex >= levelData.zones.size) {
      out.set(0, 0, 0, 0);
      return out;
    }
    final LevelZone zone = levelData.zones.get(zoneIndex);
    RuntimeTransform? runtime;
    if (zoneIndex < zoneRuntimeStates.size) {
      runtime = zoneRuntimeStates.get(zoneIndex);
    }
    final double zoneX = runtime == null ? zone.x : runtime.x;
    final double zoneY = runtime == null ? zone.y : runtime.y;
    out.set(zoneX, zoneY, zone.width, zone.height);
    return out;
  }

  Rectangle zoneRectAtPreviousIndex(int zoneIndex, Rectangle out) {
    if (zoneIndex < 0 || zoneIndex >= levelData.zones.size) {
      out.set(0, 0, 0, 0);
      return out;
    }
    final LevelZone zone = levelData.zones.get(zoneIndex);
    RuntimeTransform? runtime;
    if (zoneIndex < zonePreviousRuntimeStates.size) {
      runtime = zonePreviousRuntimeStates.get(zoneIndex);
    }
    final double zoneX = runtime == null ? zone.x : runtime.x;
    final double zoneY = runtime == null ? zone.y : runtime.y;
    out.set(zoneX, zoneY, zone.width, zone.height);
    return out;
  }

  void setSpriteVisible(int spriteIndex, bool visible) {
    if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
      return;
    }
    spriteRuntimeStates.get(spriteIndex).visible = visible;
  }

  void setPlayerAnimationOverrideByName(String? animationName) {
    if (!_hasPlayer()) {
      return;
    }
    setAnimationOverrideByName(playerSpriteIndex, animationName);
  }

  void setAnimationOverrideByName(int spriteIndex, String? animationName) {
    if (spriteIndex < 0 ||
        spriteIndex >= animationOverrideBySpriteIndex.length) {
      return;
    }
    if (animationName == null || animationName.trim().isEmpty) {
      animationOverrideBySpriteIndex[spriteIndex] = null;
      return;
    }
    animationOverrideBySpriteIndex[spriteIndex] = animationIdByName.get(
      _normalize(animationName),
    );
  }

  String? findAnimationIdByName(String? animationName) {
    if (animationName == null || animationName.trim().isEmpty) {
      return null;
    }
    return animationIdByName.get(_normalize(animationName));
  }

  IntArray findSpriteIndicesByTypeOrName(List<String> tokens) {
    final IntArray indices = IntArray();
    for (int i = 0; i < levelData.sprites.size; i++) {
      final LevelSprite sprite = levelData.sprites.get(i);
      final String type = _normalize(sprite.type);
      final String name = _normalize(sprite.name);
      if (containsAny(type, tokens) || containsAny(name, tokens)) {
        indices.add(i);
      }
    }
    return indices;
  }

  IntArray findZoneIndicesByTypeOrName(List<String> tokens) {
    final IntArray indices = IntArray();
    for (int i = 0; i < levelData.zones.size; i++) {
      final LevelZone zone = levelData.zones.get(i);
      final String type = _normalize(zone.type);
      final String name = _normalize(zone.name);
      if (containsAny(type, tokens) || containsAny(name, tokens)) {
        indices.add(i);
      }
    }
    return indices;
  }

  bool overlapsAnyZone(Rectangle bounds, IntArray zoneIndices) {
    for (final int idx in zoneIndices.iterable()) {
      if (idx < 0 || idx >= levelData.zones.size) {
        continue;
      }
      if (bounds.overlaps(zoneRectAtIndex(idx, rectCacheB))) {
        return true;
      }
    }
    return false;
  }

  bool spriteOverlapsAnyZoneByHitBoxes(
    int spriteIndex,
    double worldX,
    double worldY,
    IntArray zoneIndices,
  ) {
    if (zoneIndices.size <= 0) {
      return false;
    }
    if (spriteIndex < 0 ||
        spriteIndex >= levelData.sprites.size ||
        spriteIndex >= spriteRuntimeStates.size) {
      return false;
    }

    final LevelSprite sprite = levelData.sprites.get(spriteIndex);
    final SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
    final Array<HitBox>? hitBoxes = _activeHitBoxes(spriteIndex);
    if (hitBoxes == null || hitBoxes.size <= 0) {
      final Rectangle spriteBounds = spriteRectAt(
        spriteIndex,
        worldX,
        worldY,
        rectCacheA,
      );
      return overlapsAnyZone(spriteBounds, zoneIndices);
    }

    for (final HitBox hitBox in hitBoxes.iterable()) {
      if (hitBox.width <= 0 || hitBox.height <= 0) {
        continue;
      }
      final Rectangle hitBoxRect = _hitBoxRectAt(
        sprite,
        runtime,
        worldX,
        worldY,
        hitBox,
        rectCacheA,
      );
      if (overlapsAnyZone(hitBoxRect, zoneIndices)) {
        return true;
      }
    }
    return false;
  }

  bool spritesOverlapByHitBoxes(
    int firstSpriteIndex,
    double firstWorldX,
    double firstWorldY,
    int secondSpriteIndex,
    double secondWorldX,
    double secondWorldY,
  ) {
    if (firstSpriteIndex < 0 ||
        firstSpriteIndex >= levelData.sprites.size ||
        firstSpriteIndex >= spriteRuntimeStates.size ||
        secondSpriteIndex < 0 ||
        secondSpriteIndex >= levelData.sprites.size ||
        secondSpriteIndex >= spriteRuntimeStates.size) {
      return false;
    }

    final LevelSprite firstSprite = levelData.sprites.get(firstSpriteIndex);
    final SpriteRuntimeState firstRuntime = spriteRuntimeStates.get(
      firstSpriteIndex,
    );
    final LevelSprite secondSprite = levelData.sprites.get(secondSpriteIndex);
    final SpriteRuntimeState secondRuntime = spriteRuntimeStates.get(
      secondSpriteIndex,
    );
    final Array<HitBox>? firstHitBoxes = _activeHitBoxes(firstSpriteIndex);
    final Array<HitBox>? secondHitBoxes = _activeHitBoxes(secondSpriteIndex);

    if (firstHitBoxes == null ||
        firstHitBoxes.size <= 0 ||
        secondHitBoxes == null ||
        secondHitBoxes.size <= 0) {
      final Rectangle firstBounds = spriteRectAt(
        firstSpriteIndex,
        firstWorldX,
        firstWorldY,
        rectCacheA,
      );
      final Rectangle secondBounds = spriteRectAt(
        secondSpriteIndex,
        secondWorldX,
        secondWorldY,
        rectCacheB,
      );
      return firstBounds.overlaps(secondBounds);
    }

    for (final HitBox firstHitBox in firstHitBoxes.iterable()) {
      if (firstHitBox.width <= 0 || firstHitBox.height <= 0) {
        continue;
      }
      final Rectangle firstRect = _hitBoxRectAt(
        firstSprite,
        firstRuntime,
        firstWorldX,
        firstWorldY,
        firstHitBox,
        rectCacheA,
      );
      for (final HitBox secondHitBox in secondHitBoxes.iterable()) {
        if (secondHitBox.width <= 0 || secondHitBox.height <= 0) {
          continue;
        }
        final Rectangle secondRect = _hitBoxRectAt(
          secondSprite,
          secondRuntime,
          secondWorldX,
          secondWorldY,
          secondHitBox,
          rectCacheB,
        );
        if (firstRect.overlaps(secondRect)) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalize(String value) => value.trim().toLowerCase();

  int _findPlayerSpriteIndex() {
    for (int i = 0; i < levelData.sprites.size; i++) {
      final LevelSprite sprite = levelData.sprites.get(i);
      final String type = _normalize(sprite.type);
      final String name = _normalize(sprite.name);
      if (containsAny(type, <String>['player', 'hero', 'heroi', 'foxy']) ||
          containsAny(name, <String>['player', 'hero', 'heroi', 'foxy'])) {
        return i;
      }
    }
    return levelData.sprites.size > 0 ? 0 : -1;
  }

  void _setFullSpriteRect(
    LevelSprite sprite,
    SpriteRuntimeState runtime,
    double worldX,
    double worldY,
    Rectangle out,
  ) {
    final double anchorX = runtime.anchorX;
    final double anchorY = runtime.anchorY;
    final double left = worldX - sprite.width * anchorX;
    final double top = worldY - sprite.height * anchorY;
    out.set(left, top, sprite.width, sprite.height);
  }

  Rectangle _hitBoxRectAt(
    LevelSprite sprite,
    SpriteRuntimeState runtime,
    double worldX,
    double worldY,
    HitBox hitBox,
    Rectangle out,
  ) {
    final double anchorX = runtime.anchorX;
    final double anchorY = runtime.anchorY;
    final double left = worldX - sprite.width * anchorX;
    final double top = worldY - sprite.height * anchorY;

    double normalizedX = hitBox.x;
    double normalizedY = hitBox.y;
    if (runtime.flipX) {
      normalizedX = 1 - hitBox.x - hitBox.width;
    }
    if (runtime.flipY) {
      normalizedY = 1 - hitBox.y - hitBox.height;
    }

    final double x = left + normalizedX * sprite.width;
    final double y = top + normalizedY * sprite.height;
    final double width = hitBox.width * sprite.width;
    final double height = hitBox.height * sprite.height;
    out.set(x, y, width, height);
    return out;
  }

  Array<HitBox>? _activeHitBoxes(int spriteIndex) {
    if (spriteIndex < 0 ||
        spriteIndex >= spriteRuntimeStates.size ||
        spriteIndex >= levelData.sprites.size) {
      return null;
    }

    final LevelSprite sprite = levelData.sprites.get(spriteIndex);
    final SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
    String? animationId = runtime.animationId;
    animationId ??= sprite.animationId;
    if (animationId == null || animationId.isEmpty) {
      return null;
    }

    final AnimationClip? clip = levelData.animationClips.get(animationId);
    if (clip == null) {
      return null;
    }

    final int frameIndex = runtime.frameIndex;
    final FrameRig? frameRig = clip.frameRigs.get(frameIndex);
    if (frameRig != null && frameRig.hitBoxes.size > 0) {
      return frameRig.hitBoxes;
    }
    if (clip.hitBoxes.size > 0) {
      return clip.hitBoxes;
    }
    return null;
  }
}
