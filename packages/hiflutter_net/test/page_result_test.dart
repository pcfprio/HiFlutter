import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:test/test.dart';

void main() {
  test('stores items as an unmodifiable list with pagination metadata', () {
    final source = [1, 2, 3];
    final result = HiPageResult<int>(
      items: source,
      hasMore: true,
      page: 2,
      nextCursor: 'cursor-3',
    );
    source.add(4);

    expect(result.items, [1, 2, 3]);
    expect(result.hasMore, isTrue);
    expect(result.page, 2);
    expect(result.nextCursor, 'cursor-3');
    expect(() => result.items.add(5), throwsUnsupportedError);
  });

  test('empty() creates an empty page result with optional metadata', () {
    const empty = HiPageResult<String>.empty();

    expect(empty.items, isEmpty);
    expect(empty.hasMore, isFalse);
    expect(empty.page, isNull);
    expect(empty.nextCursor, isNull);
  });

  test('map transforms every item while preserving pagination metadata', () {
    final page = HiPageResult<int>(
      items: [10, 20],
      hasMore: true,
      page: 1,
      nextCursor: 'next',
    );

    final mapped = page.map((n) => 'item-$n');

    expect(mapped.items, ['item-10', 'item-20']);
    expect(mapped.hasMore, isTrue);
    expect(mapped.page, 1);
    expect(mapped.nextCursor, 'next');
  });
}
