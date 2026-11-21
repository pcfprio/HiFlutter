import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

String describe(HiScalar scalar) => switch (scalar) {
  HiStringScalar(:final value) => 'string $value',
  HiIntScalar(:final value) => 'int $value',
  HiDoubleScalar(:final value) => 'double $value',
  HiBoolScalar(:final value) => 'bool $value',
};

void main() {
  test('wraps each scalar type into its sealed subtype', () {
    expect(describe(HiScalar('a')), 'string a');
    expect(describe(HiScalar(1)), 'int 1');
    expect(describe(HiScalar(1.5)), 'double 1.5');
    expect(describe(HiScalar(false)), 'bool false');
  });

  test('rejects non-scalar values', () {
    expect(() => HiScalar(null), throwsArgumentError);
    expect(() => HiScalar(<int>[1]), throwsArgumentError);
    expect(() => HiScalar({'a': 1}), throwsArgumentError);
    expect(() => HiScalar(DateTime(2026)), throwsArgumentError);
  });

  test('compares by type and value', () {
    expect(HiScalar('1'), const HiStringScalar('1'));
    expect(HiScalar(1), isNot(HiScalar('1')));
    expect(HiScalar(1).hashCode, const HiIntScalar(1).hashCode);
  });
}
