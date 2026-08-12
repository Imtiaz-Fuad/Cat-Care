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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            ProgressRing(
              progress: progress,
              centerLabel: '$completedToday\n$total',
              size: 84,
              strokeWidth: 8,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s progress',
                    style: text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'No tasks yet. Add a routine or regenerate defaults.'
                        : 'You\'ve completed $completedToday of $total '
                            'tasks today. Tap a tile to edit,'
                            ' tap the circle to mark done.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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