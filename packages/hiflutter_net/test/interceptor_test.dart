import 'dart:async';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

final class _RecordingInterceptor extends HiHttpInterceptor {
  _RecordingInterceptor(
    this.name,
    this.events, {
    this.headerValue,
    this.transformResponse,
    this.transformError,
  });

  final String name;
  final List<String> events;
  final String? headerValue;
  final HiResponse Function(HiResponse)? transformResponse;
  final HiError Function(HiError)? transformError;

  @override
  FutureOr<HiRequest> onRequest(HiRequest request) {
    events.add('$name:onRequest');
    if (headerValue == null) return request;
    return request.copyWith(
      headers: {...request.headers, 'x-$name': headerValue!},
    );
  }

  @override
  FutureOr<HiResponse> onResponse(HiRequest request, HiResponse response) {
    events.add('$name:onResponse');
    return transformResponse?.call(response) ?? response;
  }

  @override
  FutureOr<HiError> onError(HiRequest request, HiError error) {
    events.add('$name:onError');
    return transformError?.call(error) ?? error;
  }
}

final class _PassthroughInterceptor extends HiHttpInterceptor {}

void main() {
  test(
    'default HiHttpInterceptor methods pass inputs through unchanged',
    () async {
      final transport = HiMemoryTransport(
        (_) => HiResponse.json(200, {'ok': true}),
      );
      final client = HiHttpClient(
        transport: transport,
        baseUrl: Uri.parse('https://api.example.com/'),
        interceptors: [_PassthroughInterceptor()],
      );

      final reply = await client.get('ping');

      expect(reply.data, {'ok': true});
    },
  );

  test('runs onRequest and onResponse in interceptor list order', () async {
    final events = <String>[];
    final transport = HiMemoryTransport((request) {
      events.add('transport');
      expect(request.headers['x-first'], '1');
      expect(request.headers['x-second'], '2');
      return HiResponse.json(200, {'count': 1});
    });

    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
      interceptors: [
        _RecordingInterceptor('first', events, headerValue: '1'),
        _RecordingInterceptor(
          'second',
          events,
          headerValue: '2',
          transformResponse: (res) => HiResponse.json(res.statusCode, {
            'count': 99,
          }, headers: res.headers),
        ),
      ],
    );

    final reply = await client.get('items');

    expect(reply.data, {'count': 99});
    expect(events, [
      'first:onRequest',
      'second:onRequest',
      'transport',
      'first:onResponse',
      'second:onResponse',
    ]);
  });

  test('calls onUnauthorized before onError interceptors on 401', () async {
    final events = <String>[];
    final client = HiHttpClient(
      transport: HiMemoryTransport((_) => HiResponse.text(401, 'unauthorized')),
      baseUrl: Uri.parse('https://api.example.com/'),
      interceptors: [
        _RecordingInterceptor(
          'first',
          events,
          headerValue: 'modified',
          transformError: (err) =>
              HiForbiddenError(message: 'rewritten:${err.kind.name}'),
        ),
        _RecordingInterceptor('second', events),
      ],
      onUnauthorized: (error, request) async {
        events.add('onUnauthorized:${request.headers['x-first']}');
      },
    );

    await expectLater(
      client.get('me'),
      throwsA(
        isA<HiForbiddenError>().having(
          (e) => e.message,
          'message',
          'rewritten:unauthorized',
        ),
      ),
    );
    expect(events, [
      'first:onRequest',
      'second:onRequest',
      'first:onResponse',
      'second:onResponse',
      'onUnauthorized:modified',
      'first:onError',
      'second:onError',
    ]);
  });

  test('runs onError interceptors when transport or decoder throws', () async {
    final events = <String>[];
    final client = HiHttpClient(
      transport: HiMemoryTransport((_) => throw const HiNetworkError()),
      baseUrl: Uri.parse('https://api.example.com/'),
      interceptors: [
        _RecordingInterceptor(
          'a',
          events,
          transformError: (_) => const HiTimeoutError(message: 'mapped'),
        ),
        _RecordingInterceptor('b', events),
      ],
    );

    await expectLater(
      client.get('fail'),
      throwsA(
        isA<HiTimeoutError>().having((e) => e.message, 'message', 'mapped'),
      ),
    );
    expect(events, ['a:onRequest', 'b:onRequest', 'a:onError', 'b:onError']);
  });

  test('cancelling during async onRequest stops before transport', () async {
    final token = HiCancelToken();
    final transport = HiMemoryTransport((_) => HiResponse.json(200, {}));
    final client = HiHttpClient(
      transport: transport,
      baseUrl: Uri.parse('https://api.example.com/'),
      interceptors: [_CancellingInterceptor(token)],
    );

    await expectLater(
      client.get('items', cancelToken: token),
      throwsA(isA<HiCancelledError>()),
    );
    expect(transport.requests, isEmpty);
  });
}

final class _CancellingInterceptor extends HiHttpInterceptor {
  _CancellingInterceptor(this.token);

  final HiCancelToken token;

  @override
  Future<HiRequest> onRequest(HiRequest request) async {
    token.cancel();
    return request;
  }
}
