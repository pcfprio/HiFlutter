import 'consent.dart';
import 'console_format.dart';
import 'fan_out.dart';
import 'scalar.dart';

/// Vendor-neutral crash reporting contract.
///
/// Inject an implementation where failures are handled; never reach it
/// through a global. Context and breadcrumb values are restricted to
/// [HiScalar] so every vendor can accept them.
abstract interface class HiCrashReporter {
  /// Reports [exception], optionally with its [stackTrace].
  ///
  /// Set [fatal] when the failure ended the app or the current flow, for
  /// example an uncaught error.
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal,
  });

  /// Reports a diagnostic [message] that is not an exception.
  Future<void> captureMessage(String message);

  /// Attaches [value] under [key] to subsequent reports; `null` removes the
  /// key.
  Future<void> setContext(String key, HiScalar? value);

  /// Records a step that led up to a later report, such as a tap or a
  /// navigation, optionally grouped by [category] and described by [data].
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data,
  });
}

/// Crash reporter that accepts every call and does nothing, for tests or when
/// crash reporting is disabled.
class HiNoOpCrashReporter implements HiCrashReporter {
  /// Creates a no-op crash reporter.
  const HiNoOpCrashReporter();

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {}

  @override
  Future<void> captureMessage(String message) async {}

  @override
  Future<void> setContext(String key, HiScalar? value) async {}

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) async {}
}

/// Crash reporter that writes readable lines, for development.
///
/// Lines look like `[crash] breadcrumb ui tap id="buy"`. Exceptions are
/// written as `[crash] exception ...` or `[crash] fatal ...`, followed by the
/// stack trace on the next lines when one is given.
class HiConsoleCrashReporter implements HiCrashReporter {
  /// Writes lines to [output], which defaults to [print].
  const HiConsoleCrashReporter({this._output = print});

  final void Function(String line) _output;

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    final line = consoleLine(_tag, [
      fatal ? 'fatal' : 'exception',
      '$exception',
    ]);
    final trace = stackTrace?.toString().trimRight() ?? '';
    _output(trace.isEmpty ? line : '$line\n$trace');
  }

  @override
  Future<void> captureMessage(String message) async =>
      _output(consoleLine(_tag, ['message', message]));

  @override
  Future<void> setContext(String key, HiScalar? value) async => _output(
    value == null
        ? consoleLine(_tag, ['context', key, 'removed'])
        : consoleLine(_tag, ['context'], {key: value}),
  );

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) async =>
      _output(consoleLine(_tag, ['breadcrumb', ?category, message], data));

  static const _tag = 'crash';
}

/// Fans every call out to all [delegates], for example several vendors.
///
/// A failing delegate never prevents the others from receiving the call.
/// Each failure is passed to `onError`; without `onError`, the returned
/// future completes with the first failure once every delegate has finished.
class HiCompositeCrashReporter implements HiCrashReporter {
  /// Fans out to [delegates], reporting failures to `onError`.
  HiCompositeCrashReporter(Iterable<HiCrashReporter> delegates, {this._onError})
    : delegates = List.unmodifiable(delegates);

  /// The implementations that receive every call, in order.
  final List<HiCrashReporter> delegates;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) => fanOut(
    delegates,
    (d) => d.captureException(exception, stackTrace: stackTrace, fatal: fatal),
    _onError,
  );

  @override
  Future<void> captureMessage(String message) =>
      fanOut(delegates, (d) => d.captureMessage(message), _onError);

  @override
  Future<void> setContext(String key, HiScalar? value) =>
      fanOut(delegates, (d) => d.setContext(key, value), _onError);

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) => fanOut(
    delegates,
    (d) => d.addBreadcrumb(message, category: category, data: data),
    _onError,
  );
}

/// Forwards to [delegate] only while [consent] is granted.
///
/// While consent is unknown or denied, every call is dropped, not queued.
class HiConsentGatedCrashReporter implements HiCrashReporter {
  /// Gates [delegate] behind [consent].
  HiConsentGatedCrashReporter(this.delegate, {required this.consent});

  /// The implementation that receives allowed calls.
  final HiCrashReporter delegate;

  /// The consent that decides whether calls are allowed.
  final HiConsent consent;

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    if (consent.isGranted) {
      await delegate.captureException(
        exception,
        stackTrace: stackTrace,
        fatal: fatal,
      );
    }
  }

  @override
  Future<void> captureMessage(String message) async {
    if (consent.isGranted) await delegate.captureMessage(message);
  }

  @override
  Future<void> setContext(String key, HiScalar? value) async {
    if (consent.isGranted) await delegate.setContext(key, value);
  }

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) async {
    if (consent.isGranted) {
      await delegate.addBreadcrumb(message, category: category, data: data);
    }
  }
}
