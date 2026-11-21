/// Calls [call] on every delegate concurrently, isolating failures.
///
/// A delegate that throws, synchronously or asynchronously, never prevents
/// the others from being called. Each failure goes to [onError]; without
/// [onError], the first failure in delegate order is rethrown once every
/// delegate has finished.
Future<void> fanOut<T>(
  List<T> delegates,
  Future<void> Function(T delegate) call,
  void Function(Object error, StackTrace stackTrace)? onError,
) async {
  final outcomes = await Future.wait([
    for (final delegate in delegates)
      Future<void>.sync(() => call(delegate)).then<(Object, StackTrace)?>(
        (_) => null,
        onError: (Object error, StackTrace stackTrace) => (error, stackTrace),
      ),
  ]);
  final failures = outcomes.nonNulls;
  if (onError != null) {
    for (final (error, stackTrace) in failures) {
      onError(error, stackTrace);
    }
  } else if (failures.isNotEmpty) {
    final (error, stackTrace) = failures.first;
    Error.throwWithStackTrace(error, stackTrace);
  }
}
