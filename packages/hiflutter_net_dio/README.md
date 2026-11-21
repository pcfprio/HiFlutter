# hiflutter_net_dio

[dio](https://pub.dev/packages/dio) implementation of the `HiTransport`
contract from `hiflutter_net`, part of
[HiFlutter](https://github.com/pcfprio/HiFlutter).

## Features

- **Zero `dio` type leakage**: the primary library
  `package:hiflutter_net_dio/hiflutter_net_dio.dart` exports only
  `HiDioTransport`, whose constructor takes standard `Duration?` timeouts.
- **Full `HiRequest` / `HiResponse` fidelity**: forwards method, URL, headers,
  raw body bytes, per-request timeout overrides and `HiCancelToken`
  cancellation, and returns all HTTP status codes (including 4xx and 5xx) as
  `HiResponse`.
- **Error normalization**: maps `DioException` timeouts to `HiTimeoutError`,
  cancellations to `HiCancelledError`, connection/certificate errors to
  `HiNetworkError` and any other failure via `HiError.from`.
- **Isolated test entrypoint**: `package:hiflutter_net_dio/testing.dart`
  provides `hiDioTransportWithAdapter` for tests that inject a custom
  `HttpClientAdapter`.

## Usage

```dart
import 'package:hiflutter_net/hiflutter_net.dart';
import 'package:hiflutter_net_dio/hiflutter_net_dio.dart';

final client = HiHttpClient(
  transport: HiDioTransport(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ),
  baseUrl: Uri.parse('https://api.example.com/v1/'),
  envelope: const HiEnvelope(),
);
```

See `example/main.dart` for a complete example.

## License

MIT
