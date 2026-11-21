# hiflutter_net

Pure Dart networking contract of [HiFlutter](https://github.com/pcfprio/HiFlutter).
It depends only on `hiflutter_base` and defines a transport-agnostic HTTP
client, response envelope decoding, pagination models and a connectivity
contract.

## Features

- **Transport-agnostic HTTP client**: `HiHttpClient` supports `get`, `post`,
  `put`, `patch`, `delete`, `head` and `request`, with per-attempt
  `HiHeadersProvider`, `defaultTimeout` fallback, `HiCancelToken`
  cancellation and an `onUnauthorized` hook.
- **Interceptor chain**: `HiHttpInterceptor` lets callers transform
  `HiRequest`, `HiResponse` and `HiError` in order around any `HiTransport`.
- **Configurable response envelope**: `HiEnvelope` decodes JSON envelopes
  with `|`-separated candidate keys (`codeKeys`, `messageKeys`, `dataKeys`),
  `successCodes` and `unauthorizedCodes`, and unpacks payloads into typed
  models via `HiReply.object`, `HiReply.list` or `HiReply.decode`.
- **Layered error mapping & redacted logging**: every HTTP, envelope, decode
  or transport failure maps to a `HiError` from `hiflutter_base`. Requests,
  responses and failures are logged under `module: 'net'` through `HiLogger`
  or the global `HiLog` entry, keeping default redaction active.
- **Pagination & connectivity contracts**: `HiPageResult<T>` represents paged
  items with `map`, while `HiConnectivity` / `HiNetworkStatus` /
  `HiMemoryConnectivity` model connectivity status.
- **In-memory test doubles**: `HiMemoryTransport` and
  `HiMemoryConnectivity` allow deterministic unit testing without real I/O.

## Usage

```dart
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';

final transport = HiMemoryTransport(
  (request) => HiResponse.json(200, {
    'code': 0,
    'message': 'ok',
    'data': {'id': 1, 'name': 'Ada'},
  }),
);

final client = HiHttpClient(
  transport: transport,
  baseUrl: Uri.parse('https://api.example.com/v1/'),
  envelope: const HiEnvelope(unauthorizedCodes: {'40101'}),
  defaultTimeout: const Duration(seconds: 15),
  onUnauthorized: (error, request) {
    // Trigger sign-out or token refresh notification.
  },
);

final user = await client.get('users/me').object((json) => json.pickString('name'));
```

See `example/main.dart` for a complete example.

## License

MIT
