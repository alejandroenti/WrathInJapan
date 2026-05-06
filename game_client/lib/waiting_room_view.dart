
import 'package:flutter/material.dart';

import 'app_data.dart';

class WaitingRoomView extends StatelessWidget {
  final AppData appData;

  const WaitingRoomView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appData,
      builder: (BuildContext context, Widget? _) {
        return _WaitingRoomBody(appData: appData);
      },
    );
  }
}

class _WaitingRoomBody extends StatelessWidget {
  final AppData appData;

  const _WaitingRoomBody({required this.appData});

  @override
  Widget build(BuildContext context) {
    final int countdown = appData.countdownSeconds;
    final bool countingDown = countdown > 0 &&
        appData.phase == MatchPhase.waiting;
    final List<MultiplayerPlayer> players = List<MultiplayerPlayer>.from(
      appData.players,
    )..sort(
      (MultiplayerPlayer a, MultiplayerPlayer b) =>
          a.joinOrder.compareTo(b.joinOrder),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Background
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(0.05)
            ..scale(1.15),
          child: Image.asset(
            'assets/media/waiting_background.png',
            fit: BoxFit.cover,
          ),
        ),
        // Dark overlay
        Container(color: Colors.black.withValues(alpha: 0.45)),
        // Content
        Column(
          children: <Widget>[
            const SizedBox(height: 32),
            // Title
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  'Waiting Room',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
                      ..color = Colors.yellow,
                  ),
                ),
                const Text(
                  'Waiting Room',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Countdown area
            SizedBox(
              height: 100,
              child: Center(
                child: countingDown
                    ? Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Text(
                            '$countdown',
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 5
                                ..color = Colors.orange,
                            ),
                          ),
                          Text(
                            '$countdown',
                            style: const TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            // Main panel: controls image + player list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Left: controls image
                    Expanded(
                      child: _Panel(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/media/controls.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right: player list
                    Expanded(
                      child: _Panel(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Text(
                                'Players',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: players.length,
                                  separatorBuilder:
                                      (BuildContext ctx, int idx) =>
                                          const Divider(
                                            color: Colors.white24,
                                            height: 1,
                                          ),
                                  itemBuilder:
                                      (BuildContext ctx, int idx) =>
                                          _PlayerRow(
                                            key: ValueKey<String>(players[idx].id),
                                            player: players[idx],
                                            isLocal:
                                                players[idx].id ==
                                                appData.playerId,
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final MultiplayerPlayer player;
  final bool isLocal;

  const _PlayerRow({super.key, required this.player, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.person,
            color: isLocal ? Colors.yellow : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              style: TextStyle(
                color: isLocal ? Colors.yellow : Colors.white,
                fontSize: 16,
                fontWeight:
                    isLocal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isLocal)
            const Text(
              '(tú)',
              style: TextStyle(color: Colors.yellow, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
