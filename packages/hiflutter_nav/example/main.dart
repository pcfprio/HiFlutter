// The example prints its results to the console.
// ignore_for_file: avoid_print

import 'package:hiflutter_nav/hiflutter_nav.dart';

/// Arguments of the article page.
class ArticleArgs {
  /// Creates arguments for article [id], optionally scrolled to [anchor].
  const ArticleArgs(this.id, {this.anchor});

  /// Article id, part of the path.
  final int id;

  /// Optional section, carried in the query string.
  final String? anchor;
}

final home = HiRoute<void>('/', encode: (_) => const {}, decode: (_) {});

final article = HiRoute<ArticleArgs>(
  '/articles/:id',
  encode: (args) => {'id': args.id, 'anchor': args.anchor},
  decode: (params) =>
      ArticleArgs(params.requireInt('id'), anchor: params.string('anchor')),
);

void main() {
  final table = HiRouteTable(
    [home, article],
    deepLinks: HiDeepLinkGuard(
      schemes: {'https', 'myapp'},
      hosts: {'example.com', '*.example.com', 'open'},
    ),
  );

  // Build locations from typed arguments.
  print(article.location(const ArticleArgs(7, anchor: 'comments')));

  // Resolve incoming deep links; untrusted ones are not routed.
  for (final link in [
    'https://m.example.com/articles/7?anchor=comments',
    'myapp://open/articles/8',
    'https://evil.com/articles/7',
    'https://example.com/articles/not-a-number',
  ]) {
    final match = table.matchDeepLink(Uri.parse(link));
    print('$link -> ${match?.location ?? 'rejected'}');
  }
}
