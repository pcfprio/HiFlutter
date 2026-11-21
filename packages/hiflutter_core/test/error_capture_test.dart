import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

class _Capture {
  _Capture(this.exception, this.stackTrace, this.fatal);

  final Object exception;
  final StackTrace? stackTrace;
  final bool fatal;
}

class _RecordingReporter extends HiNoOpCrashReporter {
  final captures = <_Capture>[];

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async => captures.add(_Capture(exception, stackTrace, fatal));
}

class _FailingReporter extends HiNoOpCrashReporter {
  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) => Future.error(StateError('reporter down'));
}

class _MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

final _sink = _MemorySink();

void main() {
  setUpAll(() => HiLog.install(HiLogger([HiLogRoute(_sink)])));

  late _RecordingReporter reporter;
  late HiErrorCapture capture;

  setUp(() {
    _sink.records.clear();
    reporter = _RecordingReporter();
  });

  tearDown(() => capture.dispose());

  test('framework errors reach the crash reporter and the log', () {
    FlutterError.onError = (_) {};
    capture = HiErrorCapture.install(reporter: reporter);
    final stack = StackTrace.current;

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('build failed'), stack: stack),
    );

    expect(reporter.captures, hasLength(1));
    expect(reporter.captures.single.exception, isA<StateError>());
    expect(reporter.captures.single.stackTrace, stack);
    expect(reporter.captures.single.fatal, isFalse);
    expect(_sink.records, hasLength(1));
    expect(_sink.records.single.level, HiLogLevel.error);
    expect(_sink.records.single.error, contains('build failed'));
  });

  test('platform dispatcher errors are reported as fatal and handled', () {
    capture = HiErrorCapture.install(reporter: reporter);
    final stack = StackTrace.current;

    final handled = PlatformDispatcher.instance.onError!(
      StateError('channel failed'),
      stack,
    );

    expect(handled, isTrue);
    expect(reporter.captures.single.exception, isA<StateError>());
    expect(reporter.captures.single.stackTrace, stack);
    expect(reporter.captures.single.fatal, isTrue);
    expect(_sink.records.single.level, HiLogLevel.error);
    expect(_sink.records.single.error, contains('channel failed'));
  });

  test('async errors inside runGuarded are reported as fatal', () async {
    capture = HiErrorCapture.install(reporter: reporter);

    final result = capture.runGuarded(() {
      unawaited(Future<void>.error(StateError('async failed')));
      return 'started';
    });
    await pumpEventQueue();

    expect(result, 'started');
    expect(reporter.captures.single.exception, isA<StateError>());
    expect(reporter.captures.single.stackTrace, isNotNull);
    expect(reporter.captures.single.fatal, isTrue);
    expect(_sink.records.single.error, contains('async failed'));
  });

  test('a failing crash reporter is logged and never rethrown', () async {
    capture = HiErrorCapture.install(reporter: _FailingReporter());

    capture.runGuarded(
      () => unawaited(Future<void>.error(StateError('async failed'))),
    );
    await pumpEventQueue();

    expect(_sink.records.map((r) => r.error), [
      contains('async failed'),
      contains('reporter down'),
    ]);
  });

  test('framework errors still reach the previous handler', () {
    final previous = <FlutterErrorDetails>[];
    FlutterError.onError = previous.add;
    capture = HiErrorCapture.install(reporter: reporter);

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('build failed')),
    );

    expect(previous.single.exception, isA<StateError>());
    expect(reporter.captures, hasLength(1));
  });

  test('dispose restores the previous handlers', () {
    final previous = <FlutterErrorDetails>[];
    FlutterError.onError = previous.add;
    capture = HiErrorCapture.install(reporter: reporter);

    capture.dispose();
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('build failed')),
    );

    expect(previous, hasLength(1));
    expect(reporter.captures, isEmpty);
    expect(PlatformDispatcher.instance.onError, isNull);
  });
}
