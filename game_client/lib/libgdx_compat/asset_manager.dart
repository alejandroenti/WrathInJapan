import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class Texture {
  final ui.Image image;

  Texture(this.image);

  int get width => image.width;

  int get height => image.height;

  void dispose() {
    image.dispose();
  }
}

class AssetManager {
  final Map<String, Texture> _texturesByPath = <String, Texture>{};
  final List<String> _queue = <String>[];
  final Set<String> _queuedSet = <String>{};

  Future<void>? _activeLoad;
  bool _batchOpen = false;
  int _batchRequested = 0;
  int _batchCompleted = 0;

  void load(String path, Type type) {
    if (type != Texture) {
      return;
    }
    if (_texturesByPath.containsKey(path) || _queuedSet.contains(path)) {
      return;
    }
    if (!_batchOpen && _queue.isEmpty && _activeLoad == null) {
      _batchOpen = true;
      _batchRequested = 0;
      _batchCompleted = 0;
    }
    _queue.add(path);
    _queuedSet.add(path);
    _batchRequested += 1;
  }

  bool update([int millis = 0]) {
    if (millis < 0) {
      millis = 0;
    }
    _pumpQueue();
    final bool done = _queue.isEmpty && _activeLoad == null;
    if (done) {
      _batchOpen = false;
    }
    return done;
  }

  double getProgress() {
    if (!_batchOpen || _batchRequested <= 0) {
      return 1;
    }
    return _batchCompleted / _batchRequested;
  }

  bool isLoaded(String path, Type type) {
    if (type != Texture) {
      return false;
    }
    return _texturesByPath.containsKey(path);
  }

  Texture get(String path, Type type) {
    if (type != Texture) {
      throw StateError('Unsupported asset type for $path: $type');
    }
    final Texture? texture = _texturesByPath[path];
    if (texture == null) {
      throw StateError('Texture not loaded: $path');
    }
    return texture;
  }

  void unload(String path) {
    final Texture? texture = _texturesByPath.remove(path);
    texture?.dispose();
    _queuedSet.remove(path);
  }

  void dispose() {
    for (final Texture texture in _texturesByPath.values) {
      texture.dispose();
    }
    _texturesByPath.clear();
    _queue.clear();
    _queuedSet.clear();
    _activeLoad = null;
    _batchOpen = false;
    _batchRequested = 0;
    _batchCompleted = 0;
  }

  void _pumpQueue() {
    if (_activeLoad != null || _queue.isEmpty) {
      return;
    }

    final String path = _queue.removeAt(0);
    _activeLoad = _loadTexture(path)
        .then((Texture texture) {
          _texturesByPath[path] = texture;
          _batchCompleted += 1;
        })
        .catchError((Object _) {
          // Count failed assets as completed so loading screens can finish.
          _batchCompleted += 1;
        })
        .whenComplete(() {
          _activeLoad = null;
          _pumpQueue();
        });
  }

  Future<Texture> _loadTexture(String path) async {
    final ByteData data = await rootBundle.load('assets/$path');
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return Texture(frameInfo.image);
  }
}
