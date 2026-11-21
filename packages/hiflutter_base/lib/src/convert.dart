/// Lenient conversion of loosely typed values, such as decoded JSON.
///
/// Every method returns `null` instead of throwing when the value cannot be
/// converted, so callers choose their own fallback with `??`.
abstract final class HiConvert {
  // 2^63: the first double outside the 64-bit integer range.
  static const double _intLimit = 9223372036854775808.0;

  /// Converts [value] to an `int`.
  ///
  /// Accepts integers, finite doubles (truncated toward zero), numeric
  /// strings (trimmed; decimals and exponents allowed) and booleans (`1` /
  /// `0`). Returns `null` for anything else, including NaN, infinities and
  /// values outside the 64-bit range.
  static int? asInt(Object? value) => switch (value) {
    int() => value,
    double() => _truncate(value),
    bool() => value ? 1 : 0,
    String() => _parseInt(value.trim()),
    _ => null,
  };

  /// Converts [value] to a finite `double`.
  ///
  /// Accepts numbers, numeric strings (trimmed) and booleans (`1.0` /
  /// `0.0`). Returns `null` for anything else, including NaN and infinities.
  static double? asDouble(Object? value) {
    final result = switch (value) {
      num() => value.toDouble(),
      bool() => value ? 1.0 : 0.0,
      String() => double.tryParse(value.trim()),
      _ => null,
    };
    return result != null && result.isFinite ? result : null;
  }

  /// Converts [value] to a `bool`.
  ///
  /// Accepts booleans, the numbers `1` and `0`, and the strings `true`,
  /// `yes`, `y`, `on`, `1` and `false`, `no`, `n`, `off`, `0` (trimmed, any
  /// letter case). Returns `null` for anything else.
  static bool? asBool(Object? value) => switch (value) {
    bool() => value,
    num() when value == 1 => true,
    num() when value == 0 => false,
    String() => switch (value.trim().toLowerCase()) {
      'true' || 'yes' || 'y' || 'on' || '1' => true,
      'false' || 'no' || 'n' || 'off' || '0' => false,
      _ => null,
    },
    _ => null,
  };

  /// Converts [value] to a `String`.
  ///
  /// Strings are returned as they are; numbers and booleans are formatted
  /// with `toString`. Returns `null` for anything else, including lists and
  /// maps.
  static String? asString(Object? value) => switch (value) {
    String() => value,
    num() || bool() => value.toString(),
    _ => null,
  };

  /// Converts [value] to a `List<T>`.
  ///
  /// Each element goes through [convert] (for example [asInt]) when given,
  /// or is kept only if it already is a `T` otherwise; elements that fail
  /// are dropped. Returns `null` when [value] is not a list.
  static List<T>? asList<T>(Object? value, [T? Function(Object?)? convert]) {
    if (value is! List) return null;
    if (convert == null) return value.whereType<T>().toList();
    return [
      for (final element in value)
        if (convert(element) case final T converted) converted,
    ];
  }

  /// Converts [value] to a `Map<String, Object?>`, stringifying keys.
  ///
  /// Returns `null` when [value] is not a map.
  static Map<String, Object?>? asMap(Object? value) => switch (value) {
    Map<String, Object?>() => value,
    Map() => {for (final MapEntry(:key, value: v) in value.entries) '$key': v},
    _ => null,
  };

  static int? _truncate(double value) =>
      value.isFinite && value >= -_intLimit && value < _intLimit
      ? value.truncate()
      : null;

  static int? _parseInt(String text) {
    if (text.isEmpty) return null;
    final whole = int.tryParse(text);
    if (whole != null) return whole;
    // Integer-looking text that failed to parse is out of range.
    if (RegExp(r'^[+-]?\d+$').hasMatch(text)) return null;
    final decimal = double.tryParse(text);
    return decimal == null ? null : _truncate(decimal);
  }
}
