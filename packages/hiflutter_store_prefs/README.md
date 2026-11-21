# hiflutter_store_prefs

[shared_preferences](https://pub.dev/packages/shared_preferences) adapter for
[`hiflutter_store`](https://pub.dev/packages/hiflutter_store): persistent
key-value storage (`NSUserDefaults` on iOS, `DataStore` on Android) behind
the `HiKeyValueStore` contract.

## Usage

```dart
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_prefs/hiflutter_store_prefs.dart';

final settings = HiKeyValueStore(HiPrefsKeyValueBackend());
await settings.setString('theme', 'dark');
final theme = await settings.getString('theme');
```

Everything `HiKeyValueStore` promises applies: credential-like keys are
refused, JSON values round-trip, and platform exceptions surface as
`HiStorageError`. No shared_preferences type appears in the API.

`clear()` deletes every shared preference of the app, including values
written outside HiFlutter.

In unit tests, use `HiKeyValueStore.memory()` instead.

## License

MIT
