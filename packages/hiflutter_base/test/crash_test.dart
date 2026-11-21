import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

/// Records every call it receives as a readable line.
class RecordingCrashReporter implements HiCrashReporter {
  final calls = <String>[];

  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) async => calls.add('exception $exception fatal=$fatal');

  @override
  Future<void> captureMessage(String message) async =>
      calls.add('message $message');

  @override
  Future<void> setContext(String key, HiScalar? value) async =>
      calls.add('context $key=$value');

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) async => calls.add('breadcrumb $message $category $data');
}

Future<void> exercise(HiCrashReporter reporter) async {
  await reporter.addBreadcrumb(
    'tap',
    category: 'ui',
    data: {'id': HiScalar('buy')},
  );
  await reporter.setContext('build', HiScalar(42));
  await reporter.captureMessage('low memory');
  await reporter.captureException(StateError('boom'), fatal: true);
}

const exercised = [
  'breadcrumb tap ui {id: buy}',
  'context build=42',
  'message low memory',
  'exception Bad state: boom fatal=true',
];

/// Fails every call synchronously.
class FailingCrashReporter implements HiCrashReporter {
  @override
  Future<void> captureException(
    Object exception, {
    StackTrace? stackTrace,
    bool fatal = false,
  }) => throw StateError('down');

  @override
  Future<void> captureMessage(String message) =>
      Future.error(StateError('down'));

  @override
  Future<void> setContext(String key, HiScalar? value) =>
      throw StateError('down');

  @override
  Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, HiScalar> data = const {},
  }) => Future.error(StateError('down'));
}

void main() {
  group('console crash reporter', () {
    test('writes readable lines', () async {
      final lines = <String>[];
      final reporter = HiConsoleCrashReporter(output: lines.add);
      final stackTrace = StackTrace.fromString('#0 main (app.dart:1)');

      await reporter.addBreadcrumb(
        'tap',
        category: 'ui',
        data: {'id': HiScalar('buy'), 'qty': HiScalar(2)},
      );
      await reporter.addBreadcrumb('opened');
      await reporter.setContext('build', HiScalar(42));
      await reporter.setContext('build', null);
      await reporter.captureMessage('low memory');
      await reporter.captureException(StateError('boom'));
      await reporter.captureException(
        StateError('boom'),
        stackTrace: stackTrace,
        fatal: true,
      );

      expect(lines, [
        '[crash] breadcrumb ui tap id="buy" qty=2',
        '[crash] breadcrumb opened',
        '[crash] context build=42',
        '[crash] context build removed',
        '[crash] message low memory',
        '[crash] exception Bad state: boom',
        '[crash] fatal Bad state: boom\n#0 main (app.dart:1)',
      ]);
    });
  });

  test('no-op crash reporter accepts every call and does nothing', () async {
    await exercise(const HiNoOpCrashReporter());
  });

  group('composite crash reporter', () {
    test('fans every call out to all delegates', () async {
      final a = RecordingCrashReporter();
      final b = RecordingCrashReporter();
      await exercise(HiCompositeCrashReporter([a, b]));
      expect(a.calls, exercised);
      expect(b.calls, exercised);
    });

    test('a failing delegate does not stop the others', () async {
      final before = RecordingCrashReporter();
      final after = RecordingCrashReporter();
      final errors = <Object>[];
      final reporter = HiCompositeCrashReporter([
        before,
        FailingCrashReporter(),
        after,
      ], onError: (error, _) => errors.add(error));

      await exercise(reporter);

      expect(before.calls, exercised);
      expect(after.calls, exercised);
      expect(errors, hasLength(4));
    });

    test(
      'without onError, reports the failure after all delegates ran',
      () async {
        final after = RecordingCrashReporter();
        final reporter = HiCompositeCrashReporter([
          FailingCrashReporter(),
          after,
        ]);

        await expectLater(reporter.captureMessage('x'), throwsStateError);
        expect(after.calls, ['message x']);
      },
    );
  });

  group('consent-gated crash reporter', () {
    for (final status in [HiConsentStatus.unknown, HiConsentStatus.denied]) {
      test('blocks everything while consent is ${status.name}', () async {
        final inner = RecordingCrashReporter();
        final consent = HiConsent(initial: status);
        await exercise(HiConsentGatedCrashReporter(inner, consent: consent));
        expect(inner.calls, isEmpty);
      });
    }

    test('passes everything through once consent is granted', () async {
      final inner = RecordingCrashReporter();
      final consent = HiConsent();
      final reporter = HiConsentGatedCrashReporter(inner, consent: consent);

      await reporter.captureMessage('before consent');
      consent.grant();
      await exercise(reporter);

      expect(inner.calls, exercised);
    });
  });
}
