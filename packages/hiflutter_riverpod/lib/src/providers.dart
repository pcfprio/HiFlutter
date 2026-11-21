import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

/// Error thrown when a HiFlutter contract provider is read before it has been
/// configured with a Riverpod override.
///
/// Configure providers at the composition root using [ProviderScope] or
/// [ProviderContainer], for example:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     hiHttpClientProvider.overrideWithValue(client),
///   ],
///   child: const MyApp(),
/// )
/// ```
final class HiUnconfiguredProviderError extends StateError {
  /// Creates an unconfigured-provider error for [providerName].
  HiUnconfiguredProviderError(this.providerName)
    : super(
        '$providerName has not been configured. Provide an implementation at '
        'the composition root using '
        'ProviderScope(overrides: [$providerName.overrideWithValue(...)]) '
        'or ProviderContainer(overrides: [$providerName.overrideWithValue(...)]).',
      );

  /// Name of the unconfigured provider, such as `hiHttpClientProvider`.
  final String providerName;
}

Provider<T> _contractProvider<T>(String name) =>
    Provider<T>((_) => throw HiUnconfiguredProviderError(name), name: name);

/// Riverpod provider for the [HiLogger] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiLoggerProvider.overrideWithValue(...)])`.
final Provider<HiLogger> hiLoggerProvider = _contractProvider<HiLogger>(
  'hiLoggerProvider',
);

/// Riverpod provider for the [HiConsent] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiConsentProvider.overrideWithValue(...)])`.
final Provider<HiConsent> hiConsentProvider = _contractProvider<HiConsent>(
  'hiConsentProvider',
);

/// Riverpod provider for the [HiAnalytics] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiAnalyticsProvider.overrideWithValue(...)])`.
final Provider<HiAnalytics> hiAnalyticsProvider =
    _contractProvider<HiAnalytics>('hiAnalyticsProvider');

/// Riverpod provider for the [HiCrashReporter] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiCrashReporterProvider.overrideWithValue(...)])`.
final Provider<HiCrashReporter> hiCrashReporterProvider =
    _contractProvider<HiCrashReporter>('hiCrashReporterProvider');

/// Riverpod provider for the [HiHttpClient] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiHttpClientProvider.overrideWithValue(...)])`.
final Provider<HiHttpClient> hiHttpClientProvider =
    _contractProvider<HiHttpClient>('hiHttpClientProvider');

/// Riverpod provider for the [HiConnectivity] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiConnectivityProvider.overrideWithValue(...)])`.
final Provider<HiConnectivity> hiConnectivityProvider =
    _contractProvider<HiConnectivity>('hiConnectivityProvider');

/// Riverpod provider for the [HiKeyValueStore] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiKeyValueStoreProvider.overrideWithValue(...)])`.
final Provider<HiKeyValueStore> hiKeyValueStoreProvider =
    _contractProvider<HiKeyValueStore>('hiKeyValueStoreProvider');

/// Riverpod provider for the [HiSecureStore] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiSecureStoreProvider.overrideWithValue(...)])`.
final Provider<HiSecureStore> hiSecureStoreProvider =
    _contractProvider<HiSecureStore>('hiSecureStoreProvider');

/// Riverpod provider for the [HiFileStore] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiFileStoreProvider.overrideWithValue(...)])`.
final Provider<HiFileStore> hiFileStoreProvider =
    _contractProvider<HiFileStore>('hiFileStoreProvider');

/// Riverpod provider for the [HiNavigator] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiNavigatorProvider.overrideWithValue(...)])`.
final Provider<HiNavigator> hiNavigatorProvider =
    _contractProvider<HiNavigator>('hiNavigatorProvider');

/// Riverpod provider for the [HiLinkOpener] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiLinkOpenerProvider.overrideWithValue(...)])`.
final Provider<HiLinkOpener> hiLinkOpenerProvider =
    _contractProvider<HiLinkOpener>('hiLinkOpenerProvider');

/// Riverpod provider for the [HiDeviceInfoSource] contract.
///
/// Throws [HiUnconfiguredProviderError] until overridden at the composition
/// root via `ProviderScope(overrides: [hiDeviceInfoSourceProvider.overrideWithValue(...)])`.
final Provider<HiDeviceInfoSource> hiDeviceInfoSourceProvider =
    _contractProvider<HiDeviceInfoSource>('hiDeviceInfoSourceProvider');

/// Builds an unmodifiable list of Riverpod [Override]s for all non-null
/// HiFlutter contract instances supplied by the composition root.
List<Override> hiProviderOverrides({
  HiLogger? logger,
  HiConsent? consent,
  HiAnalytics? analytics,
  HiCrashReporter? crashReporter,
  HiHttpClient? httpClient,
  HiConnectivity? connectivity,
  HiKeyValueStore? keyValueStore,
  HiSecureStore? secureStore,
  HiFileStore? fileStore,
  HiNavigator? navigator,
  HiLinkOpener? linkOpener,
  HiDeviceInfoSource? deviceInfoSource,
}) => List<Override>.unmodifiable([
  if (logger != null) hiLoggerProvider.overrideWithValue(logger),
  if (consent != null) hiConsentProvider.overrideWithValue(consent),
  if (analytics != null) hiAnalyticsProvider.overrideWithValue(analytics),
  if (crashReporter != null)
    hiCrashReporterProvider.overrideWithValue(crashReporter),
  if (httpClient != null) hiHttpClientProvider.overrideWithValue(httpClient),
  if (connectivity != null)
    hiConnectivityProvider.overrideWithValue(connectivity),
  if (keyValueStore != null)
    hiKeyValueStoreProvider.overrideWithValue(keyValueStore),
  if (secureStore != null) hiSecureStoreProvider.overrideWithValue(secureStore),
  if (fileStore != null) hiFileStoreProvider.overrideWithValue(fileStore),
  if (navigator != null) hiNavigatorProvider.overrideWithValue(navigator),
  if (linkOpener != null) hiLinkOpenerProvider.overrideWithValue(linkOpener),
  if (deviceInfoSource != null)
    hiDeviceInfoSourceProvider.overrideWithValue(deviceInfoSource),
]);
