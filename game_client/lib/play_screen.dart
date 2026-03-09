import 'dart:math' as math;
import 'dart:ui' as ui;

import 'libgdx_compat/asset_manager.dart';
import 'debug_overlay.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'gameplay_controller.dart';
import 'gameplay_controller_platformer.dart';
import 'gameplay_controller_top_down.dart';
import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'level_data.dart';
import 'level_loader.dart';
import 'level_renderer.dart';
import 'libgdx_compat/math_types.dart';
import 'menu_screen.dart';
import 'runtime_transform.dart';
import 'libgdx_compat/viewport.dart';

class PlayScreen extends ScreenAdapter {
  static const double defaultAnimationFps = 8;
  static const double fixedStepSeconds = 1 / 120;
  static const double maxFrameSeconds = 0.25;
  static const double hudMargin = 14;
  static const String hudBackLabel = 'Tornar';
  static const double hudButtonHeight = 48;
  static const double hudIconSize = 26;
  static const double hudIconTextGap = 8;
  static const double hudBackLabelScale = 1.45;
  static const double hudCounterScale = 1.45;
  static const double hudLifeTextScale = 1.2;
  static const double hudLifeBarWidth = 210;
  static const double hudLifeBarHeight = 14;
  static const double hudLifeBarTopGap = 8;
  static const double hudRowGap = 10;
  static const double endOverlayReturnDelaySeconds = 1;
  static const double endOverlayTitleScale = 2.4;
  static const double endOverlayPromptScale = 1.25;
  static const double endOverlayPromptGap = 44;
  static const double cameraDeadZoneFractionX = 0.22;
  static const double cameraDeadZoneFractionY = 0.18;
  static const double cameraFollowSmoothnessPerSecond = 10;

  static final ui.Color hudTextColor = colorValueOf('FFFFFF');
  static final ui.Color hudLifeBarBg = colorValueOf('5B0D0D');
  static final ui.Color hudLifeBarFill = colorValueOf('3DE67D');
  static final ui.Color hudLifeBarBorder = colorValueOf('E8FFE8');
  static final ui.Color endOverlayDim = colorValueOf('000000A8');

  final GameApp game;
  final int levelIndex;
  final OrthographicCamera camera = OrthographicCamera();
  late final Viewport viewport;
  final OrthographicCamera hudCamera = OrthographicCamera();
  final Viewport hudViewport = ScreenViewport(OrthographicCamera());
  final LevelRenderer levelRenderer = LevelRenderer();
  final DebugOverlay debugOverlayRenderer = DebugOverlay();
  final Array<SpriteRuntimeState> spriteRuntimeStates =
      Array<SpriteRuntimeState>();
  final Array<RuntimeTransform> layerRuntimeStates = Array<RuntimeTransform>();
  final Array<RuntimeTransform> zoneRuntimeStates = Array<RuntimeTransform>();
  final Array<RuntimeTransform> zonePreviousRuntimeStates =
      Array<RuntimeTransform>();
  final Array<_PathBindingRuntime> _pathBindingRuntimes =
      Array<_PathBindingRuntime>();
  final FloatArray spriteAnimationElapsed = FloatArray();
  final IntArray spriteTotalFrames = IntArray();
  List<String> spriteTotalFramesCacheKey = <String>[];
  List<String?> spriteCurrentAnimationId = <String?>[];

  late final LevelData levelData;
  late final List<bool> layerVisibilityStates;
  late final GameplayController gameplayController;
  final Rectangle backButtonBounds = Rectangle();
  final GlyphLayout hudLayout = GlyphLayout();
  Texture? backIconTexture;

  _DebugOverlayMode _debugOverlayMode = _DebugOverlayMode.none;
  _EndOverlayState _endOverlayState = _EndOverlayState.none;
  double endOverlayElapsedSeconds = 0;
  double fixedStepAccumulator = 0;
  double pathMotionTimeSeconds = 0;

  PlayScreen(this.game, this.levelIndex) {
    levelData = LevelLoader.loadLevel(levelIndex);
    layerVisibilityStates = _buildInitialLayerVisibility(levelData);
    viewport = _createViewport(levelData, camera);
    camera.setPosition(0, 0);
    viewport.update(
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
      false,
    );
    _applyInitialCameraFromLevel();
    _initializeAnimationRuntimeState();
    _initializeTransformRuntimeState();
    _initializePathBindingRuntimes();
    gameplayController = _createGameplayController();
    hudViewport.update(
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
      true,
    );
    _loadHudAssets();
  }

  @override
  void show() {
    Gdx.input.setInputProcessor(null);
  }

  @override
  void render(double delta) {
    if (Gdx.input.isKeyJustPressed(Input.keys.escape)) {
      _returnToMenu();
      return;
    }

    _updateBackButtonBounds();
    if (!_isEndOverlayActive() && _handleHudBackInput()) {
      return;
    }

    if (_isEndOverlayActive()) {
      _updateEndOverlay(delta);
      if (game.getScreen() != this) {
        return;
      }
    } else {
      _handleDebugOverlayInput();
      gameplayController.handleInput();
      _stepSimulation(delta);
      _updateEndOverlayStateIfNeeded();
    }

    viewport.apply();
    _updateCameraForGameplay();
    ScreenUtils.clear(levelData.backgroundColor);

    final SpriteBatch batch = game.getBatch();
    batch.begin();
    levelRenderer.render(
      levelData,
      game.getAssetManager(),
      batch,
      camera,
      spriteRuntimeStates,
      layerVisibilityStates,
      layerRuntimeStates,
      viewport,
    );
    batch.end();

    debugOverlayRenderer.render(
      levelData,
      camera,
      _debugOverlayMode == _DebugOverlayMode.zones ||
          _debugOverlayMode == _DebugOverlayMode.both,
      _debugOverlayMode == _DebugOverlayMode.paths ||
          _debugOverlayMode == _DebugOverlayMode.both,
      zoneRuntimeStates,
      viewport,
    );

    _renderHud();
    _renderEndOverlayIfActive();
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), false);
    hudViewport.update(width.toDouble(), height.toDouble(), true);
    _updateBackButtonBounds();
    _updateCameraForGameplay();
  }

  @override
  void dispose() {
    debugOverlayRenderer.dispose();
  }

  void _stepSimulation(double deltaSeconds) {
    final double clampedDelta = math.max(
      0,
      math.min(maxFrameSeconds, deltaSeconds),
    );
    fixedStepAccumulator += clampedDelta;

    while (fixedStepAccumulator >= fixedStepSeconds) {
      _snapshotPreviousZoneTransforms();
      _advancePathBindings(fixedStepSeconds);
      gameplayController.fixedUpdate(fixedStepSeconds);
      _updateAnimations(fixedStepSeconds);
      fixedStepAccumulator -= fixedStepSeconds;
    }
  }

  void _initializeAnimationRuntimeState() {
    spriteRuntimeStates.clear();
    spriteAnimationElapsed.clear();
    spriteTotalFrames.clear();
    spriteAnimationElapsed.setSize(levelData.sprites.size);

    for (int i = 0; i < levelData.sprites.size; i++) {
      final LevelSprite sprite = levelData.sprites.get(i);
      spriteRuntimeStates.add(
        SpriteRuntimeState(
          sprite.frameIndex,
          sprite.anchorX,
          sprite.anchorY,
          sprite.x,
          sprite.y,
          true,
          sprite.flipX,
          sprite.flipY,
          math.max(1, sprite.width.round()),
          math.max(1, sprite.height.round()),
          sprite.texturePath,
          sprite.animationId,
        ),
      );
      spriteTotalFrames.add(0);
      spriteAnimationElapsed.set(i, 0);
    }

    spriteTotalFramesCacheKey = List<String>.filled(levelData.sprites.size, '');
    spriteCurrentAnimationId = List<String?>.filled(
      levelData.sprites.size,
      null,
    );
  }

  void _initializeTransformRuntimeState() {
    layerRuntimeStates.clear();
    zoneRuntimeStates.clear();
    zonePreviousRuntimeStates.clear();

    for (int i = 0; i < levelData.layers.size; i++) {
      final LevelLayer layer = levelData.layers.get(i);
      layerRuntimeStates.add(RuntimeTransform(layer.x, layer.y));
    }

    for (int i = 0; i < levelData.zones.size; i++) {
      final LevelZone zone = levelData.zones.get(i);
      final RuntimeTransform current = RuntimeTransform(zone.x, zone.y);
      zoneRuntimeStates.add(current);
      zonePreviousRuntimeStates.add(RuntimeTransform(zone.x, zone.y));
    }

    pathMotionTimeSeconds = 0;
  }

  void _initializePathBindingRuntimes() {
    _pathBindingRuntimes.clear();
    if (levelData.pathBindings.size <= 0 || levelData.paths.size <= 0) {
      return;
    }

    final ObjectMap<String, _PathRuntime> pathById =
        ObjectMap<String, _PathRuntime>();
    for (int i = 0; i < levelData.paths.size; i++) {
      final LevelPath path = levelData.paths.get(i);
      if (path.id.isEmpty || path.points.size < 2) {
        continue;
      }
      final _PathRuntime? runtime = _PathRuntime.from(path);
      if (runtime != null) {
        pathById.put(path.id, runtime);
      }
    }

    for (int i = 0; i < levelData.pathBindings.size; i++) {
      final LevelPathBinding binding = levelData.pathBindings.get(i);
      if (!binding.enabled) {
        continue;
      }
      final _PathRuntime? path = pathById.get(binding.pathId);
      if (path == null) {
        continue;
      }

      double initialX;
      double initialY;
      if (binding.targetType == 'layer') {
        if (binding.targetIndex < 0 ||
            binding.targetIndex >= layerRuntimeStates.size) {
          continue;
        }
        final RuntimeTransform target = layerRuntimeStates.get(
          binding.targetIndex,
        );
        initialX = target.x;
        initialY = target.y;
        _pathBindingRuntimes.add(
          _PathBindingRuntime(path, binding, initialX, initialY),
        );
      } else if (binding.targetType == 'zone') {
        if (binding.targetIndex < 0 ||
            binding.targetIndex >= zoneRuntimeStates.size) {
          continue;
        }
        final RuntimeTransform target = zoneRuntimeStates.get(
          binding.targetIndex,
        );
        initialX = target.x;
        initialY = target.y;
        _pathBindingRuntimes.add(
          _PathBindingRuntime(path, binding, initialX, initialY),
        );
      } else if (binding.targetType == 'sprite') {
        if (binding.targetIndex < 0 ||
            binding.targetIndex >= spriteRuntimeStates.size) {
          continue;
        }
        final SpriteRuntimeState target = spriteRuntimeStates.get(
          binding.targetIndex,
        );
        initialX = target.worldX;
        initialY = target.worldY;
        _pathBindingRuntimes.add(
          _PathBindingRuntime(path, binding, initialX, initialY),
        );
      }
    }
  }

  void _snapshotPreviousZoneTransforms() {
    for (
      int i = 0;
      i < zoneRuntimeStates.size && i < zonePreviousRuntimeStates.size;
      i++
    ) {
      final RuntimeTransform current = zoneRuntimeStates.get(i);
      final RuntimeTransform previous = zonePreviousRuntimeStates.get(i);
      previous.x = current.x;
      previous.y = current.y;
    }
  }

  void _advancePathBindings(double delta) {
    if (_pathBindingRuntimes.size <= 0) {
      return;
    }

    pathMotionTimeSeconds += delta;
    for (final _PathBindingRuntime runtime in _pathBindingRuntimes.iterable()) {
      if (!runtime.binding.enabled) {
        continue;
      }
      final double progress = _pathProgressAtTime(
        runtime.binding.behavior,
        runtime.binding.durationSeconds,
        pathMotionTimeSeconds,
      );
      final _PathSample sample = runtime.path.sampleAtProgress(progress);

      final double targetX = runtime.binding.relativeToInitialPosition
          ? runtime.initialX + (sample.x - runtime.path.firstPointX)
          : sample.x;
      final double targetY = runtime.binding.relativeToInitialPosition
          ? runtime.initialY + (sample.y - runtime.path.firstPointY)
          : sample.y;
      _applyPathTarget(
        runtime.binding.targetType,
        runtime.binding.targetIndex,
        targetX,
        targetY,
      );
    }
  }

  void _applyPathTarget(
    String targetType,
    int targetIndex,
    double x,
    double y,
  ) {
    if (targetType == 'layer') {
      if (targetIndex >= 0 && targetIndex < layerRuntimeStates.size) {
        final RuntimeTransform target = layerRuntimeStates.get(targetIndex);
        target.x = x;
        target.y = y;
      }
      return;
    }
    if (targetType == 'zone') {
      if (targetIndex >= 0 && targetIndex < zoneRuntimeStates.size) {
        final RuntimeTransform target = zoneRuntimeStates.get(targetIndex);
        target.x = x;
        target.y = y;
      }
      return;
    }
    if (targetType == 'sprite') {
      if (targetIndex >= 0 && targetIndex < spriteRuntimeStates.size) {
        final SpriteRuntimeState target = spriteRuntimeStates.get(targetIndex);
        target.worldX = x;
        target.worldY = y;
      }
    }
  }

  double _pathProgressAtTime(
    String behavior,
    double durationSeconds,
    double timeSeconds,
  ) {
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      return 0;
    }

    final double t = math.max(0, timeSeconds);
    final String normalizedBehavior = behavior.trim().toLowerCase();
    if (normalizedBehavior == 'ping_pong' || normalizedBehavior == 'pingpong') {
      final double cycle = durationSeconds * 2;
      if (cycle <= 0) {
        return 0;
      }
      final double cycleTime = t % cycle;
      if (cycleTime <= durationSeconds) {
        return cycleTime / durationSeconds;
      }
      final double backwardsTime = cycleTime - durationSeconds;
      return 1 - (backwardsTime / durationSeconds);
    }
    if (normalizedBehavior == 'once') {
      return clampDouble(t / durationSeconds, 0, 1);
    }
    return (t % durationSeconds) / durationSeconds;
  }

  void _updateAnimations(double delta) {
    final double safeDelta = math.max(0, delta);
    for (int i = 0; i < spriteRuntimeStates.size; i++) {
      final SpriteRuntimeState runtime = spriteRuntimeStates.get(i);
      final LevelSprite sprite = levelData.sprites.get(i);
      final String? overrideAnimationId = gameplayController
          .animationOverrideForSprite(i);
      String? animationId = overrideAnimationId;
      if (animationId == null || animationId.isEmpty) {
        animationId = sprite.animationId;
      }

      final String? previousAnimationId = spriteCurrentAnimationId[i];
      if ((previousAnimationId == null && animationId != null) ||
          (previousAnimationId != null && previousAnimationId != animationId)) {
        spriteAnimationElapsed.set(i, 0);
      }
      spriteCurrentAnimationId[i] = animationId;

      if (animationId == null || animationId.isEmpty) {
        runtime.animationId = null;
        runtime.texturePath = sprite.texturePath;
        runtime.frameWidth = math.max(1, sprite.width.round());
        runtime.frameHeight = math.max(1, sprite.height.round());
        runtime.frameIndex = math.max(0, sprite.frameIndex);
        runtime.anchorX = sprite.anchorX;
        runtime.anchorY = sprite.anchorY;
        continue;
      }

      final AnimationClip? clip = levelData.animationClips.get(animationId);
      if (clip == null) {
        runtime.animationId = null;
        runtime.texturePath = sprite.texturePath;
        runtime.frameWidth = math.max(1, sprite.width.round());
        runtime.frameHeight = math.max(1, sprite.height.round());
        runtime.frameIndex = math.max(0, sprite.frameIndex);
        runtime.anchorX = sprite.anchorX;
        runtime.anchorY = sprite.anchorY;
        continue;
      }

      runtime.texturePath = clip.texturePath ?? sprite.texturePath;
      runtime.frameWidth = clip.frameWidth > 0
          ? clip.frameWidth
          : math.max(1, sprite.width.round());
      runtime.frameHeight = clip.frameHeight > 0
          ? clip.frameHeight
          : math.max(1, sprite.height.round());
      runtime.animationId = animationId;

      double elapsed = spriteAnimationElapsed.get(i) + safeDelta;
      spriteAnimationElapsed.set(i, elapsed);

      final int start = math.max(0, clip.startFrame);
      final int end = math.max(start, clip.endFrame);
      final int span = math.max(1, end - start + 1);
      final double fps = clip.fps.isFinite && clip.fps > 0
          ? clip.fps
          : defaultAnimationFps;
      final int ticks = (elapsed * fps).floor();
      final int offset = clip.loop
          ? _positiveMod(ticks, span)
          : math.min(ticks, span - 1);
      runtime.frameIndex = start + offset;

      final FrameRig? frameRig = clip.frameRigs.get(runtime.frameIndex);
      runtime.anchorX = frameRig?.anchorX ?? clip.anchorX;
      runtime.anchorY = frameRig?.anchorY ?? clip.anchorY;
    }
  }

  int _positiveMod(int value, int divisor) {
    if (divisor <= 0) {
      return 0;
    }
    final int mod = value % divisor;
    return mod < 0 ? mod + divisor : mod;
  }

  void _renderHud() {
    final ShapeRenderer shapes = game.getShapeRenderer();
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    final double hudWidth = Gdx.graphics.getWidth().toDouble();

    batch.begin();
    font.getData().setScale(hudBackLabelScale);
    font.setColor(hudTextColor);
    double backTextX = hudMargin;
    if (backIconTexture != null) {
      final ui.Rect iconSrc = ui.Rect.fromLTWH(
        0,
        0,
        backIconTexture!.width.toDouble(),
        backIconTexture!.height.toDouble(),
      );
      final ui.Rect iconDst = ui.Rect.fromLTWH(
        hudMargin,
        hudMargin + (hudButtonHeight - hudIconSize) * 0.5,
        hudIconSize,
        hudIconSize,
      );
      batch.drawRegion(backIconTexture!, iconSrc, iconDst);
      backTextX = hudMargin + hudIconSize + hudIconTextGap;
    }
    font.drawText(hudBackLabel, backTextX, hudMargin + hudButtonHeight * 0.72);
    font.getData().setScale(1);

    final GameplayController gc = gameplayController;
    String? topRightLabel;
    bool showLifeBar = false;
    double lifePercent = 0;
    if (gc is GameplayControllerTopDown) {
      topRightLabel =
          'Arbres: ${gc.getCollectedArbresCount()}/${gc.getTotalArbresCount()}';
    } else if (gc is GameplayControllerPlatformer) {
      topRightLabel =
          'Gems: ${gc.getCollectedGemsCount()}/${gc.getTotalGemsCount()}';
      showLifeBar = true;
      lifePercent = clampDouble(gc.getLifePercent(), 0, 100);
    }

    font.setColor(hudTextColor);
    final double rightEdgeX = hudWidth - hudMargin;
    final double topTextY = hudMargin + hudButtonHeight * 0.72;
    double gemsTextX = 0;
    double gemsTextY = topTextY;
    double gemsTextHeight = 0;
    double lifeTextX = 0;
    double lifeTextY = topTextY;
    final String lifeText = 'Life ${lifePercent.round()}%';
    final double lifeBarX = rightEdgeX - hudLifeBarWidth;
    double lifeBarY = 0;

    if (topRightLabel != null) {
      font.getData().setScale(hudCounterScale);
      hudLayout.setText(font, topRightLabel);
      gemsTextX = rightEdgeX - hudLayout.width;
      gemsTextHeight = hudLayout.height;
      font.getData().setScale(1);
    }

    if (showLifeBar) {
      font.getData().setScale(hudLifeTextScale);
      hudLayout.setText(font, lifeText);
      lifeTextX = rightEdgeX - hudLayout.width;
      lifeBarY = lifeTextY + hudLifeBarTopGap;
      if (topRightLabel != null) {
        gemsTextY = lifeBarY + hudLifeBarHeight + hudRowGap + gemsTextHeight;
      }
      font.getData().setScale(1);
    }

    if (showLifeBar) {
      batch.end();

      shapes.begin(ShapeType.filled);
      shapes.setColor(hudLifeBarBg);
      shapes.rect(lifeBarX, lifeBarY, hudLifeBarWidth, hudLifeBarHeight);
      shapes.setColor(hudLifeBarFill);
      shapes.rect(
        lifeBarX,
        lifeBarY,
        hudLifeBarWidth * (lifePercent / 100),
        hudLifeBarHeight,
      );
      shapes.end();

      shapes.begin(ShapeType.line);
      shapes.setColor(hudLifeBarBorder);
      shapes.rect(lifeBarX, lifeBarY, hudLifeBarWidth, hudLifeBarHeight);
      shapes.end();

      batch.begin();
    }

    if (topRightLabel != null) {
      font.getData().setScale(hudCounterScale);
      hudLayout.setText(font, topRightLabel);
      font.drawText(topRightLabel, gemsTextX, gemsTextY);
      font.getData().setScale(1);
    }

    if (showLifeBar) {
      font.getData().setScale(hudLifeTextScale);
      hudLayout.setText(font, lifeText);
      font.drawText(lifeText, lifeTextX, lifeTextY);
      font.getData().setScale(1);
    }

    batch.end();
  }

  void _loadHudAssets() {
    if (game.getAssetManager().isLoaded('other/enrrere.png', Texture)) {
      backIconTexture = game.getAssetManager().get(
        'other/enrrere.png',
        Texture,
      );
    }
  }

  void _renderEndOverlayIfActive() {
    if (!_isEndOverlayActive()) {
      return;
    }

    final ShapeRenderer shapes = game.getShapeRenderer();
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();

    shapes.begin(ShapeType.filled);
    shapes.setColor(endOverlayDim);
    shapes.rect(
      0,
      0,
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
    );
    shapes.end();

    batch.begin();
    _drawCenteredText(
      batch,
      font,
      _endOverlayTitle(),
      Gdx.graphics.getHeight() * 0.45,
      endOverlayTitleScale,
      hudTextColor,
    );
    if (endOverlayElapsedSeconds >= endOverlayReturnDelaySeconds) {
      _drawCenteredText(
        batch,
        font,
        _endOverlayPrompt(),
        Gdx.graphics.getHeight() * 0.45 + endOverlayPromptGap,
        endOverlayPromptScale,
        hudTextColor,
      );
    }
    batch.end();
  }

  void _drawCenteredText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    hudLayout.setText(font, text);
    final double x = (Gdx.graphics.getWidth() - hudLayout.width) * 0.5;
    font.draw(batch, hudLayout, x, y);
    font.getData().setScale(1);
  }

  bool _handleHudBackInput() {
    if (!Gdx.input.justTouched()) {
      return false;
    }
    final double x = Gdx.input.getX().toDouble();
    final double y = Gdx.input.getY().toDouble();
    if (backButtonBounds.contains(x, y)) {
      _returnToMenu();
      return true;
    }
    return false;
  }

  void _updateBackButtonBounds() {
    final BitmapFont font = game.getFont();
    font.getData().setScale(hudBackLabelScale);
    hudLayout.setText(font, hudBackLabel);
    font.getData().setScale(1);
    final double iconWidth = backIconTexture != null
        ? hudIconSize + hudIconTextGap
        : 0;
    backButtonBounds.set(
      hudMargin,
      hudMargin,
      iconWidth + hudLayout.width + 16,
      hudButtonHeight,
    );
  }

  void _updateEndOverlayStateIfNeeded() {
    if (_isEndOverlayActive()) {
      return;
    }

    final GameplayController gc = gameplayController;
    if (gc is GameplayControllerTopDown) {
      if (gc.isWin()) {
        _endOverlayState = _EndOverlayState.level0Win;
      }
    } else if (gc is GameplayControllerPlatformer) {
      if (gc.isGameOver()) {
        _endOverlayState = _EndOverlayState.level1Lose;
      } else if (gc.isWin()) {
        _endOverlayState = _EndOverlayState.level1Win;
      }
    }

    if (_isEndOverlayActive()) {
      endOverlayElapsedSeconds = 0;
    }
  }

  bool _isEndOverlayActive() {
    return _endOverlayState != _EndOverlayState.none;
  }

  void _updateEndOverlay(double delta) {
    endOverlayElapsedSeconds += math.max(0, delta);
    if (endOverlayElapsedSeconds < endOverlayReturnDelaySeconds) {
      return;
    }

    if (Gdx.input.justTouched() || _isAnyKeyJustPressed()) {
      _returnToMenu();
    }
  }

  bool _isAnyKeyJustPressed() {
    final List<int> keys = <int>[
      Input.keys.enter,
      Input.keys.space,
      Input.keys.escape,
      Input.keys.up,
      Input.keys.down,
      Input.keys.left,
      Input.keys.right,
      Input.keys.w,
      Input.keys.a,
      Input.keys.s,
      Input.keys.d,
    ];
    for (final int key in keys) {
      if (Gdx.input.isKeyJustPressed(key)) {
        return true;
      }
    }
    return false;
  }

  String _endOverlayTitle() {
    switch (_endOverlayState) {
      case _EndOverlayState.level0Win:
        return 'Has Guanyat';
      case _EndOverlayState.level1Lose:
        return 'You Lose';
      case _EndOverlayState.level1Win:
        return 'You Win';
      case _EndOverlayState.none:
        return '';
    }
  }

  String _endOverlayPrompt() {
    if (_endOverlayState == _EndOverlayState.level0Win) {
      return 'Apreta qualsevol tecla per tornar';
    }
    return 'Press any key to return to main menu';
  }

  void _handleDebugOverlayInput() {
    if (!Gdx.input.isKeyJustPressed(Input.keys.f3)) {
      return;
    }

    final bool shiftPressed =
        Gdx.input.isKeyPressed(Input.keys.shiftLeft) ||
        Gdx.input.isKeyPressed(Input.keys.shiftRight);
    if (shiftPressed) {
      _debugOverlayMode = _nextDebugOverlayMode(_debugOverlayMode);
    } else {
      _debugOverlayMode = _debugOverlayMode == _DebugOverlayMode.none
          ? _DebugOverlayMode.both
          : _DebugOverlayMode.none;
    }

    Gdx.app.log(
      'PlayScreen',
      'Debug overlay: ${_debugOverlayMode.name.toLowerCase()}',
    );
  }

  void _applyInitialCameraFromLevel() {
    final double centerX = levelData.viewportX + levelData.viewportWidth * 0.5;
    final double centerY = levelData.viewportY + levelData.viewportHeight * 0.5;
    camera.setPosition(centerX, centerY);
    camera.update();
  }

  void _updateCameraForGameplay() {
    if (!gameplayController.hasCameraTarget()) {
      camera.update();
      return;
    }

    final double worldW = math.max(1, levelData.worldWidth);
    final double worldH = math.max(1, levelData.worldHeight);
    final double viewW = math.max(1, viewport.worldWidth);
    final double viewH = math.max(1, viewport.worldHeight);
    final double halfW = viewW * 0.5;
    final double halfH = viewH * 0.5;

    final double minX = math.min(halfW, worldW - halfW);
    final double maxX = math.max(halfW, worldW - halfW);
    final double minY = math.min(halfH, worldH - halfH);
    final double maxY = math.max(halfH, worldH - halfH);

    final double playerX = gameplayController.getCameraTargetX();
    final double playerY = gameplayController.getCameraTargetY();
    final double currentCenterX = camera.x;
    final double currentCenterY = camera.y;

    final double deadZoneHalfW = viewW * cameraDeadZoneFractionX * 0.5;
    final double deadZoneHalfH = viewH * cameraDeadZoneFractionY * 0.5;

    double targetCenterX = currentCenterX;
    if (playerX < currentCenterX - deadZoneHalfW) {
      targetCenterX = playerX + deadZoneHalfW;
    } else if (playerX > currentCenterX + deadZoneHalfW) {
      targetCenterX = playerX - deadZoneHalfW;
    }

    double targetCenterY = currentCenterY;
    if (playerY < currentCenterY - deadZoneHalfH) {
      targetCenterY = playerY + deadZoneHalfH;
    } else if (playerY > currentCenterY + deadZoneHalfH) {
      targetCenterY = playerY - deadZoneHalfH;
    }

    targetCenterX = clampDouble(targetCenterX, minX, maxX);
    targetCenterY = clampDouble(targetCenterY, minY, maxY);

    final double dt = clampDouble(
      Gdx.graphics.getDeltaTime(),
      0,
      maxFrameSeconds,
    );
    final double followAlpha =
        1 - math.exp(-cameraFollowSmoothnessPerSecond * dt);

    double centerX = MathUtils.lerp(currentCenterX, targetCenterX, followAlpha);
    double centerY = MathUtils.lerp(currentCenterY, targetCenterY, followAlpha);

    centerX = clampDouble(centerX, minX, maxX);
    centerY = clampDouble(centerY, minY, maxY);

    camera.setPosition(centerX, centerY);
    camera.update();
  }

  GameplayController _createGameplayController() {
    if (_isPlatformerLevel(levelData)) {
      Gdx.app.log('PlayScreen', 'Gameplay mode: platformer');
      return GameplayControllerPlatformer(
        levelData,
        spriteRuntimeStates,
        layerVisibilityStates,
        zoneRuntimeStates,
        zonePreviousRuntimeStates,
      );
    }

    Gdx.app.log('PlayScreen', 'Gameplay mode: topdown');
    return GameplayControllerTopDown(
      levelData,
      spriteRuntimeStates,
      layerVisibilityStates,
      zoneRuntimeStates,
      zonePreviousRuntimeStates,
    );
  }

  bool _isPlatformerLevel(LevelData levelData) {
    for (final LevelZone zone in levelData.zones.iterable()) {
      final String type = normalize(zone.type);
      final String name = normalize(zone.name);
      if (containsAny(type, <String>['floor', 'death']) ||
          containsAny(name, <String>['floor', 'death'])) {
        return true;
      }
    }
    return false;
  }

  Viewport _createViewport(LevelData levelData, OrthographicCamera camera) {
    switch (levelData.viewportAdaptation) {
      case 'expand':
        return ExtendViewport(
          levelData.viewportWidth,
          levelData.viewportHeight,
          camera,
        );
      case 'stretch':
        return StretchViewport(
          levelData.viewportWidth,
          levelData.viewportHeight,
          camera,
        );
      case 'letterbox':
      default:
        return FitViewport(
          levelData.viewportWidth,
          levelData.viewportHeight,
          camera,
        );
    }
  }

  List<bool> _buildInitialLayerVisibility(LevelData levelData) {
    final List<bool> states = List<bool>.filled(levelData.layers.size, true);
    for (int i = 0; i < levelData.layers.size; i++) {
      states[i] = levelData.layers.get(i).visible;
    }
    return states;
  }

  _DebugOverlayMode _nextDebugOverlayMode(_DebugOverlayMode mode) {
    switch (mode) {
      case _DebugOverlayMode.none:
        return _DebugOverlayMode.zones;
      case _DebugOverlayMode.zones:
        return _DebugOverlayMode.paths;
      case _DebugOverlayMode.paths:
        return _DebugOverlayMode.both;
      case _DebugOverlayMode.both:
        return _DebugOverlayMode.none;
    }
  }

  void _returnToMenu() {
    game.unloadReferencedAssetsForLevel(levelIndex);
    game.setScreen(MenuScreen(game));
  }
}

class _PathBindingRuntime {
  final _PathRuntime path;
  final LevelPathBinding binding;
  final double initialX;
  final double initialY;

  _PathBindingRuntime(this.path, this.binding, this.initialX, this.initialY);
}

class _PathRuntime {
  final List<Vector2> points;
  final List<double> cumulativeDistances;
  final double totalDistance;
  final double firstPointX;
  final double firstPointY;

  _PathRuntime(
    this.points,
    this.cumulativeDistances,
    this.totalDistance,
    this.firstPointX,
    this.firstPointY,
  );

  static _PathRuntime? from(LevelPath path) {
    if (path.points.size < 2) {
      return null;
    }

    final List<Vector2> points = path.points.toList();
    final List<double> cumulativeDistances = <double>[0];
    double totalDistance = 0;
    for (int i = 1; i < points.length; i++) {
      final Vector2 prev = points[i - 1];
      final Vector2 curr = points[i];
      final double dx = curr.x - prev.x;
      final double dy = curr.y - prev.y;
      totalDistance += math.sqrt(dx * dx + dy * dy);
      cumulativeDistances.add(totalDistance);
    }
    final Vector2 first = points.first;
    return _PathRuntime(
      points,
      cumulativeDistances,
      totalDistance,
      first.x,
      first.y,
    );
  }

  _PathSample sampleAtProgress(double progress) {
    if (points.isEmpty) {
      return _PathSample(0, 0);
    }
    if (points.length < 2 || totalDistance <= 0) {
      final Vector2 first = points.first;
      return _PathSample(first.x, first.y);
    }

    final double clampedProgress = clampDouble(progress, 0, 1);
    final double targetDistance = totalDistance * clampedProgress;
    for (int i = 1; i < points.length; i++) {
      final double segmentStart = cumulativeDistances[i - 1];
      final double segmentEnd = cumulativeDistances[i];
      if (targetDistance > segmentEnd && i < points.length - 1) {
        continue;
      }
      final double segmentDistance = segmentEnd - segmentStart;
      if (segmentDistance <= 0) {
        final Vector2 point = points[i];
        return _PathSample(point.x, point.y);
      }
      final double localT = clampDouble(
        (targetDistance - segmentStart) / segmentDistance,
        0,
        1,
      );
      final Vector2 a = points[i - 1];
      final Vector2 b = points[i];
      return _PathSample(
        a.x + (b.x - a.x) * localT,
        a.y + (b.y - a.y) * localT,
      );
    }

    final Vector2 last = points.last;
    return _PathSample(last.x, last.y);
  }
}

class _PathSample {
  final double x;
  final double y;

  _PathSample(this.x, this.y);
}

enum _DebugOverlayMode { none, zones, paths, both }

enum _EndOverlayState { none, level0Win, level1Lose, level1Win }
