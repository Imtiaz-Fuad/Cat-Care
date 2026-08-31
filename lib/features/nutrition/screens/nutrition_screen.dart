import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cat_profile.dart';
import '../../../core/models/feeding_entry.dart';
import '../../../core/models/water_entry.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/meal_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_header.dart';
import '../../cats/widgets/cat_photo.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/feeding_edit_sheet.dart';
import '../widgets/water_edit_sheet.dart';

/// Nutrition screen — see `docs/catcare.design` § "Daily Loop / Nutrition".
///
/// Aggregates feeding + water entries for the active cat and surfaces
/// today's progress against the derived `NutritionTarget`. The
/// header shows two progress rings (food / water) side-by-side
/// with the cat's daily target. Below the rings, today's meals +
/// water log as a vertical timeline, then a 7-day history strip
/// so the user can spot trends without leaving the screen.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionProvider>(
      builder: (BuildContext context, NutritionProvider provider, Widget? _) {
        final CatProfile? cat = provider.activeCat;
        final bool loading = !provider.hasLoaded;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nutrition'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Log meal',
                icon: const Icon(Icons.restaurant_outlined),
                onPressed: () => _openFeedingSheet(context),
              ),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : cat == null
              ? const _NoActiveCat()
              : _NutritionBody(cat: cat, provider: provider),
        );
      },
    );
  }
}

class _NutritionBody extends StatelessWidget {
  const _NutritionBody({required this.cat, required this.provider});

  final CatProfile cat;
  final NutritionProvider provider;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<FeedingEntry> feedings = provider.todaysFeedings;
    final List<WaterEntry> water = provider.todaysWater;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        _NutritionHeader(cat: cat, provider: provider),
        SectionHeader(
          title: 'Today',
          subtitle: DateFormat('EEEE, MMM d').format(DateTime.now()),
        ),
        _TodayTimeline(
          feedings: feedings,
          water: water,
          onEditFeeding: (FeedingEntry entry) =>
              _openFeedingSheet(context, existing: entry),
          onDeleteFeeding: (FeedingEntry entry) =>
              _confirmDeleteFeeding(context, entry),
          onEditWater: (WaterEntry entry) =>
              _openWaterSheet(context, existing: entry),
          onDeleteWater: (WaterEntry entry) =>
              _confirmDeleteWater(context, entry),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openFeedingSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Log meal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openWaterSheet(context),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('Log water'),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Target for this cat',
          subtitle: 'Suggested daily ranges, not a vet prescription.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cat.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cat.lifeStage.displayLabel}'
                    '${cat.weightKg != null ? ' · ${cat.weightKg!.toStringAsFixed(1)} kg' : ''}'
                    '${cat.neutered ? ' · neutered' : ''}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      _Stat(
                        label: 'Food',
                        value: '${provider.target.dailyFoodGrams.toInt()} g',
                      ),
                      _Stat(
                        label: 'Water',
                        value: '${provider.target.dailyWaterMl.toInt()} ml',
                      ),
                      _Stat(
                        label: 'Meals',
                        value: '${provider.target.mealsPerDay}',
                      ),
                      _Stat(
                        label: 'kcal',
                        value: '${provider.target.dailyKcal.toInt()}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionHeader(title: 'Last 7 days'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _WeekStrip(days: provider.last7Days),
        ),
      ],
    );
  }
}

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader({required this.cat, required this.provider});

  final CatProfile cat;
  final NutritionProvider provider;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final double foodProgress = provider.foodProgress;
    final double waterProgress = provider.waterProgress;
    final double foodGrams = provider.todaysFoodGrams;
    final double waterMl = provider.todaysWaterMl;
    final int foodTarget = provider.target.dailyFoodGrams.toInt();
    final int waterTarget = provider.target.dailyWaterMl.toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Hero greeting row — avatar + cat name + small subtitle.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CatPhoto(
                    networkUrl: cat.photoUrl,
                    variant: CatPhotoVariant.avatar,
                    accentHex: cat.themeAccentHex,
                    semanticLabel: 'Photo of ${cat.name}',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Today for ${cat.name}',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.name,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s nutrition',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _RingStat(
                          label: 'Food',
                          centerLabel: '${foodGrams.toInt()} / $foodTarget g',
                          progress: foodProgress,
                          color: scheme.secondary,
                          icon: Icons.restaurant_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _RingStat(
                          label: 'Water',
                          centerLabel: '${waterMl.toInt()} / $waterTarget ml',
                          progress: waterProgress,
                          color: scheme.primary,
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openFeedingSheet(context),
                          icon: const Icon(Icons.restaurant_outlined, size: 18),
                          label: const Text('Log meal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openWaterSheet(context),
                          icon: const Icon(Icons.water_drop_outlined, size: 18),
                          label: const Text('Log water'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.label,
    required this.centerLabel,
    required this.progress,
    required this.color,
    this.icon,
  });

  final String label;
  final String centerLabel;
  final double progress;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        ProgressRing(
          progress: progress,
          centerLabel: centerLabel,
          color: color,
          size: 100,
          strokeWidth: 7,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: text.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline({
    required this.feedings,
    required this.water,
    required this.onEditFeeding,
    required this.onDeleteFeeding,
    required this.onEditWater,
    required this.onDeleteWater,
  });

  final List<FeedingEntry> feedings;
  final List<WaterEntry> water;
  final ValueChanged<FeedingEntry> onEditFeeding;
  final ValueChanged<FeedingEntry> onDeleteFeeding;
  final ValueChanged<WaterEntry> onEditWater;
  final ValueChanged<WaterEntry> onDeleteWater;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (feedings.isEmpty && water.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: EmptyState(
          icon: Icons.restaurant_outlined,
          title: 'Nothing logged today',
          subtitle: 'Tap "Log meal" or "Log water" to start tracking.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (feedings.isNotEmpty) ...<Widget>[
            Text(
              'Meals',
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final FeedingEntry entry in feedings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MealCard(
                  entry: entry,
                  onDelete: () => onDeleteFeeding(entry),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (water.isNotEmpty) ...<Widget>[
            Text(
              'Water',
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final WaterEntry entry in water)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WaterCard(
                  entry: entry,
                  onDelete: () => onDeleteWater(entry),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.entry, this.onDelete});

  final WaterEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String time = DateFormat.Hm().format(entry.time);
    final String amt = entry.amountMl.truncateToDouble() == entry.amountMl
        ? entry.amountMl.toInt().toString()
        : entry.amountMl.toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.water_drop_outlined,
                color: scheme.tertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$amt ml',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.note!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<DailyTotals> days;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final double maxFood = days
        .map((DailyTotals d) => d.foodGrams)
        .fold<double>(0, (double a, double b) => a > b ? a : b);
    final double maxWater = days
        .map((DailyTotals d) => d.waterMl)
        .fold<double>(0, (double a, double b) => a > b ? a : b);
    final double maxBar = (maxFood > maxWater ? maxFood : maxWater);
    final double scale = maxBar <= 0 ? 1.0 : maxBar;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (final DailyTotals day in days)
              Expanded(
                child: _DayBar(
                  day: day,
                  maxBar: scale,
                  foodColor: scheme.primary,
                  waterColor: scheme.tertiary,
                  labelStyle: text.labelSmall ?? const TextStyle(),
                  mutedColor: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.maxBar,
    required this.foodColor,
    required this.waterColor,
    required this.labelStyle,
    required this.mutedColor,
  });

  final DailyTotals day;
  final double maxBar;
  final Color foodColor;
  final Color waterColor;
  final TextStyle labelStyle;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final double foodFraction = maxBar <= 0
        ? 0
        : (day.foodGrams / maxBar).clamp(0.0, 1.0);
    final double waterFraction = maxBar <= 0
        ? 0
        : (day.waterMl / maxBar).clamp(0.0, 1.0);
    final DateTime now = DateTime.now();
    final bool isToday =
        day.day.year == now.year &&
        day.day.month == now.month &&
        day.day.day == now.day;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 80 * foodFraction,
                  decoration: BoxDecoration(
                    color: foodColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 80 * waterFraction,
                  decoration: BoxDecoration(
                    color: waterColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.E().format(day.day),
            style: labelStyle.copyWith(
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NoActiveCat extends StatelessWidget {
  const _NoActiveCat();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.pets_outlined,
      title: 'No active cat',
      subtitle:
          'Add a cat from the Home or Profile tab to start tracking nutrition.',
    );
  }
}

void _openFeedingSheet(BuildContext context, {FeedingEntry? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => FeedingEditSheet(existing: existing),
  );
}

void _openWaterSheet(BuildContext context, {WaterEntry? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => WaterEditSheet(existing: existing),
  );
}

Future<void> _confirmDeleteFeeding(
  BuildContext context,
  FeedingEntry entry,
) async {
  final NutritionProvider provider = context.read<NutritionProvider>();
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Delete meal?'),
      content: const Text('This removes the meal from the log.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) await provider.deleteFeeding(entry);
}

Future<void> _confirmDeleteWater(BuildContext context, WaterEntry entry) async {
  final NutritionProvider provider = context.read<NutritionProvider>();
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Delete water entry?'),
      content: const Text('This removes the entry from the log.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) await provider.deleteWater(entry);
}
