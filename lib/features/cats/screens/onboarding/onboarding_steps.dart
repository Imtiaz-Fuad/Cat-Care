import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/accent_color_extractor.dart';
import '../../models/cat_draft.dart';
import '../../widgets/cat_photo.dart';
import 'onboarding_controller.dart';

/// Step 1 of 5 — pick a photo for the cat.
///
/// Optional: the user can hit "Skip" without picking anything. The
/// accent color extraction happens asynchronously after a photo is
/// chosen (see [OnboardingController.analyzePhoto]).
class OnboardingPhotoStep extends StatelessWidget {
  const OnboardingPhotoStep({
    super.key,
    required this.controller,
    required this.onPickFromGallery,
    required this.onTakePhoto,
  });

  final OnboardingController controller;
  final Future<void> Function() onPickFromGallery;
  final Future<void> Function() onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CatDraft draft = controller.draft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add a photo',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'A picture makes it feel personal. We use it to '
            'pick an accent color for the app too.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: CatPhoto(
                networkUrl: draft.photoUrl,
                localPath: draft.photoPath,
                variant: CatPhotoVariant.avatar,
                accentHex: draft.accentHex,
                semanticLabel: 'Cat photo preview',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (draft.accentHex != null)
            Center(child: _AccentPreview(accentHex: draft.accentHex!)),
          if (controller.isBusy) ...<Widget>[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: controller.isBusy ? null : onTakePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take a photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : onPickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ],
      ),
    );
  }
}

/// Step 2 of 5 — name. The only field the rest of onboarding
/// depends on, so this is also the validation gate.
class OnboardingNameStep extends StatefulWidget {
  const OnboardingNameStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  State<OnboardingNameStep> createState() => _OnboardingNameStepState();
}

class _OnboardingNameStepState extends State<OnboardingNameStep> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.draft.name,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('What\'s your cat\'s name?', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'We use this everywhere — home screen, routines, and '
            'reminders.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(40),
            ],
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Whiskers',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              widget.controller.updateDraft(
                (CatDraft d) => d.copyWith(name: value),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Step 3 of 5 — details. All optional fields live here.
class OnboardingDetailsStep extends StatefulWidget {
  const OnboardingDetailsStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  State<OnboardingDetailsStep> createState() => _OnboardingDetailsStepState();
}

class _OnboardingDetailsStepState extends State<OnboardingDetailsStep> {
  late final TextEditingController _breed = TextEditingController(
    text: widget.controller.draft.breed ?? '',
  );
  late final TextEditingController _color = TextEditingController(
    text: widget.controller.draft.color ?? '',
  );

  @override
  void dispose() {
    _breed.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CatDraft draft = widget.controller.draft;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('A few more details', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Skip anything you\'re not sure about — you can fill it '
            'in later.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _BirthdayField(controller: widget.controller, draft: draft),
          const SizedBox(height: 16),
          _SexPicker(controller: widget.controller, draft: draft),
          const SizedBox(height: 16),
          TextField(
            controller: _breed,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Breed',
              hintText: 'e.g. Persian, Bengal',
              border: OutlineInputBorder(),
            ),
            onChanged: (String v) => widget.controller.updateDraft(
              (CatDraft d) =>
                  d.copyWith(breed: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _color,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Coat color',
              hintText: 'e.g. Tabby, black & white',
              border: OutlineInputBorder(),
            ),
            onChanged: (String v) => widget.controller.updateDraft(
              (CatDraft d) =>
                  d.copyWith(color: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: draft.neutered,
            onChanged: (bool v) => widget.controller.updateDraft(
              (CatDraft d) => d.copyWith(neutered: v),
            ),
            title: const Text('Neutered or spayed'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile.adaptive(
            value: draft.indoor,
            onChanged: (bool v) => widget.controller.updateDraft(
              (CatDraft d) => d.copyWith(indoor: v),
            ),
            title: const Text('Indoor cat'),
            subtitle: const Text('Affects outdoor activity suggestions'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _BirthdayField extends StatelessWidget {
  const _BirthdayField({required this.controller, required this.draft});

  final OnboardingController controller;
  final CatDraft draft;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = draft.birthday == null
        ? 'Pick a birthday (optional)'
        : _formatDate(draft.birthday!);

    return OutlinedButton.icon(
      onPressed: () async {
        final DateTime now = DateTime.now();
        final DateTime initial =
            draft.birthday ?? DateTime(now.year - 2, now.month, now.day);
        final DateTime first = DateTime(1990);
        final DateTime last = now;
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial.isAfter(last) ? last : initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null) {
          controller.updateDraft((CatDraft d) => d.copyWith(birthday: picked));
        }
      },
      icon: const Icon(Icons.cake_outlined),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        alignment: Alignment.centerLeft,
        foregroundColor: scheme.onSurface,
      ),
    );
  }
}

class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.controller, required this.draft});

  final OnboardingController controller;
  final CatDraft draft;

  static const List<_SexOption> _options = <_SexOption>[
    _SexOption('female', 'Female', Icons.female_outlined),
    _SexOption('male', 'Male', Icons.male_outlined),
    _SexOption('unspecified', 'Skip', Icons.question_mark),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String current = draft.sex ?? 'unspecified';

    return Row(
      children: _options
          .map(
            (_SexOption opt) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt == _options.last ? 0 : 8),
                child: ChoiceChip(
                  selected: current == opt.value,
                  onSelected: (_) {
                    controller.updateDraft(
                      (CatDraft d) => d.copyWith(
                        sex: opt.value == 'unspecified' ? null : opt.value,
                      ),
                    );
                  },
                  avatar: Icon(
                    opt.icon,
                    color: current == opt.value
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    size: 18,
                  ),
                  label: Text(opt.label),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SexOption {
  const _SexOption(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

/// Step 4 of 5 — priorities. Multi-select chips over [CatPriority.all].
class OnboardingPrioritiesStep extends StatelessWidget {
  const OnboardingPrioritiesStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> selected = controller.draft.priorities;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('What matters most?', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Pick the routines you\'d like CatCare to set up by '
            'default for ${controller.draft.name.isEmpty ? 'your cat' : controller.draft.name}.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CatPriority.all
                .map((String id) {
                  final bool isSelected = selected.contains(id);
                  return FilterChip(
                    selected: isSelected,
                    onSelected: (bool v) {
                      controller.updateDraft((CatDraft d) {
                        final List<String> next = List<String>.from(
                          d.priorities,
                        );
                        if (v) {
                          if (!next.contains(id)) next.add(id);
                        } else {
                          next.remove(id);
                        }
                        return d.copyWith(priorities: next);
                      });
                    },
                    label: Text(_labelFor(id)),
                    avatar: Icon(
                      _iconFor(id),
                      size: 18,
                      color: isSelected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  String _labelFor(String id) {
    switch (id) {
      case CatPriority.routine:
        return 'Daily routine';
      case CatPriority.nutrition:
        return 'Nutrition';
      case CatPriority.grooming:
        return 'Grooming';
      case CatPriority.health:
        return 'Health checks';
      case CatPriority.vaccinations:
        return 'Vaccinations';
      default:
        return id;
    }
  }

  IconData _iconFor(String id) {
    switch (id) {
      case CatPriority.routine:
        return Icons.schedule_outlined;
      case CatPriority.nutrition:
        return Icons.restaurant_outlined;
      case CatPriority.grooming:
        return Icons.brush_outlined;
      case CatPriority.health:
        return Icons.medical_services_outlined;
      case CatPriority.vaccinations:
        return Icons.vaccines_outlined;
      default:
        return Icons.label_outline;
    }
  }
}

/// Step 5 of 5 — summary. Reads [draft] and renders a preview card
/// that the user accepts before we actually save.
class OnboardingDoneStep extends StatelessWidget {
  const OnboardingDoneStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CatDraft draft = controller.draft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Looking good!', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Here\'s what we\'ll save for ${draft.name.isEmpty ? 'your cat' : draft.name}.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card.outlined(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _row('Name', draft.name),
                  _row(
                    'Birthday',
                    draft.birthday == null ? '—' : _formatDate(draft.birthday!),
                  ),
                  _row('Sex', _labelForSex(draft.sex)),
                  _row('Breed', draft.breed ?? '—'),
                  _row('Color', draft.color ?? '—'),
                  _row('Neutered', draft.neutered ? 'Yes' : 'No'),
                  _row('Indoor', draft.indoor ? 'Yes' : 'No'),
                  const Divider(height: 32),
                  Text('Priorities', style: text.titleSmall),
                  const SizedBox(height: 8),
                  if (draft.priorities.isEmpty)
                    Text(
                      'None selected — we\'ll keep things minimal.',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: draft.priorities
                          .map(
                            (String p) => Chip(label: Text(_priorityLabel(p))),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 110, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _labelForSex(String? v) {
  switch (v) {
    case 'female':
      return 'Female';
    case 'male':
      return 'Male';
    default:
      return '—';
  }
}

String _priorityLabel(String id) {
  switch (id) {
    case CatPriority.routine:
      return 'Daily routine';
    case CatPriority.nutrition:
      return 'Nutrition';
    case CatPriority.grooming:
      return 'Grooming';
    case CatPriority.health:
      return 'Health';
    case CatPriority.vaccinations:
      return 'Vaccinations';
    default:
      return id;
  }
}

/// Small swatch + label confirming the palette was extracted from the
/// photo. Visible only after [OnboardingController.analyzePhoto] runs.
class _AccentPreview extends StatelessWidget {
  const _AccentPreview({required this.accentHex});

  final String accentHex;

  @override
  Widget build(BuildContext context) {
    final Color? color = AccentColorExtractor.tryParseHex(accentHex);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color ?? scheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Accent preview',
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
