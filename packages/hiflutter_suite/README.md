# hiflutter_suite

Material 3 UI components of [HiFlutter](https://github.com/pcfprio/HiFlutter):
localized state views, a `ChangeNotifier`-based pagination state machine, a
paginated list view with pull-to-refresh and a four-state load-more footer,
overlay toast and confirmation dialog, grouped list rows, primary buttons, a
capsule search field, and cross-platform visual metrics.

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
- **Overlay toast & confirmation dialog**:
  - `HiToast.show` renders a non-blocking overlay toast aligned with
    `SuiteSnackbarHost` metrics (single-line centered shrink-wrap, multi-line
    left-aligned within 16dp safe margins), replaces any prior toast, and
    returns a `HiToastHandle` for early dismissal (`HiToast.dismissCurrent`
    also dismisses the active toast).
  - `HiConfirmDialog.show` presents a modal dialog via `showGeneralDialog`
    returning `Future<bool>`, with localized default labels and `colorScheme.error`
    styling when `isDestructive` is `true`.
- **Grouped list rows, primary button & search field**:
  - `HiListSection`, `HiListRow`, and `HiSelectableListRow` enforce
    `HiSuiteMetrics.listRowMinHeight` (`52.0`), support disabled dimming, and
    declare `selected` / `enabled` accessibility semantics.
  - `HiPrimaryButton` supports `HiButtonShape.rounded` and
    `HiButtonShape.capsule`, `HiSuiteMetrics.primaryButtonMinHeight` (`48.0`),
    disabled styling, and inline loading spinners that block taps.
  - `HiSearchField` renders a persistent `48.0` capsule search bar with an
    optional `TextEditingController`, localized hint, and semantic clear button.

## Usage

```dart
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

class SettingsAndFeedPage extends StatefulWidget {
  const SettingsAndFeedPage({super.key});

  @override
  State<SettingsAndFeedPage> createState() => _SettingsAndFeedPageState();
}

class _SettingsAndFeedPageState extends State<SettingsAndFeedPage> {
  final _searchController = TextEditingController();
  late final HiPaginationController<String> _pagination;
  String _selectedLocale = 'en';

  @override
  void initState() {
    super.initState();
    _pagination = HiPaginationController<String>(
      loader: (page) async => HiPageSlice(
        items: List.generate(20, (i) => 'Item ${(page - 1) * 20 + i + 1}'),
        hasMore: page < 3,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pagination.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final confirmed = await HiConfirmDialog.show(
      context,
      title: 'Reset filters?',
      message: 'This clears your current search query.',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    _searchController.clear();
    HiToast.show(context, 'Filters reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
            child: HiSearchField(controller: _searchController),
          ),
          HiListSection(
            header: const Text('Language'),
            margin: const EdgeInsets.symmetric(
              horizontal: HiSuiteMetrics.horizontalSafeMargin,
            ),
            children: [
              HiSelectableListRow(
                title: const Text('English'),
                selected: _selectedLocale == 'en',
                onTap: () => setState(() => _selectedLocale = 'en'),
              ),
              HiSelectableListRow(
                title: const Text('中文'),
                selected: _selectedLocale == 'zh',
                onTap: () => setState(() => _selectedLocale = 'zh'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(HiSuiteMetrics.horizontalSafeMargin),
            child: HiPrimaryButton(
              label: 'Reset',
              onPressed: _confirmReset,
            ),
          ),
          Expanded(
            child: HiPaginatedListView<String>(
              controller: _pagination,
              itemBuilder: (context, item, index) =>
                  HiListRow(title: Text(item)),
            ),
          ),
        ],
      ),
    );
  }
}
```

See `example/main.dart` for a complete runnable example.

## License

MIT
