import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_scaffold.dart';
import '../core/widgets/placeholder_screen.dart';
import 'app_routes.dart';

/// App router. Auth gate is added in Phase 2; placeholder routes are wired so
/// the shell can build and the team can navigate manually.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static const List<String> _shellPaths = <String>[
    AppRoutes.home,
    AppRoutes.routine,
    AppRoutes.nutrition,
    AppRoutes.profile,
  ];

  static const List<AppDestination> _destinations = <AppDestination>[
    AppDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppDestination(
      label: 'Routine',
      icon: Icons.check_box_outlined,
      selectedIcon: Icons.check_box_rounded,
    ),
    AppDestination(
      label: 'Nutrition',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant_rounded,
    ),
    AppDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static GoRouter build() {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state,
              StatefulNavigationShell shell) {
            return AppScaffold(
              navigationShell: shell,
              destinations: _destinations,
            );
          },
          branches: _buildBranches(),
        ),
        for (final _TopLevelRoute r in _topLevelRoutes) r.route,
      ],
    );
  }

  static List<StatefulShellBranch> _buildBranches() {
    return _shellPaths
        .map((String path) => StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: path,
                  builder: (_, _) => _PlaceholderForRoute(path: path),
                ),
              ],
            ))
        .toList(growable: false);
  }
}

class _TopLevelRoute {
  const _TopLevelRoute(this.path, this.title, this.subtitle);
  final String path;
  final String title;
  final String subtitle;

  GoRoute get route => GoRoute(
        path: path,
        builder: (_, _) => PlaceholderScreen(title: title, subtitle: subtitle),
      );
}

const List<_TopLevelRoute> _topLevelRoutes = <_TopLevelRoute>[
  _TopLevelRoute(
    AppRoutes.healthRecords,
    'Health Records',
    'Coming in Phase 5.',
  ),
  _TopLevelRoute(
    AppRoutes.medications,
    'Medications',
    'Coming in Phase 5.',
  ),
  _TopLevelRoute(
    AppRoutes.vaccinations,
    'Vaccinations',
    'Coming in Phase 5.',
  ),
  _TopLevelRoute(
    AppRoutes.vetFinder,
    'Vet Finder',
    'Coming in Phase 6.',
  ),
  _TopLevelRoute(
    AppRoutes.aiAssistant,
    'AI Assistant',
    'Coming in Phase 7.',
  ),
  _TopLevelRoute(
    AppRoutes.settings,
    'Settings',
    'Coming in Phase 8.',
  ),
  _TopLevelRoute(
    AppRoutes.reminders,
    'Reminders',
    'Coming in Phase 4.',
  ),
  _TopLevelRoute(
    AppRoutes.addFeeding,
    'Add Feeding',
    'Coming in Phase 4.',
  ),
  _TopLevelRoute(
    AppRoutes.nutritionReport,
    'Nutrition Report',
    'Coming in Phase 4.',
  ),
  _TopLevelRoute(
    AppRoutes.weightTrend,
    'Weight Trend',
    'Coming in Phase 5.',
  ),
  _TopLevelRoute(
    AppRoutes.emergencyGuidance,
    'Emergency Guidance',
    'Coming in Phase 7.',
  ),
  _TopLevelRoute(
    AppRoutes.weeklyReport,
    'Weekly Report',
    'Coming in Phase 7.',
  ),
  _TopLevelRoute(
    AppRoutes.grooming,
    'Grooming',
    'Coming in Phase 4.',
  ),
  _TopLevelRoute(
    AppRoutes.foodGuide,
    'Food Guide',
    'Coming in Phase 8.',
  ),
  _TopLevelRoute(
    AppRoutes.catSafety,
    'Cat Safety',
    'Coming in Phase 8.',
  ),
  _TopLevelRoute(
    AppRoutes.careGuides,
    'Care Guides',
    'Coming in Phase 8.',
  ),
  _TopLevelRoute(
    AppRoutes.kittenCare,
    'Kitten Care',
    'Coming in Phase 8.',
  ),
  _TopLevelRoute(
    AppRoutes.splash,
    'CatCare',
    'Welcome.',
  ),
  _TopLevelRoute(
    AppRoutes.login,
    'Sign In',
    'Coming in Phase 2.',
  ),
  _TopLevelRoute(
    AppRoutes.onboarding,
    'Onboarding',
    'Coming in Phase 3.',
  ),
];

class _PlaceholderForRoute extends StatelessWidget {
  const _PlaceholderForRoute({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final String label = path.substring(1).replaceAll('-', ' ');
    final String title = label.isEmpty
        ? 'Home'
        : label[0].toUpperCase() + label.substring(1);
    return PlaceholderScreen(
      title: title,
      subtitle: 'This screen will be implemented in a later phase.',
    );
  }
}
