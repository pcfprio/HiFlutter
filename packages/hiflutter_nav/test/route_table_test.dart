import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});
final user = HiRoute<int>(
  '/users/:id',
  encode: (id) => {'id': id},
  decode: (params) => params.requireInt('id'),
);
final me = HiRoute<void>('/users/me', encode: (_) => const {}, decode: (_) {});

void main() {
  group('HiRouteTable.match', () {
    final table = HiRouteTable([home, me, user]);

    test('matches a URL to its route and arguments', () {
      final match = table.match(Uri.parse('/users/9'));
      expect(match!.route, same(user));
      expect(match.args, 9);
      expect(table.match(Uri.parse('/'))!.route, same(home));
    });

    test('prefers the earlier route when several fit', () {
      expect(table.match(Uri.parse('/users/me'))!.route, same(me));
    });

    test('returns null when no route fits', () {
      expect(table.match(Uri.parse('/nowhere')), isNull);
      expect(table.match(Uri.parse('/users/x')), isNull);
    });

    test('rejects duplicate path patterns', () {
      final again = HiRoute<int>(
        '/users/:id',
        encode: (id) => {'id': id},
        decode: (params) => params.requireInt('id'),
      );
      expect(() => HiRouteTable([user, again]), throwsArgumentError);
    });
  });

  group('HiDeepLinkGuard', () {
    final guard = HiDeepLinkGuard(
      schemes: {'https', 'myapp'},
      hosts: {'example.com', '*.example.org', 'open'},
    );

    test('allows listed schemes and hosts, ignoring case', () {
      expect(guard.allows(Uri.parse('https://example.com/users/1')), isTrue);
      expect(guard.allows(Uri.parse('HTTPS://EXAMPLE.COM/')), isTrue);
      expect(guard.allows(Uri.parse('myapp://open/users/1')), isTrue);
    });

    test('allows subdomains of a wildcard host but not the bare domain', () {
      expect(guard.allows(Uri.parse('https://m.example.org/')), isTrue);
      expect(guard.allows(Uri.parse('https://a.b.example.org/')), isTrue);
      expect(guard.allows(Uri.parse('https://example.org/')), isFalse);
      expect(guard.allows(Uri.parse('https://badexample.org/')), isFalse);
    });

    test('rejects unlisted schemes', () {
      expect(guard.allows(Uri.parse('http://example.com/')), isFalse);
      expect(guard.allows(Uri.parse('javascript:alert(1)')), isFalse);
      expect(guard.allows(Uri.parse('/users/1')), isFalse);
    });

    test('rejects unlisted hosts, including look-alikes', () {
      expect(guard.allows(Uri.parse('https://evil.com/')), isFalse);
      expect(guard.allows(Uri.parse('https://example.com.evil.com/')), isFalse);
      expect(guard.allows(Uri.parse('https://example.com@evil.com/')), isFalse);
      expect(guard.allows(Uri.parse('myapp:///users/1')), isFalse);
    });
  });

  group('HiRouteTable.matchDeepLink', () {
    final guard = HiDeepLinkGuard(schemes: {'https'}, hosts: {'example.com'});

    test('routes a trusted deep link by its path and query', () {
      final table = HiRouteTable([home, user], deepLinks: guard);
      final match = table.matchDeepLink(
        Uri.parse('https://example.com/users/5?ref=mail'),
      );
      expect(match!.route, same(user));
      expect(match.args, 5);
    });

    test('does not route an untrusted deep link', () {
      final table = HiRouteTable([home, user], deepLinks: guard);
      expect(
        table.matchDeepLink(Uri.parse('https://evil.com/users/5')),
        isNull,
      );
      expect(
        table.matchDeepLink(Uri.parse('http://example.com/users/5')),
        isNull,
      );
    });

    test('does not route any deep link without a guard', () {
      final table = HiRouteTable([home, user]);
      expect(
        table.matchDeepLink(Uri.parse('https://example.com/users/5')),
        isNull,
      );
    });
  });
}
