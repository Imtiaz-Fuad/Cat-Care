import 'package:flutter/material.dart';

/// Dots + label strip shown at the top of the onboarding flow.
/// Renders `total` dots with the `current` one enlarged and tinted.
/// Lifted out of [OnboardingScreen] so step widgets (e.g. for
/// accessibility captures) can render it in isolation.
class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({
    super.key,
    required this.current,
    required this.total,
    this.label,
  });

  final int current;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < total; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: i == current ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= current
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '$label',
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
