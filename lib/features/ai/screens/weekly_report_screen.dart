import 'dart:convert';

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
        const Text(
          'Find out how your Purrfect friend passed the week 🐾',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
          ),
        ),
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
            _NoDataCard(catName: catName)
          else
            _ReportCard(
              text: _readableReportText(report.text),
              generatedAt: report.generatedAt,
              fromCache: report.fromCache,
            ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFA9472A),
                  side: const BorderSide(color: Color(0xFFA9472A)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: (aiProvider.weeklyBusy || !aiProvider.aiAvailable)
                    ? null
                    : onRegenerate,
              ),
            ),
          ),
        ] else if (error == null)
          const _NoActiveReport(),
      ],
    );
  }
}

String _readableReportText(String raw) {
  var value = raw.trim();
  if (value.startsWith('```')) {
    final int newline = value.indexOf('\n');
    if (newline >= 0) value = value.substring(newline + 1);
    if (value.endsWith('```')) value = value.substring(0, value.length - 3).trim();
  }
  try {
    final dynamic decoded = jsonDecode(value);
    if (decoded is Map && decoded['text'] is String) {
      final String text = (decoded['text'] as String).trim();
      if (text.isNotEmpty) return text;
    }
  } catch (_) {
    // Older reports may already be plain text.
  }
  return raw;
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
      color: const Color(0xFFFFF0E7),
      elevation: 3,
      shadowColor: const Color(0xFFE09A79).withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFD98E70).withValues(alpha: 0.34),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 190),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
            SelectableText(
              text,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: theme.bodyMedium?.color,
              ),
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
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
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

class _NoDataCard extends StatelessWidget {
  const _NoDataCard({required this.catName});

  final String? catName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF0E7),
      elevation: 2,
      shadowColor: const Color(0xFFE09A79).withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFD98E70).withValues(alpha: 0.3),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 190),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Add enough data about ${catName ?? 'your cat'}\'s week to get the report ^_^.',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A2A1B),
            ),
          ),
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
