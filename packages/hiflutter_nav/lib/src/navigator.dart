import 'package:flutter/widgets.dart';

import 'route.dart';

/// Builds the page widget of a [HiRoute] from its decoded arguments.
typedef HiPageBuilder<P> = Widget Function(BuildContext context, P args);

/// Binds a [route] to the widget that renders it.
///
/// Router adapters receive a list of pages next to the [HiRouteTable] they
/// generate their configuration from. Create pages with [HiRoutePage.page]
/// (`user.page((context, id) => UserPage(id: id))`) so the builder's
/// argument keeps the route's type inside a `List<HiPage<Object?>>`.
final class HiPage<P> {
  /// Renders [route] with `builder`.
  HiPage(this.route, this._builder);

  /// The route this page renders.
  final HiRoute<P> route;

  final HiPageBuilder<P> _builder;

  /// Builds the page for [args].
  Widget build(BuildContext context, P args) => _builder(context, args);
}

/// Creates the [HiPage] of a route with its argument type preserved.
extension HiRoutePage<P> on HiRoute<P> {
  /// The page rendering this route with [builder].
  HiPage<P> page(HiPageBuilder<P> builder) => HiPage(this, builder);
}

/// Router-agnostic navigation, driven by typed routes.
///
/// Implementations (for example `hiflutter_nav_go_router`) translate these
/// calls into their router; no router type appears here, so app code can
/// depend on this interface alone and be tested with a fake.
abstract interface class HiNavigator {
  /// Pushes [route] with [args] on top of the current page.
  ///
  /// Completes with the result passed to [pop], or `null`.
  Future<R?> push<P, R extends Object?>(HiRoute<P> route, P args);

  /// Replaces the current page with [route] opened with [args].
  ///
  /// Completes with the result passed to [pop], or `null`.
  Future<R?> replace<P, R extends Object?>(HiRoute<P> route, P args);

  /// Removes the current page, completing its [push] with [result].
  ///
  /// Throws a [StateError] when there is nothing to pop; check [canPop].
  void pop<R extends Object?>([R? result]);

  /// Whether [pop] would remove a page.
  bool canPop();

  /// Replaces the whole page stack with the one for [route] opened with
  /// [args].
  void go<P>(HiRoute<P> route, P args);
}
