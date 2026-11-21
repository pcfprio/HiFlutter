import 'dart:async';

import 'request.dart';
import 'response.dart';

/// Moves a [HiRequest] over the wire and returns the [HiResponse].
///
/// Implementations live in adapter packages, such as `hiflutter_net_dio`.
/// A transport must:
///
/// - return every HTTP status, including 4xx and 5xx, as a [HiResponse];
/// - throw a `HiError` (from `hiflutter_base`) when no response could be
///   obtained: `HiNetworkError` for connection failures, `HiTimeoutError`
///   when [HiRequest.timeout] elapsed, `HiCancelledError` when
///   [HiRequest.cancelToken] was cancelled;
/// - never expose its own library's types.
abstract interface class HiTransport {
  /// Sends [request] and returns its response.
  Future<HiResponse> send(HiRequest request);

  /// Releases the resources held by this transport.
  Future<void> close();
}

/// Handles a request sent to a [HiMemoryTransport].
typedef HiMemoryHandler = FutureOr<HiResponse> Function(HiRequest request);

/// An in-memory [HiTransport] for tests and prototypes.
///
/// Every request is recorded in [requests] and answered by the handler; a
/// handler may also throw a `HiError` to simulate a failed exchange.
final class HiMemoryTransport implements HiTransport {
  /// Creates a transport that answers every request with [handler].
  HiMemoryTransport(this._handler);

  final HiMemoryHandler _handler;
  final _requests = <HiRequest>[];

  /// Every request sent so far, oldest first.
  List<HiRequest> get requests => List.unmodifiable(_requests);

  @override
  Future<HiResponse> send(HiRequest request) async {
    _requests.add(request);
    return _handler(request);
  }

  @override
  Future<void> close() async {}
}
