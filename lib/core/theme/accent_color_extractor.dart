import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../services/app_logger.dart';

/// Extracts a muted pastel accent color from a cat photo.
///
/// Per docs/catcare.design §6 the photo-derived accent tints only
/// **highlights** (selected nav indicator, progress bars, etc.). Body
/// text, surfaces, and accessibility-critical colors are never
/// overwritten by the accent.
///
/// Algorithm:
///   1. Run `palette_generator` to find the dominant color (or the
///      most-vibrant fallback).
///   2. Mix toward a neutral luminance (mid-gray) by a fixed ratio so
///      the result reads as a muted pastel regardless of the photo's
///      saturation.
///   3. Slightly shift hue toward warmth so the accent never reads as
///      a clinical blue/green from a brightly-lit photo.
///   4. Encode as `#RRGGBB` for round-trip through Firestore.
class AccentColorExtractor {
  AccentColorExtractor._();

  /// Default desaturation: 60% toward neutral luminance. Picked so a
  /// vivid orange tabby yields a soft peach that still reads as the
  /// cat's "color".
  static const double defaultMix = 0.6;

  /// Maximum image region — `palette_generator` decodes the full
  /// frame by default, which is wasteful on a 12MP cat photo. Capping
  /// at 256 px on the longest side keeps extraction under ~100ms on
  /// mid-range hardware.
  static const double maxRegionSize = 256;

  /// Extract a muted pastel hex string from raw image bytes.
  ///
  /// Returns `null` when extraction fails for any reason (decoder
  /// failure, palette empty, etc.). Onboarding falls back to the app's
  /// sage default in that case — a missing accent never blocks the
  /// flow.
  static Future<String?> extractHex(
    Uint8List bytes, {
    double mix = defaultMix,
  }) async {
    try {
      final ui.Image? image = await _decode(bytes);
      if (image == null) return null;
      final PaletteGenerator palette = await PaletteGenerator.fromImage(
        image,
        maximumColorCount: 16,
        region: _centerRegion(image),
      );
      final Color source = _pickSourceColor(palette);
      final Color muted = mixTowardNeutral(source, mix);
      return mutedToHex(muted);
    } catch (error, stack) {
      AppLogger.w('AccentColorExtractor.extractHex failed', error, stack);
      return null;
    }
  }

  /// Mix [source] toward a neutral mid-gray by [mix] (0..1). 0 keeps
  /// the source untouched; 1 collapses to the neutral.
  static Color mixTowardNeutral(Color source, double mix) {
    final double clamped = mix.clamp(0.0, 1.0);
    final HSLColor hsl = HSLColor.fromColor(source);
    final HSLColor muted = hsl.withSaturation(
      (hsl.saturation * (1 - clamped)).clamp(0.0, 1.0),
    );
    final HSLColor warmed = muted.withHue(
      _warmHue(muted.hue),
    );
    // Keep lightness in the soft 0.55..0.75 range so the accent is
    // never a deep shadow color that fails contrast against text.
    final double lightness =
        warmed.lightness.clamp(0.55, 0.75).toDouble();
    return warmed.withLightness(lightness).toColor();
  }

  /// Encode a [Color] as `#RRGGBB`. Alpha is intentionally dropped —
  /// the accent is always opaque.
  static String mutedToHex(Color color) {
    final int r = (color.r * 255).round() & 0xff;
    final int g = (color.g * 255).round() & 0xff;
    final int b = (color.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  /// Parse `#RRGGBB` / `#RGB` / `RRGGBB` into a [Color]. Returns
  /// `null` when the input is malformed so callers can fall back.
  static Color? tryParseHex(String? hex) {
    if (hex == null) return null;
    String value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
    }
    if (value.length != 6) return null;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xff000000 | parsed);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxRegionSize.toInt(),
      targetHeight: maxRegionSize.toInt(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Sample the center 50% of the image — palette_generator's docs
  /// suggest a small region speeds up extraction dramatically.
  static Rect _centerRegion(ui.Image image) {
    final int w = image.width;
    final int h = image.height;
    final int left = (w * 0.25).round();
    final int top = (h * 0.25).round();
    final int width = (w * 0.5).round();
    final int height = (h * 0.5).round();
    return Rect.fromLTWH(left.toDouble(), top.toDouble(),
        width.toDouble(), height.toDouble());
  }

  static Color _pickSourceColor(PaletteGenerator palette) {
    if (palette.dominantColor != null) return palette.dominantColor!.color;
    if (palette.vibrantColor != null) return palette.vibrantColor!.color;
    if (palette.mutedColor != null) return palette.mutedColor!.color;
    if (palette.lightVibrantColor != null) {
      return palette.lightVibrantColor!.color;
    }
    // Last-resort fallback: a sage-ish tone so the accent never goes
    // missing in practice.
    return const Color(0xFF6E8E7E);
  }

  /// Nudge hue toward warm tones (oranges / peaches). We keep this as
  /// a small rotation so a cat whose photo has a strong blue tint
  /// (e.g. Russian Blue) doesn't render a clinical accent.
  static double _warmHue(double hue) {
    // Warm half of the wheel: 0..60 and 300..360. Rotate toward the
    // nearest end by up to 15° if the hue sits in the cool half.
    if (hue >= 60 && hue <= 180) {
      // Cool: pull toward 60 (yellow/orange).
      return hue - (hue - 60).clamp(0.0, 15.0);
    }
    if (hue > 180 && hue < 300) {
      // Cool: pull toward 300 (magenta/pink).
      return hue + (300 - hue).clamp(0.0, 15.0);
    }
    return hue;
  }
}
