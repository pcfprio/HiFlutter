import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_file/hiflutter_store_file.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../hiflutter_store/test/contract/file_contract.dart';

void main() {
  late Directory sandbox;
  late _FakePathProvider paths;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('hiflutter_store_file_');
    paths = _FakePathProvider(sandbox.path);
    PathProviderPlatform.instance = paths;
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  runFileStoreContract('dart:io', () async => HiFileStore(HiAppFileBackend()));

  group('HiAppFileBackend', () {
    test('stores files under the app support directory by default', () async {
      await HiFileStore(HiAppFileBackend()).writeText('a/b.txt', 'hi');
      expect(File('${sandbox.path}/support/a/b.txt').readAsStringSync(), 'hi');
    });

    final locations = {
      HiAppDirectory.support: 'support',
      HiAppDirectory.documents: 'documents',
      HiAppDirectory.cache: 'cache',
    };
    for (final MapEntry(key: location, value: dir) in locations.entries) {
      test('$location resolves to the platform $dir directory', () async {
        await HiFileStore(HiAppFileBackend(directory: location))
            .writeText('x.txt', '$location');
        expect(
          File('${sandbox.path}/$dir/x.txt').readAsStringSync(),
          '$location',
        );
      });
    }
  });

  group('platform failures', () {
    test('a missing platform directory is a HiStorageError', () async {
      paths.available = false;
      final store = HiFileStore(HiAppFileBackend());
      await expectLater(
        store.writeText('a.txt', 'x'),
        throwsA(isA<HiStorageError>()),
      );
    });

    test('a file system error is a HiStorageError with the cause', () async {
      final store = HiFileStore(HiAppFileBackend());
      await store.writeText('folder/inner.txt', 'x');
      await expectLater(
        store.writeText('folder', 'not a directory'),
        throwsA(
          isA<HiStorageError>().having(
            (e) => e.diagnostics,
            'diagnostics',
            contains('FileSystemException'),
          ),
        ),
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;
  bool available = true;

  Future<String?> _path(String name) async => available ? '$root/$name' : null;

  @override
  Future<String?> getApplicationSupportPath() => _path('support');

  @override
  Future<String?> getApplicationDocumentsPath() => _path('documents');

  @override
  Future<String?> getApplicationCachePath() => _path('cache');
}
