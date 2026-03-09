class Array<T> {
  final List<T> _values;

  Array([List<T>? values]) : _values = values ?? <T>[];

  int get size => _values.length;

  void add(T value) {
    _values.add(value);
  }

  void clear() {
    _values.clear();
  }

  T get(int index) => _values[index];

  void set(int index, T value) {
    _values[index] = value;
  }

  T first() => _values.first;

  T peek() => _values.last;

  bool contains(T value, [bool identity = false]) {
    if (identity) {
      return _values.contains(value);
    }
    return _values.contains(value);
  }

  int indexOf(T value, [bool identity = false]) {
    if (identity) {
      return _values.indexOf(value);
    }
    return _values.indexOf(value);
  }

  Iterable<T> iterable() => _values;

  List<T> toList() => List<T>.from(_values);
}

class IntArray {
  final List<int> _values = <int>[];

  int get size => _values.length;

  void add(int value) {
    _values.add(value);
  }

  int get(int index) => _values[index];

  void set(int index, int value) {
    _values[index] = value;
  }

  void clear() {
    _values.clear();
  }

  Iterable<int> iterable() => _values;
}

class FloatArray {
  final List<double> _values = <double>[];

  int get size => _values.length;

  void add(double value) {
    _values.add(value);
  }

  double get(int index) => _values[index];

  void set(int index, double value) {
    _values[index] = value;
  }

  void clear() {
    _values.clear();
  }

  void setSize(int size) {
    if (size < _values.length) {
      _values.removeRange(size, _values.length);
      return;
    }
    while (_values.length < size) {
      _values.add(0);
    }
  }
}

class IntSet {
  final Set<int> _values = <int>{};

  int get size => _values.length;

  void add(int value) {
    _values.add(value);
  }

  bool contains(int value) => _values.contains(value);

  void remove(int value) {
    _values.remove(value);
  }

  void clear() {
    _values.clear();
  }

  Iterable<int> iterable() => _values;
}

class ObjectSet<T> {
  final Set<T> _values = <T>{};

  int get size => _values.length;

  void add(T value) {
    _values.add(value);
  }

  bool contains(T value) => _values.contains(value);

  void remove(T value) {
    _values.remove(value);
  }

  void clear() {
    _values.clear();
  }

  Iterable<T> iterable() => _values;
}

class ObjectMap<K, V> {
  final Map<K, V> _values = <K, V>{};

  void put(K key, V value) {
    _values[key] = value;
  }

  V? get(K key) => _values[key];

  bool containsKey(K key) => _values.containsKey(key);

  void clear() {
    _values.clear();
  }

  Iterable<MapEntry<K, V>> entries() => _values.entries;
}

class IntFloatMap {
  final Map<int, double> _values = <int, double>{};

  int get size => _values.length;

  void put(int key, double value) {
    _values[key] = value;
  }

  double get(int key, double defaultValue) => _values[key] ?? defaultValue;

  bool containsKey(int key) => _values.containsKey(key);

  void remove(int key, double defaultValue) {
    if (defaultValue.isNaN) {
      _values.remove(key);
      return;
    }
    _values.remove(key);
  }

  void clear() {
    _values.clear();
  }

  Iterable<int> keys() => _values.keys;
}
