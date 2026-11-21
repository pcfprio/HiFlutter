# hiflutter_base

Pure Dart foundation of [HiFlutter](https://github.com/pcfprio/HiFlutter).
It has no third-party dependencies and works in any Dart or Flutter project.

## Features

- **Layered error model**: every failure is a sealed `HiError` subtype
  (`HiNetworkError`, `HiTimeoutError`, `HiUnauthorizedError`,
  `HiForbiddenError`, `HiNotFoundError`, `HiServerError`, `HiDecodeError`,
  `HiCancelledError`, `HiStorageError`, `HiUnknownError`) with a
  `retryable` flag and a `display` category for localized UI. The original
  exception is kept only as `diagnostics` text, so third-party types never
  leak into your code.
- **Lenient conversion**: `HiConvert.asInt`, `asDouble`, `asBool`,
  `asString`, `asList` and `asMap` turn loosely typed JSON values into Dart
  types, returning `null` instead of throwing.
- **Multi-candidate lookup**: `map.pick('id|uid')` and its typed variants
  (`pickInt`, `pickString`, ...) read the first present key, for backends
  whose field names disagree.

## Usage

```dart
import 'package:hiflutter_base/hiflutter_base.dart';

final json = {'uid': '42', 'vip': 'yes'};
final id = json.pickInt('id|uid');       // 42
final vip = json.pickBool('is_vip|vip'); // true

try {
  // ...
} catch (e, s) {
  final error = HiError.from(e, s);
  if (error.retryable) {
    // Offer a retry button.
  }
}
```

See `example/main.dart` for a complete example.

## License

MIT
