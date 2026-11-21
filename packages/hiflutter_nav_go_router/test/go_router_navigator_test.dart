import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';
import 'package:hiflutter_nav_go_router/hiflutter_nav_go_router.dart';

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
final user = HiRoute<int>(
  '/users/:id',
  encode: (id) => {'id': id},
  decode: (params) => params.requireInt('id'),
);
final settings = HiRoute<void>(
  '/settings',
  encode: (_) => const {},
  decode: (_) {},
);

HiGoRouterNavigator createNavigator({
  HiDeepLinkGuard? deepLinks,
  String initialLocation = '/',
}) => HiGoRouterNavigator(
  table: HiRouteTable([home, user, settings], deepLinks: deepLinks),
  pages: [
    home.page((context, _) => const Text('home')),
    user.page((context, id) => UserPage(id)),
    settings.page((context, _) => const Text('settings')),
  ],
  initialLocation: initialLocation,
);

Future<HiGoRouterNavigator> pumpApp(
  WidgetTester tester, {
  HiDeepLinkGuard? deepLinks,
  String initialLocation = '/',
}) async {
  final navigator = createNavigator(
    deepLinks: deepLinks,
    initialLocation: initialLocation,
  );
  addTearDown(navigator.dispose);
  await tester.pumpWidget(
    WidgetsApp.router(
      routerConfig: navigator.routerConfig,
      color: const Color(0xFF000000),
    ),
  );
  return navigator;
}

/// A page whose builder needs the route's typed argument.
class UserPage extends StatelessWidget {
  const UserPage(this.id, {super.key});

  final int id;

  @override
  Widget build(BuildContext context) => Text('user $id');
}

void main() {
  testWidgets('starts at the initial location', (tester) async {
    await pumpApp(tester, initialLocation: '/users/3');
    expect(find.text('user 3'), findsOneWidget);
  });

  testWidgets('push shows the page and pop returns to the previous one', (
    tester,
  ) async {
    final navigator = await pumpApp(tester);
    expect(find.text('home'), findsOneWidget);
    expect(navigator.canPop(), isFalse);

    final result = navigator.push<int, String>(user, 7);
    await tester.pumpAndSettle();
    expect(find.text('user 7'), findsOneWidget);
    expect(navigator.canPop(), isTrue);

    navigator.pop('done');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(await result, 'done');
  });

  testWidgets('pop with nothing to pop throws StateError', (tester) async {
    final navigator = await pumpApp(tester);
    expect(navigator.pop, throwsStateError);
  });

  testWidgets('replace swaps the current page', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.push<int, void>(user, 1);
    await tester.pumpAndSettle();

    navigator.replace<void, void>(settings, null);
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('go replaces the whole stack', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.push<void, void>(settings, null);
    await tester.pumpAndSettle();

    navigator.go(user, 2);
    await tester.pumpAndSettle();
    expect(find.text('user 2'), findsOneWidget);
    expect(navigator.canPop(), isFalse);
  });

  group('deep links', () {
    final guard = HiDeepLinkGuard(schemes: {'https'}, hosts: {'example.com'});

    testWidgets('a trusted link opens its route', (tester) async {
      await pumpApp(tester, deepLinks: guard);
      await openDeepLink(tester, 'https://example.com/users/42');
      expect(find.text('user 42'), findsOneWidget);
    });

    testWidgets('an in-app path opens its route', (tester) async {
      await pumpApp(tester, deepLinks: guard);
      await openDeepLink(tester, '/settings');
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('an untrusted host lands on the fallback', (tester) async {
      await pumpApp(tester, deepLinks: guard, initialLocation: '/settings');
      await openDeepLink(tester, 'https://evil.com/users/42');
      expect(find.text('user 42'), findsNothing);
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('no guard rejects every external link', (tester) async {
      await pumpApp(tester);
      await openDeepLink(tester, 'https://example.com/users/42');
      expect(find.text('user 42'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('an unknown or undecodable location lands on the fallback', (
      tester,
    ) async {
      await pumpApp(tester, deepLinks: guard);
      await openDeepLink(tester, 'https://example.com/users/abc');
      expect(find.text('home'), findsOneWidget);
      await openDeepLink(tester, '/nowhere');
      expect(find.text('home'), findsOneWidget);
    });
  });

  test('rejects pages and locations that do not fit the table', () {
    expect(
      () => HiGoRouterNavigator(
        table: HiRouteTable([home, user]),
        pages: [home.page((context, _) => const Text('home'))],
        initialLocation: '/',
      ),
      throwsArgumentError,
    );
    expect(
      () => createNavigator(initialLocation: '/nowhere'),
      throwsArgumentError,
    );
  });
}

/// Delivers [location] the way the platform does when the OS opens a link.
Future<void> openDeepLink(WidgetTester tester, String location) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': location, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}
