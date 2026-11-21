/// Pure Dart storage contracts of HiFlutter: [HiKeyValueStore] for plain
/// values and JSON, [HiSecureStore] for secrets and [HiFileStore] for files
/// addressed by relative paths, each with an in-memory implementation and a
/// backend interface that platform adapters implement.
library;

export 'src/file_store.dart';
export 'src/key_value_store.dart';
export 'src/secure_store.dart';
