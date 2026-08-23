import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/weight_entry.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/weight_provider.dart';
import 'weight_entry_screen.dart';

/// Renders the chronological weight history for the active cat with
/// a hand-rolled line chart (no chart package dependency) and a list
/// of every recorded entry.
class WeightTrendScreen extends StatelessWidget {
  const WeightTrendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (BuildContext context, WeightProvider p, Widget? _) {
        if (p.isLoading && p.records.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Weight trend')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final List<WeightEntry> chronological = p.chronological;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Weight trend'),
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
                builder: (_) => const WeightEntryScreen(),
                fullscreenDialog: true,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Log weight'),
          ),
          body: p.records.isEmpty
              ? const EmptyState(
                  icon: Icons.monitor_weight_outlined,
                  title: 'No weights logged',
                  subtitle:
                      'A monthly weigh-in helps catch health trends early.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Trend (kg)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: _WeightChart(entries: chronological),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'History',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final WeightEntry w in p.records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _WeightTile(entry: w),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.entry});

  final WeightEntry entry;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MMM d, y');
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        title: Text('${entry.weightKg.toStringAsFixed(2)} kg'),
        subtitle: Text(fmt.format(entry.recordedAt)),
        trailing: (entry.notes != null && entry.notes!.isNotEmpty)
            ? Icon(
                Icons.notes,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (BuildContext ctx) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(entry.recordedAt.toString(), style: text.titleSmall),
                  const SizedBox(height: 8),
                  if (entry.notes != null && entry.notes!.isNotEmpty)
                    Text(entry.notes!)
                  else
                    const Text('No notes for this entry.'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hand-drawn line chart. We compute min/max from the data and draw
/// straight segments between consecutive points. No external chart
/// dependency is introduced.
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Center(
        child: Text(
          entries.isEmpty
              ? 'No data'
              : 'Need at least 2 points to draw a trend.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final List<double> weights =
        entries.map((WeightEntry e) => e.weightKg).toList(growable: false);
    final double minW = weights.reduce((a, b) => a < b ? a : b);
    final double maxW = weights.reduce((a, b) => a > b ? a : b);
    final double pad = ((maxW - minW) * 0.1).clamp(0.1, 0.5);
    return CustomPaint(
      painter: _ChartPainter(
        entries: entries,
        minY: minW - pad,
        maxY: maxW + pad,
        color: Theme.of(context).colorScheme.primary,
        gridColor:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.entries,
    required this.minY,
    required this.maxY,
    required this.color,
    required this.gridColor,
    required this.labelColor,
  });

  final List<WeightEntry> entries;
  final double minY;
  final double maxY;
  final Color color;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final double w = size.width;
    final double h = size.height;
    final double leftPad = 36;
    final double bottomPad = 18;
    final double plotW = w - leftPad - 4;
    final double plotH = h - bottomPad - 8;
    final double span = (maxY - minY).abs() < 0.0001 ? 1.0 : (maxY - minY);
    final DateTime first = entries.first.recordedAt;
    final DateTime last = entries.last.recordedAt;
    final double totalMs =
        (last.difference(first).inMilliseconds.abs()).toDouble();
    final double msScale =
        totalMs < 1 ? 1.0 : totalMs;

    Offset toScreen(WeightEntry e) {
      final double y = plotH - ((e.weightKg - minY) / span) * plotH + 8;
      final double dx = totalMs < 1
          ? plotW / 2
          : (e.recordedAt.difference(first).inMilliseconds / msScale) * plotW;
      return Offset(leftPad + dx, y);
    }

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double y = 8 + (plotH / 4) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(w - 4, y), grid);
    }
    final TextPainter? minLabel = _label(
      '${minY.toStringAsFixed(1)}',
      labelColor,
    );
    minLabel?.paint(canvas, Offset(0, plotH - 4));
    final TextPainter? maxLabel = _label(
      '${maxY.toStringAsFixed(1)}',
      labelColor,
    );
    maxLabel?.paint(canvas, Offset(0, 4));

    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final Path path = Path();
    for (int i = 0; i < entries.length; i++) {
      final Offset p = toScreen(entries[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    final Paint dot = Paint()..color = color;
    for (final WeightEntry e in entries) {
      final Offset p = toScreen(e);
      canvas.drawCircle(p, 3, dot);
    }
  }

  TextPainter? _label(String text, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.entries != entries || old.minY != minY || old.maxY != maxY;
}