import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

final class MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

/// Tries to alter every record it receives and remembers each failure.
final class TamperingSink implements HiLogSink {
  final failures = <Object>[];

  @override
  void write(HiLogRecord record) {
    final attempts = <void Function()>[
      () => record.attributes['injected'] = 'x',
      () => (record.attributes['tags']! as List<Object?>).add('x'),
      () => (record.attributes['meta']! as Map<String, Object?>)['k'] = 'x',
    ];
    for (final attempt in attempts) {
      try {
        attempt();
      } catch (e) {
        failures.add(e);
      }
    }
  }
}

final class ThrowingSink implements HiLogSink {
  @override
  void write(HiLogRecord record) => throw StateError('disk full');
}

/// Logs one info record through a route with [redaction] and returns it.
HiLogRecord logOnce({
  String message = 'msg',
  Map<String, Object?> attributes = const {},
  Object? error,
  StackTrace? stackTrace,
  HiRedaction redaction = const HiRedaction.standard(),
}) {
  final sink = MemorySink();
  HiLogger([HiLogRoute(sink, redaction: redaction)]).info(
    () => message,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );
  return sink.records.single;
}

void main() {
  group('default redaction of sensitive patterns', () {
    test('hides Bearer tokens in messages and attribute values', () {
      final record = logOnce(
        message: 'sent header bearer abc.DEF-123_x~+/= to server',
        attributes: {
          'header': 'Bearer abc123',
          'nested': ['Bearer xyz789'],
        },
      );

      expect(record.message, 'sent header bearer [REDACTED] to server');
      expect(record.attributes, {
        'header': 'Bearer [REDACTED]',
        'nested': ['Bearer [REDACTED]'],
      });
    });

    test('hides JWTs wherever they appear', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0MiJ9.dBjftJeZ4CVP-mB92K27uhbUJU1p';
      final record = logOnce(
        message: 'session $jwt restored',
        attributes: {'raw': 'id=$jwt;'},
      );

      expect(record.message, 'session [REDACTED] restored');
      expect(record.attributes, {'raw': 'id=[REDACTED];'});
    });

    test('hides token-like query parameters in URLs', () {
      final record = logOnce(
        message:
            'GET https://api.example.com/v1/feed?page=2&access_token=abc123'
            '&Sign=s1&refreshToken=r2#top',
        attributes: {'url': '/login?password=hunter2&user=ada'},
      );

      expect(
        record.message,
        'GET https://api.example.com/v1/feed?page=2&access_token=[REDACTED]'
        '&Sign=s1&refreshToken=[REDACTED]#top',
      );
      expect(record.attributes, {'url': '/login?password=[REDACTED]&user=ada'});
    });

    test('hides secrets in error text and keeps the stack trace', () {
      final stackTrace = StackTrace.current;
      final record = logOnce(
        error: const FormatException('bad header: Bearer abc123'),
        stackTrace: stackTrace,
      );

      expect(record.error, 'FormatException: bad header: Bearer [REDACTED]');
      expect(record.stackTrace, same(stackTrace));
    });
  });

  group('default redaction of sensitive keys', () {
    for (final key in [
      'password',
      'Password',
      'user_password',
      'token',
      'accessToken',
      'X-Auth-Token',
      'Authorization',
      'cookie',
      'Set-Cookie',
      'client_secret',
      'api_key',
      'apiKey',
    ]) {
      test('hides the value of "$key"', () {
        final record = logOnce(attributes: {key: 'hunter2', 'user': 'ada'});

        expect(record.attributes, {key: '[REDACTED]', 'user': 'ada'});
      });
    }

    test('hides sensitive keys inside nested maps and lists', () {
      final record = logOnce(
        attributes: {
          'request': {
            'headers': {'Authorization': 'abc', 'Accept': 'json'},
            'items': [
              {'token': 'xyz', 'id': 1},
            ],
          },
          'count': 3,
          'ok': true,
          'missing': null,
        },
      );

      expect(record.attributes, {
        'request': {
          'headers': {'Authorization': '[REDACTED]', 'Accept': 'json'},
          'items': [
            {'token': '[REDACTED]', 'id': 1},
          ],
        },
        'count': 3,
        'ok': true,
        'missing': null,
      });
    });
  });

  group('level filtering', () {
    test('the default route drops debug and keeps info and above', () {
      final sink = MemorySink();
      final logger = HiLogger([HiLogRoute(sink)]);

      logger.debug(() => 'dropped');
      logger.info(() => 'kept', module: 'net');
      logger.warning(() => 'warned');
      logger.error(() => 'failed');

      expect(sink.records.map((r) => (r.level, r.message)), [
        (HiLogLevel.info, 'kept'),
        (HiLogLevel.warning, 'warned'),
        (HiLogLevel.error, 'failed'),
      ]);
      expect(sink.records.first.module, 'net');
    });

    test('records carry the time they were logged', () {
      final before = DateTime.now();
      final record = logOnce();
      final after = DateTime.now();

      expect(record.time.isBefore(before), isFalse);
      expect(record.time.isAfter(after), isFalse);
    });

    test('each route applies its own minimum level', () {
      final verbose = MemorySink();
      final quiet = MemorySink();
      final logger = HiLogger([
        HiLogRoute(verbose, minLevel: HiLogLevel.debug),
        HiLogRoute(quiet, minLevel: HiLogLevel.error),
      ]);

      logger.debug(() => 'd');
      logger.warning(() => 'w');
      logger.error(() => 'e');

      expect(verbose.records.map((r) => r.message), ['d', 'w', 'e']);
      expect(quiet.records.map((r) => r.message), ['e']);
    });
  });

  group('per-route redaction', () {
    test('routes redact independently; none must be chosen explicitly', () {
      final redacted = MemorySink();
      final raw = MemorySink();
      HiLogger([
        HiLogRoute(redacted),
        HiLogRoute(raw, redaction: const HiRedaction.none()),
      ]).info(
        () => 'login with Bearer abc123',
        attributes: {'password': 'hunter2'},
        error: 'token=t1',
      );

      expect(redacted.records.single.message, 'login with Bearer [REDACTED]');
      expect(redacted.records.single.attributes, {'password': '[REDACTED]'});
      expect(raw.records.single.message, 'login with Bearer abc123');
      expect(raw.records.single.attributes, {'password': 'hunter2'});
      expect(raw.records.single.error, 'token=t1');
    });

    test('callers can add sensitive keys and patterns', () {
      final record = logOnce(
        message: 'card 4111-1111-1111-1111 charged',
        attributes: {'id_card': '110101', 'pinCode': '0000', 'name': 'ada'},
        redaction: HiRedaction.standard(
          extraKeys: {'idCard', 'PIN'},
          extraPatterns: [RegExp(r'\d{4}(-\d{4}){3}')],
        ),
      );

      expect(record.message, 'card [REDACTED] charged');
      expect(record.attributes, {
        'id_card': '[REDACTED]',
        'pinCode': '[REDACTED]',
        'name': 'ada',
      });
    });
  });

  group('sinks cannot bypass processing', () {
    test('records are read-only at every depth', () {
      final tamperer = TamperingSink();
      final next = MemorySink();
      HiLogger([
        HiLogRoute(tamperer, redaction: const HiRedaction.none()),
        HiLogRoute(next, redaction: const HiRedaction.none()),
      ]).info(
        () => 'msg',
        attributes: {
          'tags': ['a'],
          'meta': {'k': 'v'},
        },
      );

      expect(tamperer.failures, hasLength(3));
      expect(tamperer.failures, everyElement(isA<UnsupportedError>()));
      expect(next.records.single.attributes, {
        'tags': ['a'],
        'meta': {'k': 'v'},
      });
    });

    test('a record does not change when the caller mutates its input', () {
      final sink = MemorySink();
      final attributes = <String, Object?>{
        'tags': ['a'],
      };
      HiLogger([HiLogRoute(sink)]).info(() => 'msg', attributes: attributes);

      attributes['tags'] = ['b'];

      expect(sink.records.single.attributes, {
        'tags': ['a'],
      });
    });

    test('a failing sink does not stop the other routes', () {
      final next = MemorySink();
      final logger = HiLogger([HiLogRoute(ThrowingSink()), HiLogRoute(next)]);

      expect(() => logger.info(() => 'msg'), returnsNormally);
      expect(next.records.single.message, 'msg');
    });
  });

  group('lazy messages', () {
    test('the message closure does not run when every route filters it', () {
      final logger = HiLogger([
        HiLogRoute(MemorySink()),
        HiLogRoute(MemorySink(), minLevel: HiLogLevel.warning),
      ]);
      var calls = 0;

      logger.debug(() {
        calls++;
        return 'expensive';
      });

      expect(calls, 0);
    });

    test('the message closure runs once however many routes accept it', () {
      final first = MemorySink();
      final second = MemorySink();
      final logger = HiLogger([HiLogRoute(first), HiLogRoute(second)]);
      var calls = 0;

      logger.info(() => 'call ${++calls}');

      expect(calls, 1);
      expect(first.records.single.message, 'call 1');
      expect(second.records.single.message, 'call 1');
    });
  });
}
