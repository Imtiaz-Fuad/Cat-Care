import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/water_entry.dart';
import '../providers/nutrition_provider.dart';

/// Add/edit form for a [WaterEntry]. Presented as a modal bottom
/// sheet from the Nutrition screen. When [existing] is null the
/// form creates a new entry; when supplied it edits and exposes a
/// destructive delete action.
class WaterEditSheet extends StatefulWidget {
  const WaterEditSheet({super.key, this.existing});

  final WaterEntry? existing;

  @override
  State<WaterEditSheet> createState() => _WaterEditSheetState();
}

class _WaterEditSheetState extends State<WaterEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late DateTime _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final WaterEntry? e = widget.existing;
    _amount = TextEditingController(
      text: e == null ? '' : _formatAmount(e.amountMl),
    );
    _notes = TextEditingController(text: e?.note ?? '');
    _time = e?.time ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  bool get _canSave {
    if (_saving) return false;
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
    final double amountMl = double.parse(_amount.text.trim());
    if (_isEdit) {
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
      await provider.updateWater(
        entry: widget.existing!,
        amountMl: amountMl,
        time: _time,
        note: noteParam,
      );
    } else {
      await provider.addWater(
        amountMl: amountMl,
        time: _time,
        note: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
        title: const Text('Delete water entry?'),
        content: const Text(
          'This removes the entry from the log. Existing reports are kept.',
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
      await provider.deleteWater(widget.existing!);
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
                    _isEdit ? 'Edit water entry' : 'Log water',
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
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (ml)',
                hintText: 'e.g. 60',
              ),
              onChanged: (_) => setState(() {}),
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
                hintText: 'Optional details, source, etc.',
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
                    label: Text(_isEdit ? 'Save' : 'Log water'),
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