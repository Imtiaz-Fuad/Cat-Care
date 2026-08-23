import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/health_record.dart';
import '../providers/health_provider.dart';

/// Form for creating a new `HealthRecord`.
///
/// Attachments are limited to **photos only** (`ImagePicker.pickMultiImage`)
/// — per product decision we don't expose PDF/file selection from this
/// surface. Uploaded via [HealthRepository.uploadAttachment] which writes
/// the resulting download URLs back into the record's `fileAttachments`.
class AddHealthRecordScreen extends StatefulWidget {
  const AddHealthRecordScreen({super.key});

  @override
  State<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends State<AddHealthRecordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _vetCtrl = TextEditingController();
  final TextEditingController _diagnosisCtrl = TextEditingController();
  final TextEditingController _prescriptionCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _medicinesCtrl = TextEditingController();
  final TextEditingController _vaccinesCtrl = TextEditingController();
  final TextEditingController _testsCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<_PendingAttachment> _pendingAttachments = <_PendingAttachment>[];

  DateTime _recordedAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _vetCtrl.dispose();
    _diagnosisCtrl.dispose();
    _prescriptionCtrl.dispose();
    _notesCtrl.dispose();
    _medicinesCtrl.dispose();
    _vaccinesCtrl.dispose();
    _testsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _recordedAt = picked);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        imageQuality: 80,
        limit: 8,
      );
      if (files.isEmpty) return;
      for (final XFile f in files) {
        final Uint8List bytes = await f.readAsBytes();
        final String contentType = _guessImageContentType(f.name);
        if (contentType.isEmpty) {
          // Defensive: image_picker should only ever return images here,
          // but skip anything we can't classify.
          continue;
        }
        if (!mounted) return;
        setState(() {
          _pendingAttachments.add(
            _PendingAttachment(
              name: f.name,
              bytes: bytes,
              contentType: contentType,
            ),
          );
        });
      }
    } catch (e, st) {
      debugPrint('ImagePicker error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open photo picker.')),
      );
    }
  }

  String _guessImageContentType(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    // Default to JPEG for the .jpg/.jpeg case and image_picker's defaults.
    return 'image/jpeg';
  }

  List<String> _splitCsv(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final HealthProvider provider = context.read<HealthProvider>();
    final String? activeCatId = provider.catId;
    if (activeCatId == null || activeCatId.isEmpty) {
      setState(() => _saving = false);
      _showError('No active cat selected.');
      return;
    }
    // 1. Insert the record with no attachments so we have a stable id.
    final HealthRecord draft = HealthRecord(
      id: '', // repo assigns the id
      catId: activeCatId,
      title: _titleCtrl.text.trim(),
      recordedAt: _recordedAt,
      vetName: _vetCtrl.text.trim().isEmpty ? null : _vetCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim().isEmpty
          ? null
          : _diagnosisCtrl.text.trim(),
      prescription: _prescriptionCtrl.text.trim().isEmpty
          ? null
          : _prescriptionCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      medicines: _splitCsv(_medicinesCtrl.text),
      vaccines: _splitCsv(_vaccinesCtrl.text),
      tests: _splitCsv(_testsCtrl.text),
      fileAttachments: const <String>[],
    );
    final HealthRecord? created = await provider.add(draft);
    if (created == null) {
      setState(() => _saving = false);
      _showError(provider.lastError?.message ?? 'Could not save the record.');
      return;
    }
    // 2. Upload attachments (if any) and patch the record's URLs.
    final List<String> urls = <String>[];
    for (final _PendingAttachment att in _pendingAttachments) {
      final String? url = await provider.uploadAttachment(
        recordId: created.id,
        fileName: att.name,
        bytes: att.bytes,
        contentType: att.contentType,
      );
      if (url != null) urls.add(url);
    }
    if (urls.isNotEmpty) {
      await provider.update(created.copyWith(fileAttachments: urls));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('MMM d, y');
    return Scaffold(
      appBar: AppBar(
        title: const Text('New health record'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Annual checkup',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (String? v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(fmt.format(_recordedAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vet / clinic',
                  hintText: 'Optional',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _diagnosisCtrl,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText: 'Optional',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prescriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prescription',
                  hintText: 'Optional',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medicinesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medicines',
                  hintText: 'Comma-separated, e.g. Amoxicillin, Metacam',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vaccinesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vaccines',
                  hintText: 'Comma-separated, optional',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _testsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tests',
                  hintText: 'Comma-separated, optional',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional',
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Photos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Only photos (no PDFs / documents).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              if (_pendingAttachments.isEmpty)
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No photos attached.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < _pendingAttachments.length; i++)
                      _PendingAttachmentTile(
                        attachment: _pendingAttachments[i],
                        onRemove: () => setState(
                          () => _pendingAttachments.removeAt(i),
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

class _PendingAttachment {
  const _PendingAttachment({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class _PendingAttachmentTile extends StatelessWidget {
  const _PendingAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final _PendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              attachment.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, color: Colors.white, size: 16),
              onPressed: onRemove,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}