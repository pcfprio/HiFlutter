import 'guard.dart';

/// Raw encrypted storage behind a [HiSecureStore].
///
/// Adapter packages implement this interface on top of the platform's
/// secure storage (Keychain on iOS, Keystore-backed storage on Android).
/// Error mapping is done by [HiSecureStore], so implementations stay thin.
abstract interface class HiSecureBackend {
  /// Returns the value stored under [key], or `null` when there is none.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Deletes [key]; does nothing when it is absent.
  Future<void> delete(String key);

  /// Deletes every key.
  Future<void> deleteAll();
}

/// Encrypted storage for small secret values such as tokens and passwords.
final class HiSecureStore {
  /// Creates a store on top of [backend], such as a platform adapter.
  HiSecureStore(this._backend);

  /// Creates a store that keeps values in memory only, for tests and
  /// previews. Nothing is encrypted or persisted.
  factory HiSecureStore.memory() => HiSecureStore(_MemoryBackend());

  final HiSecureBackend _backend;

  /// Returns the value stored under [key], or `null` when there is none.
  Future<String?> read(String key) =>
      guardStorage('read secure "$key"', () => _backend.read(key));

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value) =>
      guardStorage('write secure "$key"', () => _backend.write(key, value));

  /// Whether a value is stored under [key].
  Future<bool> containsKey(String key) async => await read(key) != null;

  /// Deletes [key]; does nothing when it is absent.
  Future<void> delete(String key) =>
      guardStorage('delete secure "$key"', () => _backend.delete(key));

  /// Deletes every value in this store.
  Future<void> deleteAll() =>
      guardStorage('delete all secure values', _backend.deleteAll);
}

final class _MemoryBackend implements HiSecureBackend {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}
