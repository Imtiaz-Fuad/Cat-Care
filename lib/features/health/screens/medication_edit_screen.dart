import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/medication.dart';
import '../providers/medication_provider.dart';

/// Add or edit a medication. When [existing] is supplied we prefill
/// the controllers and dispatch an `update` instead of `add`.
class MedicationEditScreen extends StatefulWidget {
  const MedicationEditScreen({super.key, this.existing});

  final Medication? existing;

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _frequencyCtrl;
  late final TextEditingController _notesCtrl;

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<TimeOfDay> _reminderTimes = <TimeOfDay>[];
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Medication? e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _doseCtrl = TextEditingController(text: e?.dose ?? '');
    _frequencyCtrl = TextEditingController(text: e?.frequency ?? 'daily');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _startDate = e.startDate;
      _endDate = e.endDate;
      _active = e.active;
      _reminderTimes.addAll(
        e.reminderTimes.map(
          (DateTime t) => TimeOfDay(hour: t.hour, minute: t.minute),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _frequencyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isEdit = widget.existing != null;
    final ThemeData formTheme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFD98E70).withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF9A452A), width: 1.4),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit medication' : 'New medication'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFF8F3),
              backgroundColor: const Color(0xFF8C341F),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Theme(
          data: formTheme,
          child: Form(
            key: _formKey,
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: <Widget>[
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dose (e.g. 5mg)',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _frequencyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Frequency (e.g. daily, every_8_hours)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Start date',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _DateTile(
                date: _startDate,
                onPick: (DateTime d) => setState(() => _startDate = d),
              ),
              const SizedBox(height: 12),
              Text(
                'End date (optional)',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateTile(
                      date: _endDate,
                      placeholder: 'No end date',
                      onPick: (DateTime d) => setState(() => _endDate = d),
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _active,
                onChanged: (bool v) => setState(() => _active = v),
                title: const Text('Active'),
                subtitle: const Text(
                  'Inactive entries hide from the routine check-off card.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Reminder times',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add reminder',
                    icon: const Icon(Icons.add_alarm),
                    onPressed: _pickReminder,
                  ),
                ],
              ),
              if (_reminderTimes.isEmpty)
                Text(
                  'No reminders set',
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < _reminderTimes.length; i++)
                      InputChip(
                        label: Text(_formatTime(_reminderTimes[i])),
                        onDeleted: () =>
                            setState(() => _reminderTimes.removeAt(i)),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_saving) ...<Widget>[
                const SizedBox(height: 24),
                const LinearProgressIndicator(),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickReminder() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _reminderTimes.add(picked));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final MedicationProvider provider = context.read<MedicationProvider>();
    final startDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final endDate = _endDate == null
        ? null
        : DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    final now = DateTime.now();
    final reminderTimes = _reminderTimes
        .map(
          (TimeOfDay t) => DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
            t.hour,
            t.minute,
          ),
        )
        .toList(growable: false);

    final Medication? existing = widget.existing;
    if (existing == null) {
      final draft = Medication(
        id: '',
        catId: '',
        name: _nameCtrl.text.trim(),
        dose: _doseCtrl.text.trim(),
        frequency: _frequencyCtrl.text.trim(),
        startDate: startDate,
        endDate: endDate,
        reminderTimes: reminderTimes,
        active: _active,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final created = await provider.add(draft);
      if (!mounted) return;
      setState(() => _saving = false);
      if (created == null) {
        _showError(provider.lastError?.message);
        return;
      }
      Navigator.of(context).pop();
    } else {
      final updated = existing.copyWith(
        name: _nameCtrl.text.trim(),
        dose: _doseCtrl.text.trim(),
        frequency: _frequencyCtrl.text.trim(),
        startDate: startDate,
        endDate: endDate,
        reminderTimes: reminderTimes,
        active: _active,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        updatedAt: now,
      );
      await provider.update(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      if (provider.lastError != null) {
        _showError(provider.lastError!.message);
        return;
      }
      Navigator.of(context).pop();
    }
  }

  void _showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Could not save medication.')),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    this.date,
    this.placeholder = 'Tap to pick',
    required this.onPick,
  });

  final DateTime? date;
  final String placeholder;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MMM d, y');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime initial = date ?? now;
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFD98E70)),
          ),
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(
          date == null ? placeholder : fmt.format(date!),
          style: date == null
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
      ),
    );
  }
}
