import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/medication.dart';
import '../providers/medication_provider.dart';
import 'medication_edit_screen.dart';

/// Read-only view of a single [Medication]. Includes a check-off
/// toggle for "today" (driven by [MedicationProvider.toggleToday]).
class MedicationDetailScreen extends StatelessWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});

  final String medicationId;

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicationProvider>(
      builder: (BuildContext context, MedicationProvider p, Widget? _) {
        Medication? found;
        for (final m in p.records) {
          if (m.id == medicationId) {
            found = m;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Medication')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final Medication med = found;
        final DateFormat fmt = DateFormat('MMM d, y');
        final String todayKey = med.dayKey(DateTime.now());
        final bool checkedToday = med.dailyCheckOff[todayKey] ?? false;
        final DateFormat tf = DateFormat('HH:mm');
        return Scaffold(
          appBar: AppBar(
            title: const Text('Medication'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicationEditScreen(existing: med),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, p, med),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Text(
                med.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(med.dose, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Frequency: ${med.frequency}'),
              const SizedBox(height: 12),
              _MetaRow(label: 'Start', value: fmt.format(med.startDate)),
              if (med.endDate != null)
                _MetaRow(label: 'End', value: fmt.format(med.endDate!)),
              _MetaRow(
                label: 'Status',
                value: med.active
                    ? (med.isActiveOn(DateTime.now()) ? 'Active today' : 'Scheduled')
                    : 'Inactive',
              ),
              if (med.reminderTimes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final DateTime t in med.reminderTimes)
                      Chip(label: Text(tf.format(t))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Card(
                color: checkedToday
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: SwitchListTile.adaptive(
                  value: checkedToday,
                  onChanged: (_) async {
                    await p.toggleToday(med);
                  },
                  title: const Text('Marked given today'),
                  subtitle: Text(
                    'Tap to ${checkedToday ? 'unmark' : 'confirm'} you gave '
                    'this dose on ${fmt.format(DateTime.now())}.',
                  ),
                ),
              ),
              if (med.notes != null && med.notes!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(med.notes!),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MedicationProvider p,
    Medication med,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete medication?'),
        content: Text(
          'This removes the ${med.name} record and clears its scheduled reminders.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await p.delete(med.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}