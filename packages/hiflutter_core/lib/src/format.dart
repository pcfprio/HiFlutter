/// Locale-independent formatting of numbers, compact counts, and file sizes
/// for display.
abstract final class HiFormat {
  static const _binaryUnits = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  static const _compactUnits = ['', 'K', 'M', 'B', 'T'];

  /// Formats [value] with thousands grouping using [groupSeparator] and a
  /// fixed [fractionDigits] count of decimal places.
  ///
  /// Non-finite values (`NaN`, `Infinity`, `-Infinity`) are returned via
  /// `toString()`. Negative zero and values that round to zero omit the `-`
  /// sign. Throws an [ArgumentError] if [fractionDigits] is negative.
  static String number(
    num value, {
    int fractionDigits = 0,
    String groupSeparator = ',',
  }) {
    _checkFractionDigits(fractionDigits);
    if (!value.isFinite) return value.toString();

    final String fixed;
    if (value is int) {
      final raw = value < 0 ? value.toString().substring(1) : value.toString();
      fixed = fractionDigits == 0 ? raw : '$raw.${'0' * fractionDigits}';
    } else {
      fixed = value.abs().toStringAsFixed(fractionDigits);
    }
    final isZero = fixed.replaceAll('0', '').replaceAll('.', '').isEmpty;
    final sign = value < 0 && !isZero ? '-' : '';

    final dot = fixed.indexOf('.');
    final intPart = dot == -1 ? fixed : fixed.substring(0, dot);
    final fracPart = dot == -1 ? '' : fixed.substring(dot);

    final grouped = intPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => groupSeparator,
    );
    return '$sign$grouped$fracPart';
  }

  /// Formats [value] in a compact form with `K`, `M`, `B` or `T` suffixes,
  /// such as `'1.5K'` or `'1M'`.
  ///
  /// Rounds to [fractionDigits], carries to the next unit when rounding reaches
  /// 1000, and drops trailing decimal zeros. Non-finite values are returned via
  /// `toString()`. Throws an [ArgumentError] if [fractionDigits] is negative.
  static String compact(num value, {int fractionDigits = 1}) {
    _checkFractionDigits(fractionDigits);
    if (!value.isFinite) return value.toString();

    final (:formatted, :unit) = _scale(
      value.abs().toDouble(),
      step: 1000,
      fractionDigits: fractionDigits,
      units: _compactUnits,
    );
    final sign = value < 0 && formatted != '0' ? '-' : '';
    return '$sign$formatted$unit';
  }

  /// Formats a size of [bytes] with the largest fitting unit, such as
  /// `'1.5 KB'` or `'3.29 MB'`.
  ///
  /// Units step by 1024 by default, or by 1000 when [binary] is `false`; the
  /// unit names are `B`, `KB`, `MB`, `GB`, `TB` and `PB` either way. The
  /// value is rounded to [fractionDigits], moves to the next unit if rounding
  /// reaches the step boundary, and drops trailing zeros.
  /// Throws an [ArgumentError] if [bytes] or [fractionDigits] is negative.
  static String fileSize(
    int bytes, {
    int fractionDigits = 2,
    bool binary = true,
  }) {
    if (bytes < 0) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be negative');
    }
    _checkFractionDigits(fractionDigits);

    final (:formatted, :unit) = _scale(
      bytes.toDouble(),
      step: binary ? 1024 : 1000,
      fractionDigits: fractionDigits,
      units: _binaryUnits,
    );
    return '$formatted $unit';
  }

  static void _checkFractionDigits(int fractionDigits) {
    if (fractionDigits < 0) {
      throw ArgumentError.value(
        fractionDigits,
        'fractionDigits',
        'must not be negative',
      );
    }
  }

  static ({String formatted, String unit}) _scale(
    double absValue, {
    required int step,
    required int fractionDigits,
    required List<String> units,
  }) {
    var value = absValue;
    var unit = 0;
    while (value >= step && unit < units.length - 1) {
      value /= step;
      unit++;
    }
    var roundedText = value.toStringAsFixed(fractionDigits);
    if (unit < units.length - 1 && double.parse(roundedText) >= step) {
      value = double.parse(roundedText) / step;
      unit++;
      roundedText = value.toStringAsFixed(fractionDigits);
    }
    return (formatted: _trimTrailingZeros(roundedText), unit: units[unit]);
  }

  static String _trimTrailingZeros(String text) {
    if (!text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
