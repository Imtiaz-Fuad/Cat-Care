import 'package:flutter/material.dart';

/// Small pill chip used by Routine + Nutrition screens to flag
/// state ("Done", "Due", "Overdue", etc.).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.backgroundOpacity = 0.15,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  /// Opacity applied to [color] for the background fill.
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tint = color ?? scheme.primary;
    final Color bg = tint.withValues(alpha: backgroundOpacity);
    final Color fg = tint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
