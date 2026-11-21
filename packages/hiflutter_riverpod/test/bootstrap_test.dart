import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

final class _RecordingCrashReporter implements HiCrashReporter {
  final List<(Object error, bool fatal)> captured = [];

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) async {}

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    captured.add((exception, fatal));
  }

  @override
  Future<void> captureMessage(
    String message, {
    HiLogLevel level = HiLogLevel.info,
  }) async {}

  @override
  Future<void> setContext(String key, HiScalar? value) async {}
}

final class _RecordingSink implements HiLogSink {
  final List<HiLogRecord> records = [];

  @override
  void write(HiLogRecord record) => records.add(record);
}

void main() {
  group('HiRiverpodBootstrap.run', () {
    testWidgets(
      'executes startup steps in strict order: log -> error capture -> ProviderScope -> runApp',
      (tester) async {
        final steps = <String>[];
        final logger = HiLogger(const []);
        const crashReporter = HiNoOpCrashReporter();
        final kvStore = HiKeyValueStore.memory();

        late HiLogger readLogger;
        late HiCrashReporter readReporter;
        late HiKeyValueStore readStore;
        Widget? mountedApp;

        final capture = await HiRiverpodBootstrap.run(
          logger: logger,
          reporter: crashReporter,
          errorModule: 'boot_error',
          installLogger: (installed) {
            expect(installed, same(logger));
            steps.add('1:installLogger');
          },
          installErrorCapture: ({required reporter, String module = 'error'}) {
            expect(reporter, same(crashReporter));
            expect(module, 'boot_error');
            steps.add('2:installErrorCapture');
            return HiErrorCapture.install(reporter: reporter, module: module);
          },
          beforeRunApp: () async {
            steps.add('3:beforeRunApp');
          },
          overrides: [hiKeyValueStoreProvider.overrideWithValue(kvStore)],
          runAppCallback: (app) {
            expect(app, isA<ProviderScope>());
            steps.add('4:runApp');
            mountedApp = app;
          },
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Consumer(
              builder: (context, ref, _) {
                steps.add('5:buildChild');
                readLogger = ref.watch(hiLoggerProvider);
                readReporter = ref.watch(hiCrashReporterProvider);
                readStore = ref.watch(hiKeyValueStoreProvider);
                return const Text('ready');
              },
            ),
          ),
        );
        addTearDown(capture.dispose);

        expect(steps, [
          '1:installLogger',
          '2:installErrorCapture',
          '3:beforeRunApp',
          '4:runApp',
        ]);
        expect(mountedApp, isNotNull);

        await tester.pumpWidget(mountedApp!);
        expect(steps, [
          '1:installLogger',
          '2:installErrorCapture',
          '3:beforeRunApp',
          '4:runApp',
          '5:buildChild',
        ]);
        expect(find.text('ready'), findsOneWidget);
        expect(readLogger, same(logger));
        expect(readReporter, same(crashReporter));
        expect(readStore, same(kvStore));
      },
    );

    test(
      'runs inside guarded zone so uncaught async errors reach crash reporter',
      () async {
        final sink = _RecordingSink();
        final logger = HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]);
        final reporter = _RecordingCrashReporter();

        final capture = await HiRiverpodBootstrap.run(
          logger: logger,
          reporter: reporter,
          installLogger: (_) {},
          runAppCallback: (_) {
            scheduleMicrotask(() {
              throw StateError('boom inside bootstrap zone');
            });
          },
          child: const SizedBox.shrink(),
        );
        addTearDown(capture.dispose);

        await Future<void>.delayed(Duration.zero);

        expect(reporter.captured, hasLength(1));
        expect(reporter.captured.single.$1, isA<StateError>());
        expect(reporter.captured.single.$2, isTrue);
      },
    );

    test(
      'installs global HiLog and HiErrorCapture by default on first startup',
      () async {
        final sink = _RecordingSink();
        final logger = HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]);
        final reporter = _RecordingCrashReporter();
        Widget? capturedRoot;

        expect(HiLog.isInstalled, isFalse);

        final capture = await HiRiverpodBootstrap.run(
          logger: logger,
          reporter: reporter,
          runAppCallback: (app) {
            capturedRoot = app;
            HiLog.info(() => 'bootstrapped', module: 'app');
          },
          child: const SizedBox.shrink(),
        );
        addTearDown(capture.dispose);

        expect(HiLog.isInstalled, isTrue);
        expect(capturedRoot, isA<ProviderScope>());
        expect(sink.records.map((r) => r.message), contains('bootstrapped'));
      },
    );
  });
}
