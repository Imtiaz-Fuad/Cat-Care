import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_scaffold.dart';
import '../core/widgets/placeholder_screen.dart';
import '../features/ai/screens/ai_assistant_screen.dart';
import '../features/ai/screens/emergency_guidance_screen.dart';
import '../features/ai/screens/food_label_screen.dart';
import '../features/ai/screens/weekly_report_screen.dart';
import '../features/authentication/providers/auth_provider.dart';
import '../features/authentication/screens/login_screen.dart';
import '../features/authentication/screens/splash_screen.dart';
import '../features/authentication/widgets/auth_gate.dart';
import '../features/cats/providers/cat_provider.dart';
import '../features/cats/screens/cat_profile_screen.dart';
import '../features/cats/screens/cat_switcher_screen.dart';
import '../features/cats/screens/onboarding/onboarding_screen.dart';
import '../features/cats/screens/profile_screen.dart';
import '../features/health/screens/health_records_screen.dart';
import '../features/health/screens/medication_list_screen.dart';
import '../features/health/screens/vaccination_list_screen.dart';
import '../features/health/screens/weight_trend_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/nutrition/screens/nutrition_screen.dart';
import '../features/routine/screens/routine_screen.dart';
import 'app_routes.dart';

/// App router. Builds a `GoRouter` with the auth gate redirect and
/// the bottom-nav shell. Providers are passed in (not read from
/// `context`) because `GoRouter` requires a single instance and
/// must outlive route rebuilds.
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static const List<String> _shellPaths = <String>[
    AppRoutes.home,
    AppRoutes.routine,
    AppRoutes.nutrition,
    AppRoutes.aiAssistant,
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
      label: 'Ask AI',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
    ),
    AppDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static GoRouter build({
    required AuthProvider authProvider,
    required CatProvider catProvider,
  }) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: Listenable.merge(<Listenable>[
        authProvider,
        catProvider,
      ]),
      redirect: AuthGate.buildRedirect(
        authProvider: authProvider,
        catProvider: catProvider,
      ),
      routes: <RouteBase>[
        // Auth-only screens (outside the shell).
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, _) => const SplashScreen(),
        ),
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),

        // Bottom-nav shell — the home destinations.
        StatefulShellRoute.indexedStack(
          builder:
              (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell shell,
              ) {
                return AppScaffold(
                  navigationShell: shell,
                  destinations: _destinations,
                );
              },
          branches: _buildBranches(),
        ),

        // Phase 3 cat-management routes — top-level so they render
        // above the bottom-nav shell and survive tab switches.
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.catSwitch,
          builder: (_, _) => const CatSwitcherScreen(),
        ),
        GoRoute(
          path: AppRoutes.catProfilePattern,
          builder: (BuildContext context, GoRouterState state) {
            return CatProfileScreen(catId: state.pathParameters['id']!);
          },
        ),

        // Top-level secondary destinations rendered above the shell.
        for (final _TopLevelRoute r in _topLevelRoutes) r.route,
      ],
    );
  }

  static List<StatefulShellBranch> _buildBranches() {
    return _shellPaths
        .map(
          (String path) => StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: path, builder: (_, _) => _branchScreenFor(path)),
            ],
          ),
        )
        .toList(growable: false);
  }

  static Widget _branchScreenFor(String path) {
    switch (path) {
      case AppRoutes.home:
        return const HomeScreen();
      case AppRoutes.routine:
        return const RoutineScreen();
      case AppRoutes.nutrition:
        return const NutritionScreen();
      case AppRoutes.aiAssistant:
        return const AiAssistantScreen();
      case AppRoutes.profile:
        return const ProfileScreen();
      default:
        return _PlaceholderForRoute(path: path);
    }
  }
}

class _TopLevelRoute {
  const _TopLevelRoute(this.path, this.title, this.subtitle, [this.builder]);
  final String path;
  final String title;
  final String subtitle;

  /// Optional override builder. When supplied, the [title]/[subtitle]
  /// still drive the placeholder fallback but the router prefers the
  /// real screen for Phase 5+ routes that have shipped.
  final Widget Function(BuildContext, GoRouterState)? builder;

  GoRoute get route => GoRoute(
    path: path,
    builder: (BuildContext context, GoRouterState state) => builder != null
        ? builder!(context, state)
        : PlaceholderScreen(title: title, subtitle: subtitle),
  );
}

/// Routes implemented in Phase 5 — these override the default
/// placeholder with their real widget so navigation lands on a
/// working screen. The list is not `const` because the override
/// builder is a runtime lambda.
final List<_TopLevelRoute> _topLevelRoutes = <_TopLevelRoute>[
  _TopLevelRoute(
    AppRoutes.healthRecords,
    'Health Records',
    'Coming in Phase 5.',
    (BuildContext _, GoRouterState _) => const HealthRecordsScreen(),
  ),
  _TopLevelRoute(
    AppRoutes.medications,
    'Medications',
    'Coming in Phase 5.',
    (BuildContext _, GoRouterState _) => const MedicationListScreen(),
  ),
  _TopLevelRoute(
    AppRoutes.vaccinations,
    'Vaccinations',
    'Coming in Phase 5.',
    (BuildContext _, GoRouterState _) => const VaccinationListScreen(),
  ),
  const _TopLevelRoute(AppRoutes.vetFinder, 'Vet Finder', 'Coming in Phase 6.'),
  const _TopLevelRoute(AppRoutes.settings, 'Settings', 'Coming in Phase 8.'),
  const _TopLevelRoute(AppRoutes.reminders, 'Reminders', 'Coming in Phase 4.'),
  const _TopLevelRoute(
    AppRoutes.addFeeding,
    'Add Feeding',
    'Coming in Phase 4.',
  ),
  const _TopLevelRoute(
    AppRoutes.nutritionReport,
    'Nutrition Report',
    'Coming in Phase 4.',
  ),
  _TopLevelRoute(
    AppRoutes.weightTrend,
    'Weight Trend',
    'Coming in Phase 5.',
    (BuildContext _, GoRouterState _) => const WeightTrendScreen(),
  ),
  _TopLevelRoute(
    AppRoutes.emergencyGuidance,
    'Emergency Guidance',
    'Coming in Phase 7.',
    (BuildContext _, GoRouterState _) => const EmergencyGuidanceScreen(),
  ),
  _TopLevelRoute(
    AppRoutes.weeklyReport,
    'Weekly Report',
    'Coming in Phase 7.',
    (BuildContext _, GoRouterState _) => const WeeklyReportScreen(),
  ),
  _TopLevelRoute(
    AppRoutes.foodLabel,
    'Food Label Scan',
    'Coming in Phase 7.',
    (BuildContext _, GoRouterState _) => const FoodLabelScreen(),
  ),
  const _TopLevelRoute(AppRoutes.grooming, 'Grooming', 'Coming in Phase 4.'),
  const _TopLevelRoute(AppRoutes.foodGuide, 'Food Guide', 'Coming in Phase 8.'),
  const _TopLevelRoute(AppRoutes.catSafety, 'Cat Safety', 'Coming in Phase 8.'),
  const _TopLevelRoute(
    AppRoutes.careGuides,
    'Care Guides',
    'Coming in Phase 8.',
  ),
  const _TopLevelRoute(
    AppRoutes.kittenCare,
    'Kitten Care',
    'Coming in Phase 8.',
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
