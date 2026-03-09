import 'dart:math' as math;
import 'dart:ui' as ui;

import 'asset_manager.dart';
import 'gdx.dart';
import 'math_types.dart';

abstract class ScreenAdapter {
  void show() {}

  void render(double delta) {}

  void resize(int width, int height) {}

  void dispose() {}
}

class Game {
  ScreenAdapter? _screen;

  ScreenAdapter? getScreen() => _screen;

  void setScreen(ScreenAdapter screen) {
    if (identical(_screen, screen)) {
      return;
    }
    _screen?.dispose();
    _screen = screen;
    _screen?.show();
    _screen?.resize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight());
  }

  void render(double delta) {
    _screen?.render(delta);
  }

  void resize(int width, int height) {
    _screen?.resize(width, height);
  }

  void dispose() {
    _screen?.dispose();
    _screen = null;
  }
}

class SpriteBatch {
  bool _inBatch = false;
  ui.Color _color = const ui.Color(0xFFFFFFFF);

  void begin() {
    _inBatch = true;
  }

  void end() {
    _inBatch = false;
  }

  void setProjectionMatrix(Object? matrix) {
    if (matrix == null) {
      return;
    }
  }

  ui.Color getColor() => _color;

  void setColor(dynamic colorOrR, [double? g, double? b, double? a]) {
    if (colorOrR is ui.Color && g == null && b == null && a == null) {
      _color = colorOrR;
      return;
    }
    if (colorOrR is num && g != null && b != null && a != null) {
      _color = ui.Color.fromARGB(
        _toColorChannel(a),
        _toColorChannel(colorOrR.toDouble()),
        _toColorChannel(g),
        _toColorChannel(b),
      );
      return;
    }
    throw ArgumentError(
      'setColor expects a ui.Color or r, g, b, a components.',
    );
  }

  void drawRegion(
    Texture texture,
    ui.Rect src,
    ui.Rect dst, {
    bool flipX = false,
    bool flipY = false,
    double pivotX = 0.5,
    double pivotY = 0.5,
  }) {
    if (!_inBatch) {
      return;
    }
    final ui.Canvas canvas = Gdx.graphics.getCanvas();
    final ui.Paint paint = ui.Paint()
      ..colorFilter = _color == const ui.Color(0xFFFFFFFF)
          ? null
          : ui.ColorFilter.mode(_color, ui.BlendMode.modulate)
      ..isAntiAlias = false
      ..filterQuality = ui.FilterQuality.none;
    if (!flipX && !flipY) {
      canvas.drawImageRect(texture.image, src, dst, paint);
      return;
    }

    canvas.save();
    final double cx = dst.left + dst.width * pivotX;
    final double cy = dst.top + dst.height * pivotY;
    canvas.translate(cx, cy);
    canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    canvas.translate(-cx, -cy);
    canvas.drawImageRect(texture.image, src, dst, paint);
    canvas.restore();
  }

  int _toColorChannel(double value) {
    return (clampDouble(value, 0, 1) * 255).round();
  }
}

enum ShapeType { filled, line }

class ShapeRenderer {
  ShapeType _type = ShapeType.filled;
  ui.Color _color = const ui.Color(0xFFFFFFFF);
  bool _begun = false;

  void setProjectionMatrix(Object? matrix) {
    if (matrix == null) {
      return;
    }
  }

  void begin(ShapeType type) {
    _type = type;
    _begun = true;
  }

  void end() {
    _begun = false;
  }

  void setColor(ui.Color color) {
    _color = color;
  }

  void rect(double x, double y, double width, double height) {
    if (!_begun) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = _color
      ..style = _type == ShapeType.filled
          ? ui.PaintingStyle.fill
          : ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    Gdx.graphics.getCanvas().drawRect(
      ui.Rect.fromLTWH(x, y, width, height),
      paint,
    );
  }

  void line(double x1, double y1, double x2, double y2) {
    if (!_begun) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = _color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    Gdx.graphics.getCanvas().drawLine(
      ui.Offset(x1, y1),
      ui.Offset(x2, y2),
      paint,
    );
  }

  void circle(double x, double y, double radius, [int segments = 12]) {
    if (segments <= 0) {
      segments = 12;
    }
    if (!_begun) {
      return;
    }
    final ui.Paint paint = ui.Paint()
      ..color = _color
      ..style = _type == ShapeType.filled
          ? ui.PaintingStyle.fill
          : ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    Gdx.graphics.getCanvas().drawCircle(ui.Offset(x, y), radius, paint);
  }

  void dispose() {}
}

class BitmapFontData {
  bool markupEnabled = false;
  double scale = 1;

  void setScale(double value) {
    scale = value;
  }
}

class BitmapFont {
  final BitmapFontData _data = BitmapFontData();
  ui.Color _color = const ui.Color(0xFFFFFFFF);

  BitmapFontData getData() => _data;

  void setColor(ui.Color color) {
    _color = color;
  }

  void draw(SpriteBatch batch, GlyphLayout layout, double x, double y) {
    if (!batch._inBatch) {
      return;
    }
    _drawText(layout.text, x, y);
  }

  void drawText(String text, double x, double y) {
    _drawText(text, x, y);
  }

  void _drawText(String text, double x, double y) {
    final ui.ParagraphBuilder pb =
        ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 16 * _data.scale))
          ..pushStyle(ui.TextStyle(color: _color, fontSize: 16 * _data.scale))
          ..addText(text);
    final ui.Paragraph paragraph = pb.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    Gdx.graphics.getCanvas().drawParagraph(
      paragraph,
      ui.Offset(x, y - paragraph.height),
    );
  }

  void dispose() {}
}

class GlyphLayout {
  String text = '';
  double width = 0;
  double height = 0;

  void setText(BitmapFont font, String value) {
    text = value;
    final ui.ParagraphBuilder pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 16 * font.getData().scale),
          )
          ..pushStyle(
            ui.TextStyle(
              color: const ui.Color(0xFFFFFFFF),
              fontSize: 16 * font.getData().scale,
            ),
          )
          ..addText(value);
    final ui.Paragraph paragraph = pb.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    width = paragraph.maxIntrinsicWidth;
    height = paragraph.height;
  }
}

class ScreenUtils {
  static void clear(ui.Color color) {
    final ui.Paint paint = ui.Paint()..color = color;
    Gdx.graphics.getCanvas().drawRect(
      ui.Rect.fromLTWH(
        0,
        0,
        Gdx.graphics.getWidth().toDouble(),
        Gdx.graphics.getHeight().toDouble(),
      ),
      paint,
    );
  }
}

class MathUtils {
  static double clamp(double value, double minValue, double maxValue) {
    return clampDouble(value, minValue, maxValue);
  }

  static int floor(double value) {
    return value.floor();
  }

  static double lerp(double from, double to, double alpha) {
    return from + (to - from) * alpha;
  }
}

class GL20 {
  static const int glColorBufferBit = 0x4000;
}

class TextureRegion {
  final Texture texture;
  final ui.Rect srcRect;

  TextureRegion(this.texture, this.srcRect);
}

List<List<TextureRegion>> splitTexture(
  Texture texture,
  int tileWidth,
  int tileHeight,
) {
  if (tileWidth <= 0 || tileHeight <= 0) {
    return <List<TextureRegion>>[];
  }

  final int rows = math.max(0, texture.height ~/ tileHeight);
  final int cols = math.max(0, texture.width ~/ tileWidth);
  final List<List<TextureRegion>> out = <List<TextureRegion>>[];
  for (int row = 0; row < rows; row++) {
    final List<TextureRegion> list = <TextureRegion>[];
    for (int col = 0; col < cols; col++) {
      list.add(
        TextureRegion(
          texture,
          ui.Rect.fromLTWH(
            (col * tileWidth).toDouble(),
            (row * tileHeight).toDouble(),
            tileWidth.toDouble(),
            tileHeight.toDouble(),
          ),
        ),
      );
    }
    out.add(list);
  }
  return out;
}
