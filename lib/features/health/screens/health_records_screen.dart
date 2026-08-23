import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/health_record.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/health_provider.dart';
import 'add_health_record_screen.dart';
import 'health_record_detail_screen.dart';

/// Phase 5 list screen for vet visits, lab work, and notes stored
/// under `users/{uid}/cats/{catId}/health/{recordId}`.
///
/// Uses a `Consumer<HealthProvider>` so the list stays live across
/// devices. The provider is bound to the active cat from `main.dart`,
/// so no `bindCat` plumbing is needed here.
class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (BuildContext context, HealthProvider p, Widget? _) {
        if (p.isLoading && p.records.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Health records')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final AppFailureBanner? banner = _bannerFor(p);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Health records'),
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
            label: const Text('New record'),
          ),
          body: p.records.isEmpty
              ? EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: 'No health records yet',
                  subtitle:
                      'Log vet visits, diagnoses, lab results or notes '
                      'so you have a clear history.',
                  actionLabel: 'Add first record',
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
                            _RecordTile(record: p.records[index]),
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
        builder: (_) => const AddHealthRecordScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  AppFailureBanner? _bannerFor(HealthProvider p) {
    if (p.lastError == null) return null;
    return AppFailureBanner(message: p.lastError!.message, onRetry: p.retry);
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final DateFormat fmt = DateFormat('MMM d, y');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => HealthRecordDetailScreen(recordId: record.id),
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
                      record.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (record.fileAttachments.isNotEmpty)
                    _AttachmentChip(count: record.fileAttachments.length),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fmt.format(record.recordedAt),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (record.diagnosis != null && record.diagnosis!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.diagnosis!,
                  style: text.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (record.vetName != null && record.vetName!.isNotEmpty) ...[
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
              if (record.fileAttachments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: record.fileAttachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: record.fileAttachments[index],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: scheme.surfaceContainerHighest),
                        errorWidget: (_, _, _) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.attach_file, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
