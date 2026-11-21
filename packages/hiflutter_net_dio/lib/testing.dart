/// Testing helpers for `hiflutter_net_dio`.
///
/// Import this library only in test code when you need to inject a fake
/// `HttpClientAdapter` into `HiDioTransport`.
library;

export 'src/dio_transport.dart' show hiDioTransportWithAdapter;
