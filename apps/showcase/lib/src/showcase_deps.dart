import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:hiflutter/hiflutter.dart';
import 'package:hiflutter_net_connectivity/hiflutter_net_connectivity.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';

/// Recording analytics sink used in the showcase UI to visualize consent gating.
final class ShowcaseAnalyticsSink implements HiAnalytics {
  /// Tracked event summaries delivered past the consent gate.
  final List<String> delivered = [];

  @override
  Future<void> flush() async {}

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) async {
    delivered.add('identify:$userId');
  }

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) async {
    delivered.add('page:$name');
  }

  @override
  Future<void> reset() async {
    delivered.clear();
  }

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) async {
    delivered.add('track:$event');
  }
}

/// Recording log sink so redacted logs can be inspected inside the showcase app.
final class ShowcaseLogSink implements HiLogSink {
  /// Redacted log lines received through [HiLogRoute].
  final List<String> entries = [];

  @override
  void write(HiLogRecord record) {
    entries.add(
      '[${record.level.name}] ${record.module ?? 'app'}: ${record.message} '
      '${record.attributes}',
    );
  }
}

/// Log sink delegating writes to a [HiFileLogSink] once initialized after the
/// Flutter binding is ready.
final class DeferredFileLogSink implements HiLogSink {
  HiFileLogSink? _inner;

  /// Attaches the initialized [HiFileLogSink].
  void attach(HiFileLogSink sink) => _inner = sink;

  @override
  void write(HiLogRecord record) => _inner?.write(record);
}

/// Bundled contract implementations assembled at the showcase composition root.
final class ShowcaseDependencies {
  ShowcaseDependencies._({
    required this.logger,
    required this.logSink,
    required this.consent,
    required this.analyticsSink,
    required this.analytics,
    required this.crashReporter,
    required this.httpClient,
    required this.connectivity,
    required this.keyValueStore,
    required this.secureStore,
    required this.fileStore,
    required this.linkOpener,
    required this.deviceInfoSource,
    this._memoryConnectivity,
  });

  /// Creates deterministic in-memory implementations for tests and offline previews.
  factory ShowcaseDependencies.inMemory() {
    final logSink = ShowcaseLogSink();
    final logger = HiLogger([
      const HiLogRoute(HiConsoleLogSink(), minLevel: HiLogLevel.debug),
      HiLogRoute(logSink, minLevel: HiLogLevel.info),
    ]);
    final consent = HiConsent();
    final analyticsSink = ShowcaseAnalyticsSink();
    final analytics = HiConsentGatedAnalytics(
      HiCompositeAnalytics([const HiConsoleAnalytics(), analyticsSink]),
      consent: consent,
    );
    final crashReporter = HiConsentGatedCrashReporter(
      const HiNoOpCrashReporter(),
      consent: consent,
    );
    final transport = HiMemoryTransport(
      (request) => HiResponse.json(200, {
        'code': 0,
        'message': 'ok',
        'data': {'id': 1, 'name': 'Ada Lovelace', 'path': request.url.path},
      }),
    );
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.hiflutter.dev/v1/'),
      headers: () => {'authorization': 'Bearer showcase-secret-token'},
      envelope: const HiEnvelope(),
      logger: logger,
    );
    final connectivity = HiMemoryConnectivity();

    return ShowcaseDependencies._(
      logger: logger,
      logSink: logSink,
      consent: consent,
      analyticsSink: analyticsSink,
      analytics: analytics,
      crashReporter: crashReporter,
      httpClient: client,
      connectivity: connectivity,
      memoryConnectivity: connectivity,
      keyValueStore: HiKeyValueStore.memory(),
      secureStore: HiSecureStore.memory(),
      fileStore: HiFileStore.memory(),
      linkOpener: _ShowcaseLinkOpener(),
      deviceInfoSource: const HiStaticDeviceInfoSource(
        HiAppDeviceInfo(
          appName: 'HiFlutterShowcase',
          packageName: 'dev.hiflutter.hiflutterShowcase',
          version: '0.1.0',
          buildNumber: '1',
          deviceModel: 'Simulator',
          osName: 'Flutter',
          osVersion: '3.50',
        ),
      ),
    );
  }

  /// Creates platform-backed implementations for running on Android and iOS.
  static Future<ShowcaseDependencies> live({
    required HiLogger logger,
    required ShowcaseLogSink logSink,
    DeferredFileLogSink? fileSinkTarget,
  }) async {
    final fileLogSink = await HiFileLogSink.inApplicationSupport();
    fileSinkTarget?.attach(fileLogSink);
    final consent = HiConsent();
    final analyticsSink = ShowcaseAnalyticsSink();
    final analytics = HiConsentGatedAnalytics(
      HiCompositeAnalytics([const HiConsoleAnalytics(), analyticsSink]),
      consent: consent,
    );
    final crashReporter = HiConsentGatedCrashReporter(
      const HiNoOpCrashReporter(),
      consent: consent,
    );
    final client = HiHttpClient(
      transport: HiDioTransport(connectTimeout: const Duration(seconds: 10)),
      baseUrl: Uri.parse('https://httpbin.org/'),
      envelope: const HiEnvelope(),
      logger: logger,
    );

    return ShowcaseDependencies._(
      logger: logger,
      logSink: logSink,
      consent: consent,
      analyticsSink: analyticsSink,
      analytics: analytics,
      crashReporter: crashReporter,
      httpClient: client,
      connectivity: HiPlusConnectivity(),
      keyValueStore: HiKeyValueStore(HiPrefsKeyValueBackend()),
      secureStore: HiSecureStore(HiSecureStorageBackend()),
      fileStore: HiFileStore(HiAppFileBackend()),
      linkOpener: HiUrlLauncherLinkOpener(),
      deviceInfoSource: const HiPlatformDeviceInfoSource(),
    );
  }

  /// Configured application logger.
  final HiLogger logger;

  /// In-memory log collector displayed by the observability demo.
  final ShowcaseLogSink logSink;

  /// Privacy consent controller.
  final HiConsent consent;

  /// Underlying analytics collector behind [analytics].
  final ShowcaseAnalyticsSink analyticsSink;

  /// Consent-gated analytics contract instance.
  final HiAnalytics analytics;

  /// Consent-gated crash reporter contract instance.
  final HiCrashReporter crashReporter;

  /// Configured HTTP client.
  final HiHttpClient httpClient;

  /// Connectivity contract instance.
  final HiConnectivity connectivity;

  /// Key-value storage contract instance.
  final HiKeyValueStore keyValueStore;

  /// Secure storage contract instance.
  final HiSecureStore secureStore;

  /// Relative file storage contract instance.
  final HiFileStore fileStore;

  /// External link opener contract instance.
  final HiLinkOpener linkOpener;

  /// App and device metadata source.
  final HiDeviceInfoSource deviceInfoSource;

  final HiMemoryConnectivity? _memoryConnectivity;

  /// Builds the full list of Riverpod overrides for [ProviderScope].
  List<Override> toOverrides({required HiNavigator navigator}) =>
      hiProviderOverrides(
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
      );

  /// Releases in-memory resources created for tests or previews.
  Future<void> dispose() async {
    await httpClient.close();
    await _memoryConnectivity?.dispose();
  }
}

class _ShowcaseLinkOpener implements HiLinkOpener {
  @override
  Future<bool> canOpen(Uri uri) async => true;

  @override
  Future<bool> open(
    Uri uri, {
    HiLinkMode mode = HiLinkMode.platformDefault,
  }) async => true;
}
