/// Raw string parameters of a matched URL, with typed accessors.
///
/// Path parameters take precedence over query parameters of the same name.
/// The `require*` accessors throw a [FormatException] when a value is
/// missing or malformed, which makes the URL not match the route.
final class HiRouteParams {
  /// Wraps [values].
  const HiRouteParams(this.values);

  /// All parameters, keyed by name.
  final Map<String, String> values;

  /// The value of [key], or `null` when absent.
  String? string(String key) => values[key];

  /// The value of [key].
  ///
  /// Throws a [FormatException] when absent.
  String requireString(String key) =>
      values[key] ?? (throw FormatException('Missing parameter "$key"'));

  /// The value of [key] as an [int], or `null` when absent.
  ///
  /// Throws a [FormatException] when present but not an integer.
  int? integer(String key) {
    final raw = values[key];
    if (raw == null) return null;
    return int.tryParse(raw) ??
        (throw FormatException('Parameter "$key" is not an integer', raw));
  }

  /// The value of [key] as a [bool], or `null` when absent.
  ///
  /// Accepts `true`/`false` and `1`/`0`; throws a [FormatException] for
  /// anything else.
  bool? boolean(String key) => switch (values[key]) {
    null => null,
    'true' || '1' => true,
    'false' || '0' => false,
    final raw => throw FormatException('Parameter "$key" is not a bool', raw),
  };

  /// The value of [key] as an [int].
  ///
  /// Throws a [FormatException] when absent or not an integer.
  int requireInt(String key) =>
      integer(key) ?? (throw FormatException('Missing parameter "$key"'));
}
