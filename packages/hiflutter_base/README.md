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
- **Logging**: a `HiLogger` sends each record to several `HiLogRoute`s,
  each with its own minimum level and `HiRedaction` policy. The default
  route drops `debug` and hides sensitive keys (`password`, `token`,
  `authorization`, `cookie`, `secret`, ...), Bearer tokens, JWTs and
  token-like URL query parameters; raw output needs an explicit
  `HiRedaction.none()`. Sinks implement `HiLogSink` and only ever receive
  read-only, already processed `HiLogRecord`s. Install the global `HiLog`
  entry once at startup and log from anywhere; before that, logging does
  nothing. Messages are closures, so filtered logs cost nothing.
  `HiConsoleLogSink` writes to the developer console.
- **Lenient conversion**: `HiConvert.asInt`, `asDouble`, `asBool`,
  `asString`, `asList` and `asMap` turn loosely typed JSON values into Dart
  types, returning `null` instead of throwing.
- **Multi-candidate lookup**: `map.pick('id|uid')` and its typed variants
  (`pickInt`, `pickString`, ...) read the first present key, for backends
  whose field names disagree.

## Usage

```dart
import 'package:hiflutter_base/hiflutter_base.dart';

// Once, in the composition root.
HiLog.install(HiLogger([
  HiLogRoute(const HiConsoleLogSink(), minLevel: HiLogLevel.debug),
]));

// Anywhere.
HiLog.info(
  () => 'GET /feed?access_token=abc', // logged as access_token=[REDACTED]
  module: 'net',
  attributes: {'Authorization': 'Bearer abc'}, // logged as [REDACTED]
);

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
