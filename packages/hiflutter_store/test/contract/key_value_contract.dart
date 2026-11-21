// Shared contract tests for every HiKeyValueStore implementation.
//
// Adapter packages import this file by relative path so that the in-memory
// implementation and each platform implementation run the same suite.
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:test/test.dart';

/// Runs the key-value contract against stores produced by [create].
///
/// [create] must return a fresh, empty store for every call.
void runKeyValueStoreContract(
  String name,
  Future<HiKeyValueStore> Function() create,
) {
  group('$name key-value contract', () {
    late HiKeyValueStore store;

    setUp(() async {
      store = await create();
    });

    test('a missing key reads as null', () async {
      expect(await store.getString('missing'), isNull);
    });

    test('strings round-trip', () async {
      await store.setString('name', 'Ada');
      expect(await store.getString('name'), 'Ada');
    });

    test('numbers and booleans round-trip', () async {
      await store.setInt('count', -42);
      await store.setDouble('ratio', 0.25);
      await store.setBool('enabled', true);
      expect(await store.getInt('count'), -42);
      expect(await store.getDouble('ratio'), 0.25);
      expect(await store.getBool('enabled'), isTrue);
    });

    test('JSON values round-trip', () async {
      const profile = {
        'id': 7,
        'name': 'Ada',
        'score': 9.5,
        'vip': false,
        'tags': ['a', 'b'],
        'address': {'city': 'Paris', 'zip': null},
      };
      await store.setJson('profile', profile);
      await store.setJson('ids', [1, 2, 3]);
      expect(await store.getJson('profile'), profile);
      expect(await store.getJson('ids'), [1, 2, 3]);
      expect(await store.getJson('missing'), isNull);
    });

    group('rejects credential-like keys', () {
      const keys = [
        'password',
        'user_password',
        'loginPasswd',
        'accessToken',
        'refresh-token',
        'AUTH_TOKEN',
        'clientSecret',
        'credentials',
        'api_key',
        'apiKey',
        'private.key',
        'passcode',
      ];
      for (final key in keys) {
        test('"$key"', () async {
          await expectLater(
            store.setString(key, 'value'),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.setJson(key, {'v': 1}),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.setInt(key, 1),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.setDouble(key, 1),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.setBool(key, true),
            throwsA(isA<HiStorageError>()),
          );
          expect(await store.getString(key), isNull);
        });
      }

      test('but accepts ordinary keys', () async {
        for (final key in [
          'theme',
          'last_tab',
          'keyboardLayout',
          'onboarded',
        ]) {
          await store.setString(key, 'x');
          expect(await store.getString(key), 'x');
        }
      });
    });

    test('reading a value as the wrong type is a decode error', () async {
      await store.setString('name', 'Ada');
      await store.setBool('flag', true);
      await expectLater(store.getInt('name'), throwsA(isA<HiDecodeError>()));
      await expectLater(store.getDouble('name'), throwsA(isA<HiDecodeError>()));
      await expectLater(store.getBool('name'), throwsA(isA<HiDecodeError>()));
      await expectLater(store.getString('flag'), throwsA(isA<HiDecodeError>()));
      await expectLater(store.getJson('flag'), throwsA(isA<HiDecodeError>()));
    });

    test('a string that is not JSON is a decode error', () async {
      await store.setString('broken', '{not json');
      await expectLater(store.getJson('broken'), throwsA(isA<HiDecodeError>()));
    });

    test('a value that cannot be encoded as JSON is refused', () async {
      await expectLater(
        store.setJson('when', DateTime(2026)),
        throwsA(isA<HiStorageError>()),
      );
      expect(await store.getString('when'), isNull);
    });

    test('remove deletes one key and containsKey reflects it', () async {
      await store.setString('a', '1');
      await store.setInt('b', 2);
      expect(await store.containsKey('a'), isTrue);
      await store.remove('a');
      expect(await store.containsKey('a'), isFalse);
      expect(await store.getString('a'), isNull);
      expect(await store.getInt('b'), 2);
      await store.remove('never-set');
    });

    test('clear deletes every key', () async {
      await store.setString('a', '1');
      await store.setBool('b', true);
      await store.clear();
      expect(await store.containsKey('a'), isFalse);
      expect(await store.containsKey('b'), isFalse);
    });

    test('an int reads back as a double', () async {
      await store.setInt('size', 3);
      expect(await store.getDouble('size'), 3.0);
    });
  });
}
