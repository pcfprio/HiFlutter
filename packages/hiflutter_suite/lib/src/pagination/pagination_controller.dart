import 'package:flutter/foundation.dart';
import 'package:hiflutter_base/hiflutter_base.dart';

/// A single page of items returned by a [HiPageLoader].
final class HiPageSlice<T> {
  /// Creates a page slice containing an unmodifiable copy of [items].
  HiPageSlice({required List<T> items, required this.hasMore})
    : items = List<T>.unmodifiable(items);

  /// Creates an empty page slice.
  const HiPageSlice.empty({this.hasMore = false}) : items = const [];

  /// Items in this page, unmodifiable.
  final List<T> items;

  /// Whether another page is available after this one.
  final bool hasMore;
}

/// Callback fetching one page of items for [HiPaginationController].
///
/// The [page] argument starts at [HiPaginationController.initialPage] (default `1`).
typedef HiPageLoader<T> = Future<HiPageSlice<T>> Function(int page);

/// Lifecycle state of a [HiPaginationController].
enum HiPaginationStatus {
  /// Waiting for the initial load or ready to load the next page.
  idle,

  /// Loading the first page while no active load is in flight.
  initialLoading,

  /// Refreshing the list from [HiPaginationController.initialPage].
  refreshing,

  /// Appending the next page after [HiPaginationController.currentPage].
  loadingMore,

  /// The last initial load or load-more attempt failed.
  failure,

  /// All available pages have been loaded.
  completed,
}

/// State-machine controller for paginated lists built on [ChangeNotifier].
///
/// Prevents concurrent re-entrant loads, normalizes thrown errors via
/// [HiError.from], preserves existing items when a refresh or load-more fails,
/// and ignores late async completions after [reset] or [dispose].
class HiPaginationController<T> extends ChangeNotifier {
  /// Creates a pagination controller backed by [loader].
  ///
  /// The first loaded page index defaults to `1` and may be customized via
  /// [initialPage] (for zero-indexed APIs).
  HiPaginationController({
    required HiPageLoader<T> loader,
    this.initialPage = 1,
  }) : assert(initialPage >= 0, 'initialPage must be non-negative'),
       _loadPage = loader,
       _currentPage = initialPage - 1;

  final HiPageLoader<T> _loadPage;

  /// First page index requested by [loadInitial] and [refresh].
  final int initialPage;

  HiPaginationStatus _status = HiPaginationStatus.idle;
  List<T> _items = List<T>.unmodifiable(const []);
  HiError? _error;
  bool _hasMore = false;
  int _currentPage;
  int _generation = 0;
  bool _disposed = false;

  /// Current state-machine status.
  HiPaginationStatus get status => _status;

  /// Unmodifiable list of items loaded so far.
  List<T> get items => _items;

  /// Failure from the most recent failed operation, cleared on the next load.
  HiError? get error => _error;

  /// Whether further pages may be fetched via [loadMore].
  bool get hasMore => _hasMore;

  /// Most recently loaded page index, or `initialPage - 1` before any page
  /// has loaded.
  int get currentPage => _currentPage;

  /// Whether [items] contains no elements.
  bool get isEmpty => _items.isEmpty;

  /// Whether any load (`initialLoading`, `refreshing`, or `loadingMore`) is
  /// currently in progress.
  bool get isLoading =>
      _status == HiPaginationStatus.initialLoading ||
      _status == HiPaginationStatus.refreshing ||
      _status == HiPaginationStatus.loadingMore;

  /// Loads [initialPage] and replaces [items].
  ///
  /// Ignored if a load is already in progress or this controller is disposed.
  Future<void> loadInitial() => _runRequest(
    loadingStatus: HiPaginationStatus.initialLoading,
    targetPage: initialPage,
    append: false,
    preserveOnFailure: false,
  );

  /// Refreshes from [initialPage].
  ///
  /// When [items] is non-empty and the refresh fails, existing [items],
  /// [currentPage], and [hasMore] are preserved, [error] is updated, and
  /// [status] returns to [HiPaginationStatus.idle] or
  /// [HiPaginationStatus.completed].
  Future<void> refresh() => _runRequest(
    loadingStatus: HiPaginationStatus.refreshing,
    targetPage: initialPage,
    append: false,
    preserveOnFailure: true,
  );

  /// Appends `currentPage + 1` to [items].
  ///
  /// Ignored when already loading, before an initial page has succeeded, or
  /// when [hasMore] is `false`.
  Future<void> loadMore() {
    if (_disposed || isLoading || !_hasMore || _currentPage < initialPage) {
      return Future<void>.value();
    }
    return _runRequest(
      loadingStatus: HiPaginationStatus.loadingMore,
      targetPage: _currentPage + 1,
      append: true,
      preserveOnFailure: false,
    );
  }

  /// Retries the failed stage: [loadInitial] when [items] is empty, or
  /// [loadMore] otherwise.
  Future<void> retry() {
    if (_disposed || isLoading) return Future<void>.value();
    if (_items.isEmpty) {
      return loadInitial();
    }
    return loadMore();
  }

  /// Resets to the initial [HiPaginationStatus.idle] state and invalidates any
  /// in-flight request.
  void reset() {
    if (_disposed) return;
    _generation++;
    _status = HiPaginationStatus.idle;
    _items = List<T>.unmodifiable(const []);
    _error = null;
    _hasMore = false;
    _currentPage = initialPage - 1;
    notifyListeners();
  }

  Future<void> _runRequest({
    required HiPaginationStatus loadingStatus,
    required int targetPage,
    required bool append,
    required bool preserveOnFailure,
  }) async {
    if (_disposed || isLoading) return;
    final generation = _generation;
    _status = loadingStatus;
    _error = null;
    notifyListeners();

    try {
      final slice = await _loadPage(targetPage);
      if (_disposed || generation != _generation) return;
      _items = append
          ? List<T>.unmodifiable([..._items, ...slice.items])
          : slice.items;
      _currentPage = targetPage;
      _hasMore = slice.hasMore;
      _error = null;
      _status = slice.hasMore
          ? HiPaginationStatus.idle
          : HiPaginationStatus.completed;
      notifyListeners();
    } catch (error, stackTrace) {
      if (_disposed || generation != _generation) return;
      _error = HiError.from(error, stackTrace);
      if (preserveOnFailure && _items.isNotEmpty) {
        _status = _hasMore
            ? HiPaginationStatus.idle
            : HiPaginationStatus.completed;
      } else {
        _status = HiPaginationStatus.failure;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
