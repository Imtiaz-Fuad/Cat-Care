import 'package:flutter/material.dart';

import '../../../core/widgets/progress_ring.dart';

/// Header card shown at the top of the Routine screen. Renders the
/// completion ring + label and a single-line subtitle.
class RoutineSummaryHeader extends StatelessWidget {
  const RoutineSummaryHeader({
    super.key,
    required this.completedToday,
    required this.total,
  });

  final int completedToday;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final double progress = total == 0 ? 0 : completedToday / total;
    return Card(
      color: const Color(0xFFFFF0E7),
      elevation: 6,
      shadowColor: const Color(0xFFE09A79).withValues(alpha: 0.38),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: <Widget>[
            ProgressRing(
              progress: progress,
              centerLabel: '$completedToday\n$total',
              color: scheme.secondary,
              size: 88,
              strokeWidth: 7,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s progress',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'No tasks yet. Add a routine or regenerate defaults.'
                        : 'You\'ve completed $completedToday of $total '
                              'tasks today. Tap a tile to edit,'
                              ' tap the circle to mark done.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
