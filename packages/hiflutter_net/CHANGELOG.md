## 0.1.0

- Initial release: `HiHttpClient` with `get`, `post`, `put`, `patch`,
  `delete`, `head` and `request`, `defaultTimeout`, `HiCancelToken`,
  `HiHttpInterceptor` chain, `onUnauthorized` callback and redacted
  `module: 'net'` logging.
- `HiTransport` contract and `HiMemoryTransport` test double, plus `HiRequest`
  and `HiResponse`.
- Configurable `HiEnvelope` decoder and `HiReply` (`object`, `list`, `decode`)
  with layered `HiError` mapping.
- `HiPageResult<T>` pagination model and `HiConnectivity` /
  `HiNetworkStatus` / `HiMemoryConnectivity` contracts.
