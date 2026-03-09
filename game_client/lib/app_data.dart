import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'network_config.dart';
import 'utils_websockets.dart';

enum MatchPhase { connecting, waiting, playing, finished }

class MultiplayerPlayer {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final int score;
  final int gemsCollected;
  final String direction;
  final String facing;
  final bool moving;
  final int joinOrder;

  const MultiplayerPlayer({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    required this.gemsCollected,
    required this.direction,
    required this.facing,
    required this.moving,
    required this.joinOrder,
  });

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 20).toDouble(),
      height: (json['height'] as num? ?? 20).toDouble(),
      score: (json['score'] as num? ?? 0).toInt(),
      gemsCollected: (json['gemsCollected'] as num? ?? 0).toInt(),
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      moving: json['moving'] as bool? ?? false,
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
    );
  }
}

class MultiplayerGem {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int value;

  const MultiplayerGem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.value,
  });

  factory MultiplayerGem.fromJson(Map<String, dynamic> json) {
    return MultiplayerGem(
      id: (json['id'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? 'green').trim().toLowerCase(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 15).toDouble(),
      height: (json['height'] as num? ?? 15).toDouble(),
      value: (json['value'] as num? ?? 1).toInt(),
    );
  }
}

class TransformSnapshot {
  final int index;
  final double x;
  final double y;

  const TransformSnapshot({
    required this.index,
    required this.x,
    required this.y,
  });

  factory TransformSnapshot.fromJson(Map<String, dynamic> json) {
    return TransformSnapshot(
      index: (json['index'] as num? ?? -1).toInt(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
    );
  }
}

class _PlayerStaticData {
  final String id;
  final String name;
  final double width;
  final double height;
  final int joinOrder;

  const _PlayerStaticData({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.joinOrder,
  });
}

class _PlayerDynamicData {
  final String id;
  final double x;
  final double y;
  final int score;
  final int gemsCollected;
  final String direction;
  final String facing;
  final bool moving;

  const _PlayerDynamicData({
    required this.id,
    required this.x,
    required this.y,
    required this.score,
    required this.gemsCollected,
    required this.direction,
    required this.facing,
    required this.moving,
  });
}

class AppData extends ChangeNotifier {
  final WebSocketsHandler _wsHandler = WebSocketsHandler();
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectDelay = const Duration(seconds: 3);

  NetworkConfig networkConfig;
  String playerName;

  bool isConnected = false;
  bool isConnecting = false;
  String? playerId;
  MatchPhase phase = MatchPhase.connecting;
  String levelName = 'All together now';
  int countdownSeconds = 60;
  int remainingGems = 0;
  String? winnerId;
  List<MultiplayerPlayer> players = const <MultiplayerPlayer>[];
  List<MultiplayerGem> gems = const <MultiplayerGem>[];
  List<TransformSnapshot> layerTransforms = const <TransformSnapshot>[];
  List<TransformSnapshot> zoneTransforms = const <TransformSnapshot>[];

  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;
  bool _disposed = false;
  String _lastDirection = 'none';
  Map<String, _PlayerStaticData> _playerStaticById =
      const <String, _PlayerStaticData>{};
  Map<String, _PlayerDynamicData> _playerDynamicById =
      const <String, _PlayerDynamicData>{};
  List<MultiplayerGem> _allGems = const <MultiplayerGem>[];
  List<int> _gemVisibility = const <int>[];

  AppData({NetworkConfig initialConfig = NetworkConfig.defaults})
    : networkConfig = initialConfig,
      playerName = initialConfig.playerName {
    _connectToWebSocket();
  }

  MultiplayerPlayer? get localPlayer {
    final String? id = playerId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final MultiplayerPlayer player in players) {
      if (player.id == id) {
        return player;
      }
    }
    return null;
  }

  List<MultiplayerPlayer> get sortedPlayers {
    final List<MultiplayerPlayer> sorted = List<MultiplayerPlayer>.from(
      players,
    );
    sorted.sort((MultiplayerPlayer a, MultiplayerPlayer b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final int byGems = b.gemsCollected.compareTo(a.gemsCollected);
      if (byGems != 0) {
        return byGems;
      }
      final int byJoinOrder = a.joinOrder.compareTo(b.joinOrder);
      if (byJoinOrder != 0) {
        return byJoinOrder;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  bool get canMove => isConnected && phase == MatchPhase.playing;

  bool get canRequestMatchRestart =>
      isConnected && phase == MatchPhase.finished;

  void updateNetworkConfig(NetworkConfig nextConfig) {
    networkConfig = nextConfig;
    playerName = nextConfig.playerName;
    _reconnectAttempts = 0;
    playerId = null;
    _lastDirection = 'none';
    disconnect();
    _connectToWebSocket();
  }

  void updateMovementDirection(String direction) {
    final String normalized = _normalizeDirection(direction);
    if (_lastDirection == normalized) {
      return;
    }
    _lastDirection = normalized;
    _sendMessage(<String, dynamic>{'type': 'direction', 'value': normalized});
  }

  void requestMatchRestart() {
    if (!canRequestMatchRestart) {
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'restartMatch'});
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _lastDirection = 'none';
    _wsHandler.disconnectFromServer();
    isConnected = false;
    isConnecting = false;
    players = const <MultiplayerPlayer>[];
    gems = const <MultiplayerGem>[];
    _allGems = const <MultiplayerGem>[];
    _gemVisibility = const <int>[];
    _playerStaticById = const <String, _PlayerStaticData>{};
    _playerDynamicById = const <String, _PlayerDynamicData>{};
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }

  void _connectToWebSocket() {
    if (_disposed) {
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print("S'ha assolit el màxim d'intents de reconnexió.");
      }
      return;
    }

    _intentionalDisconnect = false;
    isConnecting = true;
    isConnected = false;
    phase = MatchPhase.connecting;
    notifyListeners();

    _wsHandler.connectToServer(
      networkConfig.serverHost,
      networkConfig.serverPort,
      _onWebSocketMessage,
      useSecureSocket: networkConfig.useSecureWebSocket,
      onError: _onWebSocketError,
      onDone: _onWebSocketClosed,
    );
  }

  void _onWebSocketMessage(String message) {
    try {
      final Object? decoded = jsonDecode(message);
      if (decoded is! Map) {
        return;
      }
      final Map<String, dynamic> data = _mapFromDynamic(decoded);

      final String type = (data['type'] as String? ?? '').trim();
      if (type == 'welcome') {
        playerId = _wsHandler.socketId;
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        _registerPlayer();
        notifyListeners();
        return;
      }

      if (type == 'initial') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawInitialState = data['initialState'];
        _applyInitialState(
          rawInitialState is Map ? _mapFromDynamic(rawInitialState) : {},
        );
        notifyListeners();
        return;
      }

      if (type == 'gameplay') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawGameState = data['gameState'];
        _applyGameplayState(
          rawGameState is Map ? _mapFromDynamic(rawGameState) : {},
        );
        notifyListeners();
        return;
      }

      if (type == 'update') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawGameState = data['gameState'];
        final Map<String, dynamic> gameState =
            rawGameState is Map ? _mapFromDynamic(rawGameState) : {};
        _applyInitialState(gameState);
        _applyGameplayState(gameState);
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error processant missatge WebSocket: $error');
      }
    }
  }

  void _applyInitialState(Map<String, dynamic> state) {
    levelName = (state['level'] as String? ?? levelName).trim();

    final List<dynamic> rawPlayers = state['players'] as List<dynamic>? ?? [];
    _playerStaticById = <String, _PlayerStaticData>{
      for (final Map rawPlayer in rawPlayers.whereType<Map>())
        (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
            _staticPlayerFromJson(_mapFromDynamic(rawPlayer)),
    }..remove('');

    if (state.containsKey('gems')) {
      final List<dynamic> rawGems = state['gems'] as List<dynamic>? ?? [];
      _allGems = rawGems
          .whereType<Map>()
          .map((Map gem) => MultiplayerGem.fromJson(_mapFromDynamic(gem)))
          .toList(growable: false);
      _gemVisibility = List<int>.filled(_allGems.length, 1, growable: false);
      _rebuildVisibleGems();
    }

    _rebuildPlayers();
  }

  void _applyGameplayState(Map<String, dynamic> state) {
    levelName = (state['level'] as String? ?? levelName).trim();
    phase = _parsePhase(state['phase'] as String?);
    countdownSeconds = (state['countdownSeconds'] as num? ?? 0).toInt();
    remainingGems =
        (state['remainingGems'] as num? ?? state['gems']?.length ?? 0).toInt();
    winnerId = state['winnerId'] as String?;

    final List<dynamic> rawPlayers = state['players'] as List<dynamic>? ?? [];
    _playerDynamicById = <String, _PlayerDynamicData>{
      for (final Map rawPlayer in rawPlayers.whereType<Map>())
        (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
            _dynamicPlayerFromJson(_mapFromDynamic(rawPlayer)),
    }..remove('');

    if (state.containsKey('gems')) {
      final List<dynamic> rawGems = state['gems'] as List<dynamic>? ?? [];
      _allGems = rawGems
          .whereType<Map>()
          .map((Map gem) => MultiplayerGem.fromJson(_mapFromDynamic(gem)))
          .toList(growable: false);
      _gemVisibility = List<int>.filled(_allGems.length, 1, growable: false);
    }
    if (state.containsKey('gemVisibility')) {
      _gemVisibility = _normalizeGemVisibility(
        state['gemVisibility'] as List<dynamic>?,
        _allGems.length,
      );
    }

    _rebuildPlayers();
    _rebuildVisibleGems();

    final List<dynamic> rawLayerTransforms =
        state['layerTransforms'] as List<dynamic>? ?? [];
    layerTransforms = rawLayerTransforms
        .whereType<Map>()
        .map(
          (Map transform) =>
              TransformSnapshot.fromJson(_mapFromDynamic(transform)),
        )
        .toList(growable: false);

    final List<dynamic> rawZoneTransforms =
        state['zoneTransforms'] as List<dynamic>? ?? [];
    zoneTransforms = rawZoneTransforms
        .whereType<Map>()
        .map(
          (Map transform) =>
              TransformSnapshot.fromJson(_mapFromDynamic(transform)),
        )
        .toList(growable: false);
  }

  _PlayerStaticData _staticPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerStaticData(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      width: (json['width'] as num? ?? 20).toDouble(),
      height: (json['height'] as num? ?? 20).toDouble(),
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
    );
  }

  _PlayerDynamicData _dynamicPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerDynamicData(
      id: (json['id'] as String? ?? '').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      score: (json['score'] as num? ?? 0).toInt(),
      gemsCollected: (json['gemsCollected'] as num? ?? 0).toInt(),
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      moving: json['moving'] as bool? ?? false,
    );
  }

  void _rebuildPlayers() {
    final Iterable<String> ids = _playerDynamicById.isNotEmpty
        ? _playerDynamicById.keys
        : _playerStaticById.keys;
    players = ids.map((String id) {
      final _PlayerStaticData? staticData = _playerStaticById[id];
      final _PlayerDynamicData? dynamicData = _playerDynamicById[id];
      return MultiplayerPlayer(
        id: id,
        name: staticData?.name ?? 'Player',
        x: dynamicData?.x ?? 0,
        y: dynamicData?.y ?? 0,
        width: staticData?.width ?? 20,
        height: staticData?.height ?? 20,
        score: dynamicData?.score ?? 0,
        gemsCollected: dynamicData?.gemsCollected ?? 0,
        direction: dynamicData?.direction ?? 'none',
        facing: dynamicData?.facing ?? 'down',
        moving: dynamicData?.moving ?? false,
        joinOrder: staticData?.joinOrder ?? 0,
      );
    }).toList(growable: false);
  }

  void _rebuildVisibleGems() {
    if (_allGems.isEmpty) {
      gems = const <MultiplayerGem>[];
      return;
    }
    final List<MultiplayerGem> visibleGems = <MultiplayerGem>[];
    for (int i = 0; i < _allGems.length; i++) {
      if (i < _gemVisibility.length && _gemVisibility[i] == 0) {
        continue;
      }
      visibleGems.add(_allGems[i]);
    }
    gems = visibleGems;
  }

  List<int> _normalizeGemVisibility(List<dynamic>? raw, int expectedLength) {
    if (expectedLength <= 0) {
      return const <int>[];
    }
    final List<int> normalized = List<int>.filled(
      expectedLength,
      1,
      growable: false,
    );
    if (raw == null) {
      return normalized;
    }
    final int limit = raw.length < expectedLength ? raw.length : expectedLength;
    for (int i = 0; i < limit; i++) {
      normalized[i] = (raw[i] as num? ?? 1).toInt() == 0 ? 0 : 1;
    }
    return normalized;
  }

  void _registerPlayer() {
    _sendMessage(<String, dynamic>{
      'type': 'register',
      'playerName': playerName,
    });
  }

  void _onWebSocketError(dynamic error) {
    if (kDebugMode) {
      print('Error de WebSocket: $error');
    }
    isConnected = false;
    isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onWebSocketClosed() {
    if (kDebugMode) {
      print('WebSocket tancat. Intentant reconnectar...');
    }
    isConnected = false;
    isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _disposed) {
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print(
          "No es pot reconnectar al servidor després de $_maxReconnectAttempts intents.",
        );
      }
      return;
    }

    _reconnectAttempts++;
    if (kDebugMode) {
      print(
        "Intent de reconnexió #$_reconnectAttempts en ${_reconnectDelay.inSeconds} segons...",
      );
    }
    Future<void>.delayed(_reconnectDelay, () {
      if (_intentionalDisconnect || _disposed) {
        return;
      }
      _connectToWebSocket();
    });
  }

  void _sendMessage(Map<String, dynamic> payload) {
    if (_intentionalDisconnect ||
        _wsHandler.connectionStatus != ConnectionStatus.connected) {
      return;
    }
    _wsHandler.sendMessage(jsonEncode(payload));
  }

  MatchPhase _parsePhase(String? rawPhase) {
    switch ((rawPhase ?? '').trim().toLowerCase()) {
      case 'waiting':
        return MatchPhase.waiting;
      case 'playing':
        return MatchPhase.playing;
      case 'finished':
        return MatchPhase.finished;
      case 'connecting':
      default:
        return MatchPhase.connecting;
    }
  }

  String _normalizeDirection(String rawDirection) {
    switch (rawDirection.trim()) {
      case 'up':
      case 'upLeft':
      case 'left':
      case 'downLeft':
      case 'down':
      case 'downRight':
      case 'right':
      case 'upRight':
      case 'none':
        return rawDirection.trim();
      default:
        return 'none';
    }
  }

  Map<String, dynamic> _mapFromDynamic(Map<dynamic, dynamic> raw) {
    return raw.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
}
