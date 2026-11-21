import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_nav/hiflutter_nav.dart';

class UserArgs {
  const UserArgs(this.id, {this.tab});

  final int id;
  final String? tab;
}

final userRoute = HiRoute<UserArgs>(
  '/users/:id',
  encode: (args) => {'id': args.id, 'tab': args.tab},
  decode: (params) =>
      UserArgs(params.requireInt('id'), tab: params.string('tab')),
);

void main() {
  group('HiRoute.location', () {
    test('fills path parameters and puts the rest into the query', () {
      expect(
        userRoute.location(const UserArgs(42, tab: 'posts')),
        '/users/42?tab=posts',
      );
    });

    test('omits null values', () {
      expect(userRoute.location(const UserArgs(7)), '/users/7');
    });

    test('percent-encodes values', () {
      final search = HiRoute<String>(
        '/search/:q',
        encode: (q) => {'q': q, 'from': 'a&b'},
        decode: (params) => params.requireString('q'),
      );
      expect(search.location('a b/c'), '/search/a%20b%2Fc?from=a%26b');
    });

    test('rejects a missing path parameter', () {
      final broken = HiRoute<void>(
        '/users/:id',
        encode: (_) => const {},
        decode: (_) {},
      );
      expect(() => broken.location(null), throwsArgumentError);
    });
  });

  group('HiRoute.match', () {
    test('decodes path and query parameters into typed arguments', () {
      final match = userRoute.match(Uri.parse('/users/42?tab=posts'));
      expect(match, isNotNull);
      expect(match!.route, same(userRoute));
      expect(match.args.id, 42);
      expect(match.args.tab, 'posts');
      expect(match.location, '/users/42?tab=posts');
    });

    test('round-trips percent-encoded values', () {
      final search = HiRoute<String>(
        '/search/:q',
        encode: (q) => {'q': q},
        decode: (params) => params.requireString('q'),
      );
      final location = search.location('a b/c?');
      expect(search.match(Uri.parse(location))!.args, 'a b/c?');
    });

    test('ignores a trailing slash', () {
      expect(userRoute.match(Uri.parse('/users/42/'))!.args.id, 42);
    });

    test('lets path parameters win over query parameters', () {
      expect(userRoute.match(Uri.parse('/users/1?id=2'))!.args.id, 1);
    });

    test('does not match other paths', () {
      expect(userRoute.match(Uri.parse('/users')), isNull);
      expect(userRoute.match(Uri.parse('/users/1/posts')), isNull);
      expect(userRoute.match(Uri.parse('/teams/1')), isNull);
    });

    test('does not match when the arguments fail to decode', () {
      expect(userRoute.match(Uri.parse('/users/abc')), isNull);
    });
  });

  group('HiRouteParams', () {
    const params = HiRouteParams({'n': '3', 'bad': 'x', 'on': 'true'});

    test('reads optional and required values', () {
      expect(params.string('n'), '3');
      expect(params.string('missing'), isNull);
      expect(params.integer('n'), 3);
      expect(params.integer('missing'), isNull);
      expect(params.boolean('on'), isTrue);
      expect(params.boolean('missing'), isNull);
    });

    test('throws FormatException on missing or malformed values', () {
      expect(() => params.requireString('missing'), throwsFormatException);
      expect(() => params.requireInt('missing'), throwsFormatException);
      expect(() => params.integer('bad'), throwsFormatException);
      expect(() => params.boolean('bad'), throwsFormatException);
    });
  });
}
