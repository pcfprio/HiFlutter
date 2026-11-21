/// Navigation contracts of HiFlutter.
///
/// - [HiRoute]: a typed route (path pattern plus argument codec).
/// - [HiRouteTable]: matches URLs to routes; [HiDeepLinkGuard] allow-lists
///   incoming deep links by scheme and host.
/// - [HiNavigator] and [HiPage]: router-agnostic navigation.
/// - [HiLinkOpener]: opens external links.
library;

export 'src/deep_link.dart';
export 'src/link_opener.dart';
export 'src/navigator.dart';
export 'src/params.dart';
export 'src/route.dart';
export 'src/route_table.dart';
