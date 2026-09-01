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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add a photo',
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A picture makes it feel personal. We use it to '
            'pick an accent color for the app too.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: CatPhoto(
                networkUrl: draft.photoUrl,
                localPath: draft.photoPath,
                variant: CatPhotoVariant.avatar,
                accentHex: draft.accentHex,
                semanticLabel: 'Cat photo preview',
              ),
            ),
          ),
          const SizedBox(height: 14),
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
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Take a photo'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : onPickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Choose from gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: BorderSide(color: scheme.outlineVariant),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _NameDecorationRow(),
          const SizedBox(height: 20),
          Text(
            'What\'s your cat\'s name?',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We use this everywhere — home screen, routines, and '
            'reminders.',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(40),
            ],
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Whiskers',
              floatingLabelStyle: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                Icons.pets,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
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

/// A purely decorative row of small pet-themed icons used at the
/// top of the name step. Not interactive — just adds warmth.
class _NameDecorationRow extends StatelessWidget {
  const _NameDecorationRow();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<IconData> icons = <IconData>[
      Icons.cottage_outlined,
      Icons.pets,
      Icons.local_dining_outlined,
      Icons.search,
      Icons.emoji_emotions_outlined,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < icons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(icons[i], size: 18, color: scheme.primary),
          ),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'A few more details',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Skip anything you\'re not sure about — you can fill it '
            'in later.',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _BirthdayField(controller: widget.controller, draft: draft),
          const SizedBox(height: 14),
          _SexPicker(controller: widget.controller, draft: draft),
          const SizedBox(height: 14),
          TextField(
            controller: _breed,
            textCapitalization: TextCapitalization.words,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Breed',
              hintText: 'e.g. Persian, Bengal',
              prefixIcon: Icon(
                Icons.pets_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onChanged: (String v) => widget.controller.updateDraft(
              (CatDraft d) =>
                  d.copyWith(breed: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _color,
            textCapitalization: TextCapitalization.words,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Coat color',
              hintText: 'e.g. Tabby, black & white',
              prefixIcon: Icon(
                Icons.brush_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onChanged: (String v) => widget.controller.updateDraft(
              (CatDraft d) =>
                  d.copyWith(color: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          const SizedBox(height: 20),
          _SwitchRow(
            title: 'Neutered or spayed',
            value: draft.neutered,
            onChanged: (bool v) => widget.controller.updateDraft(
              (CatDraft d) => d.copyWith(neutered: v),
            ),
          ),
          const SizedBox(height: 4),
          _SwitchRow(
            title: 'Indoor cat',
            subtitle: 'Affects outdoor activity suggestions',
            value: draft.indoor,
            onChanged: (bool v) => widget.controller.updateDraft(
              (CatDraft d) => d.copyWith(indoor: v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch row with a bold title and optional subtitle. Uses the
/// Material 3 adaptive switch so it reads correctly across
/// platforms.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
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
    final TextTheme text = Theme.of(context).textTheme;
    final String label = draft.birthday == null
        ? 'Pick a birthday (optional)'
        : _formatDate(draft.birthday!);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
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
            controller.updateDraft(
              (CatDraft d) => d.copyWith(birthday: picked),
            );
          }
        },
        icon: Icon(
          Icons.cake_outlined,
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: text.titleSmall?.copyWith(
              fontWeight: draft.birthday == null
                  ? FontWeight.w500
                  : FontWeight.w600,
              color: draft.birthday == null
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          alignment: Alignment.centerLeft,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
    final TextTheme text = Theme.of(context).textTheme;
    final String current = draft.sex ?? 'unspecified';

    return Row(
      children: _options
          .map(
            (_SexOption opt) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: opt == _options.last ? 0 : 8),
                child: _SexChip(
                  option: opt,
                  selected: current == opt.value,
                  scheme: scheme,
                  text: text,
                  onTap: () => controller.updateDraft(
                    (CatDraft d) => d.copyWith(
                      sex: opt.value == 'unspecified' ? null : opt.value,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Pill-shaped outlined chip used by [_SexPicker]. Filled with the
/// secondary container (warm peach) when selected; otherwise sits on
/// a soft white surface.
class _SexChip extends StatelessWidget {
  const _SexChip({
    required this.option,
    required this.selected,
    required this.scheme,
    required this.text,
    required this.onTap,
  });

  final _SexOption option;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? scheme.secondaryContainer
        : scheme.surface;
    final Color border = selected
        ? scheme.secondaryContainer
        : scheme.outlineVariant;
    final Color foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(option.icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What matters most?',
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick the routines you\'d like CatCare to set up by '
            'default for ${controller.draft.name.isEmpty ? 'your cat' : controller.draft.name}.',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: CatPriority.all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final String id = CatPriority.all[index];
                final bool isSelected = selected.contains(id);
                return _PriorityRow(
                  id: id,
                  label: _labelFor(id),
                  icon: _iconFor(id),
                  selected: isSelected,
                  onTap: () => controller.updateDraft((CatDraft d) {
                    final List<String> next = List<String>.from(d.priorities);
                    if (isSelected) {
                      next.remove(id);
                    } else {
                      if (!next.contains(id)) next.add(id);
                    }
                    return d.copyWith(priorities: next);
                  }),
                );
              },
            ),
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

/// Single priority row — leading circular icon avatar, bold label,
/// trailing filled circle with a check when selected.
class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color avatarBackground = selected
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surface;
    final Color avatarBorder = selected
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.outlineVariant;
    final Color avatarIcon = selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: avatarBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarBorder),
                ),
                child: Icon(icon, size: 18, color: avatarIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Looking good!',
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Here\'s what we\'ll save for ${draft.name.isEmpty ? 'your cat' : draft.name}.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                children: <Widget>[
                  _SummaryRow(label: 'Name', value: draft.name),
                  _SummaryDivider(),
                  _SummaryRow(
                    label: 'Birthday',
                    value: draft.birthday == null
                        ? '—'
                        : _formatDate(draft.birthday!),
                  ),
                  _SummaryDivider(),
                  _SummaryRow(label: 'Sex', value: _labelForSex(draft.sex)),
                  _SummaryDivider(),
                  _SummaryRow(label: 'Breed', value: draft.breed ?? '—'),
                  _SummaryDivider(),
                  _SummaryRow(label: 'Color', value: draft.color ?? '—'),
                  _SummaryDivider(),
                  _SummaryRow(
                    label: 'Neutered',
                    value: draft.neutered ? 'Yes' : 'No',
                  ),
                  _SummaryDivider(),
                  _SummaryRow(
                    label: 'Indoor',
                    value: draft.indoor ? 'Yes' : 'No',
                  ),
                  _SummaryDivider(),
                  const SizedBox(height: 6),
                  Text(
                    'Priorities',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            (String p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                _priorityLabel(p),
                                style: text.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
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
}

/// Two-column row in the summary card: bold-ish label on the left,
/// value on the right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
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
