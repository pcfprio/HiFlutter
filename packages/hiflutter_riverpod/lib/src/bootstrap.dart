import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

import 'providers.dart';

/// Ordered application startup skeleton for Riverpod-backed HiFlutter apps.
///
/// Startup always executes in four deterministic steps:
/// 1. Install the global [HiLog] entry once with `logger`.
/// 2. Install global [HiErrorCapture] routing framework, platform, and zone
///    errors into `reporter` and [HiLog].
/// 3. Initialize the Flutter binding and run optional async preparation inside
///    the guarded zone, wrapping the root widget in a [ProviderScope] with
///    the configured contract overrides.
/// 4. Mount the root widget with `runApp`.
abstract final class HiRiverpodBootstrap {
  /// Runs the ordered startup sequence and mounts [child] inside a
  /// [ProviderScope].
  ///
  /// Both [logger] and [reporter] are automatically bound to
  /// [hiLoggerProvider] and [hiCrashReporterProvider], followed by any extra
  /// [overrides] from the composition root. Optional [beforeRunApp] runs inside
  /// the guarded zone after [WidgetsFlutterBinding.ensureInitialized] and
  /// before `runApp` is called.
  ///
  /// The optional [installLogger], [installErrorCapture], and [runAppCallback]
  /// hooks default to [HiLog.install], [HiErrorCapture.install], and [runApp],
  /// allowing tests to verify ordering or observe mounted roots without global
  /// side effects.
  static Future<HiErrorCapture> run({
    required HiLogger logger,
    required HiCrashReporter reporter,
    required Widget child,
    List<Override> overrides = const [],
    String errorModule = 'error',
    FutureOr<void> Function()? beforeRunApp,
    void Function(HiLogger logger)? installLogger,
    HiErrorCapture Function({required HiCrashReporter reporter, String module})?
    installErrorCapture,
    void Function(Widget app)? runAppCallback,
  }) async {
    (installLogger ?? HiLog.install)(logger);
    final capture = (installErrorCapture ?? HiErrorCapture.install)(
      reporter: reporter,
      module: errorModule,
    );

    final done = Completer<void>();
    capture.runGuarded<void>(() async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        if (beforeRunApp != null) {
          await beforeRunApp();
        }
        final scope = ProviderScope(
          overrides: [
            hiLoggerProvider.overrideWithValue(logger),
            hiCrashReporterProvider.overrideWithValue(reporter),
            ...overrides,
          ],
          child: child,
        );
        (runAppCallback ?? runApp)(scope);
      } finally {
        if (!done.isCompleted) {
          done.complete();
        }
      }
    });

    await done.future;
    return capture;
  }
}
