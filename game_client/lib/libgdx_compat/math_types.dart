import 'dart:math' as math;
import 'dart:ui' as ui;

class Vector2 {
  double x;
  double y;

  Vector2(this.x, this.y);

  Vector2 copy() => Vector2(x, y);
}

class Vector3 {
  double x;
  double y;
  double z;

  Vector3(this.x, this.y, this.z);

  Vector3 set(double nextX, double nextY, double nextZ) {
    x = nextX;
    y = nextY;
    z = nextZ;
    return this;
  }
}

class Rectangle {
  double x;
  double y;
  double width;
  double height;

  Rectangle([this.x = 0, this.y = 0, this.width = 0, this.height = 0]);

  Rectangle set(
    double nextX,
    double nextY,
    double nextWidth,
    double nextHeight,
  ) {
    x = nextX;
    y = nextY;
    width = nextWidth;
    height = nextHeight;
    return this;
  }

  bool overlaps(Rectangle other) {
    return x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y;
  }

  bool contains(double px, double py) {
    return px >= x && px <= x + width && py >= y && py <= y + height;
  }

  ui.Rect toRect() => ui.Rect.fromLTWH(x, y, width, height);
}

double clampDouble(double value, double minValue, double maxValue) {
  return math.max(minValue, math.min(maxValue, value));
}

int clampInt(int value, int minValue, int maxValue) {
  return math.max(minValue, math.min(maxValue, value));
}

int floorToInt(double value) => value.floor();

ui.Color colorValueOf(String value) {
  if (value.isEmpty) {
    return const ui.Color(0xFF000000);
  }

  final String normalized = value.trim().toLowerCase();
  final String hex = normalized.startsWith('#')
      ? normalized.substring(1)
      : normalized;
  if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) {
    return ui.Color(int.parse('0xFF$hex'));
  }
  if (RegExp(r'^[0-9a-f]{8}$').hasMatch(hex)) {
    // Keep LibGDX-compatible 8-digit hex semantics: RRGGBBAA.
    final int raw = int.parse(hex, radix: 16);
    final int rr = (raw >> 24) & 0xFF;
    final int gg = (raw >> 16) & 0xFF;
    final int bb = (raw >> 8) & 0xFF;
    final int aa = raw & 0xFF;
    return ui.Color((aa << 24) | (rr << 16) | (gg << 8) | bb);
  }

  switch (normalized) {
    case 'white':
      return const ui.Color(0xFFFFFFFF);
    case 'red':
      return const ui.Color(0xFFFF0000);
    case 'green':
      return const ui.Color(0xFF00FF00);
    case 'blue':
      return const ui.Color(0xFF0000FF);
    case 'yellow':
      return const ui.Color(0xFFFFFF00);
    case 'orange':
      return const ui.Color(0xFFFFA500);
    case 'purple':
      return const ui.Color(0xFF800080);
    case 'pink':
      return const ui.Color(0xFFFFC0CB);
    case 'gray':
    case 'grey':
      return const ui.Color(0xFF808080);
    case 'amber':
      return const ui.Color(0xFFFFBF00);
    case 'teal':
      return const ui.Color(0xFF008080);
    default:
      return const ui.Color(0xFF000000);
  }
}

String normalize(String value) => value.trim().toLowerCase();

bool containsAny(String value, List<String> needles) {
  if (value.isEmpty || needles.isEmpty) {
    return false;
  }
  for (final String needle in needles) {
    if (needle.isNotEmpty && value.contains(needle)) {
      return true;
    }
  }
  return false;
}
