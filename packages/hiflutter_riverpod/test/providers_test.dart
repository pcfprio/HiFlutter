import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

class _FakeNavigator implements HiNavigator {
  @override
  bool canPop() => false;

  @override
  void go<P>(HiRoute<P> route, P args) {}

  @override
  void pop<R extends Object?>([R? result]) {}

  @override
  Future<R?> push<P, R extends Object?>(HiRoute<P> route, P args) async => null;

  @override
  Future<R?> replace<P, R extends Object?>(HiRoute<P> route, P args) async =>
      null;
}

class _FakeLinkOpener implements HiLinkOpener {
  @override
  Future<bool> canOpen(Uri uri) async => true;

  @override
  Future<bool> open(
    Uri uri, {
    HiLinkMode mode = HiLinkMode.platformDefault,
  }) async => true;
}

void main() {
  final logger = HiLogger(const []);
  final consent = HiConsent();
  const analytics = HiNoOpAnalytics();
  const crashReporter = HiNoOpCrashReporter();
  final httpClient = HiHttpClient(
    transport: HiMemoryTransport((_) => HiResponse(statusCode: 200)),
    baseUrl: Uri.parse('https://example.com'),
  );
  final connectivity = HiMemoryConnectivity();
  final keyValueStore = HiKeyValueStore.memory();
  final secureStore = HiSecureStore.memory();
  final fileStore = HiFileStore.memory();
  final navigator = _FakeNavigator();
  final linkOpener = _FakeLinkOpener();
  const deviceInfoSource = HiStaticDeviceInfoSource(
    HiAppDeviceInfo(
      appName: 'HiFlutterTest',
      packageName: 'dev.hiflutter.test',
      version: '0.1.0',
      buildNumber: '1',
      deviceModel: 'TestDevice',
      osName: 'TestOS',
      osVersion: '1.0',
    ),
  );

  final cases =
      <
        ({
          String name,
          Provider<Object> provider,
          Object instance,
          Override Function() createOverride,
        })
      >[
        (
          name: 'hiLoggerProvider',
          provider: hiLoggerProvider,
          instance: logger,
          createOverride: () => hiLoggerProvider.overrideWithValue(logger),
        ),
        (
          name: 'hiConsentProvider',
          provider: hiConsentProvider,
          instance: consent,
          createOverride: () => hiConsentProvider.overrideWithValue(consent),
        ),
        (
          name: 'hiAnalyticsProvider',
          provider: hiAnalyticsProvider,
          instance: analytics,
          createOverride: () =>
              hiAnalyticsProvider.overrideWithValue(analytics),
        ),
        (
          name: 'hiCrashReporterProvider',
          provider: hiCrashReporterProvider,
          instance: crashReporter,
          createOverride: () =>
              hiCrashReporterProvider.overrideWithValue(crashReporter),
        ),
        (
          name: 'hiHttpClientProvider',
          provider: hiHttpClientProvider,
          instance: httpClient,
          createOverride: () =>
              hiHttpClientProvider.overrideWithValue(httpClient),
        ),
        (
          name: 'hiConnectivityProvider',
          provider: hiConnectivityProvider,
          instance: connectivity,
          createOverride: () =>
              hiConnectivityProvider.overrideWithValue(connectivity),
        ),
        (
          name: 'hiKeyValueStoreProvider',
          provider: hiKeyValueStoreProvider,
          instance: keyValueStore,
          createOverride: () =>
              hiKeyValueStoreProvider.overrideWithValue(keyValueStore),
        ),
        (
          name: 'hiSecureStoreProvider',
          provider: hiSecureStoreProvider,
          instance: secureStore,
          createOverride: () =>
              hiSecureStoreProvider.overrideWithValue(secureStore),
        ),
        (
          name: 'hiFileStoreProvider',
          provider: hiFileStoreProvider,
          instance: fileStore,
          createOverride: () =>
              hiFileStoreProvider.overrideWithValue(fileStore),
        ),
        (
          name: 'hiNavigatorProvider',
          provider: hiNavigatorProvider,
          instance: navigator,
          createOverride: () =>
              hiNavigatorProvider.overrideWithValue(navigator),
        ),
        (
          name: 'hiLinkOpenerProvider',
          provider: hiLinkOpenerProvider,
          instance: linkOpener,
          createOverride: () =>
              hiLinkOpenerProvider.overrideWithValue(linkOpener),
        ),
        (
          name: 'hiDeviceInfoSourceProvider',
          provider: hiDeviceInfoSourceProvider,
          instance: deviceInfoSource,
          createOverride: () =>
              hiDeviceInfoSourceProvider.overrideWithValue(deviceInfoSource),
        ),
      ];

  group('HiUnconfiguredProviderError', () {
    test('is a StateError with providerName and configuration guidance', () {
      final error = HiUnconfiguredProviderError('hiHttpClientProvider');

      expect(error, isA<StateError>());
      expect(error.providerName, 'hiHttpClientProvider');
      expect(error.message, contains('hiHttpClientProvider'));
      expect(
        error.message,
        contains(
          'ProviderScope(overrides: [hiHttpClientProvider.overrideWithValue(...)])',
        ),
      );
    });
  });

  group('contract providers', () {
    for (final entry in cases) {
      test(
        '${entry.name} throws HiUnconfiguredProviderError when not overridden',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          Object? caught;
          try {
            container.read(entry.provider);
          } catch (error) {
            caught = error;
          }

          expect(caught, isA<ProviderException>());
          final providerException = caught! as ProviderException;
          expect(
            providerException.exception,
            isA<HiUnconfiguredProviderError>(),
          );
          final unconfigured =
              providerException.exception as HiUnconfiguredProviderError;
          expect(unconfigured.providerName, entry.name);
          expect(unconfigured.message, contains(entry.name));
          expect(
            unconfigured.message,
            contains(
              'ProviderScope(overrides: [${entry.name}.overrideWithValue(...)])',
            ),
          );
        },
      );

      test('${entry.name} resolves configured instance when overridden', () {
        final container = ProviderContainer(
          overrides: [entry.createOverride()],
        );
        addTearDown(container.dispose);

        expect(container.read(entry.provider), same(entry.instance));
      });
    }

    testWidgets(
      'ProviderScope provides overridden contracts to Consumer widgets',
      (tester) async {
        late HiLogger readLogger;
        late HiNavigator readNavigator;

        await tester.pumpWidget(
          ProviderScope(
            overrides: hiProviderOverrides(
              logger: logger,
              navigator: navigator,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Consumer(
                builder: (context, ref, _) {
                  readLogger = ref.watch(hiLoggerProvider);
                  readNavigator = ref.watch(hiNavigatorProvider);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(readLogger, same(logger));
        expect(readNavigator, same(navigator));
      },
    );
  });

  group('hiProviderOverrides', () {
    test('returns an empty list when no contracts are supplied', () {
      expect(hiProviderOverrides(), isEmpty);
    });

    test(
      'overrides only supplied contracts and leaves others unconfigured',
      () {
        final container = ProviderContainer(
          overrides: hiProviderOverrides(logger: logger, fileStore: fileStore),
        );
        addTearDown(container.dispose);

        expect(container.read(hiLoggerProvider), same(logger));
        expect(container.read(hiFileStoreProvider), same(fileStore));
        expect(
          () => container.read(hiConsentProvider),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.exception,
              'exception',
              isA<HiUnconfiguredProviderError>().having(
                (err) => err.providerName,
                'providerName',
                'hiConsentProvider',
              ),
            ),
          ),
        );
      },
    );

    test(
      'configures all 12 contract providers when all arguments are given',
      () {
        final container = ProviderContainer(
          overrides: hiProviderOverrides(
            logger: logger,
            consent: consent,
            analytics: analytics,
            crashReporter: crashReporter,
            httpClient: httpClient,
            connectivity: connectivity,
            keyValueStore: keyValueStore,
            secureStore: secureStore,
            fileStore: fileStore,
            navigator: navigator,
            linkOpener: linkOpener,
            deviceInfoSource: deviceInfoSource,
          ),
        );
        addTearDown(container.dispose);

        for (final entry in cases) {
          expect(container.read(entry.provider), same(entry.instance));
        }
      },
    );
  });
}
