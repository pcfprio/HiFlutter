## 0.1.0

- Initial release: `HiDioTransport`, a `dio`-backed `HiTransport`
  implementation that maps `HiRequest`, `HiResponse`, `HiCancelToken` and
  `DioException`s to `hiflutter_net` / `hiflutter_base` types without
  exposing `dio` in the public API, plus `package:hiflutter_net_dio/testing.dart`
  for adapter injection in tests.
