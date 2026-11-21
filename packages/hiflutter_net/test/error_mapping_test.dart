import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

HiHttpClient clientWith(HiMemoryHandler handler, {HiEnvelope? envelope}) =>
    HiHttpClient(
      transport: HiMemoryTransport(handler),
      baseUrl: Uri.parse('https://api.example.com/'),
      envelope: envelope,
    );

Future<HiError> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on HiError catch (e) {
    return e;
  }
  fail('expected a HiError');
}

void main() {
  group('HTTP status', () {
    final table = <int, (HiErrorKind, bool)>{
      400: (HiErrorKind.server, false),
      401: (HiErrorKind.unauthorized, false),
      403: (HiErrorKind.forbidden, false),
      404: (HiErrorKind.notFound, false),
      408: (HiErrorKind.timeout, true),
      409: (HiErrorKind.server, false),
      429: (HiErrorKind.server, false),
      500: (HiErrorKind.server, true),
      502: (HiErrorKind.server, true),
      503: (HiErrorKind.server, true),
    };
    for (final MapEntry(key: status, value: (kind, retryable))
        in table.entries) {
      test('$status maps to $kind (retryable: $retryable)', () async {
        final error = await failureOf(
          clientWith((_) => HiResponse.text(status, 'oops')).get('x'),
        );

        expect(error.kind, kind);
        expect(error.retryable, retryable);
      });
    }

    test(
      'server errors carry the status and the envelope code and message',
      () async {
        final error = await failureOf(
          clientWith(
            (_) => HiResponse.json(422, {'code': 'E42', 'msg': 'Bad name'}),
            envelope: const HiEnvelope(),
          ).get('x'),
        );

        expect(
          error,
          isA<HiServerError>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', 'E42')
              .having((e) => e.message, 'message', 'Bad name'),
        );
      },
    );

    test('a non-JSON error body still maps by status', () async {
      final error = await failureOf(
        clientWith(
          (_) => HiResponse.text(500, '<html>'),
          envelope: const HiEnvelope(),
        ).get('x'),
      );

      expect(
        error,
        isA<HiServerError>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.code, 'code', isNull),
      );
    });
  });

  group('transport failure', () {
    for (final thrown in <HiError>[
      const HiNetworkError(message: 'offline'),
      const HiTimeoutError(),
      const HiCancelledError(),
    ]) {
      test('${thrown.kind} passes through unchanged', () async {
        final error = await failureOf(clientWith((_) => throw thrown).get('x'));

        expect(error, same(thrown));
      });
    }

    test('a foreign exception becomes an unknown error', () async {
      final error = await failureOf(
        clientWith((_) => throw StateError('boom')).get('x'),
      );

      expect(error, isA<HiUnknownError>());
      expect(error.diagnostics, contains('boom'));
    });
  });

  test('a 2xx body that is not JSON is a decode error', () async {
    final error = await failureOf(
      clientWith((_) => HiResponse.text(200, 'not json')).get('x'),
    );

    expect(error, isA<HiDecodeError>());
  });
}
