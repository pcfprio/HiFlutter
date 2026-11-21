import 'scalar.dart';

/// Joins [parts] and [values] into one console line, for example
/// `[analytics] track signup plan="pro" seats=3`.
String consoleLine(
  String tag,
  List<String> parts, [
  Map<String, HiScalar> values = const {},
]) => [
  '[$tag]',
  ...parts,
  for (final MapEntry(:key, :value) in values.entries)
    '$key=${switch (value) {
      HiStringScalar(:final value) => '"$value"',
      _ => '$value',
    }}',
].join(' ');
