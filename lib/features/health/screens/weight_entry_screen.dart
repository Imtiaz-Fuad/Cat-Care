import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/weight_entry.dart';
import '../providers/weight_provider.dart';
import 'weight_trend_screen.dart';

/// Single-field form to record a weight measurement.
class WeightEntryScreen extends StatefulWidget {
  const WeightEntryScreen({super.key});

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MMM d, y');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log weight'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          IconButton(
            tooltip: 'Trend',
            icon: const Icon(Icons.show_chart),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const WeightTrendScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: <Widget>[
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final double? d = double.tryParse(v.trim());
                  if (d == null || d <= 0 || d > 50) {
                    return 'Enter a weight between 0 and 50 kg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final DateTime now = DateTime.now();
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_outlined),
                    labelText: 'Date',
                  ),
                  child: Text(fmt.format(_date)),
                ),
              ),
              const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final WeightProvider provider = context.read<WeightProvider>();
    final draft = WeightEntry(
      id: '',
      catId: '',
      weightKg: double.parse(_weightCtrl.text.trim()),
      recordedAt: _date,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
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