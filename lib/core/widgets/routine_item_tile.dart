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
    const Color routineAccent = Color(0xFF9A452A);
    final bool done = task.completed;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: routineAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForCategory(task.category),
                  size: 22,
                  color: routineAccent,
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
                        fontFamily: 'Nunito',
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
              if (task.timeOfDay != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatTime(task.timeOfDay),
                    style: text.titleSmall?.copyWith(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'feeding':
        return Icons.restaurant_outlined;
      case 'medicine':
        return Icons.medication_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'play':
        return Icons.toys_outlined;
      case 'grooming':
        return Icons.shower_outlined;
      case 'litter':
        return Icons.cleaning_services_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'rest':
        return Icons.bedtime_outlined;
      default:
        return Icons.schedule_outlined;
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
