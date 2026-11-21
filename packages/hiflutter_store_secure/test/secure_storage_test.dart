import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_secure/hiflutter_store_secure.dart';

import '../../hiflutter_store/test/contract/secure_value_contract.dart';

void main() {
  runSecureStoreContract('flutter_secure_storage', () async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    return HiSecureStore(HiSecureStorageBackend());
  });

  group('platform failures', () {
    late HiSecureStore store;

    setUp(() {
      FlutterSecureStoragePlatform.instance = _FailingSecureStorage();
      store = HiSecureStore(HiSecureStorageBackend());
    });

    final operations = <String, Future<Object?> Function(HiSecureStore)>{
      'read': (s) => s.read('k'),
      'write': (s) => s.write('k', 'v'),
      'containsKey': (s) => s.containsKey('k'),
      'delete': (s) => s.delete('k'),
      'deleteAll': (s) => s.deleteAll(),
    };
    for (final MapEntry(key: name, value: run) in operations.entries) {
      test('$name surfaces a HiStorageError with the cause', () async {
        await expectLater(
          run(store),
          throwsA(
            isA<HiStorageError>().having(
              (e) => e.diagnostics,
              'diagnostics',
              contains('keychain locked'),
            ),
          ),
        );
      });
    }
  });
}

class _FailingSecureStorage extends TestFlutterSecureStoragePlatform {
  _FailingSecureStorage() : super({});

  static Never _fail() =>
      throw PlatformException(code: 'locked', message: 'keychain locked');

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _fail();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _fail();

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _fail();

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _fail();
}
