/// Allow-list that decides whether an incoming deep link may be routed.
///
/// A link is allowed only when its scheme is in [schemes] and its host is in
/// [hosts]; both comparisons ignore case. A host entry of the form
/// `*.example.com` allows every subdomain of `example.com` but not
/// `example.com` itself. Links without a scheme or host are rejected.
final class HiDeepLinkGuard {
  /// Creates a guard allowing [schemes] and [hosts].
  ///
  /// Throws an [ArgumentError] when either set is empty.
  HiDeepLinkGuard({required Set<String> schemes, required Set<String> hosts})
    : schemes = _lower(schemes, 'schemes'),
      hosts = _lower(hosts, 'hosts');

  /// Allowed schemes, in lower case.
  final Set<String> schemes;

  /// Allowed hosts, in lower case; entries may start with `*.`.
  final Set<String> hosts;

  /// Whether [uri] may be routed.
  bool allows(Uri uri) {
    if (!uri.hasScheme || !schemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    return hosts.any(
      (allowed) => allowed.startsWith('*.')
          ? host.endsWith(allowed.substring(1))
          : host == allowed,
    );
  }

  static Set<String> _lower(Set<String> values, String name) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, name, 'must not be empty');
    }
    return Set.unmodifiable({for (final value in values) value.toLowerCase()});
  }
}
