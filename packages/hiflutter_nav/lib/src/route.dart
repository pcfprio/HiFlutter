import 'params.dart';

/// Encodes typed route arguments into string-convertible parameters.
///
/// Keys named in the path pattern fill the path; every other non-null entry
/// goes into the query string. Values are converted with `toString()`.
typedef HiParamsEncoder<P> = Map<String, Object?> Function(P args);

/// Decodes typed route arguments from the parameters of a matched URL.
///
/// Throw a [FormatException] (for example through
/// [HiRouteParams.requireInt]) when the parameters are missing or invalid;
/// the URL then does not match the route.
typedef HiParamsDecoder<P> = P Function(HiRouteParams params);

/// A strongly typed route: a path pattern plus the codec of its arguments.
///
/// The pattern is an absolute path whose segments are either literals or
/// `:name` parameters, for example `/users/:id`. Navigate with typed
/// arguments instead of hand-written path strings:
///
/// ```dart
/// final user = HiRoute<int>(
///   '/users/:id',
///   encode: (id) => {'id': id},
///   decode: (params) => params.requireInt('id'),
/// );
/// user.location(42); // '/users/42'
/// ```
final class HiRoute<P> {
  /// Creates a route for [path] whose arguments are converted by `encode`
  /// and `decode`.
  ///
  /// Throws an [ArgumentError] when [path] is not an absolute path pattern.
  HiRoute(this.path, {required this._encode, required this._decode, this.name})
    : _segments = _parse(path);

  /// Pattern of this route, for example `/users/:id`.
  final String path;

  /// Optional human-readable name, used for diagnostics only.
  final String? name;

  final HiParamsEncoder<P> _encode;
  final HiParamsDecoder<P> _decode;
  final List<String> _segments;

  /// Builds the location (path plus query) that opens this route with
  /// [args].
  ///
  /// Throws an [ArgumentError] when a path parameter is missing or empty.
  String location(P args) {
    final values = {
      for (final MapEntry(:key, :value) in _encode(args).entries)
        if (value != null) key: value.toString(),
    };
    final segments = [
      for (final segment in _segments)
        if (_isParam(segment))
          Uri.encodeComponent(_take(values, segment.substring(1)))
        else
          segment,
    ];
    final query = values.isEmpty
        ? ''
        : '?${Uri(queryParameters: values).query}';
    return '/${segments.join('/')}$query';
  }

  /// Matches [uri] against this route and decodes its arguments.
  ///
  /// Only the path and query of [uri] are considered; a trailing slash is
  /// ignored. Returns `null` when the path does not fit the pattern or the
  /// decoder throws a [FormatException].
  HiRouteMatch<P>? match(Uri uri) {
    final actual = [
      for (final segment in uri.path.split('/'))
        if (segment.isNotEmpty) segment,
    ];
    if (actual.length != _segments.length) return null;
    final pathValues = <String, String>{};
    for (final (index, segment) in _segments.indexed) {
      final String value;
      try {
        value = Uri.decodeComponent(actual[index]);
      } on ArgumentError {
        return null;
      }
      if (_isParam(segment)) {
        pathValues[segment.substring(1)] = value;
      } else if (segment != value) {
        return null;
      }
    }
    final P args;
    try {
      args = _decode(HiRouteParams({...uri.queryParameters, ...pathValues}));
    } on FormatException {
      return null;
    }
    return HiRouteMatch._(this, args);
  }

  String _take(Map<String, String> values, String key) {
    final value = values.remove(key);
    if (value == null || value.isEmpty) {
      throw ArgumentError('Missing path parameter "$key" for route $path');
    }
    return value;
  }

  static bool _isParam(String segment) => segment.startsWith(':');

  static List<String> _parse(String path) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', 'must start with "/"');
    }
    return [
      for (final segment in path.split('/'))
        if (segment.isNotEmpty) segment,
    ];
  }

  @override
  String toString() => 'HiRoute(${name ?? path})';
}

/// A [route] matched from a URL, together with its decoded [args].
final class HiRouteMatch<P> {
  const HiRouteMatch._(this.route, this.args);

  /// The matched route.
  final HiRoute<P> route;

  /// The decoded arguments.
  final P args;

  /// The canonical location of this match, as built by [HiRoute.location].
  String get location => route.location(args);

  @override
  String toString() => 'HiRouteMatch($route, $args)';
}
