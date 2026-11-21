import 'consent.dart';
import 'console_format.dart';
import 'fan_out.dart';
import 'scalar.dart';

/// Vendor-neutral analytics contract.
///
/// Inject an implementation where events are produced; never reach it through
/// a global. Property values are restricted to [HiScalar] so every vendor can
/// accept them.
abstract interface class HiAnalytics {
  /// Records that [event] happened.
  Future<void> track(String event, {Map<String, HiScalar> properties});

  /// Associates subsequent events with [userId].
  Future<void> identify(String userId, {Map<String, HiScalar> traits});

  /// Records that the screen [name] was shown.
  Future<void> page(String name, {Map<String, HiScalar> properties});

  /// Forgets the current user, for example on sign out.
  Future<void> reset();

  /// Sends queued events now.
  Future<void> flush();
}

/// Analytics that accepts every call and does nothing, for tests or when
/// analytics is disabled.
class HiNoOpAnalytics implements HiAnalytics {
  /// Creates a no-op analytics.
  const HiNoOpAnalytics();

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) async {}

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) async {}

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> flush() async {}
}

/// Analytics that writes one readable line per call, for development.
///
/// Lines look like `[analytics] track signup plan="pro" seats=3`; string
/// values are quoted, other scalars are not.
class HiConsoleAnalytics implements HiAnalytics {
  /// Writes lines to [output], which defaults to [print].
  const HiConsoleAnalytics({this._output = print});

  final void Function(String line) _output;

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) async => _output(consoleLine(_tag, ['track', event], properties));

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) async => _output(consoleLine(_tag, ['identify', userId], traits));

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) async => _output(consoleLine(_tag, ['page', name], properties));

  @override
  Future<void> reset() async => _output(consoleLine(_tag, ['reset']));

  @override
  Future<void> flush() async => _output(consoleLine(_tag, ['flush']));

  static const _tag = 'analytics';
}

/// Fans every call out to all [delegates], for example several vendors.
///
/// A failing delegate never prevents the others from receiving the call.
/// Each failure is passed to `onError`; without `onError`, the returned
/// future completes with the first failure once every delegate has finished.
class HiCompositeAnalytics implements HiAnalytics {
  /// Fans out to [delegates], reporting failures to [onError].
  HiCompositeAnalytics(Iterable<HiAnalytics> delegates, {this._onError})
    : delegates = List.unmodifiable(delegates);

  /// The implementations that receive every call, in order.
  final List<HiAnalytics> delegates;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) => fanOut(
    delegates,
    (d) => d.track(event, properties: properties),
    _onError,
  );

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) => fanOut(delegates, (d) => d.identify(userId, traits: traits), _onError);

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) =>
      fanOut(delegates, (d) => d.page(name, properties: properties), _onError);

  @override
  Future<void> reset() => fanOut(delegates, (d) => d.reset(), _onError);

  @override
  Future<void> flush() => fanOut(delegates, (d) => d.flush(), _onError);
}

/// Forwards to [delegate] only while [consent] is granted.
///
/// While consent is unknown or denied, [track], [identify], [page] and
/// [flush] are dropped, not queued. [reset] always passes through, because
/// forgetting data never needs consent.
class HiConsentGatedAnalytics implements HiAnalytics {
  /// Gates [delegate] behind [consent].
  HiConsentGatedAnalytics(this.delegate, {required this.consent});

  /// The implementation that receives allowed calls.
  final HiAnalytics delegate;

  /// The consent that decides whether calls are allowed.
  final HiConsent consent;

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) async {
    if (consent.isGranted) {
      await delegate.track(event, properties: properties);
    }
  }

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) async {
    if (consent.isGranted) await delegate.identify(userId, traits: traits);
  }

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) async {
    if (consent.isGranted) await delegate.page(name, properties: properties);
  }

  @override
  Future<void> reset() => delegate.reset();

  @override
  Future<void> flush() async {
    if (consent.isGranted) await delegate.flush();
  }
}
