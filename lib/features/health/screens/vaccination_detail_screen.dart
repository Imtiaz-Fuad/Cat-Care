import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/vaccination.dart';
import '../providers/vaccination_provider.dart';

/// Read-only view of a single [Vaccination]. Delete is available via
/// the overflow menu; we rely on `VaccinationProvider.records` to
/// keep the screen reactive if the record is edited elsewhere.
class VaccinationDetailScreen extends StatelessWidget {
  const VaccinationDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    return Consumer<VaccinationProvider>(
      builder: (BuildContext context, VaccinationProvider p, Widget? _) {
        Vaccination? found;
        for (final v in p.records) {
          if (v.id == recordId) {
            found = v;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vaccination')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final Vaccination record = found;
        final DateFormat fmt = DateFormat('MMM d, y');
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vaccination'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, p, record),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Text(
                record.vaccineCode,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _MetaRow(
                label: 'Administered',
                value: fmt.format(record.administeredAt),
              ),
              if (record.nextDue != null)
                _MetaRow(label: 'Next due', value: fmt.format(record.nextDue!)),
              if (record.vetName != null && record.vetName!.isNotEmpty)
                _MetaRow(label: 'Vet', value: record.vetName!),
              if (record.batchNumber != null && record.batchNumber!.isNotEmpty)
                _MetaRow(label: 'Batch', value: record.batchNumber!),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    record.reminderEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    record.reminderEnabled
                        ? 'Reminders enabled'
                        : 'Reminders off',
                  ),
                ],
              ),
              if (record.notes != null && record.notes!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(record.notes!),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VaccinationProvider p,
    Vaccination record,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete vaccination?'),
        content: Text(
          'This removes the ${record.vaccineCode} record. '
          'This cannot be undone.',
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
      await p.delete(record.id);
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
            width: 120,
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
