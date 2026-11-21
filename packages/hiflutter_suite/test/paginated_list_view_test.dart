import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: HiSuiteLocalizations.supportedLocales,
    localizationsDelegates: HiSuiteLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  group('HiLoadMoreFooter', () {
    testWidgets(
      'renders all four statuses in EN and ZH without Material ancestor',
      (tester) async {
        var loadMoreCalls = 0;
        var retryCalls = 0;

        // Loading without Scaffold/Material ancestor.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: const HiLoadMoreFooter(status: HiLoadMoreStatus.loading),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading more...'), findsOneWidget);

        // Can load more.
        await tester.pumpWidget(
          _wrap(
            HiLoadMoreFooter(
              status: HiLoadMoreStatus.canLoadMore,
              onLoadMore: () => loadMoreCalls++,
            ),
          ),
        );
        expect(find.text('Load more'), findsOneWidget);
        await tester.tap(find.text('Load more'));
        expect(loadMoreCalls, 1);

        // No more in Chinese.
        await tester.pumpWidget(
          _wrap(
            const HiLoadMoreFooter(status: HiLoadMoreStatus.noMore),
            locale: const Locale('zh'),
          ),
        );
        expect(find.text('没有更多了'), findsOneWidget);

        // Hidden when noMoreLabel is empty string.
        await tester.pumpWidget(
          _wrap(
            const HiLoadMoreFooter(
              status: HiLoadMoreStatus.noMore,
              noMoreLabel: '',
            ),
          ),
        );
        expect(find.byType(Text), findsNothing);

        // Failed in Chinese and English with parameter overrides.
        await tester.pumpWidget(
          _wrap(
            HiLoadMoreFooter(
              status: HiLoadMoreStatus.failed,
              onRetry: () => retryCalls++,
            ),
            locale: const Locale('zh'),
          ),
        );
        expect(find.text('加载失败'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        await tester.tap(find.text('重试'));
        expect(retryCalls, 1);

        await tester.pumpWidget(
          _wrap(
            HiLoadMoreFooter(
              status: HiLoadMoreStatus.failed,
              failedLabel: 'Could not fetch page',
              retryLabel: 'Tap to retry',
              onRetry: () => retryCalls++,
            ),
          ),
        );
        expect(find.text('Could not fetch page'), findsOneWidget);
        expect(find.text('Tap to retry'), findsOneWidget);
        await tester.tap(find.byType(HiLoadMoreFooter));
        expect(retryCalls, 2);
      },
    );
  });

  group('HiPaginatedListView', () {
    testWidgets('auto-loads initial page and transitions loading -> content', (
      tester,
    ) async {
      final completer = Completer<HiPageSlice<String>>();
      final controller = HiPaginationController<String>(
        loader: (_) => completer.future,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          HiPaginatedListView<String>(
            controller: controller,
            itemBuilder: (context, item, index) => ListTile(title: Text(item)),
          ),
        ),
      );

      // Post-frame callback starts initialLoading.
      await tester.pump();
      expect(find.byType(HiLoadingView), findsOneWidget);

      completer.complete(HiPageSlice(items: ['Alpha', 'Beta'], hasMore: false));
      await tester.pump();

      expect(find.byType(HiLoadingView), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('No more items'), findsOneWidget);
    });

    testWidgets('respects autoLoad false and renders emptyView override', (
      tester,
    ) async {
      var calls = 0;
      final controller = HiPaginationController<String>(
        loader: (_) async {
          calls++;
          return const HiPageSlice.empty();
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          HiPaginatedListView<String>(
            controller: controller,
            autoLoad: false,
            emptyView: const Text('Custom Empty Slot'),
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );
      await tester.pump();

      expect(calls, 0);
      expect(find.text('Custom Empty Slot'), findsOneWidget);

      await controller.loadInitial();
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Custom Empty Slot'), findsOneWidget);
    });

    testWidgets(
      'renders initial error view, retries, and supports errorBuilder',
      (tester) async {
        var attempt = 0;
        final controller = HiPaginationController<String>(
          loader: (page) async {
            attempt++;
            if (attempt == 1) {
              throw const HiNetworkError();
            }
            return HiPageSlice(items: ['Recovered Item'], hasMore: false);
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: controller,
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
            ),
            locale: const Locale('zh'),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(HiErrorView), findsOneWidget);
        expect(find.text('网络不可用'), findsOneWidget);

        await tester.tap(find.text('重试'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Recovered Item'), findsOneWidget);
        expect(find.byType(HiErrorView), findsNothing);

        // Verify custom errorBuilder override.
        final customController = HiPaginationController<String>(
          loader: (_) async => throw const HiServerError(statusCode: 500),
        );
        addTearDown(customController.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: customController,
              errorBuilder: (context, error, retry) => TextButton(
                onPressed: retry,
                child: Text('CustomErr:${error.kind.name}'),
              ),
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('CustomErr:server'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to empty state when initial load fails with HiCancelledError',
      (tester) async {
        final controller = HiPaginationController<String>(
          loader: (_) async => throw const HiCancelledError(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: controller,
              emptyTitle: 'Nothing loaded',
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Nothing loaded'), findsOneWidget);
      },
    );

    testWidgets(
      'supports separatorBuilder without adding separator before footer',
      (tester) async {
        final controller = HiPaginationController<String>(
          loader: (_) async =>
              HiPageSlice(items: ['One', 'Two'], hasMore: false),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: controller,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (context, index) =>
                  Divider(key: ValueKey('sep-$index')),
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const ValueKey('sep-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('sep-1')), findsNothing);
        expect(find.byType(HiLoadMoreFooter), findsOneWidget);
      },
    );

    testWidgets('pulls to refresh via RefreshIndicator', (tester) async {
      var version = 1;
      final controller = HiPaginationController<String>(
        loader: (_) async =>
            HiPageSlice(items: ['Item v$version'], hasMore: false),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          HiPaginatedListView<String>(
            controller: controller,
            itemBuilder: (context, item, index) =>
                SizedBox(height: 80, child: Text(item)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Item v1'), findsOneWidget);

      version = 2;
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Item v2'), findsOneWidget);
      expect(find.text('Item v1'), findsNothing);
    });

    testWidgets(
      'auto-loads next page near bottom, shows footer failure, and retries on tap',
      (tester) async {
        var failPage2 = true;
        var page2Calls = 0;
        final controller = HiPaginationController<String>(
          loader: (page) async {
            if (page == 1) {
              return HiPageSlice(
                items: List.generate(15, (i) => 'Row $i'),
                hasMore: true,
              );
            }
            page2Calls++;
            if (failPage2) {
              throw const HiNetworkError();
            }
            return HiPageSlice(items: ['Row 15', 'Row 16'], hasMore: false);
          },
        );
        addTearDown(controller.dispose);

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: controller,
              scrollController: scrollController,
              itemBuilder: (context, item, index) =>
                  SizedBox(height: 64, child: Text(item)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Row 0'), findsOneWidget);
        expect(page2Calls, 0);

        // Scroll near the bottom to trigger loadMore automatically.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();

        expect(page2Calls, 1);
        expect(controller.status, HiPaginationStatus.failure);
        expect(find.byType(HiLoadMoreFooter), findsOneWidget);
        expect(find.text('Failed to load more'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Additional scroll while failed does not auto-retry endlessly.
        scrollController.jumpTo(scrollController.position.maxScrollExtent - 20);
        await tester.pump();
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();
        expect(page2Calls, 1);

        // Tapping the footer retries and appends page 2.
        failPage2 = false;
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();

        expect(page2Calls, 2);
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.items.length, 17);

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();
        expect(find.text('Row 16'), findsOneWidget);
        expect(find.text('No more items'), findsOneWidget);
      },
    );

    testWidgets(
      'supports tapping canLoadMore footer, displays loading footer, and switches controllers',
      (tester) async {
        final page2Completer = Completer<HiPageSlice<String>>();
        final firstController = HiPaginationController<String>(
          loader: (page) async {
            if (page == 1) {
              return HiPageSlice(items: ['First'], hasMore: true);
            }
            return page2Completer.future;
          },
        );
        addTearDown(firstController.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: firstController,
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Load more'), findsOneWidget);

        await tester.tap(find.text('Load more'));
        await tester.pump();
        expect(find.text('Loading more...'), findsOneWidget);

        page2Completer.complete(HiPageSlice(items: ['Second'], hasMore: false));
        await tester.pump();
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('No more items'), findsOneWidget);

        // Switching to a fresh idle controller auto-loads its initial page.
        final secondController = HiPaginationController<String>(
          loader: (_) async => HiPageSlice(items: ['Switched'], hasMore: false),
        );
        addTearDown(secondController.dispose);

        await tester.pumpWidget(
          _wrap(
            HiPaginatedListView<String>(
              controller: secondController,
              itemBuilder: (context, item, index) =>
                  ListTile(title: Text(item)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Switched'), findsOneWidget);
      },
    );
  });
}
