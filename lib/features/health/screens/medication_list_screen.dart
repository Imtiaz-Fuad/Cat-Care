import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/medication.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/medication_provider.dart';
import 'medication_detail_screen.dart';
import 'medication_edit_screen.dart';

/// Phase 5 list screen for medications. Active entries (i.e. whose
/// [start, endDate] range covers "today") appear at the top so the
/// most relevant treatments are always visible.
class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicationProvider>(
      builder: (BuildContext context, MedicationProvider p, Widget? _) {
        if (p.isLoading && p.records.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Medications')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final List<Medication> active = p.active;
        final List<Medication> inactive = p.records
            .where((Medication m) => !active.contains(m))
            .toList(growable: false);
        final AppFailureBanner? banner = _bannerFor(p);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Medications'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: p.retry,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAdd(context),
            icon: const Icon(Icons.add),
            label: const Text('New medication'),
          ),
          body: p.records.isEmpty
              ? EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'No medications yet',
                  subtitle:
                      'Track prescriptions, dosage and reminders so nothing slips.',
                  actionLabel: 'Add first medication',
                  onAction: () => _openAdd(context),
                )
              : Column(
                  children: <Widget>[
                    ?banner,
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: <Widget>[
                          if (active.isNotEmpty) ...<Widget>[
                            _SectionTitle(text: 'Active now (${active.length})'),
                            const SizedBox(height: 8),
                            for (final Medication m in active) ...<Widget>[
                              _MedicationTile(medication: m),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (inactive.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 16),
                            _SectionTitle(
                              text: 'Inactive (${inactive.length})',
                            ),
                            const SizedBox(height: 8),
                            for (final Medication m in inactive) ...<Widget>[
                              _MedicationTile(medication: m),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MedicationEditScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  AppFailureBanner? _bannerFor(MedicationProvider p) {
    if (p.lastError == null) return null;
    return AppFailureBanner(
      message: p.lastError!.message,
      onRetry: p.retry,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: t.titleSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('MMM d, y');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MedicationDetailScreen(medicationId: medication.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      medication.name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    medication.dose,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Frequency: ${medication.frequency}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Started ${fmt.format(medication.startDate)}'
                '${medication.endDate != null ? " → ${fmt.format(medication.endDate!)}" : ""}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (medication.reminderTimes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.alarm,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatTimes(medication.reminderTimes),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimes(List<DateTime> times) {
    final DateFormat tf = DateFormat('HH:mm');
    return times.map((DateTime t) => tf.format(t)).join(' • ');
  }
}

/// Compact error banner used by Phase 5 list screens.
class AppFailureBanner extends StatelessWidget {
  const AppFailureBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}