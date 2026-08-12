import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/feeding_entry.dart';
import '../providers/nutrition_provider.dart';

/// Add/edit form for a [FeedingEntry]. Presented as a modal bottom
/// sheet from the Nutrition screen. When [existing] is null the
/// form creates a new entry; when supplied it edits and exposes a
/// destructive delete action.
class FeedingEditSheet extends StatefulWidget {
  const FeedingEditSheet({super.key, this.existing});

  final FeedingEntry? existing;

  @override
  State<FeedingEditSheet> createState() => _FeedingEditSheetState();
}

class _FeedingEditSheetState extends State<FeedingEditSheet> {
  static const List<_FoodType> _foodTypes = <_FoodType>[
    _FoodType('dry', 'Dry'),
    _FoodType('wet', 'Wet'),
    _FoodType('raw', 'Raw'),
    _FoodType('treat', 'Treat'),
    _FoodType('mixed', 'Mixed'),
  ];

  static const List<_Unit> _units = <_Unit>[
    _Unit('g', 'g'),
    _Unit('ml', 'ml'),
    _Unit('cup', 'cup'),
    _Unit('piece', 'pc'),
  ];

  late final TextEditingController _foodName;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late String _foodType;
  late String _unit;
  late DateTime _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final FeedingEntry? e = widget.existing;
    _foodName = TextEditingController(text: e?.foodName ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : _formatAmount(e.amount),
    );
    _notes = TextEditingController(text: e?.note ?? '');
    _foodType = e?.foodType ?? 'wet';
    _unit = e?.unit ?? 'g';
    _time = e?.time ?? DateTime.now();
  }

  @override
  void dispose() {
    _foodName.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;
  bool get _canSave {
    if (_saving) return false;
    if (_foodName.text.trim().isEmpty) return false;
    final double? n = double.tryParse(_amount.text.trim());
    if (n == null || n <= 0) return false;
    return true;
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
    );
    if (picked != null) {
      setState(() {
        _time = DateTime(
          _time.year,
          _time.month,
          _time.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _time = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _time.hour,
          _time.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final NutritionProvider provider = context.read<NutritionProvider>();
    setState(() => _saving = true);
    final double amount = double.parse(_amount.text.trim());
    final String? note =
        _notes.text.trim().isEmpty ? null : _notes.text.trim();
    if (_isEdit) {
      // Sentinel-aware update: empty text means "clear the field" (pass
      // null explicitly), non-empty text means "set to this value",
      // and the sentinel means "leave the existing value alone".
      final String trimmedNote = _notes.text.trim();
      final Object? noteParam;
      if (trimmedNote.isEmpty) {
        if ((widget.existing?.note ?? '').isNotEmpty) {
          noteParam = null; // explicitly clear
        } else {
          noteParam = clearFieldSentinel;
        }
      } else if (trimmedNote == (widget.existing?.note ?? '')) {
        noteParam = clearFieldSentinel;
      } else {
        noteParam = trimmedNote;
      }
      await provider.updateFeeding(
        entry: widget.existing!,
        foodName: _foodName.text.trim(),
        foodType: _foodType,
        amount: amount,
        unit: _unit,
        time: _time,
        note: noteParam,
      );
    } else {
      await provider.addFeeding(
        foodName: _foodName.text.trim(),
        foodType: _foodType,
        amount: amount,
        unit: _unit,
        time: _time,
        note: note,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final NutritionProvider provider = context.read<NutritionProvider>();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: const Text(
          'This removes the meal from the log. Existing reports are kept.',
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
      await provider.deleteFeeding(widget.existing!);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  static String _formatAmount(double v) {
    if (v.truncateToDouble() == v) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  String _formatDateTime() {
    return DateFormat('MMM d, HH:mm').format(_time);
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
                    _isEdit ? 'Edit meal' : 'Log meal',
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
              controller: _foodName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Food',
                hintText: 'e.g. Royal Canin adult',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text('Type', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _FoodType t in _foodTypes)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _foodType == t.id,
                    onSelected: (_) => setState(() => _foodType = t.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 30',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<String>>[
                      for (final _Unit u in _units)
                        DropdownMenuItem<String>(
                          value: u.id,
                          child: Text(u.label),
                        ),
                    ],
                    onChanged: (String? v) {
                      if (v == null) return;
                      setState(() => _unit = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_formatDateTime()),
                    onPressed: _saving ? null : _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Pick time',
                  icon: const Icon(Icons.access_time_outlined),
                  onPressed: _saving ? null : _pickTime,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional details, brand, appetite, etc.',
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
                    label: Text(_isEdit ? 'Save' : 'Log meal'),
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

class _FoodType {
  const _FoodType(this.id, this.label);
  final String id;
  final String label;
}

class _Unit {
  const _Unit(this.id, this.label);
  final String id;
  final String label;
}
