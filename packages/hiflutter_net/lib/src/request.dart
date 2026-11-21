import 'dart:async';
import 'dart:convert';

/// HTTP request method.
enum HiHttpMethod {
  /// `GET`.
  get,

  /// `POST`.
  post,

  /// `PUT`.
  put,

  /// `PATCH`.
  patch,

  /// `DELETE`.
  delete,

  /// `HEAD`.
  head;

  /// The method name as sent on the wire, such as `GET`.
  String get wireName => name.toUpperCase();
}

/// Lets a caller cancel a request that is in flight.
///
/// Pass the same token to one or more requests and call [cancel]; each of
/// them then fails with a `HiCancelledError`. A cancelled token stays
/// cancelled.
final class HiCancelToken {
  final _cancelled = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels every request using this token. Calling it again does nothing.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// A fully resolved HTTP request, as seen by interceptors and transports.
final class HiRequest {
  /// Creates a request.
  ///
  /// Header names are lower-cased. [body] holds the already encoded bytes.
  HiRequest({
    required this.method,
    required this.url,
    Map<String, String> headers = const {},
    this.body,
    this.timeout,
    this.cancelToken,
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       });

  /// The request method.
  final HiHttpMethod method;

  /// The absolute URL, including query parameters.
  final Uri url;

  /// Request headers with lower-case names, unmodifiable.
  final Map<String, String> headers;

  /// The encoded request body, or `null` for none.
  final List<int>? body;

  /// How long the whole exchange may take, or `null` for no limit.
  final Duration? timeout;

  /// Token that cancels this request, if any.
  final HiCancelToken? cancelToken;

  /// [body] decoded as UTF-8 (malformed bytes replaced), or `null`.
  String? get bodyText {
    final bytes = body;
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  /// A copy with the given fields replaced.
  HiRequest copyWith({
    HiHttpMethod? method,
    Uri? url,
    Map<String, String>? headers,
    List<int>? body,
    Duration? timeout,
    HiCancelToken? cancelToken,
  }) => HiRequest(
    method: method ?? this.method,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    timeout: timeout ?? this.timeout,
    cancelToken: cancelToken ?? this.cancelToken,
  );

  @override
  String toString() => 'HiRequest(${method.wireName} $url)';
}
