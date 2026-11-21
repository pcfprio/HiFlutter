import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';

/// [HiNavigator] backed by go_router, configured from a [HiRouteTable].
///
/// Every route of the table becomes a top-level go_router route rendered
/// by its [HiPage]. Locations that match no route, or whose arguments fail
/// to decode, are redirected to the fallback location. Incoming deep links
/// with a scheme and host (for example `https://example.com/users/1`) are
/// routed only when the table's [HiRouteTable.deepLinks] guard allows
/// them; untrusted links land on the fallback location instead.
///
/// Hand [routerConfig] to the app's `.router` constructor (for example
/// `WidgetsApp.router`) and use the navigator itself
/// everywhere else; no go_router type is needed by app code.
class HiGoRouterNavigator implements HiNavigator {
  /// Creates a navigator for [table], rendering each route with the page in
  /// [pages] that has the same route.
  ///
  /// The app starts at [initialLocation]. Unknown locations and rejected
  /// deep links go to [fallbackLocation], which defaults to
  /// [initialLocation]. Throws an [ArgumentError] when a route has no page,
  /// a page's route is not in the table, or either location matches no
  /// route.
  HiGoRouterNavigator({
    required this.table,
    required List<HiPage<Object?>> pages,
    required String initialLocation,
    String? fallbackLocation,
  }) : fallbackLocation = fallbackLocation ?? initialLocation {
    _requireRoutable(initialLocation, 'initialLocation');
    _requireRoutable(this.fallbackLocation, 'fallbackLocation');
    _router = GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) => _redirect(state.uri),
      routes: [
        for (final route in table.routes)
          _goRoute(route, _pageFor(route, pages)),
      ],
    );
    for (final page in pages) {
      if (!table.routes.contains(page.route)) {
        throw ArgumentError.value(
          page.route,
          'pages',
          'route is not in the table',
        );
      }
    }
  }

  /// The route table this navigator was generated from.
  final HiRouteTable table;

  /// Where unknown locations and rejected deep links are sent.
  final String fallbackLocation;

  late final GoRouter _router;

  /// The router configuration to pass to the app's `.router` constructor.
  RouterConfig<Object> get routerConfig => _router;

  @override
  Future<R?> push<P, R extends Object?>(HiRoute<P> route, P args) =>
      _router.push<R>(route.location(args));

  @override
  Future<R?> replace<P, R extends Object?>(HiRoute<P> route, P args) =>
      _router.pushReplacement<R>(route.location(args));

  @override
  void pop<R extends Object?>([R? result]) {
    if (!canPop()) throw StateError('There is no page to pop');
    _router.pop<R>(result);
  }

  @override
  bool canPop() => _router.canPop();

  @override
  void go<P>(HiRoute<P> route, P args) => _router.go(route.location(args));

  /// Releases the underlying router.
  void dispose() => _router.dispose();

  String? _redirect(Uri uri) {
    if (uri.hasScheme || uri.host.isNotEmpty) {
      return table.matchDeepLink(uri)?.location ?? fallbackLocation;
    }
    return table.match(uri) == null ? fallbackLocation : null;
  }

  GoRoute _goRoute(HiRoute<Object?> route, HiPage<Object?> page) => GoRoute(
    path: route.path,
    builder: (context, state) {
      // The redirect guarantees that the location matches this route.
      final match = route.match(state.uri)!;
      return page.build(context, match.args);
    },
  );

  HiPage<Object?> _pageFor(
    HiRoute<Object?> route,
    List<HiPage<Object?>> pages,
  ) {
    for (final page in pages) {
      if (identical(page.route, route)) return page;
    }
    throw ArgumentError.value(route, 'pages', 'route has no page');
  }

  void _requireRoutable(String location, String name) {
    if (table.match(Uri.parse(location)) == null) {
      throw ArgumentError.value(location, name, 'matches no route');
    }
  }
}
