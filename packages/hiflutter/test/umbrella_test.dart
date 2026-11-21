import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter/hiflutter.dart';

void main() {
  test('importing and touching umbrella symbols triggers no auto-initialization', () {
    final originalOnError = FlutterError.onError;

    // Touch types from every umbrella family without installing or configuring
    // any global singletons.
    const error = HiNetworkError(message: 'offline');
    final logger = HiLogger([const HiLogRoute(HiConsoleLogSink())]);
    final client = HiHttpClient(
      transport: HiDioTransport(),
      baseUrl: Uri.parse('https://example.com'),
    );
    final kv = HiKeyValueStore.memory();
    final secure = HiSecureStore.memory();
    final files = HiFileStore.memory();
    const prefsBackend = HiPrefsKeyValueBackend;
    const secureBackend = HiSecureStorageBackend;
    const fileBackend = HiAppFileBackend;
    const deviceSource = HiPlatformDeviceInfoSource;
    const linkOpener = HiUrlLauncherLinkOpener;
    const fileSink = HiFileLogSink;
    final route = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
    final goNav = HiGoRouterNavigator(
      table: HiRouteTable([route]),
      pages: [route.page((_, _) => const SizedBox.shrink())],
      initialLocation: '/',
    );
    addTearDown(goNav.dispose);

    expect(error.retryable, isTrue);
    expect(logger, isA<HiLogger>());
    expect(client, isA<HiHttpClient>());
    expect(kv, isA<HiKeyValueStore>());
    expect(secure, isA<HiSecureStore>());
    expect(files, isA<HiFileStore>());
    expect(prefsBackend, isNotNull);
    expect(secureBackend, isNotNull);
    expect(fileBackend, isNotNull);
    expect(deviceSource, isNotNull);
    expect(linkOpener, isNotNull);
    expect(fileSink, isNotNull);
    expect(HiFormat.fileSize(1024), '1 KB');
    expect(HiSuiteMetrics.listRowMinHeight, 52.0);
    expect(HiLog.isInstalled, isFalse);
    expect(FlutterError.onError, same(originalOnError));
  });

  test(
    'exports only the 14 umbrella member libraries and zero third-party types',
    () {
      final pkgDir = Directory.current;
      final umbrellaFile = File('${pkgDir.path}/lib/hiflutter.dart');
      expect(umbrellaFile.existsSync(), isTrue);

      final lines = umbrellaFile.readAsLinesSync();
      final exportPattern = RegExp(r'''^\s*export\s+['"]([^'"]+)['"]''');
      final exportedUris = <String>[
        for (final line in lines)
          if (exportPattern.firstMatch(line) case final match?) match[1]!,
      ];

      const expectedMembers = <String>{
        'hiflutter_base',
        'hiflutter_base_log_file',
        'hiflutter_core',
        'hiflutter_core_device',
        'hiflutter_nav',
        'hiflutter_nav_go_router',
        'hiflutter_nav_url_launcher',
        'hiflutter_net',
        'hiflutter_net_dio',
        'hiflutter_store',
        'hiflutter_store_file',
        'hiflutter_store_prefs',
        'hiflutter_store_secure',
        'hiflutter_suite',
      };

      expect(
        exportedUris.toSet(),
        equals({for (final pkg in expectedMembers) 'package:$pkg/$pkg.dart'}),
      );

      // Ensure no umbrella entrypoint re-exports any third-party package.
      final repoPackagesDir = pkgDir.parent;
      for (final pkg in expectedMembers) {
        final entryFile = File('${repoPackagesDir.path}/$pkg/lib/$pkg.dart');
        expect(
          entryFile.existsSync(),
          isTrue,
          reason: 'Missing $pkg entrypoint',
        );
        for (final line in entryFile.readAsLinesSync()) {
          final match = exportPattern.firstMatch(line);
          if (match == null) continue;
          final uri = match[1]!;
          final isOwnSrc = uri.startsWith('src/');
          final isInternalHiFlutter = uri.startsWith('package:hiflutter');
          expect(
            isOwnSrc || isInternalHiFlutter,
            isTrue,
            reason: '$pkg exports external package $uri',
          );
        }
      }
    },
  );
}
