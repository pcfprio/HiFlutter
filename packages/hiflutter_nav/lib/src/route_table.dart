import 'deep_link.dart';
import 'route.dart';

/// The URL route table of an app: matches URLs to [HiRoute]s and decodes
/// their arguments.
///
/// Routes are tried in order, so list specific patterns (`/users/me`)
/// before general ones (`/users/:id`).
final class HiRouteTable {
  /// Creates a table of [routes].
  ///
  /// Incoming deep links are routed only when [deepLinks] allows them;
  /// without a guard every deep link is rejected. Throws an [ArgumentError]
  /// when two routes share a path pattern.
  HiRouteTable(List<HiRoute<Object?>> routes, {this.deepLinks})
    : routes = List.unmodifiable(routes) {
    final seen = <String>{};
    for (final route in routes) {
      if (!seen.add(_shape(route.path))) {
        throw ArgumentError.value(
          route.path,
          'routes',
          'duplicate path pattern',
        );
      }
    }
  }

  /// The routes, in matching order.
  final List<HiRoute<Object?>> routes;

  /// Allow-list for incoming deep links, or `null` to reject them all.
  final HiDeepLinkGuard? deepLinks;

  /// Matches the path and query of [uri] to the first fitting route.
  ///
  /// Use this for locations produced inside the app. Returns `null` when no
  /// route fits.
  HiRouteMatch<Object?>? match(Uri uri) {
    for (final route in routes) {
      final match = route.match(uri);
      if (match != null) return match;
    }
    return null;
  }

  /// Matches an incoming deep link, such as `https://example.com/users/1`.
  ///
  /// Returns `null` unless [deepLinks] allows [uri] and a route fits its
  /// path and query.
  HiRouteMatch<Object?>? matchDeepLink(Uri uri) {
    final guard = deepLinks;
    if (guard == null || !guard.allows(uri)) return null;
    return match(uri);
  }

  /// [path] with parameter names erased, so `/a/:x` and `/a/:y` collide.
  static String _shape(String path) => [
    for (final segment in path.split('/'))
      if (segment.isNotEmpty) segment.startsWith(':') ? ':' : segment,
  ].join('/');
}
