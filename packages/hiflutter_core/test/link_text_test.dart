import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  group('HiTextSegment', () {
    test('reports isLink based on uri presence', () {
      const plain = HiTextSegment('hello');
      final link = HiTextSegment(
        'https://example.com',
        uri: Uri.parse('https://example.com'),
      );

      expect(plain.isLink, isFalse);
      expect(plain.uri, isNull);
      expect(link.isLink, isTrue);
      expect(link.uri, Uri.parse('https://example.com'));
    });

    test('supports value equality', () {
      final a = HiTextSegment(
        'https://example.com',
        uri: Uri.parse('https://example.com'),
      );
      final b = HiTextSegment(
        'https://example.com',
        uri: Uri.parse('https://example.com'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(const HiTextSegment('hi'), isNot(equals(a)));
    });
  });

  group('HiLinkDetector.split', () {
    test('returns a single plain segment for empty or plain text', () {
      expect(HiLinkDetector.split(''), [const HiTextSegment('')]);
      expect(HiLinkDetector.split('hello world'), [
        const HiTextSegment('hello world'),
      ]);
    });

    test('detects http and https links with surrounding text', () {
      final segments = HiLinkDetector.split(
        'Visit https://example.com/docs?q=1#top or http://localhost:8080/api now',
      );
      expect(segments, [
        const HiTextSegment('Visit '),
        HiTextSegment(
          'https://example.com/docs?q=1#top',
          uri: Uri.parse('https://example.com/docs?q=1#top'),
        ),
        const HiTextSegment(' or '),
        HiTextSegment(
          'http://localhost:8080/api',
          uri: Uri.parse('http://localhost:8080/api'),
        ),
        const HiTextSegment(' now'),
      ]);
    });

    test('handles text consisting solely of a link', () {
      final segments = HiLinkDetector.split('https://dart.dev');
      expect(segments, [
        HiTextSegment('https://dart.dev', uri: Uri.parse('https://dart.dev')),
      ]);
    });

    test('strips trailing sentence punctuation', () {
      final segments = HiLinkDetector.split(
        'See https://a.com, http://b.com; https://c.com: http://d.com! https://e.com? and https://f.com.',
      );
      expect(segments.where((s) => s.isLink).map((s) => s.text), [
        'https://a.com',
        'http://b.com',
        'https://c.com',
        'http://d.com',
        'https://e.com',
        'https://f.com',
      ]);
      expect(
        segments.map((s) => s.text).join(),
        'See https://a.com, http://b.com; https://c.com: http://d.com! https://e.com? and https://f.com.',
      );
    });

    test('strips unpaired closing brackets while keeping balanced ones', () {
      expect(
        HiLinkDetector.split(
          '(see https://en.wikipedia.org/wiki/Dart_(programming_language)).',
        ),
        [
          const HiTextSegment('(see '),
          HiTextSegment(
            'https://en.wikipedia.org/wiki/Dart_(programming_language)',
            uri: Uri.parse(
              'https://en.wikipedia.org/wiki/Dart_(programming_language)',
            ),
          ),
          const HiTextSegment(').'),
        ],
      );

      expect(HiLinkDetector.split('[https://example.com/items[0]]'), [
        const HiTextSegment('['),
        HiTextSegment(
          'https://example.com/items[0]',
          uri: Uri.parse('https://example.com/items[0]'),
        ),
        const HiTextSegment(']'),
      ]);

      expect(HiLinkDetector.split('<https://example.com>'), [
        const HiTextSegment('<'),
        HiTextSegment(
          'https://example.com',
          uri: Uri.parse('https://example.com'),
        ),
        const HiTextSegment('>'),
      ]);
    });

    test('stops before CJK text and full-width punctuation', () {
      expect(HiLinkDetector.split('请访问https://example.com，谢谢。'), [
        const HiTextSegment('请访问'),
        HiTextSegment(
          'https://example.com',
          uri: Uri.parse('https://example.com'),
        ),
        const HiTextSegment('，谢谢。'),
      ]);
    });

    test('ignores invalid or non-http schemes and merges plain text', () {
      expect(HiLinkDetector.split('ftp://example.com and mailto:a@b.com'), [
        const HiTextSegment('ftp://example.com and mailto:a@b.com'),
      ]);
      expect(HiLinkDetector.split('broken http://. link'), [
        const HiTextSegment('broken http://. link'),
      ]);
      expect(HiLinkDetector.split('nothttp://example.com'), [
        const HiTextSegment('nothttp://example.com'),
      ]);
    });
  });
}
