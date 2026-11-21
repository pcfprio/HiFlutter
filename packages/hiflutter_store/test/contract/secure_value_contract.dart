// Shared contract tests for every HiSecureStore implementation.
//
// Adapter packages import this file by relative path so that the in-memory
// implementation and each platform implementation run the same suite.
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:test/test.dart';

/// Runs the secure value contract against stores produced by [create].
///
/// [create] must return a fresh, empty store for every call.
void runSecureStoreContract(
  String name,
  Future<HiSecureStore> Function() create,
) {
  group('$name secure value contract', () {
    late HiSecureStore store;

    setUp(() async {
      store = await create();
    });

    test('a missing key reads as null', () async {
      expect(await store.read('missing'), isNull);
    });

    test('values round-trip and can be overwritten', () async {
      await store.write('accessToken', 'abc.def');
      expect(await store.read('accessToken'), 'abc.def');
      await store.write('accessToken', 'ghi');
      expect(await store.read('accessToken'), 'ghi');
    });

    test('delete removes one key and containsKey reflects it', () async {
      await store.write('accessToken', 'a');
      await store.write('refreshToken', 'r');
      expect(await store.containsKey('accessToken'), isTrue);
      await store.delete('accessToken');
      expect(await store.containsKey('accessToken'), isFalse);
      expect(await store.read('accessToken'), isNull);
      expect(await store.read('refreshToken'), 'r');
      await store.delete('never-set');
    });

    test('deleteAll removes every key', () async {
      await store.write('accessToken', 'a');
      await store.write('password', 'p');
      await store.deleteAll();
      expect(await store.containsKey('accessToken'), isFalse);
      expect(await store.containsKey('password'), isFalse);
    });
  });
}
