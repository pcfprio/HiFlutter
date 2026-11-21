# hiflutter_suite

Material 3 UI components of [HiFlutter](https://github.com/pcfprio/HiFlutter):
localized state views, a `ChangeNotifier`-based pagination state machine, a
paginated list view with pull-to-refresh and a four-state load-more footer, and
cross-platform visual metrics.

## Features

- **Built-in EN/ZH localization**: `HiSuiteLocalizations` uses `gen-l10n` for
  English and Chinese defaults, works out of the box without requiring a
  registered delegate, supports custom `LocalizationsDelegate` overrides and
  widget-level string parameters, and maps `HiError.display` via
  `describeError`.
- **Aligned visual metrics**: `HiSuiteMetrics` provides cross-platform sizes,
  touch targets, margins, and corner radii (`listRowMinHeight`,
  `searchFieldHeight`, `primaryButtonMinHeight`, `minTouchTarget`,
  `horizontalSafeMargin`, `menuBorderRadius`, `tooltipBorderRadius`, and more).
- **Page state views**: `HiLoadingView`, `HiEmptyView`, `HiErrorView` (hides
  `HiErrorDisplay.none`, shows retry only when `error.retryable && onRetry != null`),
  and `HiStateView` (`HiViewState` or `HiStateView.auto`).
- **Pagination controller**: `HiPaginationController<T>` manages `idle`,
  `initialLoading`, `refreshing`, `loadingMore`, `failure`, and `completed`
  transitions with concurrency guards, `HiError.from` normalization, item
  preservation on failure, and `dispose`/`reset` safety.
- **Paginated list view**: `HiPaginatedListView<T>` pairs
  `HiPaginationController` with `RefreshIndicator`, automatic near-bottom
  loading, state views, and the four-state `HiLoadMoreFooter` (`loading`,
  `canLoadMore`, `noMore`, `failed`).

## Usage

```dart
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final HiPaginationController<String> _controller;

  @override
  void initState() {
    super.initState();
    _controller = HiPaginationController<String>(
      loader: (page) async => HiPageSlice(
        items: List.generate(20, (i) => 'Item ${(page - 1) * 20 + i + 1}'),
        hasMore: page < 3,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HiPaginatedListView<String>(
        controller: _controller,
        itemBuilder: (context, item, index) => ListTile(title: Text(item)),
      ),
    );
  }
}
```

See `example/main.dart` for a complete runnable example.

## License

MIT
