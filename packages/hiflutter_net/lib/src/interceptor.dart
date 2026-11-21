import 'dart:async';

import 'package:hiflutter_base/hiflutter_base.dart';

import 'request.dart';
import 'response.dart';

/// Intercepts HTTP requests, responses and errors around a `HiTransport`.
///
/// Subclasses can override any subset of [onRequest], [onResponse] and
/// [onError]; the default implementations return their input unchanged.
/// Interceptors run in the order they were provided to `HiHttpClient`.
abstract class HiHttpInterceptor {
  /// Creates an interceptor.
  const HiHttpInterceptor();

  /// Called before [request] is handed to the transport.
  FutureOr<HiRequest> onRequest(HiRequest request) => request;

  /// Called after [response] arrives from the transport, before HTTP status
  /// mapping and envelope decoding run.
  FutureOr<HiResponse> onResponse(HiRequest request, HiResponse response) =>
      response;

  /// Called when the request fails with [error], before it is rethrown.
  FutureOr<HiError> onError(HiRequest request, HiError error) => error;
}
