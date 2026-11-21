# hiflutter_riverpod

Optional Riverpod integration package for HiFlutter (ADR-0002). Core HiFlutter contracts remain state-management agnostic; add `hiflutter_riverpod` when your app uses Riverpod for state management and dependency injection.

## Features

- **Contract providers**: Typed `Provider`s for `HiLogger`, `HiConsent`, `HiAnalytics`, `HiCrashReporter`, `HiHttpClient`, `HiConnectivity`, `HiKeyValueStore`, `HiSecureStore`, `HiFileStore`, `HiNavigator`, `HiLinkOpener`, and `HiDeviceInfoSource`. Reading an unconfigured provider throws `HiUnconfiguredProviderError` with setup instructions.
- **Pagination adapter**: `HiPaginationNotifier` and `HiPaginationState` adapt `hiflutter_suite`'s pagination state machine to Riverpod 3 `Notifier`s (`hiPaginationProvider`, `hiPaginationProviderFamily`).
- **Ordered startup skeleton**: `HiRiverpodBootstrap.run` executes `HiLog.install` -> `HiErrorCapture.install` -> guarded `ProviderScope` -> `runApp`.

## Usage

```dart
import 'package:flutter/widgets.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_riverpod/hiflutter_riverpod.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

Future<void> main() async {
  final logger = HiLogger([const HiLogRoute(HiConsoleLogSink())]);
  const reporter = HiNoOpCrashReporter();

  await HiRiverpodBootstrap.run(
    logger: logger,
    reporter: reporter,
    overrides: hiProviderOverrides(
      keyValueStore: HiKeyValueStore.memory(),
    ),
    child: const MyApp(),
  );
}
```
