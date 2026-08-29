import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';

/// Small banner shown at the top of every AI surface. It states the
/// guardrail in plain language ("assists, does not diagnose") so the
/// user never reads an AI answer as a vet diagnosis. Used by
/// assistant + weekly report + food-label screens.
class AiGuardrailBanner extends StatelessWidget {
  const AiGuardrailBanner({
    super.key,
    this.message = 'AI assists, does not diagnose. Always confirm with a vet.',
    this.icon = Icons.info_outline,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card used by the AI Assistant composer + anywhere the user types a
/// free-form prompt. Plain `TextField` wrapped in a Card so it has
/// consistent padding with the rest of the app's forms.
class AiPromptField extends StatelessWidget {
  const AiPromptField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 3,
    this.maxLength = 1000,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int maxLength;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: TextInputAction.send,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Quota banner shown in place of error text when the free-tier
/// limit is exhausted. The wording is intentionally short and
/// friendly so the user understands the limit is from the upstream
/// provider, not from their device or account.
class AiQuotaBanner extends StatelessWidget {
  const AiQuotaBanner({
    super.key,
    this.message =
        'AI free-tier limit reached. Please try again in a few minutes.',
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.hourglass_top_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Generic error card for non-quota failures. Wraps the typed
/// [AppFailure] so we never leak raw SDK messages into the UI.
class AiErrorCard extends StatelessWidget {
  const AiErrorCard({required this.failure, this.onDismiss});

  final AppFailure failure;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                failure.message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact two-button row used to switch the AI response language
/// between English and বাংলা. Both languages share the same quota
/// budget; the toggle is purely a UX nicety.
class AiLanguageToggle extends StatelessWidget {
  const AiLanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// One of 'en' or 'bn'.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(value: 'en', label: Text('English')),
        ButtonSegment<String>(value: 'bn', label: Text('বাংলা')),
      ],
      selected: <String>{value},
      onSelectionChanged: (Set<String> s) {
        if (s.isEmpty) return;
        onChanged(s.first);
      },
    );
  }
}
