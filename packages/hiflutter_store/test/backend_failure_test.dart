import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:test/test.dart';

void main() {
  group('HiKeyValueStore over a failing backend', () {
    test('wraps foreign exceptions in a HiStorageError', () async {
      final store = HiKeyValueStore(_FailingBackend(StateError('locked')));
      await expectLater(
        store.setString('theme', 'dark'),
        throwsA(
          isA<HiStorageError>().having(
            (e) => e.diagnostics,
            'diagnostics',
            contains('locked'),
          ),
        ),
      );
      await expectLater(store.getInt('n'), throwsA(isA<HiStorageError>()));
      await expectLater(store.clear(), throwsA(isA<HiStorageError>()));
    });

    test('passes a HiError from the backend through unchanged', () async {
      const error = HiCancelledError(message: 'stop');
      final store = HiKeyValueStore(_FailingBackend(error));
      await expectLater(store.remove('theme'), throwsA(same(error)));
    });
  });
}

final class _FailingBackend implements HiKeyValueBackend {
  _FailingBackend(this.error);

  final Object error;

  @override
  Future<Object?> read(String key) async => throw error;

  @override
  Future<void> write(String key, Object value) async => throw error;

  @override
  Future<void> remove(String key) async => throw error;

  @override
  Future<void> clear() async => throw error;
}
