import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [HiKeyValueBackend] backed by shared_preferences
/// (`NSUserDefaults` on iOS, `DataStore` on Android).
///
/// Wrap it in a [HiKeyValueStore]:
///
/// ```dart
/// final store = HiKeyValueStore(HiPrefsKeyValueBackend());
/// ```
final class HiPrefsKeyValueBackend implements HiKeyValueBackend {
  /// Creates a backend using the platform's shared preferences.
  HiPrefsKeyValueBackend();

  final _prefs = SharedPreferencesAsync();

  @override
  Future<Object?> read(String key) async =>
      (await _prefs.getAll(allowList: {key}))[key];

  @override
  Future<void> write(String key, Object value) => switch (value) {
    String() => _prefs.setString(key, value),
    int() => _prefs.setInt(key, value),
    double() => _prefs.setDouble(key, value),
    bool() => _prefs.setBool(key, value),
    _ => throw ArgumentError.value(value, 'value', 'Unsupported type'),
  };

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  /// Deletes every shared preference of the app, including ones written
  /// outside HiFlutter.
  @override
  Future<void> clear() => _prefs.clear();
}
