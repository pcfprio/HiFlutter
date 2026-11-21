import 'package:flutter/widgets.dart';

/// Utilities for parsing hex color strings into [Color] values.
abstract final class HiColor {
  static final _hexDigits = RegExp(r'^[0-9a-fA-F]+$');

  /// Parses a hex string into a [Color].
  ///
  /// Accepts `#RGB`, `#RRGGBB`, and `#AARRGGBB` formats, with or without a
  /// leading `#` and regardless of letter case. Throws a [FormatException]
  /// when [hex] does not match one of these formats.
  static Color parseHex(String hex) {
    final parsed = tryParseHex(hex);
    if (parsed == null) {
      throw FormatException('Invalid hex color', hex);
    }
    return parsed;
  }

  /// Attempts to parse a hex string into a [Color], returning `null` if
  /// [hex] is invalid.
  ///
  /// Accepts `#RGB`, `#RRGGBB`, and `#AARRGGBB` formats, with or without a
  /// leading `#` and regardless of letter case.
  static Color? tryParseHex(String hex) {
    var digits = hex.trim();
    if (digits.startsWith('#')) {
      digits = digits.substring(1);
    }
    if (!_hexDigits.hasMatch(digits)) return null;

    final String argb;
    switch (digits.length) {
      case 3:
        final r = digits[0];
        final g = digits[1];
        final b = digits[2];
        argb = 'FF$r$r$g$g$b$b';
      case 6:
        argb = 'FF$digits';
      case 8:
        argb = digits;
      default:
        return null;
    }
    return Color(int.parse(argb, radix: 16));
  }
}

/// Convenience color helpers on [Color].
extension HiColorExtension on Color {
  /// Formats this color as an uppercase hex string, such as `'#12ABEF'` or
  /// `'#8012ABEF'`.
  ///
  /// Set [leadingHash] to `false` to omit the `#` prefix, and [includeAlpha]
  /// to `true` to prepend the alpha byte.
  String toHex({bool leadingHash = true, bool includeAlpha = false}) {
    final argb = toARGB32();
    final rgb = (argb & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    final prefix = leadingHash ? '#' : '';
    if (!includeAlpha) return '$prefix$rgb';
    final alpha = ((argb >> 24) & 0xFF)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    return '$prefix$alpha$rgb';
  }

  /// Contrasting foreground color (`#000000` or `#FFFFFF`) computed from
  /// relative luminance.
  Color get onColor {
    // Matches Flutter's luminance contrast threshold so mid-tone primaries
    // (such as #2196F3) receive white foregrounds.
    final luminance = computeLuminance();
    const threshold = 0.15;
    return (luminance + 0.05) * (luminance + 0.05) > threshold
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }

  /// Returns a copy of this color with its current alpha channel multiplied by
  /// [factor], clamped to `[0.0, 1.0]`.
  ///
  /// Throws an [ArgumentError] if [factor] is `NaN`.
  Color scaleAlpha(double factor) {
    if (factor.isNaN) {
      throw ArgumentError.value(factor, 'factor', 'must not be NaN');
    }
    return withValues(alpha: (a * factor).clamp(0.0, 1.0));
  }
}

/// MediaQuery shortcuts on [BuildContext] using fine-grained aspect lookups.
extension HiContextExtension on BuildContext {
  /// Logical size of the enclosing media, equivalent to `MediaQuery.sizeOf`.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Safe-area view padding of the enclosing media, equivalent to
  /// `MediaQuery.viewPaddingOf`.
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  /// Platform brightness of the enclosing media, equivalent to
  /// `MediaQuery.platformBrightnessOf`.
  Brightness get platformBrightness => MediaQuery.platformBrightnessOf(this);

  /// Whether [platformBrightness] is [Brightness.dark].
  bool get isDarkMode => platformBrightness == Brightness.dark;
}
