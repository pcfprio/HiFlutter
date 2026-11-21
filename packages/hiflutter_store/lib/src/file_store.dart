import 'dart:convert';
import 'dart:typed_data';

import 'package:hiflutter_base/hiflutter_base.dart';

import 'guard.dart';

/// Raw file storage behind a [HiFileStore].
///
/// Adapter packages implement this interface on top of a file system. Every
/// `path` passed in has already been validated and normalized by
/// [HiFileStore]: it is relative, uses `/` separators and contains no `.`,
/// `..` or empty segments. Error mapping is done by [HiFileStore], so
/// implementations stay thin.
abstract interface class HiFileBackend {
  /// Returns the content of the file at [path], or `null` when it does not
  /// exist.
  Future<Uint8List?> read(String path);

  /// Writes [bytes] to the file at [path], creating parent directories and
  /// replacing any previous content.
  Future<void> write(String path, Uint8List bytes);

  /// Whether a file exists at [path].
  Future<bool> exists(String path);

  /// Deletes the file at [path]; does nothing when it does not exist.
  Future<void> delete(String path);
}

/// File storage addressed by relative paths such as `cache/avatar.png`.
///
/// Both `/` and `\` separate path segments, and `.` and empty segments are
/// ignored, so `docs/./a.txt` and `docs\a.txt` name the same file as
/// `docs/a.txt`. Paths that could escape the store are refused with a
/// [HiStorageError]: empty paths, absolute paths, Windows drive paths, paths
/// containing a `..` segment and paths containing a NUL character.
final class HiFileStore {
  /// Creates a store on top of [backend], such as a platform adapter.
  HiFileStore(this._backend);

  /// Creates a store that keeps files in memory only, for tests and
  /// previews.
  factory HiFileStore.memory() => HiFileStore(_MemoryBackend());

  final HiFileBackend _backend;

  static final _separators = RegExp(r'[/\\]');
  static final _drive = RegExp('^[A-Za-z]:');

  static String _normalize(String path) {
    Never refuse(String reason) =>
        throw HiStorageError(message: 'Refusing file path "$path": $reason');
    if (path.contains('\x00')) refuse('it contains a NUL character');
    if (path.startsWith(_separators) || path.startsWith(_drive)) {
      refuse('it must be relative');
    }
    final segments = [
      for (final segment in path.split(_separators))
        if (segment.isNotEmpty && segment != '.') segment,
    ];
    if (segments.contains('..')) refuse('".." segments are not allowed');
    if (segments.isEmpty) refuse('it names no file');
    return segments.join('/');
  }

  /// Returns the bytes of the file at [path], or `null` when it does not
  /// exist.
  Future<Uint8List?> readBytes(String path) async {
    final normalized = _normalize(path);
    return guardStorage(
      'read file "$normalized"',
      () => _backend.read(normalized),
    );
  }

  /// Writes [bytes] to the file at [path], replacing any previous content.
  Future<void> writeBytes(String path, List<int> bytes) async {
    final normalized = _normalize(path);
    await guardStorage(
      'write file "$normalized"',
      () => _backend.write(normalized, Uint8List.fromList(bytes)),
    );
  }

  /// Returns the content of the file at [path] decoded as UTF-8, or `null`
  /// when it does not exist.
  ///
  /// Throws a [HiDecodeError] when the content is not valid UTF-8.
  Future<String?> readText(String path) async {
    final bytes = await readBytes(path);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e, s) {
      throw HiDecodeError(
        message: 'The file "$path" is not valid UTF-8',
        cause: e,
        stackTrace: s,
      );
    }
  }

  /// Writes [text] encoded as UTF-8 to the file at [path].
  Future<void> writeText(String path, String text) =>
      writeBytes(path, utf8.encode(text));

  /// Whether a file exists at [path].
  Future<bool> exists(String path) async {
    final normalized = _normalize(path);
    return guardStorage(
      'check file "$normalized"',
      () => _backend.exists(normalized),
    );
  }

  /// Deletes the file at [path]; does nothing when it does not exist.
  Future<void> delete(String path) async {
    final normalized = _normalize(path);
    await guardStorage(
      'delete file "$normalized"',
      () => _backend.delete(normalized),
    );
  }
}

final class _MemoryBackend implements HiFileBackend {
  final _files = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String path) async => _files[path];

  @override
  Future<void> write(String path, Uint8List bytes) async =>
      _files[path] = bytes;

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<void> delete(String path) async => _files.remove(path);
}
