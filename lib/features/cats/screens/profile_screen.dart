import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../../../core/models/cat_profile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../routes/app_routes.dart';
import '../../ai/providers/ai_provider.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../routine/providers/routine_provider.dart';
import '../providers/cat_provider.dart';
import '../widgets/cat_photo.dart';

/// Profile tab — see `docs/catcare.design` § "Profile Tab".
///
/// Combines a header (active cat identity + photo) with a stats
/// card showing today's routine completion, meals, and water
/// progress, plus a list of shortcuts to secondary destinations
/// (cat switcher, sign-out, and Phase 5+ links rendered as
/// "coming soon" tiles for visual continuity).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatProvider>(
      builder: (BuildContext context, CatProvider cats, Widget? _) {
        final CatProfile? active = cats.activeCat;
        final bool loading = !cats.hasLoaded;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: <Widget>[
              if (active != null)
                IconButton(
                  tooltip: 'Switch cat',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => context.push(AppRoutes.catSwitch),
                ),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : active == null
              ? const _NoActiveCat()
              : _ProfileBody(cat: active),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.cat});

  final CatProfile cat;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CatPhoto(
                          networkUrl: cat.photoUrl,
                          variant: CatPhotoVariant.avatar,
                          accentHex: cat.themeAccentHex,
                          semanticLabel: 'Photo of ${cat.name}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              cat.name,
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                cat.lifeStage.displayLabel,
                                if (cat.weightKg != null)
                                  '${cat.weightKg!.toStringAsFixed(1)} kg',
                                if (cat.breed != null && cat.breed!.isNotEmpty)
                                  cat.breed!,
                              ].join(' · '),
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit cat',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            context.push(AppRoutes.catProfile(cat.id)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TodayStatsCard(cat: cat),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Shortcuts',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const _ShortcutTile(
          icon: Icons.swap_horiz_rounded,
          title: 'Switch or add a cat',
          subtitle: 'Manage the cats in your household.',
          route: AppRoutes.catSwitch,
        ),
        const _ShortcutTile(
          icon: Icons.medical_services_outlined,
          title: 'Health records',
          subtitle: 'Vet visits, diagnoses, lab results and notes.',
          route: AppRoutes.healthRecords,
        ),
        const _ShortcutTile(
          icon: Icons.medication_outlined,
          title: 'Medications & vaccinations',
          subtitle: 'Track active meds and upcoming boosters.',
          route: AppRoutes.medications,
        ),
        const _ShortcutTile(
          icon: Icons.location_searching,
          title: 'Find a vet nearby',
          subtitle: 'Coming soon',
          enabled: false,
        ),
        const _ShortcutTile(
          icon: Icons.smart_toy_outlined,
          title: 'AI assistant',
          subtitle: 'Ask care questions for your active cat.',
          route: AppRoutes.aiAssistant,
        ),
        const _ShortcutTile(
          icon: Icons.assignment_outlined,
          title: 'Weekly report',
          subtitle: 'A 7-day care summary for your active cat.',
          route: AppRoutes.weeklyReport,
        ),
        const _ShortcutTile(
          icon: Icons.qr_code_scanner_outlined,
          title: 'Food label scan',
          subtitle: 'Analyze a packaged cat food label.',
          route: AppRoutes.foodLabel,
        ),
        const _ShortcutTile(
          icon: Icons.local_hospital_outlined,
          title: 'Emergency guidance',
          subtitle: 'Safety signs and what to do.',
          route: AppRoutes.emergencyGuidance,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            onPressed: () => _confirmSignOut(context),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to sign in again to access your cats\' data.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      // Clear AI caches before sign-out so the next account does not
      // inherit this session's chat history or generated reports.
      context.read<AiProvider>().reset();
      await auth.signOut();
    }
  }
}

class _TodayStatsCard extends StatelessWidget {
  const _TodayStatsCard({required this.cat});

  final CatProfile cat;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Consumer2<RoutineProvider, NutritionProvider>(
      builder:
          (
            BuildContext context,
            RoutineProvider routine,
            NutritionProvider nutrition,
            Widget? _,
          ) {
            final int done = routine.completedTodayCount;
            final int total = routine.totalRoutineCount;
            final int percent = routine.completionPercent;
            final int meals = nutrition.todaysMealCount;
            final int foodG = nutrition.todaysFoodGrams.toInt();
            final int foodTarget = nutrition.target.dailyFoodGrams.toInt();
            final int waterMl = nutrition.todaysWaterMl.toInt();
            final int waterTarget = nutrition.target.dailyWaterMl.toInt();
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Today's snapshot",
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.check_box_outlined,
                            label: 'Routine',
                            value: '$done / $total',
                            sub: '$percent% done',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.restaurant_outlined,
                            label: 'Food',
                            value: '$foodG / $foodTarget g',
                            sub: '$meals meal${meals == 1 ? '' : 's'}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.water_drop_outlined,
                            label: 'Water',
                            value: '$waterMl / $waterTarget ml',
                            sub: percent < 50 ? 'Below target' : 'On track',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: scheme.onSecondaryContainer, size: 22),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? scheme.onSurfaceVariant : scheme.outline,
        ),
      ),
      trailing: enabled ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: route == null ? null : () => context.push(route!),
    );
  }
}

class _NoActiveCat extends StatelessWidget {
  const _NoActiveCat();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.person_outline,
      title: 'No active cat',
      subtitle: 'Add a cat first to see your profile dashboard.',
      actionLabel: 'Add a cat',
      onAction: () => context.push(AppRoutes.onboarding),
    );
  }
}
