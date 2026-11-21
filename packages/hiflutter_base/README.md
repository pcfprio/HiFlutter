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
- **Analytics and crash reporting contracts**: `HiAnalytics` (`track`,
  `identify`, `page`, `reset`, `flush`) and `HiCrashReporter`
  (`captureException`, `captureMessage`, `setContext`, `addBreadcrumb`),
  with values restricted to the sealed `HiScalar` type. Each comes with
  no-op, console, composite (fan-out with failure isolation) and
  consent-gated implementations. No vendor SDK is included; write an adapter
  for yours.
- **Privacy consent gate**: `HiConsent` holds an observable
  `unknown` / `granted` / `denied` status. The consent-gated implementations
  drop every outgoing call until consent is granted; unknown counts as not
  granted, and analytics `reset` always passes through.

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

Analytics and crash reporting are injected, never global. Wire them in the
composition root behind the user's consent:

```dart
final consent = HiConsent(); // Restore a persisted decision via `initial`.
final HiAnalytics analytics = HiConsentGatedAnalytics(
  HiCompositeAnalytics([const HiConsoleAnalytics(), myVendorAnalytics]),
  consent: consent,
);

await analytics.track('signup', properties: {'plan': HiScalar('pro')});
// Dropped: consent is still unknown.

consent.grant();
await analytics.track('signup', properties: {'plan': HiScalar('pro')});
// Sent to every delegate.
```

See `example/main.dart` for a complete example.

## License

MIT
