import 'dart:convert';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

void main() {
  group('pick', () {
    final map = <String, Object?>{'id': 1, 'uid': 2, 'nil': null, 'name': 'a'};

    test('reads a single key', () {
      expect(map.pick('name'), 'a');
    });

    test('falls back to the next candidate when a key is missing', () {
      expect(map.pick('user_id|uid'), 2);
    });

    test('skips candidates whose value is null', () {
      expect(map.pick('nil|uid'), 2);
    });

    test('prefers the first candidate present', () {
      expect(map.pick('id|uid'), 1);
      expect(map.pick('uid|id'), 2);
    });

    test('trims candidates and ignores empty ones', () {
      expect(map.pick(' missing | uid '), 2);
      expect(map.pick('||uid|'), 2);
    });

    test('returns null when no candidate has a value', () {
      expect(map.pick('a|b'), isNull);
      expect(map.pick('nil'), isNull);
      expect(map.pick(''), isNull);
    });
  });

  group('typed pick', () {
    final json = jsonDecode(
      '{"count":"5","price":"9.5","ok":"yes","title":7,'
      '"tags":["a",1,"b"],"user":{"id":3}}',
    ) as Map<String, dynamic>;

    test('converts the picked value leniently', () {
      expect(json.pickInt('total|count'), 5);
      expect(json.pickDouble('amount|price'), 9.5);
      expect(json.pickBool('success|ok'), isTrue);
      expect(json.pickString('name|title'), '7');
      expect(json.pickList<String>('list|tags'), ['a', 'b']);
      expect(json.pickList('tags', HiConvert.asString), ['a', '1', 'b']);
      expect(json.pickMap('owner|user'), {'id': 3});
    });

    test('returns null when nothing matches or conversion fails', () {
      expect(json.pickInt('missing'), isNull);
      expect(json.pickInt('ok'), isNull);
      expect(json.pickMap('tags'), isNull);
    });
  });
}
