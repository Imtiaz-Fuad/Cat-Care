import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/empty_state.dart';
import '../../cats/providers/cat_provider.dart';
import '../providers/ai_provider.dart';
import '../repositories/ai_repository.dart';
import '../widgets/ai_guardrail_banner.dart';

/// Weekly AI summary screen — see `functions/src/index.ts`
/// `weeklyReport` handler. The Cloud Function:
///
///   1. Short-circuits with the static "Not enough data yet" text
///      when the cat has no feedings / water / weight logs in the
///      rolling 7-day window (this saves the free-tier quota).
///   2. Otherwise, summarizes the past week, writes the result to
///      `users/{uid}/cats/{catId}/weeklyReports/{weekId}`, and
///      returns the cached value on subsequent calls unless
///      `force: true`.
///
/// `weekId` here is computed on the client as the ISO week number so
/// the UI can pre-select the current week and request a different
/// week in the future (we ship just the current week for now).
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  String? _loadingForCatId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? catId = context.read<CatProvider>().activeCatId;
    if (catId != null && _loadingForCatId != catId) {
      _loadingForCatId = catId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AiProvider>().loadWeeklyReport(
          catId: catId,
          weekId: _currentWeekId(),
          force: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CatProvider, AiProvider>(
      builder:
          (
            BuildContext context,
            CatProvider catProvider,
            AiProvider aiProvider,
            Widget? _,
          ) {
            final String? catId = catProvider.activeCatId;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Weekly Report'),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.refresh),
                    onPressed: aiProvider.weeklyBusy || catId == null
                        ? null
                        : () => aiProvider.loadWeeklyReport(
                            catId: catId,
                            weekId: _currentWeekId(),
                            force: true,
                          ),
                  ),
                ],
              ),
              body: catId == null
                  ? const _NoActiveCat()
                  : _Body(
                      aiProvider: aiProvider,
                      weekId: _currentWeekId(),
                      catName: catProvider.activeCat?.name,
                      onRegenerate: () => aiProvider.loadWeeklyReport(
                        catId: catId,
                        weekId: _currentWeekId(),
                        force: true,
                      ),
                    ),
            );
          },
    );
  }

  /// ISO week id, e.g. `2024-W42`. Stable across clients and matches
  /// what the Cloud Function uses as the document id.
  static String _currentWeekId() {
    final DateTime now = DateTime.now();
    // Approximate ISO week-of-year — Flutter's intl package has
    // DateFormat('YYYY-Www') but we keep the dependency footprint
    // minimal by computing inline.
    final DateTime utc = DateTime.utc(now.year, now.month, now.day);
    final int dayOfYear =
        utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
    final int isoWeek = ((dayOfYear - utc.weekday + 10) / 7).floor();
    final int week = isoWeek < 1 ? 1 : (isoWeek > 53 ? 53 : isoWeek);
    return '${utc.year}-W${week.toString().padLeft(2, '0')}';
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.aiProvider,
    required this.weekId,
    required this.catName,
    required this.onRegenerate,
  });

  final AiProvider aiProvider;
  final String weekId;
  final String? catName;
  final Future<void> Function() onRegenerate;

  @override
  Widget build(BuildContext context) {
    final AppFailure? error = aiProvider.lastError;
    final WeeklyReportResult? report = aiProvider.weeklyReport;

    if (aiProvider.weeklyBusy && report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        const AiGuardrailBanner(),
        const SizedBox(height: 12),
        Text(
          'Week $weekId${catName != null ? '  ·  for $catName' : ''}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        if (error != null)
          aiProvider.isQuotaLimited
              ? AiQuotaBanner(onDismiss: aiProvider.clearError)
              : AiErrorCard(failure: error, onDismiss: aiProvider.clearError),
        if (report != null) ...<Widget>[
          if (report.noData)
            const _NoDataCard()
          else
            _ReportCard(
              text: report.text,
              generatedAt: report.generatedAt,
              fromCache: report.fromCache,
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate'),
            onPressed: (aiProvider.weeklyBusy || !aiProvider.aiAvailable)
                ? null
                : onRegenerate,
          ),
        ] else if (error == null)
          const _NoActiveReport(),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.text,
    required this.generatedAt,
    required this.fromCache,
  });

  final String text;
  final DateTime? generatedAt;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final TextTheme theme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(
              text,
              style: theme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  fromCache ? Icons.cached_outlined : Icons.fiber_new_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  fromCache
                      ? 'Cached'
                      : (generatedAt != null
                            ? 'Generated just now'
                            : 'Generated'),
                  style: theme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataCard extends StatelessWidget {
  const _NoDataCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Not enough data yet — log a few meals, water refills, or a '
          'weight reading this week and the report will appear on the next '
          'refresh.',
        ),
      ),
    );
  }
}

class _NoActiveReport extends StatelessWidget {
  const _NoActiveReport();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.insights_outlined,
      title: 'No report yet',
      subtitle: 'Tap "Regenerate" to generate this week\'s summary.',
    );
  }
}

class _NoActiveCat extends StatelessWidget {
  const _NoActiveCat();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.pets_outlined,
      title: 'No active cat',
      subtitle:
          'Add or select a cat from the Profile tab to generate a weekly report.',
    );
  }
}
