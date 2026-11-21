# hiflutter_net_connectivity

[connectivity_plus](https://pub.dev/packages/connectivity_plus) implementation
of the `HiConnectivity` contract from `hiflutter_net`, part of
[HiFlutter](https://github.com/pcfprio/HiFlutter).

## Features

- **Zero `connectivity_plus` type leakage**: the primary library
  `package:hiflutter_net_connectivity/hiflutter_net_connectivity.dart` exports
  only `HiPlusConnectivity`.
- **Status mapping**: converts `List<ConnectivityResult>` from `check()` and
  `onStatusChanged` into `HiNetworkStatus.online` when non-empty and containing
  at least one non-`none` entry, or `HiNetworkStatus.offline` otherwise.
- **Duplicate suppression**: `onStatusChanged` deduplicates consecutive
  identical `HiNetworkStatus` values by default (`emitDistinct: true`), such as
  switching between Wi-Fi and cellular while remaining online.
- **Normalized errors**: converts platform exceptions and stream errors into
  `HiError` via `HiError.from`.

## Usage

```dart
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_connectivity/hiflutter_net_connectivity.dart';

Future<void> main() async {
  const HiConnectivity connectivity = HiPlusConnectivity();

  final status = await connectivity.check();
  if (status.isOnline) {
    // Proceed with network work.
  }

  final subscription = connectivity.onStatusChanged.listen((next) {
    // React to HiNetworkStatus.online / HiNetworkStatus.offline transitions.
  });
  await subscription.cancel();
}
```

See `example/main.dart` for a complete Flutter widget example.

## License

MIT
