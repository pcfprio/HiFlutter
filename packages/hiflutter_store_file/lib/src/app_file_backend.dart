import 'dart:io';
import 'dart:typed_data';

import 'package:hiflutter_store/hiflutter_store.dart';
import 'package:path_provider/path_provider.dart';

/// App-private directory that a [HiAppFileBackend] stores files in.
enum HiAppDirectory {
  /// Persistent files the user does not manage directly
  /// (`getApplicationSupportDirectory`). The default.
  support,

  /// User documents (`getApplicationDocumentsDirectory`); visible in the
  /// Files app on iOS when file sharing is enabled.
  documents,

  /// Re-creatable files the system may delete under storage pressure
  /// (`getApplicationCacheDirectory`).
  cache,
}

/// A [HiFileBackend] that stores files with `dart:io` under an app-private
/// directory provided by path_provider.
///
/// Wrap it in a [HiFileStore]:
///
/// ```dart
/// final files = HiFileStore(HiAppFileBackend());
/// await files.writeText('notes/today.txt', 'hello');
/// ```
final class HiAppFileBackend implements HiFileBackend {
  /// Creates a backend storing files under [directory].
  HiAppFileBackend({this.directory = HiAppDirectory.support});

  /// The app-private directory that files are stored in.
  final HiAppDirectory directory;

  String? _root;

  Future<String> _resolveRoot() async => (await switch (directory) {
    HiAppDirectory.support => getApplicationSupportDirectory(),
    HiAppDirectory.documents => getApplicationDocumentsDirectory(),
    HiAppDirectory.cache => getApplicationCacheDirectory(),
  }).path;

  Future<File> _file(String path) async {
    final root = _root ??= await _resolveRoot();
    return File(
      '$root${Platform.pathSeparator}'
      '${path.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  @override
  Future<Uint8List?> read(String path) async {
    final file = await _file(path);
    try {
      return await file.readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final file = await _file(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<bool> exists(String path) async => (await _file(path)).exists();

  @override
  Future<void> delete(String path) async {
    try {
      await (await _file(path)).delete();
    } on PathNotFoundException {
      // Already absent.
    }
  }
}
