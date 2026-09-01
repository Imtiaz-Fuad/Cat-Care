import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/accent_color_extractor.dart';

/// Render a cat photo in one of three shapes per design §5:
///
/// * [CatPhotoVariant.hero] — large, fills the screen width; used at
///   the top of `CatProfileScreen` and the onboarding photo step.
/// * [CatPhotoVariant.avatar] — circular, used in lists and the
///   active-cat chip.
/// * [CatPhotoVariant.personality] — small rounded square used in
///   inline UIs (e.g. routine assignments, daily card).
///
/// Pass either [networkUrl] (preferred, cached) or [localPath] (a
/// freshly picked file that hasn't been uploaded yet — typical during
/// onboarding). When neither is set we render a soft tinted
/// placeholder so layout stays stable.
class CatPhoto extends StatelessWidget {
  const CatPhoto({
    super.key,
    this.networkUrl,
    this.localPath,
    this.variant = CatPhotoVariant.avatar,
    this.accentHex,
    this.semanticLabel,
    this.useCatEmojiFallback = false,
  });

  final String? networkUrl;
  final String? localPath;
  final CatPhotoVariant variant;
  final String? accentHex;
  final String? semanticLabel;
  final bool useCatEmojiFallback;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final double size = switch (variant) {
      CatPhotoVariant.hero => double.infinity,
      CatPhotoVariant.avatar => 56,
      CatPhotoVariant.personality => 48,
    };

    final double dim = switch (variant) {
      CatPhotoVariant.hero => 280,
      CatPhotoVariant.avatar => 56,
      CatPhotoVariant.personality => 48,
    };

    final BorderRadius radius = switch (variant) {
      CatPhotoVariant.avatar => BorderRadius.circular(dim / 2),
      CatPhotoVariant.personality => BorderRadius.circular(12),
      CatPhotoVariant.hero => BorderRadius.circular(24),
    };

    final Widget? image = _buildImage(context);
    final Color placeholderColor = _parseOrFallback(
      accentHex,
      scheme.primaryContainer,
    );
    final Color? accentBorder = AccentColorExtractor.tryParseHex(accentHex);

    return Semantics(
      label: semanticLabel ?? 'Cat photo',
      image: true,
      container: true,
      child: SizedBox(
        width: size == double.infinity ? null : size,
        height: dim,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              image ??
                  ColoredBox(
                    color: placeholderColor,
                    child: Center(
                      child: useCatEmojiFallback
                          ? Text(
                              '🐱',
                              style: TextStyle(fontSize: dim / 2.5),
                            )
                          : Icon(
                              Icons.pets,
                              size: dim / 2.5,
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: 0.6,
                              ),
                            ),
                    ),
                  ),
              if (accentBorder != null)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: accentBorder, width: 2),
                      borderRadius: radius,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildImage(BuildContext context) {
    if (networkUrl != null && networkUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: BoxFit.cover,
        placeholder: (BuildContext _, String url) => _shimmer(context),
        errorWidget: (BuildContext _, String url, Object? error) =>
            _shimmer(context),
      );
    }
    if (localPath != null && localPath!.isNotEmpty) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext _, Object error, StackTrace? stack) =>
            _shimmer(context),
      );
    }
    return null;
  }

  Widget _shimmer(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Color _parseOrFallback(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String cleaned = hex.replaceAll('#', '').toUpperCase();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    final int? value = int.tryParse(cleaned, radix: 16);
    return value == null ? fallback : Color(value);
  }
}

enum CatPhotoVariant { hero, avatar, personality }
