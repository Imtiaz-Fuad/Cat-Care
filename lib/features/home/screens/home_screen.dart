import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cat_profile.dart';
import '../../../core/models/feeding_entry.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/widgets/daily_insight_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/upcoming_card.dart';
import '../../../routes/app_routes.dart';
import '../../cats/providers/cat_provider.dart';
import '../../cats/widgets/cat_photo.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../nutrition/widgets/feeding_edit_sheet.dart';
import '../../nutrition/widgets/water_edit_sheet.dart';
import '../../routine/providers/routine_provider.dart';
import '../../routine/widgets/routine_edit_sheet.dart';

/// Home screen — see `docs/catcare.design` § "Daily Loop / Home".
///
/// Lightweight landing tab that glues together Routine + Nutrition
/// state. Shows:
///   * greeting + active cat header
///   * today's routine completion ring
///   * next 2 upcoming routines
///   * today's meals + water summary (with quick-log shortcuts)
///   * a one-line daily insight generated from the data
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatProvider>(
      builder: (BuildContext context, CatProvider catProvider, Widget? _) {
        final CatProfile? cat = catProvider.activeCat;
        final bool loading = !catProvider.hasLoaded;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Today'),
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
              : _HomeBody(cat: cat),
        );
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.cat});

  final CatProfile cat;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Consumer2<RoutineProvider, NutritionProvider>(
      builder:
          (
            BuildContext context,
            RoutineProvider routineProvider,
            NutritionProvider nutritionProvider,
            Widget? _,
          ) {
            final List<RoutineTask> todays = routineProvider.todaysRoutines;
            final int completed = routineProvider.completedTodayCount;
            final int total = routineProvider.totalRoutineCount;
            final int percent = routineProvider.completionPercent;
            final List<RoutineTask> upcoming = _nextUpcoming(todays);
            final List<FeedingEntry> recentMeals = nutritionProvider
                .todaysFeedings
                .take(3)
                .toList();
            final double foodG = nutritionProvider.todaysFoodGrams;
            final double waterMl = nutritionProvider.todaysWaterMl;
            final int foodTarget = nutritionProvider.target.dailyFoodGrams
                .toInt();
            final int waterTarget = nutritionProvider.target.dailyWaterMl
                .toInt();
            final String insight = _insightFor(
              routineProvider: routineProvider,
              nutritionProvider: nutritionProvider,
            );
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                // Hero greeting header — avatar + cat name + small subtitle.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CatPhoto(
                          networkUrl: null,
                          variant: CatPhotoVariant.avatar,
                          accentHex: cat.themeAccentHex,
                          useCatEmojiFallback: true,
                          semanticLabel: 'Photo of ${cat.name}',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _greeting(),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CompletionCard(
                    completed: completed,
                    total: total,
                    percent: percent,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: _WeeklyReportCard(
                    onTap: () => context.push(AppRoutes.weeklyReport),
                  ),
                ),
                if (upcoming.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  const _SectionTitle(title: 'Next up'),
                  for (final RoutineTask t in upcoming)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: UpcomingCard(
                        title: t.title,
                        subtitle: t.category.isEmpty
                            ? 'Routine'
                            : '${t.category[0].toUpperCase()}${t.category.substring(1)}',
                        timeLabel: _formatTime(t.timeOfDay),
                        icon: _iconForCategory(t.category),
                        iconColor: const Color(0xFF9A452A),
                        onTap: () => _openRoutineEditor(context, task: t),
                      ),
                    ),
                ] else if (total > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.check_circle_outline,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'All routines done for today. Great job!',
                                style: text.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                _SectionTitle(title: 'Today for ${cat.name}'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _NutritionSummaryCard(
                          label: 'Food',
                          centerLabel: '${foodG.toInt()} / $foodTarget g',
                          progress: nutritionProvider.foodProgress,
                          accentColor: scheme.secondary,
                          accentIcon: Icons.restaurant_outlined,
                          onTap: () => _openFeedingSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NutritionSummaryCard(
                          label: 'Water',
                          centerLabel: '${waterMl.toInt()} / $waterTarget ml',
                          progress: nutritionProvider.waterProgress,
                          accentColor: scheme.primary,
                          accentIcon: Icons.water_drop_outlined,
                          onTap: () => _openWaterSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (recentMeals.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text(
                                'Recent meals',
                                style: text.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final FeedingEntry meal in recentMeals)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: scheme.secondary.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.restaurant_outlined,
                                        size: 16,
                                        color: scheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        meal.foodName,
                                        style: text.bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.Hm().format(meal.time),
                                      style: text.labelMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DailyInsightCard(
                    title: 'Daily insight',
                    body: insight,
                  ),
                ),
              ],
            );
          },
    );
  }

  static String _greeting() {
    final DateTime now = DateTime.now();
    final int hour = now.hour;
    if (hour < 5) return 'Late night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  static String _formatTime(DateTime? t) {
    if (t == null) return 'Anytime';
    return DateFormat.Hm().format(t);
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'feeding':
        return Icons.restaurant_outlined;
      case 'play':
        return Icons.toys_outlined;
      case 'grooming':
        return Icons.shower_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'rest':
        return Icons.bedtime_outlined;
      case 'litter':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  /// Pick the next 2 routines that are not yet done today, ordered
  /// by time-of-day (nulls last).
  static List<RoutineTask> _nextUpcoming(List<RoutineTask> tasks) {
    final DateTime midnight = DateTime.now();
    final DateTime today = DateTime(
      midnight.year,
      midnight.month,
      midnight.day,
    );
    final List<RoutineTask> pending = tasks
        .where(
          (RoutineTask t) =>
              !(t.lastCompletedAt != null &&
                  !t.lastCompletedAt!.isBefore(today)),
        )
        .toList();
    pending.sort((RoutineTask a, RoutineTask b) {
      final DateTime? ta = a.timeOfDay;
      final DateTime? tb = b.timeOfDay;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return pending.take(2).toList(growable: false);
  }

  static String _insightFor({
    required RoutineProvider routineProvider,
    required NutritionProvider nutritionProvider,
  }) {
    final int percent = routineProvider.completionPercent;
    final double waterP = nutritionProvider.waterProgress;
    final double foodP = nutritionProvider.foodProgress;
    if (percent == 100) {
      return 'All routines done — give yourself (and your cat) a pat on the head.';
    }
    if (waterP < 0.5) {
      return 'Water intake is below half the daily target. Try a fresh bowl near a favorite spot.';
    }
    if (foodP > 1.2) {
      return 'Looks like over-feeding today. Watch portions at the next meal.';
    }
    if (percent >= 60) {
      return 'Nice momentum — most of today\'s routine is already in the bag.';
    }
    if (percent > 0) {
      return 'You\'re off to a good start. Two more routines and today is on track.';
    }
    return 'Start the day gently: log breakfast or a quick play session.';
  }
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      color: const Color(0xFFFFE9DD),
      elevation: 7,
      shadowColor: const Color(0xFFD97850).withValues(alpha: 0.42),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFA5482A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFF9A452A),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Weekly report',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5A2A1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See your cat’s 7-day care summary',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A452A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.completed,
    required this.total,
    required this.percent,
  });

  final int completed;
  final int total;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
              progress: total <= 0 ? 0 : percent / 100,
              centerLabel: '$percent%',
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
                    total <= 0 ? 'No routines yet' : 'Routine progress',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total <= 0
                        ? 'Add a routine to start tracking your day.'
                        : '$completed of $total done today',
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

class _NutritionSummaryCard extends StatelessWidget {
  const _NutritionSummaryCard({
    required this.label,
    required this.centerLabel,
    required this.progress,
    required this.accentColor,
    required this.accentIcon,
    required this.onTap,
  });

  final String label;
  final String centerLabel;
  final double progress;
  final Color accentColor;
  final IconData accentIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            children: <Widget>[
              ProgressRing(
                progress: progress,
                centerLabel: centerLabel,
                color: accentColor,
                size: 84,
                strokeWidth: 7,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(accentIcon, size: 14, color: accentColor),
                  const SizedBox(width: 6),
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
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
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
      title: 'Welcome to CatCare',
      subtitle:
          'Add a cat from the Profile tab to see today\'s routine and nutrition.',
    );
  }
}

Future<void> _openFeedingSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const FeedingEditSheet(),
  );
}

Future<void> _openWaterSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const WaterEditSheet(),
  );
}

Future<void> _openRoutineEditor(
  BuildContext context, {
  required RoutineTask task,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => RoutineEditSheet(existing: task),
  );
}
