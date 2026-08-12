import 'package:flutter/material.dart';

/// Minimal "today vs target" indicator shown by the Home + Nutrition
/// screens. Renders a thin progress ring with a centered headline
/// (e.g. "12 / 60 g").
///
/// Progress is clamped to `[0, 1]` for the visual arc, but the
/// caller can opt-in to the raw >1.0 value by reading [labelColor]
/// and rendering "over target" themselves.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.centerLabel,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
    this.backgroundColor,
  });

  /// 0.0 - 1.0+ (caller decides whether to clamp).
  final double progress;
  final String centerLabel;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color fill = color ?? scheme.primary;
    final Color track =
        backgroundColor ?? scheme.outlineVariant.withValues(alpha: 0.4);
    final double clamped = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(track),
              strokeCap: StrokeCap.round,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            centerLabel,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
