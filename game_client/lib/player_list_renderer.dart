import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';

class PlayerListStyle {
  final double maxTextScale;
  final double minTextScale;
  final double maxRowHeight;
  final double minRowHeight;
  final int maxCharsAtLowCount;
  final int maxCharsAtHighCount;

  const PlayerListStyle({
    required this.maxTextScale,
    required this.minTextScale,
    required this.maxRowHeight,
    required this.minRowHeight,
    required this.maxCharsAtLowCount,
    required this.maxCharsAtHighCount,
  });
}

class PlayerListRenderer {
  static const PlayerListStyle waitingRoomStyle = PlayerListStyle(
    maxTextScale: 1.0,
    minTextScale: 0.72,
    maxRowHeight: 29,
    minRowHeight: 18,
    maxCharsAtLowCount: 20,
    maxCharsAtHighCount: 15,
  );

  static const PlayerListStyle gameplayStyle = PlayerListStyle(
    maxTextScale: 0.96,
    minTextScale: 0.72,
    maxRowHeight: 27,
    minRowHeight: 19,
    maxCharsAtLowCount: 19,
    maxCharsAtHighCount: 15,
  );

  static void render({
    required SpriteBatch batch,
    required BitmapFont font,
    required GlyphLayout layout,
    required List<MultiplayerPlayer> players,
    required String? localPlayerId,
    required double left,
    required double right,
    required double startY,
    required ui.Color textColor,
    required ui.Color localPlayerColor,
    required void Function(
      SpriteBatch batch,
      BitmapFont font,
      String text,
      double x,
      double y,
      double scale,
      ui.Color color,
    )
    drawLeftAlignedText,
    required void Function(
      SpriteBatch batch,
      BitmapFont font,
      String text,
      double right,
      double y,
      double scale,
      ui.Color color,
    )
    drawRightAlignedText,
    required PlayerListStyle style,
  }) {
    final _PlayerListMetrics metrics = _metrics(players.length, style);
    double rowY = startY;
    int rank = 1;
    for (final MultiplayerPlayer player in players) {
      final bool isLocalPlayer = player.id == localPlayerId;
      final ui.Color rowColor = isLocalPlayer ? localPlayerColor : textColor;
      drawLeftAlignedText(
        batch,
        font,
        '$rank. ${_truncatePlayerName(player.name, metrics.maxChars)}',
        left,
        rowY,
        metrics.textScale,
        rowColor,
      );
      drawRightAlignedText(
        batch,
        font,
        '${player.score}',
        right,
        rowY,
        metrics.textScale,
        rowColor,
      );
      rowY += metrics.rowHeight;
      rank++;
    }
  }

  static _PlayerListMetrics _metrics(int playerCount, PlayerListStyle style) {
    final double t = clampDouble((playerCount - 10) / 15, 0, 1);
    return _PlayerListMetrics(
      textScale:
          ui.lerpDouble(style.maxTextScale, style.minTextScale, t) ??
          style.minTextScale,
      rowHeight:
          ui.lerpDouble(style.maxRowHeight, style.minRowHeight, t) ??
          style.minRowHeight,
      maxChars:
          (ui.lerpDouble(
                    style.maxCharsAtLowCount.toDouble(),
                    style.maxCharsAtHighCount.toDouble(),
                    t,
                  ) ??
                  style.maxCharsAtHighCount.toDouble())
              .round(),
    );
  }

  static String _truncatePlayerName(String text, int maxChars) {
    if (text.length <= maxChars) {
      return text;
    }
    return '${text.substring(0, math.max(0, maxChars - 3))}...';
  }
}

class _PlayerListMetrics {
  final double textScale;
  final double rowHeight;
  final int maxChars;

  const _PlayerListMetrics({
    required this.textScale,
    required this.rowHeight,
    required this.maxChars,
  });
}
