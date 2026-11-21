import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

/// A [HiSecureBackend] backed by flutter_secure_storage (Keychain on iOS,
/// Keystore-protected storage on Android), using the plugin's default
/// options.
///
/// Wrap it in a [HiSecureStore]:
///
/// ```dart
/// final secrets = HiSecureStore(HiSecureStorageBackend());
/// ```
final class HiSecureStorageBackend implements HiSecureBackend {
  /// Creates a backend using the platform's secure storage.
  HiSecureStorageBackend();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  /// Deletes every value the app stored with flutter_secure_storage,
  /// including ones written outside HiFlutter.
  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
