import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/health_record.dart';
import '../providers/health_provider.dart';

/// Read-only view of a single [HealthRecord], with an attached
/// delete action that confirms before calling
/// [HealthProvider.delete].
class HealthRecordDetailScreen extends StatelessWidget {
  const HealthRecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  HealthRecord? _findRecord(HealthProvider p) {
    for (final HealthRecord r in p.records) {
      if (r.id == recordId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Consumer<HealthProvider>(
      builder: (BuildContext context, HealthProvider p, Widget? _) {
        final HealthRecord? record = _findRecord(p);
        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Health record')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final DateFormat fmt = DateFormat('MMM d, y');
        return Scaffold(
          appBar: AppBar(
            title: const Text('Health record'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, p),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              Text(record.title, style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                fmt.format(record.recordedAt),
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (record.vetName != null && record.vetName!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MetaRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Vet / clinic',
                  value: record.vetName!,
                ),
              ],
              if (record.diagnosis != null &&
                  record.diagnosis!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Diagnosis'),
                const SizedBox(height: 4),
                Text(record.diagnosis!, style: text.bodyMedium),
              ],
              if (record.prescription != null &&
                  record.prescription!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Prescription'),
                const SizedBox(height: 4),
                Text(record.prescription!, style: text.bodyMedium),
              ],
              if (record.medicines.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Medicines'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String m in record.medicines)
                      Chip(label: Text(m)),
                  ],
                ),
              ],
              if (record.vaccines.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Vaccines'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String v in record.vaccines)
                      Chip(label: Text(v)),
                  ],
                ),
              ],
              if (record.tests.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Tests'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String t in record.tests)
                      Chip(label: Text(t)),
                  ],
                ),
              ],
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: 'Notes'),
                const SizedBox(height: 4),
                Text(record.notes!, style: text.bodyMedium),
              ],
              if (record.fileAttachments.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionLabel(
                  label: 'Photos (${record.fileAttachments.length})',
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: <Widget>[
                    for (final String url in record.fileAttachments)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () => _previewImage(context, url),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: scheme.surfaceContainerHighest,
                            ),
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
                  ],
                ),
              ],
              if (p.lastError != null) ...[
                const SizedBox(height: 24),
                _ErrorPanel(failure: p.lastError!, onRetry: p.retry),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HealthProvider p,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
          'The record and any attached photos will be removed from '
          'the cat\u2019s history.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await p.delete(recordId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _previewImage(BuildContext context, String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewScreen(url: url),
        fullscreenDialog: true,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              failure.message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PhotoViewScreen extends StatelessWidget {
  const _PhotoViewScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const CircularProgressIndicator(),
            errorWidget: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}