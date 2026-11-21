# hiflutter_store_file

[path_provider](https://pub.dev/packages/path_provider) and `dart:io`
adapter for [`hiflutter_store`](https://pub.dev/packages/hiflutter_store):
app-private file storage behind the `HiFileStore` contract.

## Usage

```dart
import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:hiflutter_store_file/hiflutter_store_file.dart';

final files = HiFileStore(HiAppFileBackend());
await files.writeText('drafts/note.txt', 'hello');
final note = await files.readText('drafts/note.txt');

final cache = HiFileStore(HiAppFileBackend(directory: HiAppDirectory.cache));
await cache.writeBytes('thumbs/1.png', pngBytes);
```

`HiAppDirectory` selects the app-private directory:

- `support` (default): persistent files the user does not manage.
- `documents`: user documents.
- `cache`: re-creatable files the system may delete.

Paths are relative to that directory; absolute paths and `..` segments are
refused. Parent directories are created on write. File system and
path_provider failures surface as `HiStorageError`.

In unit tests, use `HiFileStore.memory()` instead.

## License

MIT
