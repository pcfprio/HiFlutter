## 0.1.0

- Initial release: layered `HiError` model, `HiConvert` lenient type
  conversion and `'a|b'` multi-candidate map lookup.
- Logging: `HiLogger` routes each record to several `HiLogRoute`s, each with
  its own minimum level and `HiRedaction` policy (sensitive keys, Bearer
  tokens, JWTs and token-like URL query parameters are hidden by default);
  the install-once global `HiLog` entry with lazy messages; and the
  `HiConsoleLogSink` console sink.
