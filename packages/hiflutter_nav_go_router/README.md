# hiflutter_nav_go_router

[go_router](https://pub.dev/packages/go_router) implementation of the
`HiNavigator` contract from `hiflutter_nav`, part of
[HiFlutter](https://github.com/pcfprio/HiFlutter).

## Features

- Generates the go_router configuration from a `HiRouteTable` and a list of
  `HiPage`s: one route per table entry, rendered with typed arguments.
- Implements `push`, `replace`, `pop` and `go` with typed routes; app code
  never sees a go_router type.
- Redirects unknown locations, and locations whose arguments fail to
  decode, to a fallback location.
- Routes incoming deep links (`https://example.com/users/1`) only when the
  table's `HiDeepLinkGuard` allows them; untrusted links land on the
  fallback.

## Usage

```dart
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_go_router/hiflutter_nav_go_router.dart';

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
final user = HiRoute<int>(
  '/users/:id',
  encode: (id) => {'id': id},
  decode: (params) => params.requireInt('id'),
);

final navigator = HiGoRouterNavigator(
  table: HiRouteTable(
    [home, user],
    deepLinks: HiDeepLinkGuard(schemes: {'https'}, hosts: {'example.com'}),
  ),
  pages: [
    home.page((context, _) => const HomePage()),
    user.page((context, id) => UserPage(id: id)), // id is an int
  ],
  initialLocation: '/',
);

// Pass navigator.routerConfig to your app's `.router` constructor
// (for example WidgetsApp.router), then navigate with typed routes:
// navigator.push(user, 42);
```

Enable deep linking for Android and iOS as described in the Flutter
documentation; the navigator then receives the full link and checks it
against the guard. See `example/main.dart` for a complete app.

## License

MIT
