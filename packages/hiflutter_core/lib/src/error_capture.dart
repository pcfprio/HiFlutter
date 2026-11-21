import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hiflutter_base/hiflutter_base.dart';

/// Global error capture: sends every uncaught error to a [HiCrashReporter]
/// and writes it to the global [HiLog] at [HiLogLevel.error].
///
/// Install it once in the composition root, after [HiLog.install] and before
/// `runApp`, and start the app inside [runGuarded]:
///
/// ```dart
/// final capture = HiErrorCapture.install(reporter: crashReporter);
/// capture.runGuarded(() => runApp(const MyApp()));
/// ```
///
/// Three kinds of errors are captured:
///
/// - framework errors passed to [FlutterError.onError], such as build or
///   layout failures, reported with `fatal: false` because the app keeps
///   running; the previous handler still runs afterwards, so the default
///   console dump is kept;
/// - errors passed to [PlatformDispatcher.onError], reported with
///   `fatal: true` and marked as handled;
/// - uncaught errors in the zone of [runGuarded], reported with
///   `fatal: true`.
///
/// A crash reporter that throws or fails never breaks error handling: the
/// failure is only logged.
final class HiErrorCapture {
  HiErrorCapture._(this._reporter, this._module);

  /// Takes over [FlutterError.onError] and [PlatformDispatcher.onError],
  /// sending captured errors to [reporter].
  ///
  /// Log records are tagged with [module]. Call [dispose] to restore the
  /// previous handlers.
  static HiErrorCapture install({
    required HiCrashReporter reporter,
    String module = 'error',
  }) {
    final capture = HiErrorCapture._(reporter, module);
    final dispatcher = PlatformDispatcher.instance;
    capture._previousFlutterHandler = FlutterError.onError;
    capture._previousPlatformHandler = dispatcher.onError;
    FlutterError.onError = capture._onFlutterError;
    dispatcher.onError = capture._onPlatformError;
    return capture;
  }

  final HiCrashReporter _reporter;
  final String _module;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;
  bool _disposed = false;

  void _onFlutterError(FlutterErrorDetails details) {
    _report('Framework error', details.exception, details.stack, fatal: false);
    _previousFlutterHandler?.call(details);
  }

  bool _onPlatformError(Object error, StackTrace stackTrace) {
    _report('Uncaught platform error', error, stackTrace, fatal: true);
    _previousPlatformHandler?.call(error, stackTrace);
    return true;
  }

  void _report(
    String what,
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
  }) {
    HiLog.error(
      () => what,
      module: _module,
      error: error,
      stackTrace: stackTrace,
    );
    unawaited(
      Future.sync(
        () => _reporter.captureException(
          error,
          stackTrace: stackTrace,
          fatal: fatal,
        ),
      ).then<void>(
        (_) {},
        onError: (Object failure, StackTrace failureStack) => HiLog.error(
          () => 'Crash reporter failed',
          module: _module,
          error: failure,
          stackTrace: failureStack,
        ),
      ),
    );
  }

  /// Runs [body] in a guarded zone whose uncaught errors are captured, and
  /// returns its result.
  ///
  /// Returns `null` when [body] itself throws synchronously; that error is
  /// captured like any other.
  R? runGuarded<R>(R Function() body) => runZonedGuarded(
    body,
    (error, stackTrace) =>
        _report('Uncaught zone error', error, stackTrace, fatal: true),
  );

  /// Restores the handlers that were in place before [install].
  ///
  /// Errors in zones started by [runGuarded] are still captured. Calling
  /// this more than once has no further effect.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
  }
}
