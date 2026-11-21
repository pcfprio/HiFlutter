import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A [ValueNotifier] that is safe to change at any time.
///
/// - Changing [value] after [dispose] updates nothing and does not throw,
///   for example when an async callback finishes after its page closed.
///   Calling [dispose] again does not throw either.
/// - Changing [value] while a frame is being built, laid out or painted
///   delays the notification until the end of that frame, so listeners such
///   as a [ValueListenableBuilder] never call `setState` during build. A
///   delayed notification is dropped if the notifier is disposed first.
class HiSafeValueNotifier<T> extends ValueNotifier<T> {
  /// Creates a notifier holding [value].
  HiSafeValueNotifier(super.value);

  bool _disposed = false;
  bool _notificationScheduled = false;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      scheduler.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
