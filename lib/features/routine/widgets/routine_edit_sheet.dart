import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/routine_task.dart';
import '../providers/routine_provider.dart';
import '../services/routine_generator_service.dart';

/// Add/edit form for a [RoutineTask]. Presented as a modal bottom
/// sheet from the Routine screen. When [existing] is null the form
/// creates a fresh task; when supplied it edits the existing one and
/// exposes a destructive "Delete" action.
class RoutineEditSheet extends StatefulWidget {
  const RoutineEditSheet({super.key, this.existing});

  final RoutineTask? existing;

  @override
  State<RoutineEditSheet> createState() => _RoutineEditSheetState();
}

class _RoutineEditSheetState extends State<RoutineEditSheet> {
  static const List<_CategoryChoice> _categories = <_CategoryChoice>[
    _CategoryChoice(RoutineCategories.feeding, 'Feed',
        Icons.restaurant_outlined),
    _CategoryChoice(RoutineCategories.water, 'Water',
        Icons.water_drop_outlined),
    _CategoryChoice(RoutineCategories.medicine, 'Med',
        Icons.medication_outlined),
    _CategoryChoice(RoutineCategories.play, 'Play',
        Icons.toys_outlined),
    _CategoryChoice(RoutineCategories.brushing, 'Brush',
        Icons.brush_outlined),
    _CategoryChoice(RoutineCategories.grooming, 'Groom',
        Icons.content_cut_outlined),
    _CategoryChoice(RoutineCategories.litter, 'Litter',
        Icons.cleaning_services_outlined),
    _CategoryChoice(RoutineCategories.exercise, 'Exercise',
        Icons.directions_run_outlined),
    _CategoryChoice(RoutineCategories.sleep, 'Sleep', Icons.bedtime_outlined),
  ];

  static const List<_RepeatChoice> _repeatChoices = <_RepeatChoice>[
    _RepeatChoice('daily', 'Daily'),
    _RepeatChoice('weekdays', 'Weekdays'),
    _RepeatChoice('weekly', 'Weekly'),
    _RepeatChoice('custom', 'Custom'),
  ];

  late final TextEditingController _title;
  late final TextEditingController _notes;
  late String _category;
  late String _repeat;
  late bool _reminder;
  TimeOfDay? _time;
  bool _hasTime = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final RoutineTask? e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? RoutineCategories.feeding;
    _repeat = e?.repeat ?? 'daily';
    _reminder = e?.reminder ?? false;
    final DateTime? tod = e?.timeOfDay;
    if (tod != null) {
      _hasTime = true;
      _time = TimeOfDay(hour: tod.hour, minute: tod.minute);
    } else {
      _hasTime = false;
      _time = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;
  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _hasTime = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final RoutineProvider provider = context.read<RoutineProvider>();
    setState(() => _saving = true);
    final DateTime? tod = _hasTime && _time != null
        ? _composeTime(_time!)
        : null;
    if (_isEdit) {
      await provider.updateTask(
        task: widget.existing!,
        title: _title.text.trim(),
        category: _category,
        timeOfDay: tod,
        repeat: _repeat,
        reminder: _reminder,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
    } else {
      await provider.createTask(
        title: _title.text.trim(),
        category: _category,
        timeOfDay: tod,
        repeat: _repeat,
        reminder: _reminder,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final RoutineProvider provider = context.read<RoutineProvider>();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: const Text(
          'This will remove the routine and its reminders. '
          'Existing history is kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteTask(widget.existing!);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  DateTime _composeTime(TimeOfDay t) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  String _formatTimeLabel() {
    final TimeOfDay t = _time ?? const TimeOfDay(hour: 9, minute: 0);
    final DateTime now = DateTime.now();
    return DateFormat.Hm().format(DateTime(now.year, now.month, now.day,
        t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final EdgeInsets insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + insets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit routine' : 'New routine',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_isEdit)
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: _saving ? null : _confirmDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Morning meal',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Category', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _CategoryChoice c in _categories)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _category == c.id,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _hasTime,
                    onChanged: (bool v) =>
                        setState(() => _hasTime = v),
                    title: const Text('Specific time'),
                    subtitle: Text(
                      _hasTime
                          ? _formatTimeLabel()
                          : 'Anytime during the day',
                    ),
                  ),
                ),
                if (_hasTime)
                  IconButton(
                    tooltip: 'Pick time',
                    icon: const Icon(Icons.access_time_outlined),
                    onPressed: _saving ? null : _pickTime,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Repeat', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _RepeatChoice r in _repeatChoices)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: _repeat == r.id,
                    onSelected: (_) => setState(() => _repeat = r.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _reminder,
              onChanged: (bool v) => setState(() => _reminder = v),
              title: const Text('Reminder'),
              subtitle: const Text(
                'We\'ll notify you around the scheduled time.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 2,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional details, dosage, etc.',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isEdit ? 'Save' : 'Add routine'),
                    onPressed: _canSave ? _save : null,
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

class _CategoryChoice {
  const _CategoryChoice(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _RepeatChoice {
  const _RepeatChoice(this.id, this.label);
  final String id;
  final String label;
}