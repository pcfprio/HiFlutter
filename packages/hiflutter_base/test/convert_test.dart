import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

void main() {
  group('HiConvert.asInt', () {
    final cases = <(Object?, int?)>[
      (42, 42),
      (-7, -7),
      (3.9, 3),
      (-3.9, -3),
      ('42', 42),
      (' 42 ', 42),
      ('+5', 5),
      ('3.9', 3),
      ('1e3', 1000),
      ('9223372036854775807', 9223372036854775807),
      ('9223372036854775808', null),
      (1e19, null),
      (double.nan, null),
      (double.infinity, null),
      (true, 1),
      (false, 0),
      ('', null),
      ('abc', null),
      (null, null),
      (<int>[1], null),
    ];
    for (final (input, expected) in cases) {
      test('${_show(input)} -> $expected', () {
        expect(HiConvert.asInt(input), expected);
      });
    }
  });

  group('HiConvert.asDouble', () {
    final cases = <(Object?, double?)>[
      (1, 1.0),
      (2.5, 2.5),
      ('3.5', 3.5),
      (' 2 ', 2.0),
      ('-0.25', -0.25),
      ('NaN', null),
      ('Infinity', null),
      (double.nan, null),
      (double.negativeInfinity, null),
      (true, 1.0),
      ('', null),
      ('1,5', null),
      (null, null),
    ];
    for (final (input, expected) in cases) {
      test('${_show(input)} -> $expected', () {
        expect(HiConvert.asDouble(input), expected);
      });
    }
  });

  group('HiConvert.asBool', () {
    final cases = <(Object?, bool?)>[
      (true, true),
      (false, false),
      (1, true),
      (0, false),
      (1.0, true),
      (0.0, false),
      (2, null),
      ('true', true),
      ('TRUE', true),
      (' yes ', true),
      ('1', true),
      ('y', true),
      ('on', true),
      ('false', false),
      ('No', false),
      ('0', false),
      ('n', false),
      ('off', false),
      ('maybe', null),
      ('', null),
      (null, null),
    ];
    for (final (input, expected) in cases) {
      test('${_show(input)} -> $expected', () {
        expect(HiConvert.asBool(input), expected);
      });
    }
  });

  group('HiConvert.asString', () {
    final cases = <(Object?, String?)>[
      ('x', 'x'),
      ('', ''),
      (42, '42'),
      (3.5, '3.5'),
      (true, 'true'),
      (null, null),
      (<String, Object?>{}, null),
      (<Object?>[], null),
    ];
    for (final (input, expected) in cases) {
      test('${_show(input)} -> ${_show(expected)}', () {
        expect(HiConvert.asString(input), expected);
      });
    }
  });

  group('HiConvert.asList', () {
    test('converts elements and drops the ones that fail', () {
      expect(HiConvert.asList([1, '2', 'x', null, 3.7], HiConvert.asInt), [
        1,
        2,
        3,
      ]);
    });

    test('keeps only elements of the requested type without a converter', () {
      expect(HiConvert.asList<String>(['a', 1, 'b']), ['a', 'b']);
    });

    test('returns null for non-lists', () {
      expect(HiConvert.asList<Object?>('a,b'), isNull);
      expect(HiConvert.asList<Object?>(null), isNull);
      expect(HiConvert.asList<Object?>({'a': 1}), isNull);
    });

    test('returns an empty list for an empty list', () {
      expect(HiConvert.asList<int>(<Object?>[]), isEmpty);
    });
  });

  group('HiConvert.asMap', () {
    test('returns string-keyed maps as they are', () {
      expect(HiConvert.asMap({'a': 1, 'b': null}), {'a': 1, 'b': null});
    });

    test('stringifies non-string keys', () {
      expect(HiConvert.asMap({1: 'x', true: 'y'}), {'1': 'x', 'true': 'y'});
    });

    test('returns null for non-maps', () {
      expect(HiConvert.asMap(['a']), isNull);
      expect(HiConvert.asMap('{"a":1}'), isNull);
      expect(HiConvert.asMap(null), isNull);
    });
  });
}

String _show(Object? value) =>
    value is String ? '"$value"' : '$value (${value.runtimeType})';
