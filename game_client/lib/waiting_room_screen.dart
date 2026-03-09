import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'level_data.dart';
import 'level_loader.dart';
import 'play_screen.dart';
import 'player_list_renderer.dart';

class WaitingRoomScreen extends ScreenAdapter {
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double panelWidth = 320;
  static const double panelPadding = 14;
  static const double leaderboardStartY = 92;
  static const double gemLegendSpriteSize = 28;
  static const double gemLegendCenterOffsetX = 44;

  static final ui.Color background = colorValueOf('070E08');
  static final ui.Color panelFill = colorValueOf('09140CCC');
  static final ui.Color panelStroke = colorValueOf('35FF74');
  static final ui.Color titleColor = colorValueOf('FFFFFF');
  static final ui.Color textColor = colorValueOf('D8FFE3');
  static final ui.Color dimTextColor = colorValueOf('76A784');
  static final ui.Color highlightColor = colorValueOf('35FF74');
  static final ui.Color localPlayerColor = colorValueOf('FFE07A');

  final GameApp game;
  final int levelIndex;
  final Viewport viewport = FitViewport(
    worldWidth,
    worldHeight,
    OrthographicCamera(),
  );
  final GlyphLayout layout = GlyphLayout();
  late final LevelData levelData;
  late final Map<String, LevelSprite> gemTemplateByType;

  WaitingRoomScreen(this.game, this.levelIndex) {
    levelData = LevelLoader.loadLevel(levelIndex);
    gemTemplateByType = _buildGemTemplates(levelData);
  }

  @override
  void render(double delta) {
    final AppData appData = game.getAppData();
    if (appData.phase == MatchPhase.playing ||
        appData.phase == MatchPhase.finished) {
      game.setScreen(PlayScreen(game, levelIndex));
      return;
    }

    ScreenUtils.clear(background);
    viewport.apply();

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.filled);
    shapes.setColor(panelFill);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(panelStroke);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();

    final double legendCenterX =
        (worldWidth - panelWidth) * 0.5 + gemLegendCenterOffsetX;
    final List<_GemLegendEntry> gemLegend = <_GemLegendEntry>[
      _GemLegendEntry('blue', 'Blue gem', 1),
      _GemLegendEntry('green', 'Green gem', 2),
      _GemLegendEntry('yellow', 'Yellow gem', 3),
      _GemLegendEntry('purple', 'Purple gem', 5),
    ];

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();

    _drawCenteredText(
      batch,
      font,
      'Waiting Room',
      worldHeight * 0.18,
      2.8,
      titleColor,
    );
    _drawCenteredText(
      batch,
      font,
      'Match starts in',
      worldHeight * 0.32,
      1.6,
      dimTextColor,
    );
    _drawCenteredText(
      batch,
      font,
      '${math.max(0, appData.countdownSeconds)}',
      worldHeight * 0.48,
      5.5,
      highlightColor,
    );

    _drawCenteredText(
      batch,
      font,
      'Collect as many gems as you can.',
      worldHeight * 0.62,
      1.55,
      textColor,
    );

    double legendTextY = worldHeight * 0.71;
    for (final _GemLegendEntry entry in gemLegend) {
      _drawGemLegendSprite(
        batch,
        entry.type,
        legendCenterX - 168,
        legendTextY - 22,
      );
      _drawCenteredText(
        batch,
        font,
        '${entry.label}  ${entry.points} pt${entry.points == 1 ? '' : 's'}',
        legendTextY,
        1.22,
        textColor,
      );
      legendTextY += 42;
    }

    _drawLeftAlignedText(
      batch,
      font,
      'Leaderboard',
      worldWidth - panelWidth + panelPadding,
      34,
      1.45,
      titleColor,
    );
    _drawLeftAlignedText(
      batch,
      font,
      'Match starts soon',
      worldWidth - panelWidth + panelPadding,
      64,
      1.0,
      dimTextColor,
    );

    PlayerListRenderer.render(
      batch: batch,
      font: font,
      layout: layout,
      players: appData.sortedPlayers,
      localPlayerId: appData.playerId,
      left: worldWidth - panelWidth + panelPadding,
      right: worldWidth - panelPadding,
      startY: leaderboardStartY,
      textColor: textColor,
      localPlayerColor: localPlayerColor,
      drawLeftAlignedText: _drawLeftAlignedText,
      drawRightAlignedText: _drawRightAlignedText,
      style: PlayerListRenderer.gameplayStyle,
    );

    if (appData.sortedPlayers.isEmpty) {
      _drawLeftAlignedText(
        batch,
        font,
        'Waiting for players...',
        worldWidth - panelWidth + panelPadding,
        leaderboardStartY,
        1.0,
        dimTextColor,
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
    layout.setText(font, text);
    final double x = (worldWidth - panelWidth - layout.width) * 0.5;
    font.draw(batch, layout, x, y);
    font.getData().setScale(1);
  }

  void _drawLeftAlignedText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double x,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    font.drawText(text, x, y);
    font.getData().setScale(1);
  }

  void _drawRightAlignedText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double right,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    layout.setText(font, text);
    font.draw(batch, layout, right - layout.width, y);
    font.getData().setScale(1);
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }

  Map<String, LevelSprite> _buildGemTemplates(LevelData data) {
    final Map<String, LevelSprite> templates = <String, LevelSprite>{};
    for (final LevelSprite sprite in data.sprites.iterable()) {
      final String type = normalize(sprite.type);
      if (type.contains('gem purple')) {
        templates['purple'] = sprite;
      } else if (type.contains('gem yellow')) {
        templates['yellow'] = sprite;
      } else if (type.contains('gem green')) {
        templates['green'] = sprite;
      } else if (type.contains('gem blue')) {
        templates['blue'] = sprite;
      }
    }
    return templates;
  }

  void _drawGemLegendSprite(
    SpriteBatch batch,
    String gemType,
    double x,
    double y,
  ) {
    final LevelSprite? template =
        gemTemplateByType[gemType] ?? gemTemplateByType['green'];
    if (template == null) {
      return;
    }

    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(template.texturePath, Texture)) {
      return;
    }

    final Texture texture = assets.get(template.texturePath, Texture);
    final ui.Rect src = _frameSourceRect(
      texture,
      math.max(1, template.width.round()),
      math.max(1, template.height.round()),
      math.max(0, template.frameIndex),
    );
    final ui.Rect dst = viewport.worldToScreenRect(
      x,
      y,
      gemLegendSpriteSize,
      gemLegendSpriteSize,
    );
    batch.drawRegion(texture, src, dst);
  }

  ui.Rect _frameSourceRect(
    Texture texture,
    int frameWidth,
    int frameHeight,
    int frameIndex,
  ) {
    final int safeWidth = math.max(1, frameWidth);
    final int safeHeight = math.max(1, frameHeight);
    final int cols = math.max(1, texture.width ~/ safeWidth);
    final int rows = math.max(1, texture.height ~/ safeHeight);
    final int total = cols * rows;
    final int safeFrame = clampInt(frameIndex, 0, total - 1);
    final int srcCol = safeFrame % cols;
    final int srcRow = safeFrame ~/ cols;
    return ui.Rect.fromLTWH(
      (srcCol * safeWidth).toDouble(),
      (srcRow * safeHeight).toDouble(),
      safeWidth.toDouble(),
      safeHeight.toDouble(),
    );
  }
}

class _GemLegendEntry {
  final String type;
  final String label;
  final int points;

  const _GemLegendEntry(this.type, this.label, this.points);
}
