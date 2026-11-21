import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';

void main() {
  group('HiPaginationState', () {
    test('initial constructor starts idle with unmodifiable empty items', () {
      final state = HiPaginationState<int>.initial();

      expect(state.status, HiPaginationStatus.idle);
      expect(state.items, isEmpty);
      expect(() => state.items.add(1), throwsUnsupportedError);
      expect(state.error, isNull);
      expect(state.hasMore, isFalse);
      expect(state.currentPage, 0);
      expect(state.isEmpty, isTrue);
      expect(state.isLoading, isFalse);
    });

    test('supports zero-based initialPage and value equality', () {
      final zero = HiPaginationState<String>.initial(initialPage: 0);
      expect(zero.currentPage, -1);

      final a = HiPaginationState<int>(
        status: HiPaginationStatus.idle,
        items: [1, 2],
        hasMore: true,
        currentPage: 1,
      );
      final b = a.copyWith(error: const HiNetworkError(message: 'offline'));
      final c = b.copyWith(clearError: true);

      expect(() => a.items.add(3), throwsUnsupportedError);
      expect(b.error, isA<HiNetworkError>());
      expect(c, equals(a));
      expect(c.hashCode, equals(a.hashCode));
    });
  });

  group('HiPaginationNotifier', () {
    test('loadInitial and loadMore transition through idle -> loading -> completed', () async {
      final requestedPages = <int>[];
      final statuses = <HiPaginationStatus>[];
      final provider =
          NotifierProvider<
            HiPaginationNotifier<String>,
            HiPaginationState<String>
          >(
            () => HiPaginationNotifier<String>(
              loader: (page) async {
                requestedPages.add(page);
                return HiPageSlice(
                  items: ['p$page-a', 'p$page-b'],
                  hasMore: page == 1,
                );
              },
            ),
          );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.listen(provider, (_, next) => statuses.add(next.status));
      final notifier = container.read(provider.notifier);

      await notifier.loadInitial();
      var state = container.read(provider);
      expect(requestedPages, [1]);
      expect(statuses, [
        HiPaginationStatus.initialLoading,
        HiPaginationStatus.idle,
      ]);
      expect(state.items, ['p1-a', 'p1-b']);
      expect(state.currentPage, 1);
      expect(state.hasMore, isTrue);
      expect(state.isEmpty, isFalse);
      expect(state.isLoading, isFalse);
      expect(() => state.items.add('x'), throwsUnsupportedError);

      await notifier.loadMore();
      state = container.read(provider);
      expect(requestedPages, [1, 2]);
      expect(statuses, [
        HiPaginationStatus.initialLoading,
        HiPaginationStatus.idle,
        HiPaginationStatus.loadingMore,
        HiPaginationStatus.completed,
      ]);
      expect(state.items, ['p1-a', 'p1-b', 'p2-a', 'p2-b']);
      expect(state.currentPage, 2);
      expect(state.hasMore, isFalse);

      // Subsequent loadMore is ignored once completed.
      await notifier.loadMore();
      expect(requestedPages, [1, 2]);
    });

    test('loadInitial failure wraps error with HiError.from and retries initial page', () async {
      var attempt = 0;
      final requestedPages = <int>[];
      final provider = hiPaginationProvider<int>(
        (_) => (page) async {
          requestedPages.add(page);
          attempt++;
          if (attempt == 1) {
            throw TimeoutException('slow');
          }
          return HiPageSlice(items: [1, 2, 3], hasMore: false);
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(provider.notifier);
      await notifier.loadInitial();

      var state = container.read(provider);
      expect(requestedPages, [1]);
      expect(state.status, HiPaginationStatus.failure);
      expect(state.error, isA<HiTimeoutError>());
      expect(state.items, isEmpty);
      expect(state.currentPage, 0);

      await notifier.retry();
      state = container.read(provider);
      expect(requestedPages, [1, 1]);
      expect(state.status, HiPaginationStatus.completed);
      expect(state.error, isNull);
      expect(state.items, [1, 2, 3]);
      expect(state.currentPage, 1);
    });

    test(
      'loadMore failure preserves items and page, then retry loads next page',
      () async {
        var failPage2 = true;
        final requestedPages = <int>[];
        final provider = hiPaginationProvider<int>(
          (_) => (page) async {
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
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(provider.notifier);
        await notifier.loadInitial();

        await notifier.loadMore();
        var state = container.read(provider);
        expect(requestedPages, [1, 2]);
        expect(state.status, HiPaginationStatus.failure);
        expect(state.error, isA<HiNetworkError>());
        expect(state.items, [1, 2]);
        expect(state.currentPage, 1);
        expect(state.hasMore, isTrue);

        failPage2 = false;
        await notifier.retry();
        state = container.read(provider);
        expect(requestedPages, [1, 2, 2]);
        expect(state.status, HiPaginationStatus.completed);
        expect(state.error, isNull);
        expect(state.items, [1, 2, 3, 4]);
        expect(state.currentPage, 2);
        expect(state.hasMore, isFalse);
      },
    );

    test(
      'refresh replaces items on success and preserves items on failure',
      () async {
        var mode = 'initial';
        final provider = hiPaginationProvider<String>(
          (_) =>
              (page) async => switch (mode) {
                'initial' => HiPageSlice(
                  items: ['old-1', 'old-2'],
                  hasMore: true,
                ),
                'fail' => throw const FormatException('bad json'),
                'ok' => HiPageSlice(items: ['new-1'], hasMore: false),
                _ => const HiPageSlice.empty(),
              },
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(provider.notifier);
        await notifier.loadInitial();

        mode = 'fail';
        await notifier.refresh();
        var state = container.read(provider);
        expect(state.items, ['old-1', 'old-2']);
        expect(state.hasMore, isTrue);
        expect(state.currentPage, 1);
        expect(state.status, HiPaginationStatus.idle);
        expect(state.error, isA<HiDecodeError>());

        mode = 'ok';
        await notifier.refresh();
        state = container.read(provider);
        expect(state.items, ['new-1']);
        expect(state.hasMore, isFalse);
        expect(state.currentPage, 1);
        expect(state.status, HiPaginationStatus.completed);
        expect(state.error, isNull);

        mode = 'fail';
        await notifier.refresh();
        state = container.read(provider);
        expect(state.items, ['new-1']);
        expect(state.status, HiPaginationStatus.completed);
        expect(state.error, isA<HiDecodeError>());
      },
    );

    test(
      'refresh while empty transitions to failure and retries initial page',
      () async {
        var attempt = 0;
        final provider = hiPaginationProvider<int>(
          (_) => (page) async {
            attempt++;
            if (attempt == 1) {
              throw const HiServerError(statusCode: 500);
            }
            return HiPageSlice(items: [page], hasMore: false);
          },
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(provider.notifier);
        await notifier.refresh();
        var state = container.read(provider);
        expect(state.status, HiPaginationStatus.failure);
        expect(state.error, isA<HiServerError>());
        expect(state.items, isEmpty);

        await notifier.retry();
        state = container.read(provider);
        expect(state.status, HiPaginationStatus.completed);
        expect(state.items, [1]);
        expect(state.currentPage, 1);
      },
    );

    test('ignores concurrent re-entrant calls while loading', () async {
      final completer = Completer<HiPageSlice<int>>();
      var calls = 0;
      final provider = hiPaginationProvider<int>(
        (_) => (page) {
          calls++;
          return completer.future;
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(provider.notifier);
      final inFlight = notifier.loadInitial();
      expect(
        container.read(provider).status,
        HiPaginationStatus.initialLoading,
      );
      expect(container.read(provider).isLoading, isTrue);

      await notifier.loadInitial();
      await notifier.refresh();
      await notifier.loadMore();
      await notifier.retry();
      expect(calls, 1);
      expect(
        container.read(provider).status,
        HiPaginationStatus.initialLoading,
      );

      completer.complete(HiPageSlice(items: [10], hasMore: false));
      await inFlight;
      final state = container.read(provider);
      expect(state.status, HiPaginationStatus.completed);
      expect(state.items, [10]);
    });

    test(
      'reset invalidates in-flight response and restores initial state',
      () async {
        final firstCompleter = Completer<HiPageSlice<int>>();
        var calls = 0;
        final provider = hiPaginationProvider<int>(
          (_) => (page) {
            calls++;
            if (calls == 1) return firstCompleter.future;
            return Future.value(HiPageSlice(items: [page], hasMore: true));
          },
          initialPage: 0,
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(provider).currentPage, -1);

        final notifier = container.read(provider.notifier);
        final inFlight = notifier.loadInitial();
        expect(
          container.read(provider).status,
          HiPaginationStatus.initialLoading,
        );

        notifier.reset();
        var state = container.read(provider);
        expect(state.status, HiPaginationStatus.idle);
        expect(state.items, isEmpty);
        expect(state.error, isNull);
        expect(state.hasMore, isFalse);
        expect(state.currentPage, -1);

        await notifier.loadInitial();
        state = container.read(provider);
        expect(state.items, [0]);
        expect(state.currentPage, 0);

        firstCompleter.complete(HiPageSlice(items: [999], hasMore: false));
        await inFlight;
        state = container.read(provider);
        expect(state.items, [0]);
        expect(state.status, HiPaginationStatus.idle);
        expect(state.currentPage, 0);
      },
    );

    test(
      'container.dispose safely drops late async completion and failure',
      () async {
        final successCompleter = Completer<HiPageSlice<int>>();
        final successProvider = hiPaginationProvider<int>(
          (_) =>
              (_) => successCompleter.future,
        );
        final errorCompleter = Completer<HiPageSlice<int>>();
        final errorProvider = hiPaginationProvider<int>(
          (_) =>
              (_) => errorCompleter.future,
        );

        final container = ProviderContainer();
        var notifications = 0;
        container.listen(successProvider, (_, _) => notifications++);

        final successNotifier = container.read(successProvider.notifier);
        final errorNotifier = container.read(errorProvider.notifier);

        final f1 = successNotifier.loadInitial();
        final f2 = errorNotifier.loadInitial();
        expect(notifications, 1);

        container.dispose();

        successCompleter.complete(HiPageSlice(items: [1, 2], hasMore: true));
        errorCompleter.completeError(StateError('late error'));
        await Future.wait([f1, f2]);

        expect(notifications, 1);

        // Post-dispose calls are harmless no-ops.
        await successNotifier.loadInitial();
        await successNotifier.refresh();
        await successNotifier.loadMore();
        await successNotifier.retry();
        successNotifier.reset();
      },
    );

    test('ignores loadMore before any initial page is loaded', () async {
      var calls = 0;
      final provider = hiPaginationProvider<int>(
        (_) => (_) async {
          calls++;
          return HiPageSlice(items: [1], hasMore: true);
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(provider.notifier).loadMore();
      expect(calls, 0);
      expect(container.read(provider).status, HiPaginationStatus.idle);
    });

    test('hiPaginationProvider reads dependencies from Ref and drops stale work on rebuild', () async {
      final firstCompleter = Completer<HiPageSlice<String>>();
      final firstClient = HiHttpClient(
        transport: HiMemoryTransport((_) => HiResponse(statusCode: 200)),
        baseUrl: Uri.parse('https://v1.example.com'),
      );
      final secondClient = HiHttpClient(
        transport: HiMemoryTransport((_) => HiResponse(statusCode: 200)),
        baseUrl: Uri.parse('https://v2.example.com'),
      );

      final provider = hiPaginationProvider<String>((ref) {
        final client = ref.watch(hiHttpClientProvider);
        return (page) {
          if (client == firstClient) {
            return firstCompleter.future;
          }
          return Future.value(
            HiPageSlice(items: ['v2-page-$page'], hasMore: false),
          );
        };
      });

      final container = ProviderContainer(
        overrides: [hiHttpClientProvider.overrideWithValue(firstClient)],
      );
      addTearDown(container.dispose);

      final inFlight = container.read(provider.notifier).loadInitial();
      expect(
        container.read(provider).status,
        HiPaginationStatus.initialLoading,
      );

      container.updateOverrides([
        hiHttpClientProvider.overrideWithValue(secondClient),
      ]);
      expect(container.read(provider).status, HiPaginationStatus.idle);
      expect(container.read(provider).items, isEmpty);

      firstCompleter.complete(HiPageSlice(items: ['stale'], hasMore: true));
      await inFlight;
      expect(container.read(provider).items, isEmpty);

      await container.read(provider.notifier).loadInitial();
      expect(container.read(provider).items, ['v2-page-1']);
      expect(container.read(provider).status, HiPaginationStatus.completed);
    });

    test(
      'hiPaginationProviderFamily isolates pagination state per argument',
      () async {
        final searchProvider = hiPaginationProviderFamily<String, String>(
          (_, query) =>
              (page) async =>
                  HiPageSlice(items: ['$query-$page'], hasMore: false),
          isAutoDispose: true,
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Keep autoDispose providers active across async gaps.
        final subA = container.listen(searchProvider('dart'), (_, _) {});
        final subB = container.listen(searchProvider('flutter'), (_, _) {});
        addTearDown(subA.close);
        addTearDown(subB.close);

        await container.read(searchProvider('dart').notifier).loadInitial();
        await container.read(searchProvider('flutter').notifier).loadInitial();

        expect(container.read(searchProvider('dart')).items, ['dart-1']);
        expect(container.read(searchProvider('flutter')).items, ['flutter-1']);
      },
    );
  });
}
