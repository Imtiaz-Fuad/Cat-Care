import 'package:cat_care/core/theme/accent_color_extractor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccentColorExtractor.mixTowardNeutral', () {
    test('mix 0 preserves source saturation (modulo hue nudge + clamp)', () {
      const Color source = Color(0xFFFF0000); // red
      // With mix = 0 the extractor only nudges hue and clamps lightness;
      // saturation must remain at the source's level.
      final HSLColor before = HSLColor.fromColor(source);
      final Color result = AccentColorExtractor.mixTowardNeutral(source, 0);
      final HSLColor after = HSLColor.fromColor(result);
      expect(after.saturation, closeTo(before.saturation, 0.01));
    });

    test('mix 1 collapses saturation to zero', () {
      const Color source = Color(0xFF00FF00); // green
      final Color result = AccentColorExtractor.mixTowardNeutral(source, 1);
      // When saturation is zero, r, g, b must be equal.
      expect(result.r, closeTo(result.g, 0.01));
      expect(result.g, closeTo(result.b, 0.01));
    });

    test('mid mix reduces saturation but does not zero it', () {
      const Color source = Color(0xFFFF8000); // orange
      final HSLColor before = HSLColor.fromColor(source);
      final Color result = AccentColorExtractor.mixTowardNeutral(source, 0.5);
      final HSLColor after = HSLColor.fromColor(result);
      expect(after.saturation, lessThan(before.saturation));
      expect(after.saturation, greaterThan(0.0));
    });

    test('mix is clamped to [0, 1]', () {
      const Color source = Color(0xFF123456);
      // mix > 1 should behave like mix = 1.
      final Color high = AccentColorExtractor.mixTowardNeutral(source, 5);
      final Color clamped = AccentColorExtractor.mixTowardNeutral(source, 1);
      expect(high.r, closeTo(clamped.r, 0.01));
      expect(high.g, closeTo(clamped.g, 0.01));
      expect(high.b, closeTo(clamped.b, 0.01));
    });

    test('output lightness stays within the soft 0.55..0.75 band', () {
      // Try a few very dark and very bright sources.
      const List<Color> sources = <Color>[
        Color(0xFF000000), // black
        Color(0xFFFFFFFF), // white
        Color(0xFF0000FF), // pure blue
        Color(0xFFFF00FF), // magenta
        Color(0xFF112233), // dark navy
      ];
      for (final Color c in sources) {
        final Color result = AccentColorExtractor.mixTowardNeutral(c, 0.6);
        final HSLColor hsl = HSLColor.fromColor(result);
        expect(hsl.lightness, greaterThanOrEqualTo(0.55 - 0.01));
        expect(hsl.lightness, lessThanOrEqualTo(0.75 + 0.01));
      }
    });
  });

  group('AccentColorExtractor.mutedToHex', () {
    test('encodes rgb channels as uppercase hex', () {
      expect(
        AccentColorExtractor.mutedToHex(const Color(0xFFA1B2C3)),
        '#A1B2C3',
      );
    });

    test('drops alpha channel', () {
      // alpha 0x80 should be ignored; only RGB reach the output.
      expect(
        AccentColorExtractor.mutedToHex(const Color(0x80A1B2C3)),
        '#A1B2C3',
      );
    });

    test('pads single-digit channels with leading zero', () {
      expect(
        AccentColorExtractor.mutedToHex(const Color(0xFF010203)),
        '#010203',
      );
    });
  });

  group('AccentColorExtractor.tryParseHex', () {
    test('parses 6-digit hex with hash', () {
      expect(
        AccentColorExtractor.tryParseHex('#A1B2C3'),
        const Color(0xFFA1B2C3),
      );
    });

    test('parses 6-digit hex without hash', () {
      expect(
        AccentColorExtractor.tryParseHex('A1B2C3'),
        const Color(0xFFA1B2C3),
      );
    });

    test('parses 3-digit hex by doubling each channel', () {
      // #ABC -> #AABBCC
      expect(AccentColorExtractor.tryParseHex('#abc'), const Color(0xFFAABBCC));
    });

    test('returns null for null input', () {
      expect(AccentColorExtractor.tryParseHex(null), isNull);
    });

    test('returns null for malformed strings', () {
      expect(AccentColorExtractor.tryParseHex(''), isNull);
      expect(AccentColorExtractor.tryParseHex('#ZZZZZZ'), isNull);
      expect(AccentColorExtractor.tryParseHex('#1234'), isNull);
      expect(AccentColorExtractor.tryParseHex('not-hex'), isNull);
    });
  });

  group('mutedToHex <-> tryParseHex round-trip', () {
    test('every pastel survives a round-trip', () {
      const List<Color> pastels = <Color>[
        Color(0xFFA1B2C3),
        Color(0xFF6E8E7E),
        Color(0xFFEFD5C0),
        Color(0xFFFBE7CC),
        Color(0xFF7B9EA8),
      ];
      for (final Color c in pastels) {
        final String hex = AccentColorExtractor.mutedToHex(c);
        final Color? parsed = AccentColorExtractor.tryParseHex(hex);
        expect(parsed, isNotNull);
        expect(parsed!.r, closeTo(c.r, 1 / 255));
        expect(parsed.g, closeTo(c.g, 1 / 255));
        expect(parsed.b, closeTo(c.b, 1 / 255));
      }
    });
  });
}
