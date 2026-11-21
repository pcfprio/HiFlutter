import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_prefs/hiflutter_store_prefs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../../hiflutter_store/test/contract/key_value_contract.dart';

void main() {
  runKeyValueStoreContract('shared_preferences', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    return HiKeyValueStore(HiPrefsKeyValueBackend());
  });

  group('platform failures', () {
    late HiKeyValueStore store;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance = _FailingPrefs();
      store = HiKeyValueStore(HiPrefsKeyValueBackend());
    });

    final operations = <String, Future<Object?> Function(HiKeyValueStore)>{
      'getString': (s) => s.getString('k'),
      'setString': (s) => s.setString('k', 'v'),
      'setJson': (s) => s.setJson('k', [1]),
      'containsKey': (s) => s.containsKey('k'),
      'remove': (s) => s.remove('k'),
      'clear': (s) => s.clear(),
    };
    for (final MapEntry(key: name, value: run) in operations.entries) {
      test('$name surfaces a HiStorageError with the cause', () async {
        await expectLater(
          run(store),
          throwsA(
            isA<HiStorageError>().having(
              (e) => e.diagnostics,
              'diagnostics',
              contains('disk full'),
            ),
          ),
        );
      });
    }
  });
}

final class _FailingPrefs extends InMemorySharedPreferencesAsync {
  _FailingPrefs() : super.empty();

  static Never _fail() =>
      throw PlatformException(code: 'io', message: 'disk full');

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async => _fail();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => _fail();

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async => _fail();
}
