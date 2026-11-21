import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/load_more_footer.dart';
import '../widgets/state_views.dart';
import 'pagination_controller.dart';

/// Signature for building one row inside [HiPaginatedListView].
typedef HiPaginatedItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// Paginated vertical list view bound to a [HiPaginationController].
///
/// Handles optional initial auto-loading, pull-to-refresh via
/// [RefreshIndicator], first-page [HiLoadingView] / [HiEmptyView] /
/// [HiErrorView] states, scroll-near-bottom pagination triggers, and the
/// four-state [HiLoadMoreFooter].
class HiPaginatedListView<T> extends StatefulWidget {
  /// Creates a paginated list view driven by [controller].
  const HiPaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.scrollController,
    this.physics,
    this.autoLoad = true,
    this.shrinkWrap = false,
    this.loadMoreThreshold = 200.0,
    this.loadingBuilder,
    this.emptyView,
    this.emptyBuilder,
    this.errorBuilder,
    this.footerBuilder,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.errorTitle,
    this.errorMessage,
    this.retryLabel,
    this.loadMoreLoadingLabel,
    this.canLoadMoreLabel,
    this.noMoreLabel,
    this.loadMoreFailedLabel,
  }) : assert(loadMoreThreshold >= 0, 'loadMoreThreshold must be non-negative');

  /// Pagination state-machine controller driving this list.
  ///
  /// The caller retains ownership of [controller] and is responsible for
  /// disposing it.
  final HiPaginationController<T> controller;

  /// Builder for each loaded item.
  final HiPaginatedItemBuilder<T> itemBuilder;

  /// Optional separator builder rendered between adjacent data items (never
  /// between the last item and the footer).
  final IndexedWidgetBuilder? separatorBuilder;

  /// Outer padding passed to the underlying [ListView].
  final EdgeInsetsGeometry? padding;

  /// Optional scroll controller attached to the underlying [ListView].
  final ScrollController? scrollController;

  /// Scroll physics for the underlying scrollables.
  ///
  /// Defaults to [AlwaysScrollableScrollPhysics] so pull-to-refresh works even
  /// when items fit within the viewport.
  final ScrollPhysics? physics;

  /// Whether to automatically call [HiPaginationController.loadInitial] on
  /// first mount when [controller] is still idle and empty. Defaults to `true`.
  final bool autoLoad;

  /// Whether the underlying [ListView] shrinks to fit its children.
  final bool shrinkWrap;

  /// Remaining scroll extent in logical pixels below which [loadMore] triggers.
  /// Defaults to `200.0`.
  final double loadMoreThreshold;

  /// Custom builder replacing the default [HiLoadingView] on initial load.
  final WidgetBuilder? loadingBuilder;

  /// Static custom empty state widget. Overridden by [emptyBuilder] if both
  /// are provided.
  final Widget? emptyView;

  /// Custom builder replacing [emptyView] and the default [HiEmptyView].
  final WidgetBuilder? emptyBuilder;

  /// Custom builder replacing the default [HiErrorView] on initial load error.
  final Widget Function(
    BuildContext context,
    HiError error,
    VoidCallback retry,
  )?
  errorBuilder;

  /// Custom builder replacing the default [HiLoadMoreFooter].
  final Widget Function(BuildContext context, HiLoadMoreStatus status)?
  footerBuilder;

  /// Optional title override passed to [HiEmptyView].
  final String? emptyTitle;

  /// Optional description passed to [HiEmptyView].
  final String? emptyMessage;

  /// Optional icon passed to [HiEmptyView].
  final Widget? emptyIcon;

  /// Optional title override passed to [HiErrorView].
  final String? errorTitle;

  /// Optional message override passed to [HiErrorView].
  final String? errorMessage;

  /// Optional retry label override passed to [HiErrorView] and
  /// [HiLoadMoreFooter].
  final String? retryLabel;

  /// Optional label override for [HiLoadMoreStatus.loading].
  final String? loadMoreLoadingLabel;

  /// Optional label override for [HiLoadMoreStatus.canLoadMore].
  final String? canLoadMoreLabel;

  /// Optional label override for [HiLoadMoreStatus.noMore].
  final String? noMoreLabel;

  /// Optional label override for [HiLoadMoreStatus.failed].
  final String? loadMoreFailedLabel;

  @override
  State<HiPaginatedListView<T>> createState() => _HiPaginatedListViewState<T>();
}

class _HiPaginatedListViewState<T> extends State<HiPaginatedListView<T>> {
  bool _pendingAutoLoad = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoLoadIfNeeded();
  }

  @override
  void didUpdateWidget(HiPaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pendingAutoLoad = false;
      _scheduleAutoLoadIfNeeded();
    }
  }

  void _scheduleAutoLoadIfNeeded() {
    final controller = widget.controller;
    if (!widget.autoLoad ||
        controller.status != HiPaginationStatus.idle ||
        !controller.isEmpty ||
        controller.error != null) {
      return;
    }
    _pendingAutoLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingAutoLoad = false;
      if (widget.autoLoad &&
          widget.controller.status == HiPaginationStatus.idle &&
          widget.controller.isEmpty &&
          widget.controller.error == null) {
        widget.controller.loadInitial();
      }
    });
  }

  HiLoadMoreStatus _footerStatus(HiPaginationController<T> controller) {
    if (controller.status == HiPaginationStatus.loadingMore) {
      return HiLoadMoreStatus.loading;
    }
    if (controller.status == HiPaginationStatus.failure) {
      return HiLoadMoreStatus.failed;
    }
    if (controller.hasMore) {
      return HiLoadMoreStatus.canLoadMore;
    }
    return HiLoadMoreStatus.noMore;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification &&
        notification is! OverscrollNotification) {
      return false;
    }

    final controller = widget.controller;
    if (controller.isLoading ||
        controller.status == HiPaginationStatus.failure ||
        !controller.hasMore) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0 &&
        metrics.pixels > 0 &&
        metrics.extentAfter <= widget.loadMoreThreshold) {
      controller.loadMore();
    }
    return false;
  }

  Widget _wrapPullToRefreshState(Widget child) {
    final effectivePhysics =
        widget.physics ?? const AlwaysScrollableScrollPhysics();
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: effectivePhysics,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final items = controller.items;

        if (items.isEmpty) {
          if (controller.status == HiPaginationStatus.initialLoading ||
              controller.status == HiPaginationStatus.refreshing ||
              (_pendingAutoLoad &&
                  controller.status == HiPaginationStatus.idle)) {
            return widget.loadingBuilder?.call(context) ??
                const HiLoadingView();
          }
          final error = controller.error;
          if (controller.status == HiPaginationStatus.failure &&
              error != null) {
            final errorContent =
                widget.errorBuilder?.call(context, error, controller.retry) ??
                HiErrorView(
                  error: error,
                  onRetry: controller.retry,
                  title: widget.errorTitle,
                  message: widget.errorMessage,
                  retryLabel: widget.retryLabel,
                );
            return _wrapPullToRefreshState(errorContent);
          }
          final emptyContent =
              widget.emptyBuilder?.call(context) ??
              widget.emptyView ??
              HiEmptyView(
                title: widget.emptyTitle,
                message: widget.emptyMessage,
                icon: widget.emptyIcon,
              );
          return _wrapPullToRefreshState(emptyContent);
        }

        final footerStatus = _footerStatus(controller);
        final effectivePhysics =
            widget.physics ?? const AlwaysScrollableScrollPhysics();

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ListView.builder(
              controller: widget.scrollController,
              padding: widget.padding,
              shrinkWrap: widget.shrinkWrap,
              physics: effectivePhysics,
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return widget.footerBuilder?.call(context, footerStatus) ??
                      HiLoadMoreFooter(
                        status: footerStatus,
                        onLoadMore: controller.loadMore,
                        onRetry: controller.retry,
                        loadingLabel: widget.loadMoreLoadingLabel,
                        canLoadMoreLabel: widget.canLoadMoreLabel,
                        noMoreLabel: widget.noMoreLabel,
                        failedLabel: widget.loadMoreFailedLabel,
                        retryLabel: widget.retryLabel,
                      );
                }
                final itemWidget = widget.itemBuilder(
                  context,
                  items[index],
                  index,
                );
                final separator = widget.separatorBuilder;
                if (separator == null || index >= items.length - 1) {
                  return itemWidget;
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [itemWidget, separator(context, index)],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
