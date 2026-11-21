/// A single page of items returned by a paginated API endpoint.
final class HiPageResult<T> {
  /// Creates a page result holding an unmodifiable copy of [items].
  HiPageResult({
    required List<T> items,
    this.hasMore = false,
    this.page,
    this.nextCursor,
  }) : items = List<T>.unmodifiable(items);

  /// Creates an empty page result.
  const HiPageResult.empty({this.hasMore = false, this.page, this.nextCursor})
    : items = const [];

  /// The items in this page, unmodifiable.
  final List<T> items;

  /// Whether another page is available after this one.
  final bool hasMore;

  /// Page index when the endpoint uses numeric pagination, if known.
  final int? page;

  /// Opaque cursor for the next page when the endpoint uses cursor pagination.
  final String? nextCursor;

  /// Transforms every item in [items] with [transform], preserving [hasMore],
  /// [page] and [nextCursor].
  HiPageResult<R> map<R>(R Function(T item) transform) => HiPageResult<R>(
    items: [for (final item in items) transform(item)],
    hasMore: hasMore,
    page: page,
    nextCursor: nextCursor,
  );
}
