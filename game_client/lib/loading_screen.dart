import 'dart:ui' as ui;
import 'dart:math' as math;

import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'waiting_room_screen.dart';

class LoadingScreen extends ScreenAdapter {
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double minSecondsOnScreen = 0.85;
  static const double visualProgressSpeed = 3.2;

  static final ui.Color background = colorValueOf('050A06');
  static final ui.Color barBg = colorValueOf('0A1A0F');
  static final ui.Color barFill = colorValueOf('35FF74');
  static final ui.Color textColor = colorValueOf('35FF74');
  static final ui.Color subtextColor = colorValueOf('21964A');

  final GameApp game;
  final int levelIndex;
  final Viewport viewport = FitViewport(
    worldWidth,
    worldHeight,
    OrthographicCamera(),
  );
  final GlyphLayout layout = GlyphLayout();

  double elapsedSeconds = 0;
  double visualProgress = 0;

  bool _levelReady = false;

  LoadingScreen(this.game, this.levelIndex);

  @override
  void show() {
    game.queueReferencedAssetsForLevel(levelIndex);
    elapsedSeconds = 0;
    visualProgress = 0;
    _levelReady = false;
  }

  @override
  void render(double delta) {
    elapsedSeconds += delta;

    final bool done = game.getAssetManager().update(17);
    final double actualProgress = clampDouble(
      game.getAssetManager().getProgress(),
      0,
      1,
    );
    final double maxProgressForTime = clampDouble(
      elapsedSeconds / minSecondsOnScreen,
      0,
      1,
    );
    final double targetProgress = math.min(actualProgress, maxProgressForTime);
    visualProgress = math.min(
      targetProgress,
      visualProgress + math.max(0, delta) * visualProgressSpeed,
    );

    if (done &&
        elapsedSeconds >= minSecondsOnScreen &&
        visualProgress >= 0.999 &&
        !_levelReady) {
      _levelReady = true;
      game.setScreen(WaitingRoomScreen(game, levelIndex));
      return;
    }

    ScreenUtils.clear(background);
    viewport.apply();

    _renderBar(visualProgress);
    _renderText(visualProgress);
  }

  void _renderBar(double progress) {
    final double clamped = clampDouble(progress, 0, 1);
    const double barWidth = 620;
    const double barHeight = 28;
    final double x = (worldWidth - barWidth) * 0.5;
    final double y = worldHeight * 0.44;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    shapes.begin(ShapeType.filled);
    shapes.setColor(barBg);
    shapes.rect(x, y, barWidth, barHeight);
    shapes.setColor(barFill);
    shapes.rect(x, y, barWidth * clamped, barHeight);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(barFill);
    shapes.rect(x, y, barWidth, barHeight);
    shapes.end();
  }

  void _renderText(double progress) {
    final double clamped = clampDouble(progress, 0, 1);

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();

    _drawCenteredText(
      batch,
      font,
      'Loading ${game.getLevelName(levelIndex)}',
      worldHeight * 0.58,
      2,
      textColor,
    );
    _drawCenteredText(
      batch,
      font,
      '${(clamped * 100).round()}%',
      worldHeight * 0.40,
      1.5,
      subtextColor,
    );

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
    layout.setText(font, text);
    final double x = (worldWidth - layout.width) * 0.5;
    font.draw(batch, layout, x, y);
    font.getData().setScale(1);
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }
}
