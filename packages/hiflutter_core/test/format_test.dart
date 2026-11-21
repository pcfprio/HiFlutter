import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  group('fileSize', () {
    test('uses 1024-based units and trims trailing zeros', () {
      expect(HiFormat.fileSize(0), '0 B');
      expect(HiFormat.fileSize(1023), '1023 B');
      expect(HiFormat.fileSize(1024), '1 KB');
      expect(HiFormat.fileSize(1536), '1.5 KB');
      expect(HiFormat.fileSize(1024 * 1024 * 3 + 1024 * 300), '3.29 MB');
      expect(HiFormat.fileSize(5 * 1024 * 1024 * 1024), '5 GB');
      expect(HiFormat.fileSize(1024 * 1024 * 1024 * 1024 * 2), '2 TB');
    });

    test('rounds to fractionDigits', () {
      expect(HiFormat.fileSize(1536, fractionDigits: 0), '2 KB');
      expect(HiFormat.fileSize(1100, fractionDigits: 1), '1.1 KB');
    });

    test('moves to the next unit when rounding reaches it', () {
      expect(HiFormat.fileSize(1024 * 1024 - 1), '1 MB');
      expect(HiFormat.fileSize(999999, binary: false), '1 MB');
    });

    test('can use 1000-based units', () {
      expect(HiFormat.fileSize(1500, binary: false), '1.5 KB');
      expect(HiFormat.fileSize(999, binary: false), '999 B');
    });

    test('rejects negative sizes', () {
      expect(() => HiFormat.fileSize(-1), throwsArgumentError);
    });
  });

  group('number', () {
    test('groups integer digits by thousands', () {
      expect(HiFormat.number(0), '0');
      expect(HiFormat.number(999), '999');
      expect(HiFormat.number(1000), '1,000');
      expect(HiFormat.number(1234567), '1,234,567');
    });

    test('formats fixed fractionDigits and handles decimals', () {
      expect(HiFormat.number(1234.5, fractionDigits: 2), '1,234.50');
      expect(HiFormat.number(1234.567, fractionDigits: 2), '1,234.57');
      expect(HiFormat.number(1234.5, fractionDigits: 0), '1,235');
      expect(HiFormat.number(0.5, fractionDigits: 2), '0.50');
    });

    test('supports negative numbers without negative zero', () {
      expect(HiFormat.number(-1234), '-1,234');
      expect(HiFormat.number(-1234567.89, fractionDigits: 2), '-1,234,567.89');
      expect(HiFormat.number(-0.0), '0');
      expect(HiFormat.number(-0.001, fractionDigits: 2), '0.00');
    });

    test('supports custom groupSeparator', () {
      expect(HiFormat.number(1234567, groupSeparator: ' '), '1 234 567');
      expect(
        HiFormat.number(1234567.5, fractionDigits: 1, groupSeparator: '_'),
        '1_234_567.5',
      );
    });

    test('preserves precision for large integers when fractionDigits is 0', () {
      expect(HiFormat.number(9007199254740993), '9,007,199,254,740,993');
    });

    test('handles non-finite numbers and rejects negative fractionDigits', () {
      expect(HiFormat.number(double.nan), 'NaN');
      expect(HiFormat.number(double.infinity), 'Infinity');
      expect(HiFormat.number(double.negativeInfinity), '-Infinity');
      expect(
        () => HiFormat.number(10, fractionDigits: -1),
        throwsArgumentError,
      );
    });
  });

  group('compact', () {
    test('formats values with K, M, B, T units and drops trailing zeros', () {
      expect(HiFormat.compact(0), '0');
      expect(HiFormat.compact(999), '999');
      expect(HiFormat.compact(1000), '1K');
      expect(HiFormat.compact(1500), '1.5K');
      expect(HiFormat.compact(1200000), '1.2M');
      expect(HiFormat.compact(1500000000), '1.5B');
      expect(HiFormat.compact(2000000000000), '2T');
      expect(HiFormat.compact(1500000000000000), '1500T');
    });

    test('supports custom fractionDigits and drops trailing zeros', () {
      expect(HiFormat.compact(1234, fractionDigits: 2), '1.23K');
      expect(HiFormat.compact(1200, fractionDigits: 2), '1.2K');
      expect(HiFormat.compact(12.34, fractionDigits: 1), '12.3');
      expect(HiFormat.compact(12.0, fractionDigits: 1), '12');
    });

    test('carries to the next unit when rounding reaches 1000', () {
      expect(HiFormat.compact(999950), '1M');
      expect(HiFormat.compact(999.95), '1K');
      expect(HiFormat.compact(999.6, fractionDigits: 0), '1K');
      expect(HiFormat.compact(999.4, fractionDigits: 0), '999');
    });

    test('supports negative numbers without negative zero', () {
      expect(HiFormat.compact(-1500), '-1.5K');
      expect(HiFormat.compact(-999950), '-1M');
      expect(HiFormat.compact(-0.0), '0');
      expect(HiFormat.compact(-0.04, fractionDigits: 1), '0');
    });

    test('handles non-finite numbers and rejects negative fractionDigits', () {
      expect(HiFormat.compact(double.nan), 'NaN');
      expect(HiFormat.compact(double.infinity), 'Infinity');
      expect(HiFormat.compact(double.negativeInfinity), '-Infinity');
      expect(
        () => HiFormat.compact(10, fractionDigits: -1),
        throwsArgumentError,
      );
    });
  });
}
