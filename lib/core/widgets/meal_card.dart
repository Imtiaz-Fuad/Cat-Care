import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feeding_entry.dart';

/// Card row representing a single [FeedingEntry] in the Nutrition
/// screen list. Shows time, food name + type, amount, and a delete
/// overflow action.
class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.entry, this.onDelete});

  final FeedingEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String time = DateFormat.Hm().format(entry.time);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(entry.foodType),
                color: scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.foodName,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_typeLabel(entry.foodType)} · ${_amountLabel(entry)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  time,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'wet':
        return Icons.set_meal_outlined;
      case 'dry':
        return Icons.bakery_dining_outlined;
      case 'raw':
        return Icons.restaurant_outlined;
      case 'treat':
        return Icons.cake_outlined;
      case 'mixed':
        return Icons.local_dining_outlined;
      default:
        return Icons.pets;
    }
  }

  static String _typeLabel(String type) {
    if (type.isEmpty) return 'Meal';
    return type[0].toUpperCase() + type.substring(1);
  }

  static String _amountLabel(FeedingEntry e) {
    final String amt = e.amount.truncateToDouble() == e.amount
        ? e.amount.toInt().toString()
        : e.amount.toStringAsFixed(1);
    return '$amt ${e.unit}';
  }
}
