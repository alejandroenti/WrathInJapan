import 'dart:ui' as ui;
import 'dart:math' as math;

import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'loading_screen.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';

class MenuScreen extends ScreenAdapter {
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double blinkIntervalSeconds = 0.42;

  static final ui.Color background = colorValueOf('000000');
  static final ui.Color primary = colorValueOf('#35FF74');
  static final ui.Color dim = colorValueOf('#146F34');
  static final ui.Color scanline = colorValueOf('#17A84022');
  static final ui.Color selectedFill = colorValueOf('#0E1E12');
  static final ui.Color unselectedFill = colorValueOf('#060B08');
  static final ui.Color unselectedText = colorValueOf('#23AA54');
  static final ui.Color footer = colorValueOf('#21964A');

  final GameApp game;
  final Viewport viewport = FitViewport(
    worldWidth,
    worldHeight,
    OrthographicCamera(),
  );
  final Vector3 pointer = Vector3(0, 0, 0);
  final GlyphLayout layout = GlyphLayout();
  final Array<Rectangle> optionRects = Array<Rectangle>();
  late final Array<String> options;

  int selectedIndex = 0;
  bool cursorVisible = true;
  double blinkAccumulator = 0;

  MenuScreen(this.game) {
    options = game.getMenuOptions();
    _rebuildOptionRects();
  }

  @override
  void render(double delta) {
    _updateBlink(delta);
    _handleKeyboardInput();
    _handlePointerInput();

    ScreenUtils.clear(background);

    viewport.apply();

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    _renderBackground(shapes);
    _renderOptions(shapes);

    final SpriteBatch batch = game.getBatch();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();
    _renderTexts(batch, game.getFont());
    batch.end();
  }

  void _handleKeyboardInput() {
    if (Gdx.input.isKeyJustPressed(Input.keys.up) ||
        Gdx.input.isKeyJustPressed(Input.keys.w)) {
      _moveSelection(-1);
    }
    if (Gdx.input.isKeyJustPressed(Input.keys.down) ||
        Gdx.input.isKeyJustPressed(Input.keys.s)) {
      _moveSelection(1);
    }
    if (Gdx.input.isKeyJustPressed(Input.keys.enter) ||
        Gdx.input.isKeyJustPressed(Input.keys.space)) {
      _startSelectedLevel();
    }
  }

  void _handlePointerInput() {
    if (!Gdx.input.justTouched()) {
      return;
    }
    pointer.set(Gdx.input.getX().toDouble(), Gdx.input.getY().toDouble(), 0);
    pointer.y = worldHeight - pointer.y;
    for (int i = 0; i < optionRects.size; i++) {
      if (optionRects.get(i).contains(pointer.x, pointer.y)) {
        selectedIndex = i;
        _startSelectedLevel();
        return;
      }
    }
  }

  void _updateBlink(double delta) {
    blinkAccumulator += delta;
    if (blinkAccumulator >= blinkIntervalSeconds) {
      blinkAccumulator -= blinkIntervalSeconds;
      cursorVisible = !cursorVisible;
    }
  }

  void _renderBackground(ShapeRenderer shapes) {
    shapes.begin(ShapeType.line);
    shapes.setColor(scanline);
    double y = 0;
    while (y <= worldHeight) {
      final double drawY = _toScreenY(y);
      shapes.line(0, drawY, worldWidth, drawY);
      y += 4;
    }
    shapes.end();
  }

  void _renderOptions(ShapeRenderer shapes) {
    shapes.begin(ShapeType.filled);
    for (int i = 0; i < optionRects.size; i++) {
      shapes.setColor(i == selectedIndex ? selectedFill : unselectedFill);
      final Rectangle rect = optionRects.get(i);
      shapes.rect(
        rect.x,
        _toScreenRectY(rect.y, rect.height),
        rect.width,
        rect.height,
      );
    }
    shapes.end();

    shapes.begin(ShapeType.line);
    for (int i = 0; i < optionRects.size; i++) {
      shapes.setColor(i == selectedIndex ? primary : dim);
      final Rectangle rect = optionRects.get(i);
      shapes.rect(
        rect.x,
        _toScreenRectY(rect.y, rect.height),
        rect.width,
        rect.height,
      );
    }
    shapes.end();
  }

  void _renderTexts(SpriteBatch batch, BitmapFont font) {
    _drawCenteredText(
      batch,
      font,
      'Game Example',
      worldHeight * 0.82,
      3.2,
      primary,
    );
    _drawCenteredText(batch, font, 'SELECT LEVEL', worldHeight * 0.70, 2, dim);

    for (int i = 0; i < optionRects.size; i++) {
      final Rectangle rect = optionRects.get(i);
      final bool selected = i == selectedIndex;
      final String prefix = selected && cursorVisible ? '> ' : '  ';
      final ui.Color textColor = selected ? primary : unselectedText;
      _drawCenteredTextInRect(
        batch,
        font,
        '$prefix${options.get(i)}',
        rect,
        1.9,
        textColor,
      );
    }

    _drawCenteredText(
      batch,
      font,
      'ARROWS/W,S: MOVE   ENTER/SPACE: PLAY   MOUSE: CLICK',
      36,
      1.1,
      footer,
    );
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
    font.draw(batch, layout, x, _toScreenY(y));
    font.getData().setScale(1);
  }

  void _drawCenteredTextInRect(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    Rectangle rect,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    layout.setText(font, text);
    final double x = rect.x + (rect.width - layout.width) * 0.5;
    final double y = _toScreenY(
      rect.y + rect.height * 0.5 - layout.height * 0.5,
    );
    font.draw(batch, layout, x, y);
    font.getData().setScale(1);
  }

  void _moveSelection(int delta) {
    if (options.size == 0) {
      return;
    }

    selectedIndex += delta;
    if (selectedIndex < 0) {
      selectedIndex = options.size - 1;
    } else if (selectedIndex >= options.size) {
      selectedIndex = 0;
    }
    cursorVisible = true;
    blinkAccumulator = 0;
  }

  void _startSelectedLevel() {
    if (options.size == 0) {
      return;
    }
    game.setScreen(LoadingScreen(game, selectedIndex));
  }

  void _rebuildOptionRects() {
    optionRects.clear();

    final double width = clampDouble(worldWidth * 0.46, 220, 420);
    const double buttonHeight = 60;
    const double spacing = 18;
    final double startY = worldHeight * 0.55;
    final double centerX = worldWidth * 0.5;

    for (int i = 0; i < math.max(1, options.size); i++) {
      final double centerY = startY - i * (buttonHeight + spacing);
      optionRects.add(
        Rectangle(
          centerX - width * 0.5,
          centerY - buttonHeight * 0.5,
          width,
          buttonHeight,
        ),
      );
    }
  }

  double _toScreenY(double yUp) {
    return worldHeight - yUp;
  }

  double _toScreenRectY(double rectYUp, double height) {
    return worldHeight - rectYUp - height;
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
    _rebuildOptionRects();
  }
}
