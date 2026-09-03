import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/vaccination.dart';
import '../../../core/services/content/content_repository.dart';
import '../providers/vaccination_provider.dart';

/// Form to log a vaccination. We resolve the vaccine cadence through
/// `ContentRepository` so the saved record carries a non-null
/// `nextDue` and the manager can derive a status at render time.
class AddVaccinationScreen extends StatefulWidget {
  const AddVaccinationScreen({super.key});

  @override
  State<AddVaccinationScreen> createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends State<AddVaccinationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _vetCtrl = TextEditingController();
  final TextEditingController _batchCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String? _vaccineCode;
  DateTime _administeredAt = DateTime.now();
  bool _reminderEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _vetCtrl.dispose();
    _batchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log vaccine'),
        actions: <Widget>[
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA44A2A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: <Widget>[
              Text('Vaccine', style: text.titleSmall),
              const SizedBox(height: 8),
              _VaccineCodeField(
                initial: _vaccineCode,
                onSelected: (String code) =>
                    setState(() => _vaccineCode = code),
              ),
              const SizedBox(height: 20),
              Text('Administered on', style: text.titleSmall),
              const SizedBox(height: 8),
              _DateField(
                date: _administeredAt,
                onPick: (DateTime d) => setState(() => _administeredAt = d),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _vetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vet (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _batchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Batch number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _reminderEnabled,
                onChanged: (bool v) => setState(() => _reminderEnabled = v),
                title: const Text('Remind me before next due'),
                subtitle: const Text(
                  'Local notifications fire 7 days before the booster date.',
                ),
              ),
              const SizedBox(height: 8),
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
    );
  }

  Future<void> _save() async {
    if (_vaccineCode == null || _vaccineCode!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a vaccine first.')));
      return;
    }
    setState(() => _saving = true);
    final ContentRepository content = context.read<ContentRepository>();
    final VaccinationProvider provider = context.read<VaccinationProvider>();

    DateTime? nextDue;
    try {
      final info = await content.getVaccineInfo(_vaccineCode!);
      if (info != null && info.boosterIntervalDays > 0) {
        nextDue = _administeredAt.add(Duration(days: info.boosterIntervalDays));
      }
    } catch (_) {
      // Non-fatal: the saved record still surfaces; cadence just unknown.
    }

    final draft = Vaccination(
      id: '',
      catId: '',
      vaccineCode: _vaccineCode!,
      administeredAt: _administeredAt,
      nextDue: nextDue,
      vetName: _vetCtrl.text.trim().isEmpty ? null : _vetCtrl.text.trim(),
      batchNumber: _batchCtrl.text.trim().isEmpty
          ? null
          : _batchCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      reminderEnabled: _reminderEnabled,
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

class _VaccineCodeField extends StatelessWidget {
  const _VaccineCodeField({required this.initial, required this.onSelected});

  final String? initial;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: _loadOptions(context),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DropdownMenuItem<String>>> snap,
          ) {
            if (!snap.hasData) {
              return const LinearProgressIndicator();
            }
            final items = snap.data!;
            return DropdownButtonFormField<String>(
              initialValue: initial,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vaccine',
                border: OutlineInputBorder(),
              ),
              items: items,
              onChanged: (String? v) {
                if (v != null) onSelected(v);
              },
            );
          },
    );
  }

  Future<List<DropdownMenuItem<String>>> _loadOptions(
    BuildContext context,
  ) async {
    final ContentRepository content = context.read<ContentRepository>();
    final list = await content.listVaccineInfo();
    return list
        .map(
          (v) => DropdownMenuItem<String>(value: v.code, child: Text(v.name)),
        )
        .toList(growable: false);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});

  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MMM d, y');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(fmt.format(date)),
      ),
    );
  }
}
