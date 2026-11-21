import 'dart:convert';

import 'package:hiflutter_base/hiflutter_base.dart';

import 'guard.dart';

/// Raw storage behind a [HiKeyValueStore].
///
/// Adapter packages implement this interface on top of a platform library.
/// Values passed to [write] and returned from [read] are always a [String],
/// [int], [double] or [bool]; validation, JSON encoding and error mapping are
/// done by [HiKeyValueStore], so implementations stay thin.
abstract interface class HiKeyValueBackend {
  /// Returns the value stored under [key], or `null` when there is none.
  Future<Object?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, Object value);

  /// Deletes [key]; does nothing when it is absent.
  Future<void> remove(String key);

  /// Deletes every key.
  Future<void> clear();
}

/// Persistent key-value storage for strings, numbers, booleans and JSON.
///
/// Plain key-value storage is not encrypted, so writes to keys that look
/// like credentials (containing `password`, `passwd`, `passcode`, `token`,
/// `secret`, `credential`, `apikey` or `privatekey`, ignoring case and
/// separators) are refused with a [HiStorageError]. Keep such values in a
/// `HiSecureStore` instead.
final class HiKeyValueStore {
  /// Creates a store on top of [backend], such as a platform adapter.
  HiKeyValueStore(this._backend);

  /// Creates a store that keeps values in memory only, for tests and
  /// previews.
  factory HiKeyValueStore.memory() => HiKeyValueStore(_MemoryBackend());

  final HiKeyValueBackend _backend;

  static const _credentialWords = [
    'password',
    'passwd',
    'passcode',
    'token',
    'secret',
    'credential',
    'apikey',
    'privatekey',
  ];

  static final _separators = RegExp('[^a-z0-9]');

  Future<void> _write(String key, Object value) async {
    final normalized = key.toLowerCase().replaceAll(_separators, '');
    if (_credentialWords.any(normalized.contains)) {
      throw HiStorageError(
        message:
            'Refusing to store "$key" in plain key-value storage: it looks '
            'like a credential. Use HiSecureStore instead.',
      );
    }
    await guardStorage('write "$key"', () => _backend.write(key, value));
  }

  Future<T?> _read<T extends Object>(String key) async {
    final value = await guardStorage('read "$key"', () => _backend.read(key));
    if (value == null || value is T) return value as T?;
    throw HiDecodeError(
      message: 'Expected a $T under "$key", found ${value.runtimeType}',
    );
  }

  /// Returns the string stored under [key], or `null` when there is none.
  Future<String?> getString(String key) => _read<String>(key);

  /// Stores [value] under [key].
  Future<void> setString(String key, String value) => _write(key, value);

  /// Returns the integer stored under [key], or `null` when there is none.
  Future<int?> getInt(String key) => _read<int>(key);

  /// Stores [value] under [key].
  Future<void> setInt(String key, int value) => _write(key, value);

  /// Returns the number stored under [key] as a double, or `null` when there
  /// is none. A stored integer is widened to a double.
  Future<double?> getDouble(String key) async =>
      (await _read<num>(key))?.toDouble();

  /// Stores [value] under [key].
  Future<void> setDouble(String key, double value) => _write(key, value);

  /// Returns the boolean stored under [key], or `null` when there is none.
  Future<bool?> getBool(String key) => _read<bool>(key);

  /// Stores [value] under [key].
  Future<void> setBool(String key, bool value) => _write(key, value);

  /// Returns the decoded JSON value stored under [key] with [setJson], or
  /// `null` when there is none.
  ///
  /// Throws a [HiDecodeError] when the stored text is not valid JSON.
  Future<Object?> getJson(String key) async {
    final text = await getString(key);
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } on FormatException catch (e, s) {
      throw HiDecodeError(
        message: 'The value under "$key" is not valid JSON',
        cause: e,
        stackTrace: s,
      );
    }
  }

  /// Stores [value], which must be JSON-encodable, under [key].
  ///
  /// The value is stored as its JSON text, so [getString] on the same key
  /// returns that text. Throws a [HiStorageError] when [value] cannot be
  /// encoded.
  Future<void> setJson(String key, Object? value) async {
    final String text;
    try {
      text = jsonEncode(value);
    } on JsonUnsupportedObjectError catch (e, s) {
      throw HiStorageError(
        message: 'The value for "$key" cannot be encoded as JSON',
        cause: e,
        stackTrace: s,
      );
    }
    await setString(key, text);
  }

  /// Whether a value of any type is stored under [key].
  Future<bool> containsKey(String key) async =>
      await guardStorage('read "$key"', () => _backend.read(key)) != null;

  /// Deletes [key]; does nothing when it is absent.
  Future<void> remove(String key) =>
      guardStorage('remove "$key"', () => _backend.remove(key));

  /// Deletes every key in this store.
  Future<void> clear() => guardStorage('clear', _backend.clear);
}

final class _MemoryBackend implements HiKeyValueBackend {
  final _values = <String, Object>{};

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Object value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
