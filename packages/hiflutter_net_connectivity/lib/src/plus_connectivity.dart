import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:hiflutter_net/hiflutter_net.dart';

/// [HiConnectivity] backed by `connectivity_plus`.
///
/// Third-party plugin types never leak through the public API; any platform
/// failure is normalized into a [HiError] via [HiError.from].
final class HiPlusConnectivity implements HiConnectivity {
  /// Creates a `connectivity_plus` adapter.
  ///
  /// When [emitDistinct] is `true` (the default), [onStatusChanged] suppresses
  /// consecutive identical [HiNetworkStatus] values, for example when the
  /// device switches between Wi-Fi and cellular while staying
  /// [HiNetworkStatus.online].
  const HiPlusConnectivity({this.emitDistinct = true});

  /// Whether [onStatusChanged] suppresses consecutive identical statuses.
  final bool emitDistinct;

  static final StreamTransformer<HiNetworkStatus, HiNetworkStatus>
  _errorTransformer =
      StreamTransformer<HiNetworkStatus, HiNetworkStatus>.fromHandlers(
        handleData: (status, sink) => sink.add(status),
        handleError: (error, stackTrace, sink) =>
            sink.addError(HiError.from(error, stackTrace), stackTrace),
      );

  @override
  Future<HiNetworkStatus> check() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _mapResults(results);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(HiError.from(error, stackTrace), stackTrace);
    }
  }

  @override
  Stream<HiNetworkStatus> get onStatusChanged {
    try {
      final mapped = Connectivity().onConnectivityChanged
          .map(_mapResults)
          .transform(_errorTransformer);
      return emitDistinct ? mapped.distinct() : mapped;
    } catch (error, stackTrace) {
      return Stream<HiNetworkStatus>.error(
        HiError.from(error, stackTrace),
        stackTrace,
      );
    }
  }

  static HiNetworkStatus _mapResults(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    return hasConnection ? HiNetworkStatus.online : HiNetworkStatus.offline;
  }
}
