import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/behavior_log.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/behavior_provider.dart';
import 'behavior_entry_screen.dart';

/// Timeline view of all recorded behavior logs for the active cat.
/// Most recent first; tapping a row expands notes if present.
class BehaviorHistoryScreen extends StatelessWidget {
  const BehaviorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BehaviorProvider>(
      builder: (BuildContext context, BehaviorProvider p, Widget? _) {
        if (p.isLoading && p.records.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Behavior history')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Behavior history'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: p.retry,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const BehaviorEntryScreen(),
                fullscreenDialog: true,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Log now'),
          ),
          body: p.records.isEmpty
              ? const EmptyState(
                  icon: Icons.timeline_outlined,
                  title: 'No behavior logs yet',
                  subtitle:
                      'Quick daily check-ins build a useful pattern over time.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: p.records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) =>
                      _LogTile(log: p.records[index]),
                ),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final BehaviorLog log;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('EEE, MMM d • HH:mm');
    final List<Widget> chips = <Widget>[];
    if (log.appetite != null) {
      chips.add(_Chip(label: 'Appetite ${log.appetite}/5'));
    }
    if (log.activity != null) {
      chips.add(_Chip(label: 'Activity ${log.activity}/5'));
    }
    if (log.mood != null) {
      chips.add(_Chip(label: 'Mood ${log.mood}/5'));
    }
    if (log.sleepHours != null) {
      chips.add(_Chip(label: 'Sleep ${log.sleepHours!.toStringAsFixed(1)}h'));
    }
    if (log.vomitingPresent == true) {
      chips.add(const _Chip(label: 'Vomiting', danger: true));
    }
    if (log.diarrheaPresent == true) {
      chips.add(const _Chip(label: 'Diarrhea', danger: true));
    }
    if (log.aggressionPresent == true) {
      chips.add(const _Chip(label: 'Aggression', danger: true));
    }
    if (log.hidingPresent == true) {
      chips.add(const _Chip(label: 'Hiding', danger: true));
    }
    if (log.urinationNormal == false) {
      chips.add(const _Chip(label: 'Urination off', danger: true));
    }
    if (log.litterNormal == false) {
      chips.add(const _Chip(label: 'Litter off', danger: true));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fmt.format(log.recordedAt),
              style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
            if (log.notes != null && log.notes!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(log.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bg = danger ? scheme.errorContainer : scheme.secondaryContainer;
    final Color fg = danger
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
