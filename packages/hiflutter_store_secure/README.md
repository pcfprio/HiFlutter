# hiflutter_store_secure

[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
adapter for [`hiflutter_store`](https://pub.dev/packages/hiflutter_store):
encrypted storage for tokens and other secrets (Keychain on iOS,
Keystore-protected storage on Android) behind the `HiSecureStore` contract.

## Usage

```dart
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_secure/hiflutter_store_secure.dart';

final secrets = HiSecureStore(HiSecureStorageBackend());
await secrets.write('accessToken', token);
final saved = await secrets.read('accessToken');
await secrets.delete('accessToken');
```

The plugin's default options are used. Platform exceptions surface as
`HiStorageError`; no flutter_secure_storage type appears in the API.

`deleteAll()` deletes every value the app stored with flutter_secure_storage,
including values written outside HiFlutter.

In unit tests, use `HiSecureStore.memory()` instead.

## License

MIT
