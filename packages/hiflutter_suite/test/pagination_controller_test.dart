import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';

void main() {
  group('HiPaginationController', () {
    test('starts idle with empty unmodifiable items', () {
      final controller = HiPaginationController<int>(
        loader: (_) async => const HiPageSlice.empty(),
      );
      addTearDown(controller.dispose);

      expect(controller.status, HiPaginationStatus.idle);
      expect(controller.items, isEmpty);
      expect(() => controller.items.add(1), throwsUnsupportedError);
      expect(controller.error, isNull);
      expect(controller.hasMore, isFalse);
      expect(controller.currentPage, 0);
      expect(controller.isEmpty, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test(
      'loadInitial transitions idle -> initialLoading -> idle/completed',
      () async {
        final statuses = <HiPaginationStatus>[];
        final requestedPages = <int>[];
        final controller = HiPaginationController<String>(
          loader: (page) async {
            requestedPages.add(page);
            return HiPageSlice(items: ['a', 'b'], hasMore: page == 1);
          },
        );
        addTearDown(controller.dispose);
        controller.addListener(() => statuses.add(controller.status));

        await controller.loadInitial();
        expect(requestedPages, [1]);
        expect(statuses, [
          HiPaginationStatus.initialLoading,
          HiPaginationStatus.idle,
        ]);
        expect(controller.items, ['a', 'b']);
        expect(controller.currentPage, 1);
        expect(controller.hasMore, isTrue);
        expect(controller.isEmpty, isFalse);
        expect(controller.isLoading, isFalse);
        expect(() => controller.items.add('x'), throwsUnsupportedError);

        await controller.loadMore();
        expect(requestedPages, [1, 2]);
        expect(statuses, [
          HiPaginationStatus.initialLoading,
          HiPaginationStatus.idle,
          HiPaginationStatus.loadingMore,
          HiPaginationStatus.completed,
        ]);
        expect(controller.items, ['a', 'b', 'a', 'b']);
        expect(controller.currentPage, 2);
        expect(controller.hasMore, isFalse);

        // Subsequent loadMore is ignored once completed.
        await controller.loadMore();
        expect(requestedPages, [1, 2]);
      },
    );

    test(
      'loadInitial failure wraps error with HiError.from and retries initial',
      () async {
        var attempt = 0;
        final requestedPages = <int>[];
        final controller = HiPaginationController<int>(
          loader: (page) async {
            requestedPages.add(page);
            attempt++;
            if (attempt == 1) {
              throw TimeoutException('slow');
            }
            return HiPageSlice(items: [1, 2, 3], hasMore: false);
          },
        );
        addTearDown(controller.dispose);

        await controller.loadInitial();
        expect(requestedPages, [1]);
        expect(controller.status, HiPaginationStatus.failure);
        expect(controller.error, isA<HiTimeoutError>());
        expect(controller.items, isEmpty);
        expect(controller.currentPage, 0);

        await controller.retry();
        expect(requestedPages, [1, 1]);
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.error, isNull);
        expect(controller.items, [1, 2, 3]);
        expect(controller.currentPage, 1);
      },
    );

    test(
      'loadMore failure preserves items and page, then retry loads next page',
      () async {
        var failPage2 = true;
        final requestedPages = <int>[];
        final controller = HiPaginationController<int>(
          loader: (page) async {
            requestedPages.add(page);
            if (page == 1) {
              return HiPageSlice(items: [1, 2], hasMore: true);
            }
            if (failPage2) {
              throw const HiNetworkError(message: 'offline');
            }
            return HiPageSlice(items: [3, 4], hasMore: false);
          },
        );
        addTearDown(controller.dispose);

        await controller.loadInitial();
        expect(controller.items, [1, 2]);
        expect(controller.currentPage, 1);

        await controller.loadMore();
        expect(requestedPages, [1, 2]);
        expect(controller.status, HiPaginationStatus.failure);
        expect(controller.error, isA<HiNetworkError>());
        expect(controller.items, [1, 2]);
        expect(controller.currentPage, 1);
        expect(controller.hasMore, isTrue);

        failPage2 = false;
        await controller.retry();
        expect(requestedPages, [1, 2, 2]);
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.error, isNull);
        expect(controller.items, [1, 2, 3, 4]);
        expect(controller.currentPage, 2);
        expect(controller.hasMore, isFalse);
      },
    );

    test(
      'refresh replaces items on success and preserves items on failure',
      () async {
        var mode = 'initial';
        final controller = HiPaginationController<String>(
          loader: (page) async {
            return switch (mode) {
              'initial' => HiPageSlice(
                items: ['old-1', 'old-2'],
                hasMore: true,
              ),
              'fail' => throw const FormatException('bad json'),
              'ok' => HiPageSlice(items: ['new-1'], hasMore: false),
              _ => const HiPageSlice.empty(),
            };
          },
        );
        addTearDown(controller.dispose);

        await controller.loadInitial();
        expect(controller.items, ['old-1', 'old-2']);
        expect(controller.status, HiPaginationStatus.idle);

        // Refresh failure while items already exist keeps items and returns to
        // idle (controllable state) while exposing the error.
        mode = 'fail';
        await controller.refresh();
        expect(controller.items, ['old-1', 'old-2']);
        expect(controller.hasMore, isTrue);
        expect(controller.currentPage, 1);
        expect(controller.status, HiPaginationStatus.idle);
        expect(controller.error, isA<HiDecodeError>());

        // Refresh success clears the previous error and updates items/status.
        mode = 'ok';
        await controller.refresh();
        expect(controller.items, ['new-1']);
        expect(controller.hasMore, isFalse);
        expect(controller.currentPage, 1);
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.error, isNull);

        // Refresh failure when already completed returns to completed.
        mode = 'fail';
        await controller.refresh();
        expect(controller.items, ['new-1']);
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.error, isA<HiDecodeError>());
      },
    );

    test('ignores concurrent re-entrant calls while loading', () async {
      final completer = Completer<HiPageSlice<int>>();
      var calls = 0;
      final controller = HiPaginationController<int>(
        loader: (page) {
          calls++;
          return completer.future;
        },
      );
      addTearDown(controller.dispose);

      final f1 = controller.loadInitial();
      expect(controller.status, HiPaginationStatus.initialLoading);
      expect(controller.isLoading, isTrue);

      await controller.loadInitial();
      await controller.refresh();
      await controller.loadMore();
      await controller.retry();
      expect(calls, 1);
      expect(controller.status, HiPaginationStatus.initialLoading);

      completer.complete(HiPageSlice(items: [10], hasMore: false));
      await f1;
      expect(controller.status, HiPaginationStatus.completed);
      expect(controller.items, [10]);
    });

    test('reset cancels in-flight response and restores initial state', () async {
      final firstCompleter = Completer<HiPageSlice<int>>();
      var calls = 0;
      final controller = HiPaginationController<int>(
        initialPage: 0,
        loader: (page) {
          calls++;
          if (calls == 1) return firstCompleter.future;
          return Future.value(HiPageSlice(items: [page], hasMore: true));
        },
      );
      addTearDown(controller.dispose);

      expect(controller.currentPage, -1);

      final inFlight = controller.loadInitial();
      expect(controller.status, HiPaginationStatus.initialLoading);

      controller.reset();
      expect(controller.status, HiPaginationStatus.idle);
      expect(controller.items, isEmpty);
      expect(controller.error, isNull);
      expect(controller.hasMore, isFalse);
      expect(controller.currentPage, -1);

      // Start a new request and let the stale first request resolve afterward.
      await controller.loadInitial();
      expect(controller.items, [0]);
      expect(controller.currentPage, 0);

      firstCompleter.complete(HiPageSlice(items: [999], hasMore: false));
      await inFlight;

      expect(controller.items, [0]);
      expect(controller.status, HiPaginationStatus.idle);
      expect(controller.currentPage, 0);
    });

    test(
      'dispose safely drops late async completions without notifying',
      () async {
        final completer = Completer<HiPageSlice<int>>();
        final controller = HiPaginationController<int>(
          loader: (_) => completer.future,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        final future = controller.loadInitial();
        expect(notifications, 1);

        controller.dispose();
        completer.complete(HiPageSlice(items: [1, 2], hasMore: true));
        await future;

        expect(notifications, 1);
        expect(controller.items, isEmpty);

        // Calls after dispose are harmless no-ops.
        await controller.loadInitial();
        await controller.refresh();
        await controller.loadMore();
        await controller.retry();
        controller.reset();
        controller.dispose();
      },
    );

    test('ignores loadMore before any initial page is loaded', () async {
      var calls = 0;
      final controller = HiPaginationController<int>(
        loader: (_) async {
          calls++;
          return HiPageSlice(items: [1], hasMore: true);
        },
      );
      addTearDown(controller.dispose);

      await controller.loadMore();
      expect(calls, 0);
      expect(controller.status, HiPaginationStatus.idle);
    });

    test(
      'refresh while empty transitions to failure and retries initial page',
      () async {
        var attempt = 0;
        final controller = HiPaginationController<int>(
          loader: (page) async {
            attempt++;
            if (attempt == 1) {
              throw const HiServerError(statusCode: 500);
            }
            return HiPageSlice(items: [page], hasMore: false);
          },
        );
        addTearDown(controller.dispose);

        await controller.refresh();
        expect(controller.status, HiPaginationStatus.failure);
        expect(controller.error, isA<HiServerError>());
        expect(controller.items, isEmpty);

        await controller.retry();
        expect(controller.status, HiPaginationStatus.completed);
        expect(controller.items, [1]);
        expect(controller.currentPage, 1);
      },
    );
  });
}
