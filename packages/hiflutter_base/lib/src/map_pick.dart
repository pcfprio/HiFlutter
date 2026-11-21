import 'convert.dart';

/// Multi-candidate lookup for maps whose keys vary between backends.
///
/// A `keys` argument lists candidate keys separated by `|`, such as
/// `'user_id|uid|id'`. Candidates are trimmed, empty ones are ignored, and
/// the value of the first candidate that is present and not `null` wins.
/// Keys that themselves contain `|` cannot be looked up this way.
extension HiMapPick on Map<String, Object?> {
  /// The value of the first candidate in [keys] that is present and not
  /// `null`, or `null` when there is none.
  Object? pick(String keys) {
    for (final candidate in keys.split('|')) {
      final key = candidate.trim();
      if (key.isEmpty) continue;
      final value = this[key];
      if (value != null) return value;
    }
    return null;
  }

  /// [pick] converted with [HiConvert.asInt].
  int? pickInt(String keys) => HiConvert.asInt(pick(keys));

  /// [pick] converted with [HiConvert.asDouble].
  double? pickDouble(String keys) => HiConvert.asDouble(pick(keys));

  /// [pick] converted with [HiConvert.asBool].
  bool? pickBool(String keys) => HiConvert.asBool(pick(keys));

  /// [pick] converted with [HiConvert.asString].
  String? pickString(String keys) => HiConvert.asString(pick(keys));

  /// [pick] converted with [HiConvert.asList].
  List<T>? pickList<T>(String keys, [T? Function(Object?)? convert]) =>
      HiConvert.asList<T>(pick(keys), convert);

  /// [pick] converted with [HiConvert.asMap].
  Map<String, Object?>? pickMap(String keys) => HiConvert.asMap(pick(keys));
}
