import 'package:flutter/widgets.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_go_router/hiflutter_nav_go_router.dart';

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});

final user = HiRoute<int>(
  '/users/:id',
  encode: (id) => {'id': id},
  decode: (params) => params.requireInt('id'),
);

void main() {
  late final HiNavigator navigator;
  final router = HiGoRouterNavigator(
    table: HiRouteTable([
      home,
      user,
    ], deepLinks: HiDeepLinkGuard(schemes: {'https'}, hosts: {'example.com'})),
    pages: [
      home.page((context, _) => HomePage(navigator: navigator)),
      user.page((context, id) => UserPage(id: id, navigator: navigator)),
    ],
    initialLocation: '/',
  );
  navigator = router;
  runApp(
    WidgetsApp.router(
      routerConfig: router.routerConfig,
      color: const Color(0xFF2962FF),
    ),
  );
}

/// Lists users.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key, required this.navigator});

  /// Used to open user pages.
  final HiNavigator navigator;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final id in [1, 2, 3])
          GestureDetector(
            onTap: () => navigator.push<int, void>(user, id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Open user $id'),
            ),
          ),
      ],
    ),
  );
}

/// Shows one user.
class UserPage extends StatelessWidget {
  /// Creates the page of user [id].
  const UserPage({super.key, required this.id, required this.navigator});

  /// The user's id, decoded from the URL.
  final int id;

  /// Used to go back.
  final HiNavigator navigator;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Center(
      child: GestureDetector(
        onTap: navigator.canPop() ? navigator.pop : null,
        child: Text('Profile of user $id (tap to go back)'),
      ),
    ),
  );
}
