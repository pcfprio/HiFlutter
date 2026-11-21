import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';

/// [HiTransport] backed by `dio`.
///
/// Wraps a `Dio` instance internally without exposing any `dio` types in its
/// public API. Every HTTP status code is returned as a [HiResponse], and all
/// `DioException`s are mapped to [HiError] subtypes.
final class HiDioTransport implements HiTransport {
  /// Creates a transport with optional default connection, send and receive
  /// timeouts.
  HiDioTransport({
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) : _dio = _createDio(
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
       );

  HiDioTransport._(this._dio);

  final Dio _dio;

  static Dio _createDio({
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      ),
    )..interceptors.removeImplyContentTypeInterceptor();
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }
    return dio;
  }

  @override
  Future<HiResponse> send(HiRequest request) async {
    final cancelToken = request.cancelToken;
    if (cancelToken?.isCancelled ?? false) {
      throw const HiCancelledError(message: 'Request cancelled.');
    }

    final dioCancelToken = cancelToken == null ? null : CancelToken();
    if (cancelToken == null || dioCancelToken == null) {
      try {
        return await _performRequest(request, null);
      } catch (e, s) {
        throw _mapError(e, s);
      }
    }

    final completer = Completer<HiResponse>();
    unawaited(
      cancelToken.whenCancelled.then((_) {
        if (!dioCancelToken.isCancelled) {
          dioCancelToken.cancel();
        }
        if (!completer.isCompleted) {
          completer.completeError(
            const HiCancelledError(message: 'Request cancelled.'),
          );
        }
      }),
    );
    unawaited(
      _performRequest(request, dioCancelToken).then(
        (response) {
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        },
        onError: (Object e, StackTrace s) {
          if (!completer.isCompleted) {
            completer.completeError(_mapError(e, s), s);
          }
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<void> close() async => _dio.close();

  Future<HiResponse> _performRequest(
    HiRequest request,
    CancelToken? cancelToken,
  ) async {
    final body = request.body;
    final data = body == null
        ? null
        : body is Uint8List
        ? body
        : Uint8List.fromList(body);

    final dioResponse = await _dio.requestUri<List<int>>(
      request.url,
      data: data,
      cancelToken: cancelToken,
      options: Options(
        method: request.method.wireName,
        headers: request.headers.isEmpty
            ? null
            : Map<String, Object?>.from(request.headers),
        connectTimeout: request.timeout,
        sendTimeout: request.timeout,
        receiveTimeout: request.timeout,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );

    return HiResponse(
      statusCode: dioResponse.statusCode ?? 0,
      headers: {
        for (final MapEntry(:key, value: values)
            in dioResponse.headers.map.entries)
          key: values.join(', '),
      },
      body: dioResponse.data ?? const [],
    );
  }

  static HiError _mapError(Object error, StackTrace stackTrace) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => HiTimeoutError(
          message: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
        DioExceptionType.cancel => HiCancelledError(
          message: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
        DioExceptionType.connectionError ||
        DioExceptionType.badCertificate => HiNetworkError(
          message: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
        DioExceptionType.badResponse ||
        DioExceptionType.unknown ||
        DioExceptionType.transformTimeout => switch (error.error) {
          final HiError hiError => hiError,
          final Object cause when error.type == DioExceptionType.unknown =>
            HiError.from(cause, stackTrace),
          _ => HiError.from(error, stackTrace),
        },
      };
    }
    return HiError.from(error, stackTrace);
  }
}

/// Creates a [HiDioTransport] using a custom `dio` [HttpClientAdapter].
///
/// Exposed exclusively from `package:hiflutter_net_dio/testing.dart` for
/// package tests so that `package:hiflutter_net_dio/hiflutter_net_dio.dart`
/// never leaks `dio` types.
HiDioTransport hiDioTransportWithAdapter(
  HttpClientAdapter adapter, {
  Duration? connectTimeout,
  Duration? sendTimeout,
  Duration? receiveTimeout,
}) => HiDioTransport._(
  HiDioTransport._createDio(
    connectTimeout: connectTimeout,
    sendTimeout: sendTimeout,
    receiveTimeout: receiveTimeout,
    adapter: adapter,
  ),
);
