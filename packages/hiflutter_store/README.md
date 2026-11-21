# hiflutter_store

Pure Dart storage contracts of [HiFlutter](https://github.com/pcfprio/HiFlutter).
It depends only on `hiflutter_base` and works in any Dart or Flutter project.

## Features

- **`HiKeyValueStore`**: strings, integers, doubles, booleans and JSON
  values. Writes to keys that look like credentials (`password`, `token`,
  `secret`, `apiKey`, ...) are refused with a `HiStorageError`, so secrets
  cannot end up in unencrypted storage by accident.
- **`HiSecureStore`**: small secret values such as tokens, kept in the
  platform's encrypted storage.
- **`HiFileStore`**: bytes and UTF-8 text addressed by relative paths.
  Absolute paths and `..` segments are refused, so a path can never escape
  the store.
- **In-memory implementations**: `HiKeyValueStore.memory()`,
  `HiSecureStore.memory()` and `HiFileStore.memory()` need no platform
  channel, which makes unit tests trivial.
- **One error model**: every failure is a `HiError` from `hiflutter_base`;
  platform exceptions become `HiStorageError`, unreadable values become
  `HiDecodeError`.

## Platform implementations

Each store wraps a small backend interface (`HiKeyValueBackend`,
`HiSecureBackend`, `HiFileBackend`). Ready-made backends live in adapter
packages:

| Store | Package | Backend |
|---|---|---|
| `HiKeyValueStore` | `hiflutter_store_prefs` | `HiPrefsKeyValueBackend` |
| `HiSecureStore` | `hiflutter_store_secure` | `HiSecureStorageBackend` |
| `HiFileStore` | `hiflutter_store_file` | `HiAppFileBackend` |

## Usage

```dart
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_store/hiflutter_store.dart';

final settings = HiKeyValueStore.memory();
await settings.setBool('onboarded', true);
await settings.setJson('profile', {'id': 7, 'name': 'Ada'});

try {
  await settings.setString('accessToken', '...');
} on HiStorageError {
  // Credentials belong in a HiSecureStore.
}

final files = HiFileStore.memory();
await files.writeText('notes/today.txt', 'hello');
```

See `example/main.dart` for a complete example.

## License

MIT
