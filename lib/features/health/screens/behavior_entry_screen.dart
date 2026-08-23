import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/behavior_log.dart';
import '../providers/behavior_provider.dart';
import 'behavior_history_screen.dart';

/// Quick (<=30s) observation form. Per PRD Â§6.11 we capture a small
/// snapshot of how the cat is doing today plus an optional note.
class BehaviorEntryScreen extends StatefulWidget {
  const BehaviorEntryScreen({super.key});

  @override
  State<BehaviorEntryScreen> createState() => _BehaviorEntryScreenState();
}

class _BehaviorEntryScreenState extends State<BehaviorEntryScreen> {
  int? _appetite;
  int? _activity;
  int? _mood;
  double? _sleepHours;
  bool? _vomiting;
  bool? _diarrhea;
  bool? _urinationNormal;
  bool? _litterNormal;
  bool? _aggression;
  bool? _hiding;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Behavior check-in'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const BehaviorHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            Text('How is your cat doing?', style: text.titleMedium),
            const SizedBox(height: 16),
            _RatingRow(
              title: 'Appetite',
              value: _appetite,
              onChanged: (int v) => setState(() => _appetite = v),
            ),
            _RatingRow(
              title: 'Activity',
              value: _activity,
              onChanged: (int v) => setState(() => _activity = v),
            ),
            _RatingRow(
              title: 'Mood',
              value: _mood,
              onChanged: (int v) => setState(() => _mood = v),
            ),
            _SleepField(
              hours: _sleepHours,
              onChanged: (double v) => setState(() => _sleepHours = v),
            ),
            const SizedBox(height: 8),
            _TriStateRow(
              title: 'Vomiting',
              value: _vomiting,
              onChanged: (bool? v) => setState(() => _vomiting = v),
            ),
            _TriStateRow(
              title: 'Diarrhea',
              value: _diarrhea,
              onChanged: (bool? v) => setState(() => _diarrhea = v),
            ),
            _TriStateRow(
              title: 'Urination normal',
              value: _urinationNormal,
              onChanged: (bool? v) => setState(() => _urinationNormal = v),
            ),
            _TriStateRow(
              title: 'Litter use normal',
              value: _litterNormal,
              onChanged: (bool? v) => setState(() => _litterNormal = v),
            ),
            _TriStateRow(
              title: 'Aggression',
              value: _aggression,
              onChanged: (bool? v) => setState(() => _aggression = v),
            ),
            _TriStateRow(
              title: 'Hiding',
              value: _hiding,
              onChanged: (bool? v) => setState(() => _hiding = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_saving) ...<Widget>[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final BehaviorProvider provider = context.read<BehaviorProvider>();
    final draft = BehaviorLog(
      id: '',
      catId: '',
      recordedAt: DateTime.now(),
      appetite: _appetite,
      activity: _activity,
      mood: _mood,
      sleepHours: _sleepHours,
      vomitingPresent: _vomiting,
      diarrheaPresent: _diarrhea,
      urinationNormal: _urinationNormal,
      litterNormal: _litterNormal,
      aggressionPresent: _aggression,
      hidingPresent: _hiding,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    final created = await provider.add(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.lastError?.message ?? 'Could not save.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  icon: Icon(
                    i <= (value ?? 0) ? Icons.star : Icons.star_border,
                    color: i <= (value ?? 0)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () => onChanged(i),
                ),
              const Spacer(),
              Text(
                value == null ? '—' : '$value / 5',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepField extends StatelessWidget {
  const _SleepField({required this.hours, required this.onChanged});

  final double? hours;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Text('Sleep'),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: hours ?? 8,
              min: 0,
              max: 20,
              divisions: 40,
              label: '${(hours ?? 8).toStringAsFixed(1)}h',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              hours == null ? '—' : '${hours!.toStringAsFixed(1)}h',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriStateRow extends StatelessWidget {
  const _TriStateRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title)),
          SegmentedButton<bool?>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<bool?>>[
              ButtonSegment<bool?>(value: true, label: Text('Yes')),
              ButtonSegment<bool?>(value: false, label: Text('No')),
            ],
            selected: <bool?>{value},
            emptySelectionAllowed: true,
            onSelectionChanged: (Set<bool?> s) => onChanged(s.firstOrNull),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
