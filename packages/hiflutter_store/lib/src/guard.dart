import 'package:hiflutter_base/hiflutter_base.dart';

/// Runs a backend operation, turning any non-[HiError] failure into a
/// [HiStorageError] that keeps the original only as diagnostics.
Future<T> guardStorage<T>(String action, Future<T> Function() operation) async {
  try {
    return await operation();
  } on HiError {
    rethrow;
  } catch (e, s) {
    throw HiStorageError(message: 'Failed to $action', cause: e, stackTrace: s);
  }
}
