import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/cats/providers/cat_provider.dart';
import '../../core/theme/accent_color_extractor.dart';

/// Shared scaffold for the four bottom-nav destinations per
/// docs/catcare.design §3: Home / Routine / Nutrition / Profile.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? accentHex = context.select<CatProvider, String?>(
      (CatProvider c) => c.activeCat?.themeAccentHex,
    );
    final Color? accent = AccentColorExtractor.tryParseHex(accentHex);
    final Color indicatorColor =
        accent?.withValues(alpha: 0.22) ??
        scheme.primary.withValues(alpha: 0.12);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        indicatorColor: indicatorColor,
        destinations: <NavigationDestination>[
          for (final AppDestination d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
