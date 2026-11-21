/// Pure Dart networking contract of HiFlutter.
///
/// [HiHttpClient] sends requests through a pluggable [HiTransport] with
/// [HiHttpInterceptor] chains, decodes replies with a configurable
/// [HiEnvelope], models paginated lists with [HiPageResult], defines the
/// [HiConnectivity] contract and maps every failure to the `HiError` model of
/// `hiflutter_base`.
library;

export 'src/client.dart';
export 'src/connectivity.dart';
export 'src/envelope.dart';
export 'src/interceptor.dart';
export 'src/page_result.dart';
export 'src/reply.dart';
export 'src/request.dart';
export 'src/response.dart';
export 'src/transport.dart';
