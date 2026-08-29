import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/content/emergency_guidance.dart';
import '../../../core/services/content/content_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/ai_guardrail_banner.dart';

/// Local emergency guidance — **no AI call**. This screen pulls the
/// `content/emergency/*` collection via [ContentRepository] and
/// renders the static, vet-curated cards. PRD §8 forbids using AI to
/// triage emergencies (latency + liability), so the Cloud Function
/// is intentionally never invoked here.
///
/// Each card shows signs to watch for, what to do / not do, and a
/// strong "contact a vet immediately" call-to-action.
class EmergencyGuidanceScreen extends StatefulWidget {
  const EmergencyGuidanceScreen({super.key});

  @override
  State<EmergencyGuidanceScreen> createState() =>
      _EmergencyGuidanceScreenState();
}

class _EmergencyGuidanceScreenState extends State<EmergencyGuidanceScreen> {
  Future<List<EmergencyGuidance>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<EmergencyGuidance>> _load() async {
    final ContentRepository repo = context.read<ContentRepository>();
    return repo.listEmergencyGuidance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Guidance')),
      body: FutureBuilder<List<EmergencyGuidance>>(
        future: _future,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<EmergencyGuidance>> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load guidance',
                  subtitle: '${snapshot.error}',
                );
              }
              final List<EmergencyGuidance> items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_hospital_outlined,
                  title: 'No guidance available',
                  subtitle:
                      'Emergency guidance will appear here once the content is seeded.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: items.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: AiGuardrailBanner(
                        message:
                            'These are general safety notes, not a diagnosis. '
                            'If your cat shows any of these signs, contact a vet '
                            'immediately.',
                        icon: Icons.warning_amber_outlined,
                      ),
                    );
                  }
                  return _EmergencyCard(item: items[index - 1]);
                },
              );
            },
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.item});

  final EmergencyGuidance item;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _iconFor(item.severity),
                  color: _colorFor(item.severity, scheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SeverityChip(severity: item.severity),
              ],
            ),
            if (item.summary != null &&
                item.summary!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(item.summary!, style: text.bodyMedium),
            ],
            if (item.signs.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Signs to watch for', style: text.titleSmall),
              const SizedBox(height: 4),
              for (final String s in item.signs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(child: Text(s, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
            if (item.doNow.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Do now', style: text.titleSmall),
              const SizedBox(height: 4),
              for (final String s in item.doNow)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check, color: scheme.primary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(s, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
            if (item.doNot.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Do not', style: text.titleSmall),
              const SizedBox(height: 4),
              for (final String s in item.doNot)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.close, color: scheme.error, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(s, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.local_hospital, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact a vet immediately.',
                      style: text.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (item.source != null &&
                item.source!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Source: ${item.source!}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.report_gmailerrorred_outlined;
      case 'urgent':
        return Icons.priority_high_outlined;
      default:
        return Icons.visibility_outlined;
    }
  }

  Color _colorFor(String severity, ColorScheme scheme) {
    switch (severity) {
      case 'critical':
        return scheme.error;
      case 'urgent':
        return scheme.tertiary;
      default:
        return scheme.primary;
    }
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (severity) {
      case 'critical':
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        label = 'CRITICAL';
        break;
      case 'urgent':
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        label = 'URGENT';
        break;
      default:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        label = 'MONITOR';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
