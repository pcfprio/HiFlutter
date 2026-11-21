import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';

/// Immutable state snapshot exposed by [HiPaginationNotifier].
@immutable
final class HiPaginationState<T> {
  /// Creates a pagination state containing an unmodifiable copy of [items].
  HiPaginationState({
    required this.status,
    required List<T> items,
    this.error,
    required this.hasMore,
    required this.currentPage,
  }) : items = List<T>.unmodifiable(items);

  /// Creates the initial idle pagination state for [initialPage].
  ///
  /// Sets [currentPage] to `initialPage - 1` before any page has succeeded.
  factory HiPaginationState.initial({int initialPage = 1}) {
    assert(initialPage >= 0, 'initialPage must be non-negative');
    return HiPaginationState<T>(
      status: HiPaginationStatus.idle,
      items: const [],
      hasMore: false,
      currentPage: initialPage - 1,
    );
  }

  /// Current pagination lifecycle status.
  final HiPaginationStatus status;

  /// Unmodifiable list of items loaded so far.
  final List<T> items;

  /// Error from the most recent failed operation, cleared on the next load.
  final HiError? error;

  /// Whether further pages may be fetched via `loadMore`.
  final bool hasMore;

  /// Most recently loaded page index, or `initialPage - 1` before any page
  /// has succeeded.
  final int currentPage;

  /// Whether [items] contains no elements.
  bool get isEmpty => items.isEmpty;

  /// Whether any request (`initialLoading`, `refreshing`, or `loadingMore`)
  /// is currently in progress.
  bool get isLoading =>
      status == HiPaginationStatus.initialLoading ||
      status == HiPaginationStatus.refreshing ||
      status == HiPaginationStatus.loadingMore;

  /// Returns a copy of this state with the provided fields replaced.
  ///
  /// Set [clearError] to `true` to reset [error] back to `null`.
  HiPaginationState<T> copyWith({
    HiPaginationStatus? status,
    List<T>? items,
    HiError? error,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
  }) => HiPaginationState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore,
    currentPage: currentPage ?? this.currentPage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiPaginationState<T> &&
          status == other.status &&
          error == other.error &&
          hasMore == other.hasMore &&
          currentPage == other.currentPage &&
          listEquals(items, other.items);

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAll(items), error, hasMore, currentPage);
}

/// Riverpod [Notifier] adapting [HiPaginationController]'s pagination state
/// machine to [HiPaginationState].
///
/// Prevents concurrent re-entrant loads, normalizes thrown errors via
/// [HiError.from], preserves existing items when a refresh or load-more fails,
/// and discards late async completions after [reset], provider invalidation, or
/// container disposal.
class HiPaginationNotifier<T> extends Notifier<HiPaginationState<T>> {
  /// Creates a pagination notifier backed by a fixed page [loader].
  ///
  /// The first loaded page defaults to `1` and may be customized via
  /// [initialPage] (for zero-indexed APIs).
  HiPaginationNotifier({required HiPageLoader<T> loader, this.initialPage = 1})
    : assert(initialPage >= 0, 'initialPage must be non-negative'),
      _createLoader = ((_) => loader);

  /// Creates a pagination notifier whose page loader is built inside [build]
  /// with access to Riverpod's [Ref].
  HiPaginationNotifier.fromRef({
    required this._createLoader,
    this.initialPage = 1,
  }) : assert(initialPage >= 0, 'initialPage must be non-negative');

  /// First page index requested by [loadInitial] and [refresh].
  final int initialPage;

  final HiPageLoader<T> Function(Ref ref) _createLoader;
  late HiPageLoader<T> _loadPage;
  Ref? _activeRef;
  int _generation = 0;

  bool get _isMounted => _activeRef?.mounted ?? false;

  @override
  HiPaginationState<T> build() {
    _generation++;
    _activeRef = ref;
    ref.onDispose(() => _generation++);
    _loadPage = _createLoader(ref);
    return HiPaginationState<T>.initial(initialPage: initialPage);
  }

  /// Loads [initialPage] and replaces [HiPaginationState.items].
  ///
  /// Ignored if a load is already in progress or this notifier is no longer
  /// mounted.
  Future<void> loadInitial() => _runRequest(
    loadingStatus: HiPaginationStatus.initialLoading,
    targetPage: initialPage,
    append: false,
    preserveOnFailure: false,
  );

  /// Refreshes from [initialPage].
  ///
  /// When [HiPaginationState.items] is non-empty and the refresh fails,
  /// existing items, `currentPage`, and `hasMore` are preserved,
  /// [HiPaginationState.error] is updated, and [HiPaginationState.status]
  /// returns to [HiPaginationStatus.idle] or [HiPaginationStatus.completed].
  Future<void> refresh() => _runRequest(
    loadingStatus: HiPaginationStatus.refreshing,
    targetPage: initialPage,
    append: false,
    preserveOnFailure: true,
  );

  /// Appends `currentPage + 1` to [HiPaginationState.items].
  ///
  /// Ignored when already loading, before an initial page has succeeded, when
  /// [HiPaginationState.hasMore] is `false`, or when no longer mounted.
  Future<void> loadMore() {
    if (!_isMounted) return Future<void>.value();
    final current = state;
    if (current.isLoading ||
        !current.hasMore ||
        current.currentPage < initialPage) {
      return Future<void>.value();
    }
    return _runRequest(
      loadingStatus: HiPaginationStatus.loadingMore,
      targetPage: current.currentPage + 1,
      append: true,
      preserveOnFailure: false,
    );
  }

  /// Retries the failed stage: [loadInitial] when [HiPaginationState.items] is
  /// empty, or [loadMore] otherwise.
  Future<void> retry() {
    if (!_isMounted) return Future<void>.value();
    final current = state;
    if (current.isLoading) return Future<void>.value();
    if (current.isEmpty) {
      return loadInitial();
    }
    return loadMore();
  }

  /// Resets to the initial [HiPaginationStatus.idle] state and invalidates any
  /// in-flight request.
  void reset() {
    if (!_isMounted) return;
    _generation++;
    state = HiPaginationState<T>.initial(initialPage: initialPage);
  }

  Future<void> _runRequest({
    required HiPaginationStatus loadingStatus,
    required int targetPage,
    required bool append,
    required bool preserveOnFailure,
  }) async {
    if (!_isMounted) return;
    final current = state;
    if (current.isLoading) return;

    final activeRef = ref;
    final generation = _generation;
    state = current.copyWith(status: loadingStatus, clearError: true);

    try {
      final slice = await _loadPage(targetPage);
      if (!activeRef.mounted || generation != _generation) return;
      final latest = state;
      final nextItems = append
          ? <T>[...latest.items, ...slice.items]
          : slice.items;
      state = HiPaginationState<T>(
        status: slice.hasMore
            ? HiPaginationStatus.idle
            : HiPaginationStatus.completed,
        items: nextItems,
        hasMore: slice.hasMore,
        currentPage: targetPage,
      );
    } catch (error, stackTrace) {
      if (!activeRef.mounted || generation != _generation) return;
      final latest = state;
      final mappedError = HiError.from(error, stackTrace);
      final nextStatus = preserveOnFailure && latest.items.isNotEmpty
          ? (latest.hasMore
                ? HiPaginationStatus.idle
                : HiPaginationStatus.completed)
          : HiPaginationStatus.failure;
      state = latest.copyWith(status: nextStatus, error: mappedError);
    }
  }
}

/// Creates a [NotifierProvider] managing a [HiPaginationNotifier] whose page
/// loader is created with access to Riverpod's [Ref].
NotifierProvider<HiPaginationNotifier<T>, HiPaginationState<T>>
hiPaginationProvider<T>(
  HiPageLoader<T> Function(Ref ref) createLoader, {
  int initialPage = 1,
  String? name,
  Iterable<ProviderOrFamily>? dependencies,
  bool isAutoDispose = false,
}) => NotifierProvider<HiPaginationNotifier<T>, HiPaginationState<T>>(
  () => HiPaginationNotifier<T>.fromRef(
    createLoader: createLoader,
    initialPage: initialPage,
  ),
  name: name,
  dependencies: dependencies,
  isAutoDispose: isAutoDispose,
);

/// Creates a [NotifierProviderFamily] managing [HiPaginationNotifier]
/// instances parameterized by [Arg].
NotifierProviderFamily<HiPaginationNotifier<T>, HiPaginationState<T>, Arg>
hiPaginationProviderFamily<T, Arg>(
  HiPageLoader<T> Function(Ref ref, Arg arg) createLoader, {
  int initialPage = 1,
  String? name,
  Iterable<ProviderOrFamily>? dependencies,
  bool isAutoDispose = false,
}) =>
    NotifierProvider.family<HiPaginationNotifier<T>, HiPaginationState<T>, Arg>(
      (arg) => HiPaginationNotifier<T>.fromRef(
        createLoader: (ref) => createLoader(ref, arg),
        initialPage: initialPage,
      ),
      name: name,
      dependencies: dependencies,
      isAutoDispose: isAutoDispose,
    );
