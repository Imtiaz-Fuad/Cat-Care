import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/vaccination.dart';
import '../../../core/models/content/vaccine_info.dart';
import '../../../core/services/content/content_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../providers/vaccination_provider.dart';
import '../services/vaccination_manager.dart';
import 'add_vaccination_screen.dart';
import 'vaccination_detail_screen.dart';

/// Phase 5 list screen for vaccinations administered to the active cat.
///
/// Each row shows vaccine code + administered date and a status chip
/// (current / upcoming / overdue) computed from `VaccinationManager`.
/// Tap a row to open the detail screen; the FAB opens the add screen.
class VaccinationListScreen extends StatelessWidget {
  const VaccinationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VaccinationProvider>(
      builder: (BuildContext context, VaccinationProvider p, Widget? _) {
        if (p.isLoading && p.records.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vaccinations')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final AppFailureBanner? banner = _bannerFor(p);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vaccinations'),
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
            label: const Text('Log vaccine'),
          ),
          body: p.records.isEmpty
              ? EmptyState(
                  icon: Icons.vaccines_outlined,
                  title: 'No vaccinations logged',
                  subtitle:
                      'Track every vaccine so you never miss the next booster.',
                  actionLabel: 'Log first vaccine',
                  onAction: () => _openAdd(context),
                )
              : Column(
                  children: <Widget>[
                    ?banner,
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: p.records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) =>
                            _VaccinationTile(record: p.records[index]),
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
        builder: (_) => const AddVaccinationScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  AppFailureBanner? _bannerFor(VaccinationProvider p) {
    if (p.lastError == null) return null;
    return AppFailureBanner(message: p.lastError!.message, onRetry: p.retry);
  }
}

/// Pure helper so the list can colour-code each record without
/// holding its own copy of [VaccinationManager].
({String label, Color color, IconData icon}) deriveStatus(
  Vaccination v, {
  required DateTime now,
  required DateTime? nextDue,
}) {
  if (nextDue == null) {
    return (
      label: 'No cadence',
      color: const Color(0xFF6B7280),
      icon: Icons.help_outline,
    );
  }
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(nextDue.year, nextDue.month, nextDue.day);
  if (due.isBefore(today)) {
    return (
      label: 'Overdue',
      color: const Color(0xFFDC2626),
      icon: Icons.error_outline,
    );
  }
  final daysLeft = due.difference(today).inDays;
  if (daysLeft <= 30) {
    return (
      label: 'Due in ${daysLeft}d',
      color: const Color(0xFFD97706),
      icon: Icons.schedule,
    );
  }
  return (
    label: 'Current',
    color: const Color(0xFF059669),
    icon: Icons.verified_outlined,
  );
}

class _VaccinationTile extends StatelessWidget {
  const _VaccinationTile({required this.record});

  final Vaccination record;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final DateFormat fmt = DateFormat('MMM d, y');
    final status = deriveStatus(
      record,
      now: DateTime.now(),
      nextDue: record.nextDue,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => VaccinationDetailScreen(recordId: record.id),
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
                    child: FutureBuilder<VaccineInfo?>(
                      future: context.read<ContentRepository>().getVaccineInfo(
                        _displayCode(record.vaccineCode),
                      ),
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              info?.name ?? _displayCode(record.vaccineCode),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (info != null && info.description.isNotEmpty)
                              Text(
                                info.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  fontSize: (text.bodySmall?.fontSize ?? 12) * 1.15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA44A2A),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  StatusChip(
                    label: status.label,
                    color: status.color,
                    icon: status.icon,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Given ${fmt.format(record.administeredAt)}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (record.nextDue != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Next due ${fmt.format(record.nextDue!)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (record.vetName != null &&
                  record.vetName!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.vetName!,
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
}

/// Compact error banner reused by the Phase 5 list screens.
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _displayCode(String code) =>
    code == 'PLACEHOLDER-FVRCP' ? 'FVRCP' : code;
