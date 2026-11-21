import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hiflutter_base/hiflutter_base.dart';

import 'envelope.dart';
import 'interceptor.dart';
import 'json_body.dart';
import 'reply.dart';
import 'request.dart';
import 'response.dart';
import 'transport.dart';

/// Provides headers added to every request, such as an access token.
///
/// Called once per attempt, so a retried request picks up fresh values.
typedef HiHeadersProvider = FutureOr<Map<String, String>> Function();

/// Called when a request fails with a [HiUnauthorizedError] (HTTP 401 or a
/// business code in [HiEnvelope.unauthorizedCodes]), before error interceptors
/// run.
typedef HiUnauthorizedCallback = FutureOr<void> Function(
  HiUnauthorizedError error,
  HiRequest request,
);

/// A transport-agnostic HTTP client for JSON APIs.
final class HiHttpClient {
  /// Creates a client that sends requests through [transport].
  ///
  /// Request paths are resolved against [baseUrl]. [headers] provides
  /// default headers; per-request headers win over them. [defaultTimeout] is
  /// applied when a request does not specify its own timeout. [interceptors]
  /// run in list order around transport calls. [onUnauthorized] runs when HTTP
  /// 401 or an unauthorized envelope business code is encountered. When
  /// [logger] is omitted, logs go through the global [HiLog] entry.
  factory HiHttpClient({
    required HiTransport transport,
    required Uri baseUrl,
    HiHeadersProvider? headers,
    HiEnvelope? envelope,
    Duration? defaultTimeout,
    List<HiHttpInterceptor> interceptors = const [],
    HiUnauthorizedCallback? onUnauthorized,
    HiLogger? logger,
  }) => HiHttpClient._(
    transport,
    baseUrl,
    headers,
    envelope,
    defaultTimeout,
    List<HiHttpInterceptor>.unmodifiable(interceptors),
    onUnauthorized,
    logger,
  );

  HiHttpClient._(
    this._transport,
    this._baseUrl,
    this._headers,
    this._envelope,
    this._defaultTimeout,
    this._interceptors,
    this._onUnauthorized,
    this._logger,
  );

  final HiTransport _transport;
  final Uri _baseUrl;
  final HiHeadersProvider? _headers;
  final HiEnvelope? _envelope;
  final Duration? _defaultTimeout;
  final List<HiHttpInterceptor> _interceptors;
  final HiUnauthorizedCallback? _onUnauthorized;
  final HiLogger? _logger;

  /// Sends a `GET` request; see [request].
  Future<HiReply> get(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.get,
    path,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a `POST` request; see [request].
  Future<HiReply> post(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.post,
    path,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a `PUT` request; see [request].
  Future<HiReply> put(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.put,
    path,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a `PATCH` request; see [request].
  Future<HiReply> patch(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.patch,
    path,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a `DELETE` request; see [request].
  Future<HiReply> delete(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.delete,
    path,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a `HEAD` request; see [request].
  Future<HiReply> head(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => request(
    HiHttpMethod.head,
    path,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
  );

  /// Sends a request and decodes its reply.
  Future<HiReply> request(
    HiHttpMethod method,
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) async {
    final resolvedUrl = _resolveUrl(path, query);
    final effectiveTimeout = timeout ?? _defaultTimeout;
    var currentRequest = HiRequest(
      method: method,
      url: resolvedUrl,
      headers: headers,
      timeout: effectiveTimeout,
      cancelToken: cancelToken,
    );
    HiResponse? rawResponse;

    try {
      _throwIfCancelled(cancelToken);

      final defaults = await _headers?.call() ?? const {};
      _throwIfCancelled(cancelToken);

      final merged = <String, String>{
        for (final MapEntry(:key, :value) in defaults.entries)
          key.toLowerCase(): value,
        for (final MapEntry(:key, :value) in headers.entries)
          key.toLowerCase(): value,
      };
      final bytes = _encodeBody(body, merged);
      currentRequest = HiRequest(
        method: method,
        url: resolvedUrl,
        headers: merged,
        body: bytes,
        timeout: effectiveTimeout,
        cancelToken: cancelToken,
      );

      for (final interceptor in _interceptors) {
        currentRequest = await interceptor.onRequest(currentRequest);
        _throwIfCancelled(currentRequest.cancelToken);
      }

      _log(
        HiLogLevel.info,
        () => '${currentRequest.method.wireName} ${currentRequest.url}',
        attributes: {
          'method': currentRequest.method.wireName,
          'url': '${currentRequest.url}',
          if (currentRequest.headers.isNotEmpty)
            'headers': currentRequest.headers,
        },
      );

      var response = await _transport.send(currentRequest);
      for (final interceptor in _interceptors) {
        response = await interceptor.onResponse(currentRequest, response);
      }
      rawResponse = response;

      final envelope = _envelope;
      if (!response.isSuccessful) {
        throw _statusError(response, envelope);
      }
      final reply = envelope == null
          ? HiReply(response: response, data: decodeJsonBody(response))
          : envelope.decode(response);

      _log(
        HiLogLevel.info,
        () =>
            '${currentRequest.method.wireName} ${currentRequest.url} -> '
            '${response.statusCode}',
        attributes: {
          'method': currentRequest.method.wireName,
          'url': '${currentRequest.url}',
          'status': response.statusCode,
          if (response.headers.isNotEmpty) 'headers': response.headers,
        },
      );
      return reply;
    } catch (e, s) {
      var error = HiError.from(e, s);
      if (error is HiUnauthorizedError) {
        try {
          await _onUnauthorized?.call(error, currentRequest);
        } catch (ue, us) {
          error = HiError.from(ue, us);
        }
      }
      for (final interceptor in _interceptors) {
        try {
          error = await interceptor.onError(currentRequest, error);
        } catch (ie, is_) {
          error = HiError.from(ie, is_);
        }
      }
      _log(
        HiLogLevel.error,
        () =>
            '${currentRequest.method.wireName} ${currentRequest.url} '
            'failed: ${error.kind.name}',
        attributes: {
          'method': currentRequest.method.wireName,
          'url': '${currentRequest.url}',
          if (currentRequest.headers.isNotEmpty)
            'headers': currentRequest.headers,
          if (rawResponse != null) 'status': rawResponse.statusCode,
          'errorKind': error.kind.name,
        },
        error: error.diagnostics,
        stackTrace: error.stackTrace,
      );
      throw error;
    }
  }

  /// Releases the underlying transport's resources.
  Future<void> close() => _transport.close();

  Uri _resolveUrl(String path, Map<String, Object?> query) {
    final url = _baseUrl.resolve(path);
    if (query.isEmpty) return url;
    final parameters = <String, Object?>{
      ...url.queryParametersAll,
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null) key: '$value',
    };
    return parameters.isEmpty ? url : url.replace(queryParameters: parameters);
  }

  void _log(
    HiLogLevel level,
    String Function() message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logger = _logger;
    if (logger != null) {
      logger.log(
        level,
        message,
        module: 'net',
        attributes: attributes,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      HiLog.log(
        level,
        message,
        module: 'net',
        attributes: attributes,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _throwIfCancelled(HiCancelToken? token) {
    if (token?.isCancelled ?? false) {
      throw const HiCancelledError(message: 'Request cancelled.');
    }
  }

  static List<int>? _encodeBody(Object? body, Map<String, String> headers) {
    if (body == null) return null;
    if (body is Uint8List) return body;
    if (body is String) return utf8.encode(body);
    if (body is Map || body is Iterable) {
      headers.putIfAbsent(
        'content-type',
        () => 'application/json; charset=utf-8',
      );
      return utf8.encode(jsonEncode(body));
    }
    throw ArgumentError.value(
      body,
      'body',
      'Unsupported body type ${body.runtimeType}',
    );
  }

  static HiError _statusError(HiResponse response, HiEnvelope? envelope) {
    final (code, message) = envelope?.peek(response) ?? (null, null);
    return switch (response.statusCode) {
      401 => HiUnauthorizedError(message: message),
      403 => HiForbiddenError(message: message),
      404 => HiNotFoundError(message: message),
      408 => HiTimeoutError(message: message),
      final status => HiServerError(
        statusCode: status,
        code: code,
        message: message,
      ),
    };
  }
}
