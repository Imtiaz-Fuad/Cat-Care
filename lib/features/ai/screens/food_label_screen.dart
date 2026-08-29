import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/empty_state.dart';
import '../providers/ai_provider.dart';
import '../repositories/ai_repository.dart';
import '../widgets/ai_guardrail_banner.dart';

/// Cat-food label photo → structured guaranteed-analysis. See
/// `functions/src/index.ts` `extractFoodLabel` and
/// `functions/src/prompts/extract_food_label.md`.
///
/// Workflow:
///   1. User picks a photo from the gallery or camera.
///   2. The image is encoded as base64 (5 MB max — the Cloud
///      Function rejects anything larger with `invalid-argument`).
///   3. We call `extractFoodLabel` and render the structured fields
///      in a Card; any unreadable field renders as "Not detected".
///   4. If the model reports `missingData: true`, we render the
///      `[CONTENT PLACEHOLDER]` banner so the user knows the numbers
///      are not reliable.
///
/// Note: this surface never blocks the rest of the app if quota is
/// exhausted — the [AiQuotaBanner] explains the wait and the user
/// can retry later.
class FoodLabelScreen extends StatefulWidget {
  const FoodLabelScreen({super.key});

  @override
  State<FoodLabelScreen> createState() => _FoodLabelScreenState();
}

class _FoodLabelScreenState extends State<FoodLabelScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;

  @override
  void dispose() {
    // AiProvider owns the parsed FoodLabelExtraction; nothing else
    // here needs explicit cleanup beyond controller-style widgets.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiProvider>(
      builder: (BuildContext context, AiProvider ai, Widget? _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Food Label'),
            actions: <Widget>[
              if (ai.foodLabel != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: (ai.foodLabelBusy || !ai.aiAvailable)
                      ? null
                      : () {
                          ai.clearFoodLabel();
                          setState(() => _pickedFile = null);
                        },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              const AiGuardrailBanner(
                message:
                    'Photo is sent to a Cloud Function that calls Gemini. '
                    'Numbers may be approximate — verify against the label.',
                icon: Icons.image_outlined,
              ),
              const SizedBox(height: 16),
              _PickerRow(
                onPickGallery: () => _pick(ImageSource.gallery),
                onPickCamera: () => _pick(ImageSource.camera),
                busy: ai.foodLabelBusy,
                pickedFile: _pickedFile,
                disabled: !ai.aiAvailable,
              ),
              const SizedBox(height: 12),
              if (ai.lastError != null)
                ai.isQuotaLimited
                    ? AiQuotaBanner(onDismiss: ai.clearError)
                    : AiErrorCard(
                        failure: ai.lastError!,
                        onDismiss: ai.clearError,
                      ),
              if (ai.foodLabelBusy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (ai.foodLabel != null)
                _LabelCard(extraction: ai.foodLabel!)
              else
                const _Hint(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(ImageSource source) async {
    final AiProvider ai = context.read<AiProvider>();
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return; // User cancelled.
      setState(() => _pickedFile = file);
      final Uint8List bytes = await file.readAsBytes();
      // 5 MB ceiling to match the Cloud Function check in
      // extractFoodLabel handler.
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image is larger than 5 MB — please pick a smaller one.',
            ),
          ),
        );
        return;
      }
      final String mimeType = _mimeTypeFor(file.name);
      final String base64 = base64Encode(bytes);
      await ai.extractFoodLabel(
        imageBase64: base64,
        mimeType: mimeType,
        locale: 'en',
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  /// Pick a mime type from the file extension. Defaults to jpeg since
  /// that is what the prompt expects.
  static String _mimeTypeFor(String name) {
    final String ext = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.onPickGallery,
    required this.onPickCamera,
    required this.busy,
    required this.pickedFile,
    this.disabled = false,
  });

  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final bool busy;
  final XFile? pickedFile;

  /// When true, the picker buttons are visually disabled and ignore taps.
  /// Used to lock the screen when the daily AI cap has been reached.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (busy || disabled) ? null : onPickGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pick from gallery'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (busy || disabled) ? null : onPickCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Use camera'),
          ),
        ),
        if (pickedFile != null) ...<Widget>[
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              File(pickedFile!.path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_not_supported_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.extraction});

  final FoodLabelExtraction extraction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              extraction.foodName.isEmpty
                  ? 'Unknown product'
                  : extraction.foodName,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (extraction.brand.isNotEmpty)
              Text(
                extraction.brand,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (extraction.missingData) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '[CONTENT PLACEHOLDER] Some fields could not be read — '
                  'verify against the label.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Guaranteed analysis', style: text.titleSmall),
            const SizedBox(height: 8),
            _AnalysisRow(
              label: 'Protein',
              value: extraction.guaranteedAnalysis.proteinPct,
            ),
            _AnalysisRow(
              label: 'Fat',
              value: extraction.guaranteedAnalysis.fatPct,
            ),
            _AnalysisRow(
              label: 'Fiber',
              value: extraction.guaranteedAnalysis.fiberPct,
            ),
            _AnalysisRow(
              label: 'Moisture',
              value: extraction.guaranteedAnalysis.moisturePct,
            ),
            if (extraction.ingredientsRaw.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('Ingredients', style: text.titleSmall),
              const SizedBox(height: 8),
              SelectableText(extraction.ingredientsRaw, style: text.bodySmall),
            ],
            if (extraction.notes != null &&
                extraction.notes!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(extraction.notes!, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(width: 96, child: Text(label, style: text.bodyMedium)),
          Expanded(
            child: Text(
              value == null ? 'Not detected' : '${value!.toStringAsFixed(1)} %',
              style: text.bodyMedium?.copyWith(
                color: value == null ? scheme.onSurfaceVariant : null,
                fontStyle: value == null ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.qr_code_scanner_outlined,
      title: 'Scan a cat-food label',
      subtitle:
          'Pick a clear photo of the back of the package. We\'ll read the '
          'guaranteed analysis and ingredients for you.',
    );
  }
}
