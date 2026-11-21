import 'dart:typed_data';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

final class _MemorySink implements HiLogSink {
  final records = <HiLogRecord>[];

  @override
  void write(HiLogRecord record) => records.add(record);
}

void main() {
  test(
    'resolves paths against the base URL and returns the JSON body',
    () async {
      final transport = HiMemoryTransport(
        (request) => HiResponse.json(200, {'id': 7}),
      );
      final client = HiHttpClient(
        transport: transport,
        baseUrl: Uri.parse('https://api.example.com/v1/'),
      );

      final reply = await client.get('users/me', query: {'lang': 'en'});

      expect(reply.data, {'id': 7});
      expect(
        transport.requests.single.url,
        Uri.parse('https://api.example.com/v1/users/me?lang=en'),
      );
      expect(transport.requests.single.method, HiHttpMethod.get);
    },
  );

  test('merges provided default headers under per-request headers', () async {
    final transport = HiMemoryTransport((request) => HiResponse.json(200, {}));
    var token = 'a';
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
      headers: () async => {'authorization': 'Bearer $token', 'x-app': '1'},
    );

    await client.get('a', headers: {'x-app': '2'});
    token = 'b';
    await client.get('b');

    expect(transport.requests[0].headers, {
      'authorization': 'Bearer a',
      'x-app': '2',
    });
    expect(transport.requests[1].headers['authorization'], 'Bearer b');
  });

  test('encodes a map body as JSON with a JSON content type', () async {
    final transport = HiMemoryTransport((request) => HiResponse.json(200, {}));
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
    );

    await client.post('login', body: {'name': 'ada'});

    final request = transport.requests.single;
    expect(request.method, HiHttpMethod.post);
    expect(request.bodyText, '{"name":"ada"}');
    expect(request.headers['content-type'], 'application/json; charset=utf-8');
  });

  test('preserves caller content-type, supports String and Uint8List bodies, '
      'and drops null query values cleanly', () async {
    final transport = HiMemoryTransport((request) => HiResponse.json(200, {}));
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/v1/'),
    );

    await client.post(
      'custom',
      query: {'ignored': null},
      headers: {'Content-Type': 'application/problem+json'},
      body: {'error': 'bad'},
    );
    await client.post('text', body: 'plain');
    final rawBytes = Uint8List.fromList([1, 2, 3]);
    await client.post('bytes', body: rawBytes);

    expect(
      transport.requests[0].url,
      Uri.parse('https://api.example.com/v1/custom'),
    );
    expect(
      transport.requests[0].headers['content-type'],
      'application/problem+json',
    );
    expect(transport.requests[1].bodyText, 'plain');
    expect(transport.requests[1].headers.containsKey('content-type'), isFalse);
    expect(transport.requests[2].body, rawBytes);
    expect(transport.requests[2].headers.containsKey('content-type'), isFalse);
  });

  test('supports put, patch, delete, and head convenience methods', () async {
    final transport = HiMemoryTransport((request) => HiResponse.json(200, {}));
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
    );

    await client.put('items/1', body: {'name': 'a'});
    await client.patch('items/1', body: {'name': 'b'});
    await client.delete('items/1', query: {'force': true});
    await client.head('items/1', headers: {'x-check': '1'});

    expect(transport.requests.map((r) => r.method), [
      HiHttpMethod.put,
      HiHttpMethod.patch,
      HiHttpMethod.delete,
      HiHttpMethod.head,
    ]);
    expect(transport.requests[0].bodyText, '{"name":"a"}');
    expect(transport.requests[1].bodyText, '{"name":"b"}');
    expect(
      transport.requests[2].url,
      Uri.parse('https://api.example.com/items/1?force=true'),
    );
    expect(transport.requests[3].headers['x-check'], '1');
  });

  group('timeouts and cancellation', () {
    test(
      'falls back to defaultTimeout when per-request timeout is omitted',
      () async {
        final transport = HiMemoryTransport((_) => HiResponse.json(200, {}));
        const defaultTimeout = Duration(seconds: 15);
        const overrideTimeout = Duration(seconds: 3);
        final client = HiHttpClient(
          transport: transport,
          baseUrl: Uri.parse('https://api.example.com/'),
          defaultTimeout: defaultTimeout,
        );

        await client.get('a');
        await client.post('b', timeout: overrideTimeout);
        await client.put('c', timeout: overrideTimeout);
        await client.patch('d', timeout: overrideTimeout);
        await client.delete('e', timeout: overrideTimeout);
        await client.head('f', timeout: overrideTimeout);

        expect(transport.requests[0].timeout, defaultTimeout);
        for (var i = 1; i < transport.requests.length; i++) {
          expect(transport.requests[i].timeout, overrideTimeout);
        }
      },
    );

    test('throws HiCancelledError immediately when cancelToken is already '
        'cancelled', () async {
      final transport = HiMemoryTransport((_) => HiResponse.json(200, {}));
      var headersCalled = false;
      final client = HiHttpClient(
        transport: transport,
        baseUrl: Uri.parse('https://api.example.com/'),
        headers: () {
          headersCalled = true;
          return const {};
        },
      );
      final token = HiCancelToken()..cancel();

      await expectLater(
        client.get('items', cancelToken: token),
        throwsA(isA<HiCancelledError>()),
      );
      expect(transport.requests, isEmpty);
      expect(headersCalled, isFalse);
    });

    test(
      'passes cancelToken to the transport when not yet cancelled',
      () async {
        final transport = HiMemoryTransport((_) => HiResponse.json(200, {}));
        final client = HiHttpClient(
          transport: transport,
          baseUrl: Uri.parse('https://api.example.com/'),
        );
        final token = HiCancelToken();

        await client.get('items', cancelToken: token);

        expect(transport.requests.single.cancelToken, same(token));
      },
    );
  });

  group('onUnauthorized callback', () {
    test('fires on HTTP 401 before the error is thrown', () async {
      final events = <String>[];
      final client = HiHttpClient(
        transport: HiMemoryTransport(
          (_) => HiResponse.json(401, {'message': 'Token expired'}),
        ),
        baseUrl: Uri.parse('https://api.example.com/'),
        envelope: const HiEnvelope(),
        onUnauthorized: (error, request) async {
          events.add('callback:${error.message}:${request.url}');
        },
      );

      await expectLater(
        client.get('me'),
        throwsA(
          isA<HiUnauthorizedError>().having(
            (e) => e.message,
            'message',
            'Token expired',
          ),
        ),
      );
      expect(events, ['callback:Token expired:https://api.example.com/me']);
    });

    test('fires on 2xx envelope unauthorizedCodes', () async {
      HiUnauthorizedError? capturedError;
      HiRequest? capturedRequest;
      final client = HiHttpClient(
        transport: HiMemoryTransport(
          (_) => HiResponse.json(200, {'code': 40101, 'msg': 'Re-auth'}),
        ),
        baseUrl: Uri.parse('https://api.example.com/'),
        envelope: const HiEnvelope(unauthorizedCodes: {'40101'}),
        onUnauthorized: (error, request) {
          capturedError = error;
          capturedRequest = request;
        },
      );

      await expectLater(
        client.post('orders'),
        throwsA(isA<HiUnauthorizedError>()),
      );
      expect(capturedError?.message, 'Re-auth');
      expect(capturedRequest?.method, HiHttpMethod.post);
      expect(capturedRequest?.url, Uri.parse('https://api.example.com/orders'));
    });

    test(
      'does not fire for non-unauthorized errors such as 403 or 500',
      () async {
        var called = false;
        final client = HiHttpClient(
          transport: HiMemoryTransport((req) {
            return req.url.path.endsWith('403')
                ? HiResponse.text(403, 'forbidden')
                : HiResponse.text(500, 'error');
          }),
          baseUrl: Uri.parse('https://api.example.com/'),
          onUnauthorized: (_, _) => called = true,
        );

        await expectLater(client.get('403'), throwsA(isA<HiForbiddenError>()));
        await expectLater(client.get('500'), throwsA(isA<HiServerError>()));
        expect(called, isFalse);
      },
    );
  });

  group('logging and redaction', () {
    test('logs request start and response success with module net and '
        'redacts sensitive headers and query parameters', () async {
      final sink = _MemorySink();
      final logger = HiLogger([HiLogRoute(sink, minLevel: HiLogLevel.debug)]);
      final client = HiHttpClient(
        transport: HiMemoryTransport(
          (_) => HiResponse.json(
            200,
            {'ok': true},
            headers: {'set-cookie': 'sid=topsecret'},
          ),
        ),
        baseUrl: Uri.parse('https://api.example.com/'),
        headers: () => {
          'authorization': 'Bearer secret-jwt',
          'cookie': 'session=xyz',
          'x-client': 'hi',
        },
        logger: logger,
      );

      await client.get('feed', query: {'token': 'q-secret', 'page': 2});

      expect(sink.records, hasLength(2));

      final started = sink.records[0];
      expect(started.module, 'net');
      expect(started.level, HiLogLevel.info);
      expect(started.message, contains('GET'));
      expect(started.message, contains('token=[REDACTED]'));
      expect(started.message, isNot(contains('q-secret')));
      expect(started.attributes['method'], 'GET');
      expect(started.attributes['url'], contains('token=[REDACTED]'));
      expect(started.attributes['url'], isNot(contains('q-secret')));
      expect(started.attributes['headers'], {
        'authorization': '[REDACTED]',
        'cookie': '[REDACTED]',
        'x-client': 'hi',
      });

      final succeeded = sink.records[1];
      expect(succeeded.module, 'net');
      expect(succeeded.level, HiLogLevel.info);
      expect(succeeded.attributes['status'], 200);
      expect(succeeded.attributes['url'], isNot(contains('q-secret')));
      expect(succeeded.attributes['headers'], {
        'content-type': 'application/json; charset=utf-8',
        'set-cookie': '[REDACTED]',
      });
    });

    test('logs failure with module net and redacts sensitive data', () async {
      final sink = _MemorySink();
      final logger = HiLogger([HiLogRoute(sink)]);
      final client = HiHttpClient(
        transport: HiMemoryTransport(
          (_) => HiResponse.text(502, 'bad gateway'),
        ),
        baseUrl: Uri.parse('https://api.example.com/'),
        headers: () => {'authorization': 'Bearer secret-token'},
        logger: logger,
      );

      await expectLater(
        client.get('me', query: {'access_token': 'url-secret'}),
        throwsA(isA<HiServerError>()),
      );

      expect(sink.records, hasLength(2));
      final failed = sink.records[1];
      expect(failed.module, 'net');
      expect(failed.level, HiLogLevel.error);
      expect(failed.message, isNot(contains('url-secret')));
      expect(failed.attributes['method'], 'GET');
      expect(failed.attributes['url'], contains('access_token=[REDACTED]'));
      expect(failed.attributes['headers'], {'authorization': '[REDACTED]'});
      expect(failed.attributes['status'], 502);
      expect(failed.error, contains('HiServerError'));
    });

    test('logs failure status 200 when envelope unauthorizedCodes triggers '
        'onUnauthorized', () async {
      final sink = _MemorySink();
      final events = <String>[];
      final logger = HiLogger([HiLogRoute(sink)]);
      final client = HiHttpClient(
        transport: HiMemoryTransport(
          (_) => HiResponse.json(200, {'code': 40101, 'message': 'Expired'}),
        ),
        baseUrl: Uri.parse('https://api.example.com/'),
        envelope: const HiEnvelope(unauthorizedCodes: {'40101'}),
        onUnauthorized: (error, request) {
          events.add('onUnauthorized:${error.message}');
        },
        logger: logger,
      );

      await expectLater(
        client.get('profile'),
        throwsA(isA<HiUnauthorizedError>()),
      );

      expect(events, ['onUnauthorized:Expired']);
      expect(sink.records, hasLength(2));
      expect(sink.records[1].level, HiLogLevel.error);
      expect(sink.records[1].attributes['status'], 200);
      expect(sink.records[1].attributes['errorKind'], 'unauthorized');
    });
  });

  test('close delegates to transport close', () async {
    final transport = _ClosableMemoryTransport();
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
    );

    await client.close();

    expect(transport.closed, isTrue);
  });
}

final class _ClosableMemoryTransport implements HiTransport {
  bool closed = false;

  @override
  Future<HiResponse> send(HiRequest request) async => HiResponse.json(200, {});

  @override
  Future<void> close() async {
    closed = true;
  }
}
