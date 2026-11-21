import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_dio/hiflutter_net_dio.dart';
import 'package:hiflutter_net_dio/testing.dart';
import 'package:test/test.dart';

typedef _FetchHandler = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
  Future<void>? cancelFuture,
);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _FetchHandler _handler;
  RequestOptions? lastOptions;
  List<int>? lastBodyBytes;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (requestStream != null) {
      final collected = <int>[];
      await for (final chunk in requestStream) {
        collected.addAll(chunk);
      }
      lastBodyBytes = collected;
    } else {
      lastBodyBytes = null;
    }
    return _handler(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

Future<HiError> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on HiError catch (e) {
    return e;
  }
  fail('expected a HiError');
}

void main() {
  group('request and response mapping', () {
    test(
      'forwards method, URL, headers and raw body bytes unchanged',
      () async {
        final adapter = _FakeAdapter((options, _, _) async {
          return ResponseBody.fromString(
            '{"id":42}',
            200,
            headers: {
              'Content-Type': ['application/json; charset=utf-8'],
              'Set-Cookie': ['a=1', 'b=2'],
            },
          );
        });
        final transport = hiDioTransportWithAdapter(adapter);
        final body = utf8.encode('{"name":"ada"}');

        final response = await transport.send(
          HiRequest(
            method: HiHttpMethod.post,
            url: Uri.parse('https://api.example.com/v1/users?page=1'),
            headers: {
              'authorization': 'Bearer tok',
              'content-type': 'application/json; charset=utf-8',
            },
            body: body,
          ),
        );

        final options = adapter.lastOptions!;
        expect(options.method, 'POST');
        expect(
          options.uri,
          Uri.parse('https://api.example.com/v1/users?page=1'),
        );
        expect(options.headers['authorization'], 'Bearer tok');
        expect(
          options.headers['content-type'],
          'application/json; charset=utf-8',
        );
        expect(adapter.lastBodyBytes, body);

        expect(response.statusCode, 200);
        expect(response.bodyText, '{"id":42}');
        expect(
          response.headers['content-type'],
          'application/json; charset=utf-8',
        );
        expect(response.headers['set-cookie'], 'a=1, b=2');
      },
    );

    test('returns 4xx and 5xx responses without throwing', () async {
      for (final status in [400, 401, 404, 500, 503]) {
        final adapter = _FakeAdapter(
          (_, _, _) async => ResponseBody.fromString(
            '{"error":"fail"}',
            status,
            headers: {
              'content-type': ['application/json'],
            },
          ),
        );
        final transport = hiDioTransportWithAdapter(adapter);

        final response = await transport.send(
          HiRequest(
            method: HiHttpMethod.get,
            url: Uri.parse('https://api.example.com/fail'),
          ),
        );

        expect(response.statusCode, status);
        expect(response.bodyText, '{"error":"fail"}');
      }
    });

    test('handles empty response body such as 204 or HEAD', () async {
      final adapter = _FakeAdapter(
        (_, _, _) async => ResponseBody.fromBytes(const [], 204),
      );
      final transport = hiDioTransportWithAdapter(adapter);

      final response = await transport.send(
        HiRequest(
          method: HiHttpMethod.head,
          url: Uri.parse('https://api.example.com/ping'),
        ),
      );

      expect(response.statusCode, 204);
      expect(response.body, isEmpty);
    });
  });

  group('timeouts', () {
    test(
      'uses transport default timeouts when request timeout is null',
      () async {
        final adapter = _FakeAdapter(
          (_, _, _) async => ResponseBody.fromString('{}', 200),
        );
        const connect = Duration(seconds: 5);
        const send = Duration(seconds: 6);
        const receive = Duration(seconds: 7);
        final transport = hiDioTransportWithAdapter(
          adapter,
          connectTimeout: connect,
          sendTimeout: send,
          receiveTimeout: receive,
        );

        await transport.send(
          HiRequest(
            method: HiHttpMethod.get,
            url: Uri.parse('https://api.example.com/t'),
          ),
        );

        final options = adapter.lastOptions!;
        expect(options.connectTimeout, connect);
        expect(options.sendTimeout, send);
        expect(options.receiveTimeout, receive);
      },
    );

    test(
      'overrides transport timeouts when HiRequest.timeout is set',
      () async {
        final adapter = _FakeAdapter(
          (_, _, _) async => ResponseBody.fromString('{}', 200),
        );
        const requestTimeout = Duration(seconds: 2);
        final transport = hiDioTransportWithAdapter(
          adapter,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        );

        await transport.send(
          HiRequest(
            method: HiHttpMethod.get,
            url: Uri.parse('https://api.example.com/t'),
            timeout: requestTimeout,
          ),
        );

        final options = adapter.lastOptions!;
        expect(options.connectTimeout, requestTimeout);
        expect(options.sendTimeout, requestTimeout);
        expect(options.receiveTimeout, requestTimeout);
      },
    );
  });

  group('cancellation', () {
    test(
      'throws HiCancelledError immediately when token is already cancelled',
      () async {
        var called = false;
        final adapter = _FakeAdapter((_, _, _) async {
          called = true;
          return ResponseBody.fromString('{}', 200);
        });
        final transport = hiDioTransportWithAdapter(adapter);
        final token = HiCancelToken()..cancel();

        final error = await _failureOf(
          transport.send(
            HiRequest(
              method: HiHttpMethod.get,
              url: Uri.parse('https://api.example.com/c'),
              cancelToken: token,
            ),
          ),
        );

        expect(error, isA<HiCancelledError>());
        expect(called, isFalse);
      },
    );

    test('propagates HiCancelToken cancellation to Dio cancelFuture', () async {
      final adapterStarted = Completer<void>();
      var cancelFutureTriggered = false;
      final neverCompletes = Completer<ResponseBody>();

      final adapter = _FakeAdapter((options, _, cancelFuture) {
        unawaited(
          cancelFuture?.then((_) {
            cancelFutureTriggered = true;
          }),
        );
        adapterStarted.complete();
        return neverCompletes.future;
      });
      final transport = hiDioTransportWithAdapter(adapter);
      final token = HiCancelToken();

      final pending = transport.send(
        HiRequest(
          method: HiHttpMethod.get,
          url: Uri.parse('https://api.example.com/c'),
          cancelToken: token,
        ),
      );
      await adapterStarted.future;
      token.cancel();

      final error = await _failureOf(pending);
      expect(error, isA<HiCancelledError>());
      expect(cancelFutureTriggered, isTrue);
    });

    test(
      'handles adapter throwing DioException.requestCancelled cleanly',
      () async {
        final adapter = _FakeAdapter((options, _, cancelFuture) async {
          await cancelFuture;
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled by caller',
          );
        });
        final transport = hiDioTransportWithAdapter(adapter);
        final token = HiCancelToken();

        final pending = transport.send(
          HiRequest(
            method: HiHttpMethod.get,
            url: Uri.parse('https://api.example.com/c'),
            cancelToken: token,
          ),
        );
        token.cancel();

        final error = await _failureOf(pending);
        expect(error, isA<HiCancelledError>());
      },
    );
  });

  group('DioException mapping', () {
    final mappingCases = <(DioExceptionType, HiErrorKind)>[
      (DioExceptionType.connectionTimeout, HiErrorKind.timeout),
      (DioExceptionType.sendTimeout, HiErrorKind.timeout),
      (DioExceptionType.receiveTimeout, HiErrorKind.timeout),
      (DioExceptionType.cancel, HiErrorKind.cancelled),
      (DioExceptionType.connectionError, HiErrorKind.network),
      (DioExceptionType.badCertificate, HiErrorKind.network),
      (DioExceptionType.badResponse, HiErrorKind.unknown),
      (DioExceptionType.unknown, HiErrorKind.unknown),
      (DioExceptionType.transformTimeout, HiErrorKind.unknown),
    ];

    for (final (dioType, expectedKind) in mappingCases) {
      test('$dioType maps to $expectedKind', () async {
        final adapter = _FakeAdapter((options, _, _) async {
          throw DioException(
            requestOptions: options,
            type: dioType,
            message: 'simulated $dioType',
          );
        });
        final transport = hiDioTransportWithAdapter(adapter);

        final error = await _failureOf(
          transport.send(
            HiRequest(
              method: HiHttpMethod.get,
              url: Uri.parse('https://api.example.com/err'),
            ),
          ),
        );

        expect(error.kind, expectedKind);
        expect(error.diagnostics, contains('DioException'));
      });
    }

    test('maps non-DioException errors via HiError.from', () async {
      final adapter = _FakeAdapter(
        (_, _, _) async => throw const FormatException('bad wire data'),
      );
      final transport = hiDioTransportWithAdapter(adapter);

      final error = await _failureOf(
        transport.send(
          HiRequest(
            method: HiHttpMethod.get,
            url: Uri.parse('https://api.example.com/err'),
          ),
        ),
      );

      expect(error, isA<HiUnknownError>());
      expect(error.diagnostics, contains('bad wire data'));
    });
  });

  test('close closes the underlying Dio adapter', () async {
    final adapter = _FakeAdapter(
      (_, _, _) async => ResponseBody.fromString('{}', 200),
    );
    final transport = hiDioTransportWithAdapter(adapter);

    await transport.close();

    expect(adapter.closed, isTrue);
  });

  test('works end-to-end with HiHttpClient', () async {
    final adapter = _FakeAdapter((options, _, _) async {
      expect(options.method, 'POST');
      return ResponseBody.fromString(
        '{"code":0,"message":"ok","data":{"id":9}}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    });
    final client = HiHttpClient(
      transport: hiDioTransportWithAdapter(adapter),
      baseUrl: Uri.parse('https://api.example.com/v1/'),
      envelope: const HiEnvelope(),
    );

    final reply = await client.post('items', body: {'title': 'hi'});

    expect(reply.data, {'id': 9});
    await client.close();
  });

  test(
    'public constructor creates a HiDioTransport without dio types',
    () async {
      final transport = HiDioTransport(
        connectTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      );
      await transport.close();
    },
  );
}
