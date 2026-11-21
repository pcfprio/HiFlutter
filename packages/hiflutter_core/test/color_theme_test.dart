import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiflutter_core/hiflutter_core.dart';

void main() {
  group('HiColor', () {
    test('parses #RGB, #RRGGBB, and #AARRGGBB with or without hash', () {
      expect(HiColor.parseHex('#f0a'), const Color(0xFFFF00AA));
      expect(HiColor.parseHex('0f8'), const Color(0xFF00FF88));
      expect(HiColor.parseHex('#123456'), const Color(0xFF123456));
      expect(HiColor.parseHex('abcdef'), const Color(0xFFABCDEF));
      expect(HiColor.parseHex('#80123456'), const Color(0x80123456));
      expect(HiColor.parseHex('00FFFFFF'), const Color(0x00FFFFFF));
      expect(HiColor.parseHex('  #336699  '), const Color(0xFF336699));
    });

    test('tryParseHex returns null for invalid hex strings', () {
      expect(HiColor.tryParseHex(''), isNull);
      expect(HiColor.tryParseHex('#'), isNull);
      expect(HiColor.tryParseHex('##123456'), isNull);
      expect(HiColor.tryParseHex('#1234'), isNull);
      expect(HiColor.tryParseHex('#12345'), isNull);
      expect(HiColor.tryParseHex('#1234567'), isNull);
      expect(HiColor.tryParseHex('#123456789'), isNull);
      expect(HiColor.tryParseHex('#GGGGGG'), isNull);
      expect(HiColor.tryParseHex('0x123456'), isNull);
    });

    test('parseHex throws FormatException on invalid input', () {
      expect(() => HiColor.parseHex('not-a-color'), throwsFormatException);
      expect(() => HiColor.parseHex('#1234'), throwsFormatException);
    });
  });

  group('HiColorExtension', () {
    test('toHex formats RGB and ARGB hex strings', () {
      const color = Color(0x8012ABEF);
      expect(color.toHex(), '#12ABEF');
      expect(color.toHex(leadingHash: false), '12ABEF');
      expect(color.toHex(includeAlpha: true), '#8012ABEF');
      expect(color.toHex(leadingHash: false, includeAlpha: true), '8012ABEF');
      expect(const Color(0xFF00050A).toHex(), '#00050A');
    });

    test('onColor selects black on light colors and white on dark colors', () {
      expect(const Color(0xFFFFFFFF).onColor, const Color(0xFF000000));
      expect(const Color(0xFFFFF59D).onColor, const Color(0xFF000000));
      expect(const Color(0xFF000000).onColor, const Color(0xFFFFFFFF));
      expect(const Color(0xFF0D47A1).onColor, const Color(0xFFFFFFFF));
      expect(const Color(0xFF2196F3).onColor, const Color(0xFFFFFFFF));
    });

    test('scaleAlpha scales current alpha and clamps to [0, 1]', () {
      const half = Color.from(alpha: 0.5, red: 1, green: 0, blue: 0);
      expect(half.scaleAlpha(0.5).a, closeTo(0.25, 1e-6));
      expect(half.scaleAlpha(0.0).a, closeTo(0.0, 1e-6));
      expect(half.scaleAlpha(3.0).a, closeTo(1.0, 1e-6));
      expect(half.scaleAlpha(-1.0).a, closeTo(0.0, 1e-6));
      expect(() => half.scaleAlpha(double.nan), throwsArgumentError);
    });
  });

  group('HiContextExtension', () {
    testWidgets('reads size, viewPadding, platformBrightness and isDarkMode', (
      tester,
    ) async {
      late Size screenSize;
      late EdgeInsets viewPadding;
      late Brightness brightness;
      late bool isDark;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(top: 47, bottom: 34),
            platformBrightness: Brightness.dark,
          ),
          child: Builder(
            builder: (context) {
              screenSize = context.screenSize;
              viewPadding = context.viewPadding;
              brightness = context.platformBrightness;
              isDark = context.isDarkMode;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(screenSize, const Size(390, 844));
      expect(viewPadding, const EdgeInsets.only(top: 47, bottom: 34));
      expect(brightness, Brightness.dark);
      expect(isDark, isTrue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            viewPadding: EdgeInsets.zero,
            platformBrightness: Brightness.light,
          ),
          child: Builder(
            builder: (context) {
              brightness = context.platformBrightness;
              isDark = context.isDarkMode;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(brightness, Brightness.light);
      expect(isDark, isFalse);
    });
  });
}
