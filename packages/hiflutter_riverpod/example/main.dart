import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_suite/hiflutter_suite.dart';

final postsProvider = hiPaginationProvider<String>(
  (_) =>
      (page) async =>
          HiPageSlice(items: ['Item $page-1', 'Item $page-2'], hasMore: false),
);

Future<void> main() async {
  final logger = HiLogger([const HiLogRoute(HiConsoleLogSink())]);
  const reporter = HiNoOpCrashReporter();

  await HiRiverpodBootstrap.run(
    logger: logger,
    reporter: reporter,
    overrides: hiProviderOverrides(keyValueStore: HiKeyValueStore.memory()),
    child: const _DemoApp(),
  );
}

class _DemoApp extends ConsumerWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagination = ref.watch(postsProvider);
    return WidgetsApp(
      color: const Color(0xFF1565C0),
      home: Center(child: Text('Loaded ${pagination.items.length} item(s)')),
    );
  }
}
