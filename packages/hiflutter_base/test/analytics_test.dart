import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

/// Records every call it receives as a readable line.
class RecordingAnalytics implements HiAnalytics {
  final calls = <String>[];

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) async => calls.add('track $event $properties');

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) async => calls.add('identify $userId $traits');

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) async => calls.add('page $name $properties');

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Future<void> flush() async => calls.add('flush');
}

/// Fails every call, synchronously or asynchronously.
class FailingAnalytics implements HiAnalytics {
  FailingAnalytics({this.sync = false});

  final bool sync;

  Future<void> _fail() {
    if (sync) throw StateError('sync failure');
    return Future.error(StateError('async failure'));
  }

  @override
  Future<void> track(
    String event, {
    Map<String, HiScalar> properties = const {},
  }) => _fail();

  @override
  Future<void> identify(
    String userId, {
    Map<String, HiScalar> traits = const {},
  }) => _fail();

  @override
  Future<void> page(
    String name, {
    Map<String, HiScalar> properties = const {},
  }) => _fail();

  @override
  Future<void> reset() => _fail();

  @override
  Future<void> flush() => _fail();
}

void main() {
  group('console analytics', () {
    test('writes one readable line per call', () async {
      final lines = <String>[];
      final analytics = HiConsoleAnalytics(output: lines.add);

      await analytics.track(
        'signup',
        properties: {
          'plan': HiScalar('pro'),
          'seats': HiScalar(3),
          'price': HiScalar(9.5),
          'trial': HiScalar(false),
        },
      );
      await analytics.identify('u1', traits: {'vip': HiScalar(true)});
      await analytics.page('home');
      await analytics.reset();
      await analytics.flush();

      expect(lines, [
        '[analytics] track signup plan="pro" seats=3 price=9.5 trial=false',
        '[analytics] identify u1 vip=true',
        '[analytics] page home',
        '[analytics] reset',
        '[analytics] flush',
      ]);
    });
  });

  test('no-op analytics accepts every call and does nothing', () async {
    const analytics = HiNoOpAnalytics();
    await analytics.track('signup', properties: {'plan': HiScalar('pro')});
    await analytics.identify('u1');
    await analytics.page('home');
    await analytics.reset();
    await analytics.flush();
  });

  group('composite analytics', () {
    test('fans every call out to all delegates', () async {
      final a = RecordingAnalytics();
      final b = RecordingAnalytics();
      final analytics = HiCompositeAnalytics([a, b]);

      await analytics.track('signup', properties: {'plan': HiScalar('pro')});
      await analytics.identify('u1');
      await analytics.page('home');
      await analytics.reset();
      await analytics.flush();

      const expected = [
        'track signup {plan: pro}',
        'identify u1 {}',
        'page home {}',
        'reset',
        'flush',
      ];
      expect(a.calls, expected);
      expect(b.calls, expected);
    });

    test('a failing delegate does not stop the others', () async {
      final before = RecordingAnalytics();
      final after = RecordingAnalytics();
      final errors = <Object>[];
      final analytics = HiCompositeAnalytics([
        before,
        FailingAnalytics(sync: true),
        FailingAnalytics(),
        after,
      ], onError: (error, _) => errors.add(error));

      await analytics.track('signup');
      await analytics.reset();

      expect(before.calls, ['track signup {}', 'reset']);
      expect(after.calls, ['track signup {}', 'reset']);
      expect(errors, hasLength(4));
      expect(errors, everyElement(isA<StateError>()));
    });

    test('without onError, reports the first failure after all delegates '
        'ran', () async {
      final after = RecordingAnalytics();
      final analytics = HiCompositeAnalytics([
        FailingAnalytics(sync: true),
        FailingAnalytics(),
        after,
      ]);

      await expectLater(
        analytics.flush(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'sync failure'),
        ),
      );
      expect(after.calls, ['flush']);
    });
  });

  group('consent-gated analytics', () {
    test('blocks everything while consent is unknown', () async {
      final inner = RecordingAnalytics();
      final analytics = HiConsentGatedAnalytics(inner, consent: HiConsent());

      await analytics.track('signup');
      await analytics.identify('u1');
      await analytics.page('home');
      await analytics.flush();

      expect(inner.calls, isEmpty);
    });

    test('blocks everything while consent is denied', () async {
      final inner = RecordingAnalytics();
      final consent = HiConsent(initial: HiConsentStatus.denied);
      final analytics = HiConsentGatedAnalytics(inner, consent: consent);

      await analytics.track('signup');
      await analytics.identify('u1');
      await analytics.page('home');
      await analytics.flush();

      expect(inner.calls, isEmpty);
    });

    test('passes everything through once consent is granted', () async {
      final inner = RecordingAnalytics();
      final consent = HiConsent();
      final analytics = HiConsentGatedAnalytics(inner, consent: consent);

      await analytics.track('before');
      consent.grant();
      await analytics.track('signup', properties: {'plan': HiScalar('pro')});
      await analytics.identify('u1', traits: {'vip': HiScalar(true)});
      await analytics.page('home', properties: {'tab': HiScalar(2)});
      await analytics.flush();

      expect(inner.calls, [
        'track signup {plan: pro}',
        'identify u1 {vip: true}',
        'page home {tab: 2}',
        'flush',
      ]);
    });

    test('blocks again after consent is revoked', () async {
      final inner = RecordingAnalytics();
      final consent = HiConsent(initial: HiConsentStatus.granted);
      final analytics = HiConsentGatedAnalytics(inner, consent: consent);

      consent.deny();
      await analytics.track('signup');

      expect(inner.calls, isEmpty);
    });

    test('always passes reset through', () async {
      for (final status in HiConsentStatus.values) {
        final inner = RecordingAnalytics();
        final consent = HiConsent(initial: status);
        await HiConsentGatedAnalytics(inner, consent: consent).reset();
        expect(inner.calls, ['reset'], reason: '$status');
      }
    });
  });
}
