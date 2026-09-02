import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cat_profile.dart';
import '../../../core/models/medication.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/routine_item_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../cats/providers/cat_provider.dart';
import '../../cats/widgets/cat_photo.dart';
import '../../health/providers/medication_provider.dart';
import '../../../routes/app_routes.dart';
import '../providers/routine_provider.dart';
import '../widgets/routine_edit_sheet.dart';

/// Routine screen — see `docs/catcare.design` § "Daily Loop / Routine".
///
/// Groups today's tasks into Morning / Midday / Evening buckets
/// (anything without a timeOfDay falls under "Anytime"). Tapping a
/// tile opens the edit bottom sheet; the leading circle toggles
/// completion. The header surfaces today's completion ring + a
/// regenerate button.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoutineProvider, CatProvider>(
      builder:
          (
            BuildContext context,
            RoutineProvider provider,
            CatProvider catProvider,
            Widget? _,
          ) {
            final List<RoutineTask> tasks = provider.routines;
            final bool loading = !provider.hasLoaded;
            final CatProfile? cat = catProvider.activeCat;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Routine'),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Regenerate defaults',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: provider.isBusy
                        ? null
                        : () => _confirmRegenerate(context, provider),
                  ),
                  IconButton(
                    tooltip: 'Add routine',
                    icon: const Icon(Icons.add),
                    onPressed: () => _openEditor(context),
                  ),
                ],
              ),
              body: loading
                  ? const Center(child: CircularProgressIndicator())
                  : _Body(
                      tasks: tasks,
                      cat: cat,
                    ),
              floatingActionButton: loading
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New task'),
                    ),
            );
          },
    );
  }

  Future<void> _openEditor(BuildContext context, {RoutineTask? task}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => RoutineEditSheet(existing: task),
    );
  }

  Future<void> _confirmRegenerate(
    BuildContext context,
    RoutineProvider provider,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Regenerate defaults?'),
        content: const Text(
          'New routines matching your cat\'s life stage will be added. '
          'Existing tasks are kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add defaults'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.reseedDefaults();
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.tasks,
    required this.cat,
  });

  final List<RoutineTask> tasks;
  final CatProfile? cat;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const EmptyState(
        title: 'No routines yet',
        subtitle:
            'Tap “New task” to add your first routine, or regenerate defaults for a head start.',
        icon: Icons.event_note_outlined,
      );
    }
    final List<RoutineTask> visibleTasks = _withoutDuplicates(tasks);
    final Map<_Bucket, List<RoutineTask>> grouped = _group(visibleTasks);
    return CustomScrollView(
      slivers: <Widget>[
        if (cat != null)
          SliverToBoxAdapter(child: _RoutineHeroHeader(cat: cat!)),
        SliverToBoxAdapter(child: _CareShortcutsCard(cat: cat)),
        const SliverToBoxAdapter(child: _TodaysMedsCard()),
        for (final _Bucket bucket in _Bucket.values)
          if (grouped[bucket]!.isNotEmpty)
            _BucketSection(bucket: bucket, tasks: grouped[bucket]!),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Map<_Bucket, List<RoutineTask>> _group(List<RoutineTask> tasks) {
    final Map<_Bucket, List<RoutineTask>> out = <_Bucket, List<RoutineTask>>{
      for (final _Bucket b in _Bucket.values) b: <RoutineTask>[],
    };
    for (final RoutineTask t in tasks) {
      final _Bucket b = _bucketFor(t.timeOfDay);
      out[b]!.add(t);
    }
    for (final List<RoutineTask> bucket in out.values) {
      bucket.sort((RoutineTask a, RoutineTask b) {
        final DateTime? at = a.timeOfDay;
        final DateTime? bt = b.timeOfDay;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    }
    return out;
  }

  /// Keep one visible row for a routine with the same title, category, and
  /// scheduled time. This is presentation-only; persisted records remain
  /// unchanged so no routine data is deleted implicitly from the UI.
  List<RoutineTask> _withoutDuplicates(List<RoutineTask> tasks) {
    final Set<String> seen = <String>{};
    return tasks.where((RoutineTask task) {
      final DateTime? time = task.timeOfDay;
      final String key = '${task.title.trim().toLowerCase()}|'
          '${task.category.trim().toLowerCase()}|'
          '${time?.hour ?? -1}:${time?.minute ?? -1}';
      return seen.add(key);
    }).toList(growable: false);
  }

  static _Bucket _bucketFor(DateTime? t) {
    if (t == null) return _Bucket.anytime;
    if (t.hour < 11) return _Bucket.morning;
    if (t.hour < 17) return _Bucket.midday;
    return _Bucket.evening;
  }
}

enum _Bucket {
  morning('Morning', Icons.wb_sunny_outlined),
  midday('Midday', Icons.wb_cloudy_outlined),
  evening('Evening', Icons.nights_stay_outlined),
  anytime('Anytime', Icons.schedule_outlined);

  const _Bucket(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _BucketSection extends StatelessWidget {
  const _BucketSection({required this.bucket, required this.tasks});

  final _Bucket bucket;
  final List<RoutineTask> tasks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int done = tasks.where((RoutineTask t) => t.completed).length;
    return SliverList.list(
      children: <Widget>[
        SectionHeader(
          title: bucket.label,
          subtitle: '$done of ${tasks.length} done',
          trailing: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(bucket.icon, color: scheme.secondary, size: 18),
          ),
        ),
        for (final RoutineTask t in tasks)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _TaskTile(task: t),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final RoutineTask task;

  @override
  Widget build(BuildContext context) {
    final RoutineProvider provider = context.read<RoutineProvider>();
    final bool overdue = _isOverdue(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RoutineItemTile(
          task: task,
          onToggle: (bool v) => provider.setCompletion(task, done: v),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (BuildContext ctx) => RoutineEditSheet(existing: task),
          ),
        ),
        if (overdue)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: StatusChip(
                label: 'Overdue',
                color: Theme.of(context).colorScheme.error,
                icon: Icons.error_outline,
              ),
            ),
          ),
      ],
    );
  }

  static bool _isOverdue(RoutineTask t) {
    if (t.completed || t.timeOfDay == null) return false;
    final DateTime now = DateTime.now();
    final DateTime due = DateTime(
      now.year,
      now.month,
      now.day,
      t.timeOfDay!.hour,
      t.timeOfDay!.minute,
    );
    return now.isAfter(due);
  }
}

/// Tiny helper used by callers needing today's date label.
String todayLabel() => DateFormat.MMMMEEEEd().format(DateTime.now());

/// Hero greeting header for the Routine screen — avatar + cat name
/// followed by a calm "let's keep {name} comfortable today" line.
class _RoutineHeroHeader extends StatelessWidget {
  const _RoutineHeroHeader({required this.cat});

  final CatProfile cat;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            height: 52,
            child: FutureBuilder<String?>(
              future: context.read<CatProvider>().localPhotoPath(cat.id),
              builder: (BuildContext context, snapshot) {
                return CatPhoto(
                  localPath: snapshot.data,
                  variant: CatPhotoVariant.avatar,
                  accentHex: cat.themeAccentHex,
                  useCatEmojiFallback: true,
                  semanticLabel: 'Photo of ${cat.name}',
                );
              },
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
    );
  }
}

class _CareShortcutsCard extends StatelessWidget {
  const _CareShortcutsCard({required this.cat});

  final CatProfile? cat;

  @override
  Widget build(BuildContext context) {
    final String catName = cat?.name ?? 'your cat';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: const Color(0xFFFFF0E7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                "Don't forget to add $catName's medicine",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.medication_outlined,
                      label: 'Medications',
                      onTap: () => context.push(AppRoutes.medications),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.vaccines_outlined,
                      label: 'Vaccinations',
                      onTap: () => context.push(AppRoutes.vaccinations),
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

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6DDD3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(width: 2),
            Icon(icon, size: 18, color: Color(0xFFA9472A)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8C341F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card shown on the Routine screen: lists the medications that are
/// active today and exposes a one-tap check-off per item. Backed by
/// [MedicationProvider.toggleToday], which writes to Firestore via the
/// existing medication repository.
class _TodaysMedsCard extends StatelessWidget {
  const _TodaysMedsCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Consumer<MedicationProvider>(
      builder: (BuildContext context, MedicationProvider provider, Widget? _) {
        final List<Medication> meds = provider.active;
        if (meds.isEmpty) {
          return const SizedBox.shrink();
        }
        final DateFormat tf = DateFormat('HH:mm');
        final String todayKey = _todayKey(DateTime.now());
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_outlined,
                          size: 18,
                          color: scheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Today\'s medications',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final Medication m in meds)
                    _MedCheckRow(
                      medication: m,
                      checked: m.dailyCheckOff[todayKey] ?? false,
                      timeLabel: m.reminderTimes.isEmpty
                          ? null
                          : tf.format(m.reminderTimes.first),
                      onToggle: () => provider.toggleToday(m),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _todayKey(DateTime day) {
    final String y = day.year.toString().padLeft(4, '0');
    final String m = day.month.toString().padLeft(2, '0');
    final String d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _MedCheckRow extends StatelessWidget {
  const _MedCheckRow({
    required this.medication,
    required this.checked,
    required this.timeLabel,
    required this.onToggle,
  });

  final Medication medication;
  final bool checked;
  final String? timeLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              checked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: checked ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    medication.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  Text(
                    '${medication.dose} • ${medication.frequency}'
                    '${timeLabel != null ? ' • $timeLabel' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
