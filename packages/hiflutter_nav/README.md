# hiflutter_nav

Navigation contracts of [HiFlutter](https://github.com/pcfprio/HiFlutter).
It depends on nothing but the Flutter SDK; plug in a router with an adapter
such as `hiflutter_nav_go_router`, and open external links with
`hiflutter_nav_url_launcher`.

## Features

- **Typed routes**: `HiRoute<P>` pairs a path pattern (`/users/:id`) with
  an encoder and decoder for its arguments, so you navigate with
  `navigator.push(userRoute, 42)` instead of hand-written strings. Path
  parameters fill the pattern; other values go into the query string.
  `HiRouteParams` offers typed accessors (`requireInt`, `boolean`, ...).
- **URL route table**: `HiRouteTable` matches a URL to the first fitting
  route and decodes its arguments; URLs whose arguments fail to decode do
  not match.
- **Deep-link allow-list**: `HiDeepLinkGuard` accepts only listed schemes
  and hosts (with `*.example.com` subdomain wildcards).
  `HiRouteTable.matchDeepLink` routes nothing without a guard.
- **Router-agnostic navigation**: `HiNavigator` (`push`, `replace`, `pop`,
  `go`) and `HiPage`, which binds a route to its widget; create pages with
  `route.page((context, args) => ...)` to keep the argument type.
- **External links**: `HiLinkOpener` opens web pages or other apps in a
  chosen `HiLinkMode`.

## Usage

```dart
import 'package:hiflutter_nav/hiflutter_nav.dart';

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
final user = HiRoute<int>(
  '/users/:id',
  encode: (id) => {'id': id},
  decode: (params) => params.requireInt('id'),
);

final table = HiRouteTable(
  [home, user],
  deepLinks: HiDeepLinkGuard(schemes: {'https'}, hosts: {'example.com'}),
);

user.location(42);                                   // '/users/42'
table.match(Uri.parse('/users/42'))?.args;           // 42
table.matchDeepLink(Uri.parse('https://evil.com/')); // null
```

App code depends on `HiNavigator` and `HiLinkOpener` only, so it can be
tested with fakes. See `example/main.dart` for a complete example.

## License

MIT
