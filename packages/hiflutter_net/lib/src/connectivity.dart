import 'dart:async';

/// Whether the device currently has network connectivity.
enum HiNetworkStatus {
  /// A network connection is available.
  online,

  /// No network connection is available.
  offline;

  /// Whether this status is [online].
  bool get isOnline => this == online;
}

/// Reports the current network status and emits subsequent changes.
abstract interface class HiConnectivity {
  /// Checks the current network status.
  Future<HiNetworkStatus> check();

  /// Emits each network status change.
  Stream<HiNetworkStatus> get onStatusChanged;
}

/// An in-memory [HiConnectivity] for tests and prototypes.
///
/// Starts at `initial` (defaulting to [HiNetworkStatus.online]), updates when
/// [emit] is called and closes [onStatusChanged] when [dispose] is called.
final class HiMemoryConnectivity implements HiConnectivity {
  /// Creates an in-memory connectivity source starting at [initial].
  HiMemoryConnectivity({HiNetworkStatus initial = HiNetworkStatus.online})
    : _status = initial;

  HiNetworkStatus _status;
  final StreamController<HiNetworkStatus> _controller =
      StreamController<HiNetworkStatus>.broadcast();

  @override
  Future<HiNetworkStatus> check() async => _status;

  @override
  Stream<HiNetworkStatus> get onStatusChanged => _controller.stream;

  /// Updates the current status to [status] and broadcasts it to listeners.
  void emit(HiNetworkStatus status) {
    _status = status;
    _controller.add(status);
  }

  /// Closes [onStatusChanged].
  Future<void> dispose() => _controller.close();
}
