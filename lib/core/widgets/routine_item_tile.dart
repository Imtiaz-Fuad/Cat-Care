import 'package:flutter/material.dart';

import '../../core/models/routine_task.dart';

/// Compact list tile for a single [RoutineTask]. Displays the
/// scheduled time, icon for the category, title, optional note,
/// and a leading check-mark that the user toggles to mark the
/// task done today.
class RoutineItemTile extends StatelessWidget {
  const RoutineItemTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
  });

  final RoutineTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool done = task.completed;
    final String time = _formatTime(task.timeOfDay);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      time,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _categoryLabel(task.category),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if ((task.notes ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        task.notes!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (task.reminder) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reminder on',
                            style: text.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DoneToggle(done: done, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return '—';
    final String hh = t.hour.toString().padLeft(2, '0');
    final String mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String _categoryLabel(String category) {
    switch (category) {
      case 'feeding':
        return 'Feed';
      case 'medicine':
        return 'Med';
      case 'water':
        return 'Water';
      case 'play':
        return 'Play';
      case 'grooming':
        return 'Groom';
      case 'litter':
        return 'Litter';
      default:
        return category;
    }
  }
}

class _DoneToggle extends StatelessWidget {
  const _DoneToggle({required this.done, required this.onChanged});

  final bool done;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: done ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: done ? scheme.primary : scheme.outlineVariant,
          width: 1.4,
        ),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: done ? 'Mark undone' : 'Mark done',
        icon: Icon(
          done ? Icons.check_rounded : Icons.radio_button_unchecked,
          color: done ? scheme.onPrimary : scheme.onSurfaceVariant,
          size: 18,
        ),
        onPressed: () => onChanged(!done),
      ),
    );
  }
}
