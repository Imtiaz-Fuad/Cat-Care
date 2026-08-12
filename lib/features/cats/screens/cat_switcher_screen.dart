import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/cat_provider.dart';
import '../widgets/cat_photo.dart';

/// Sidebar surface — see `docs/catcare.design` § "Navigation Drawer /
/// Sidebar": under the "CAT" heading the user gets "Cat profile /
/// switch cat".
///
/// Renders:
///   * One [ListTile] per owned cat. Tapping it sets the cat active
///     and pops back.
///   * An "Add another cat" row that navigates to onboarding.
///   * A subtle "Currently active" hint on the selected cat.
class CatSwitcherScreen extends StatelessWidget {
  const CatSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your cats')),
      body: Consumer<CatProvider>(
        builder: (BuildContext context, CatProvider cats, Widget? _) {
          if (!cats.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cats.cats.isEmpty) {
            return _EmptySwitcher(onAdd: () => context.push('/onboarding'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cats.cats.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
            itemBuilder: (BuildContext context, int index) {
              if (index == cats.cats.length) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(Icons.add, color: scheme.onSecondaryContainer),
                  ),
                  title: const Text('Add another cat'),
                  onTap: () => context.push('/onboarding'),
                );
              }
              final current = cats.cats[index];
              final bool active = cats.activeCat?.id == current.id;
              return ListTile(
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: CatPhoto(
                    networkUrl: current.photoUrl,
                    variant: CatPhotoVariant.avatar,
                    accentHex: current.themeAccentHex,
                    semanticLabel: 'Photo of ${current.name}',
                  ),
                ),
                title: Text(current.name, style: text.titleMedium),
                subtitle: Text(
                  active
                      ? 'Currently active'
                      : current.breed ?? 'Tap to switch',
                  style: text.bodySmall?.copyWith(
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  active ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: active ? scheme.primary : scheme.outlineVariant,
                ),
                onTap: () async {
                  await cats.setActiveCat(current.id);
                  if (context.mounted) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/cats/${current.id}');
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptySwitcher extends StatelessWidget {
  const _EmptySwitcher({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.pets_outlined, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No cats yet', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add your first cat to start tracking routines, '
              'vaccinations, and more.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a cat'),
            ),
          ],
        ),
      ),
    );
  }
}
