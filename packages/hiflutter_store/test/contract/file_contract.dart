// Shared contract tests for every HiFileStore implementation.
//
// Adapter packages import this file by relative path so that the in-memory
// implementation and each platform implementation run the same suite.
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:test/test.dart';

/// Runs the file contract against stores produced by [create].
///
/// [create] must return a fresh, empty store for every call.
void runFileStoreContract(String name, Future<HiFileStore> Function() create) {
  group('$name file contract', () {
    late HiFileStore store;

    setUp(() async {
      store = await create();
    });

    test('a missing file reads as null', () async {
      expect(await store.readBytes('missing.bin'), isNull);
      expect(await store.readText('missing.txt'), isNull);
    });

    test('bytes round-trip in nested directories', () async {
      await store.writeBytes('cache/images/a.bin', [0, 1, 254, 255]);
      expect(await store.readBytes('cache/images/a.bin'), [0, 1, 254, 255]);
    });

    test('text round-trips as UTF-8 and can be overwritten', () async {
      await store.writeText('notes/today.txt', 'héllo 世界');
      expect(await store.readText('notes/today.txt'), 'héllo 世界');
      await store.writeText('notes/today.txt', 'bye');
      expect(await store.readText('notes/today.txt'), 'bye');
    });

    test('exists and delete', () async {
      await store.writeText('a/b.txt', 'x');
      await store.writeText('a/c.txt', 'y');
      expect(await store.exists('a/b.txt'), isTrue);
      await store.delete('a/b.txt');
      expect(await store.exists('a/b.txt'), isFalse);
      expect(await store.readText('a/b.txt'), isNull);
      expect(await store.readText('a/c.txt'), 'y');
      await store.delete('never/written.txt');
    });

    test('reading non-UTF-8 bytes as text is a decode error', () async {
      await store.writeBytes('raw.bin', [0xff, 0xfe, 0xc3]);
      await expectLater(
        store.readText('raw.bin'),
        throwsA(isA<HiDecodeError>()),
      );
    });

    group('rejects paths that escape the store', () {
      const paths = [
        '',
        '.',
        '/',
        '../outside.txt',
        'a/../../outside.txt',
        'a/../b.txt',
        '..\\outside.txt',
        '/etc/passwd',
        '\\windows\\win.ini',
        'C:\\boot.ini',
        'c:/boot.ini',
        'a/b/..',
        'nul\x00.txt',
      ];
      for (final path in paths) {
        test('"${path.replaceAll('\x00', r'\0')}"', () async {
          await expectLater(
            store.writeText(path, 'x'),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.writeBytes(path, [1]),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.readText(path),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(
            store.readBytes(path),
            throwsA(isA<HiStorageError>()),
          );
          await expectLater(store.exists(path), throwsA(isA<HiStorageError>()));
          await expectLater(store.delete(path), throwsA(isA<HiStorageError>()));
        });
      }
    });

    test('equivalent spellings of a path address the same file', () async {
      await store.writeText('docs/./a.txt', 'one');
      expect(await store.readText('docs/a.txt'), 'one');
      expect(await store.readText('docs//a.txt'), 'one');
      expect(await store.readText('./docs/a.txt'), 'one');
      expect(await store.readText('docs\\a.txt'), 'one');
    });
  });
}
