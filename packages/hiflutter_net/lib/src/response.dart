import 'dart:convert';

/// A raw HTTP response, as returned by a transport.
///
/// Every status code, including 4xx and 5xx, arrives as a response; only
/// failures to exchange at all are thrown by the transport.
final class HiResponse {
  /// Creates a response. Header names are lower-cased.
  HiResponse({
    required this.statusCode,
    Map<String, String> headers = const {},
    List<int> body = const [],
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       }),
       body = List.unmodifiable(body);

  /// Creates a response whose body is [json] encoded as UTF-8 JSON.
  factory HiResponse.json(
    int statusCode,
    Object? json, {
    Map<String, String> headers = const {},
  }) => HiResponse(
    statusCode: statusCode,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    body: utf8.encode(jsonEncode(json)),
  );

  /// Creates a response whose body is [text] encoded as UTF-8.
  factory HiResponse.text(
    int statusCode,
    String text, {
    Map<String, String> headers = const {},
  }) => HiResponse(
    statusCode: statusCode,
    headers: headers,
    body: utf8.encode(text),
  );

  /// The HTTP status code.
  final int statusCode;

  /// Response headers with lower-case names, unmodifiable. Repeated headers
  /// are joined with `, `.
  final Map<String, String> headers;

  /// The raw body bytes, unmodifiable.
  final List<int> body;

  /// [body] decoded as UTF-8, with malformed bytes replaced.
  String get bodyText => utf8.decode(body, allowMalformed: true);

  /// Whether [statusCode] is in the 2xx range.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'HiResponse($statusCode)';
}
