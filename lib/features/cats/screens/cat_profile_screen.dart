import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/cat_life_stage.dart';
import '../../../core/models/cat_profile.dart';
import '../../../routes/app_routes.dart';
import '../providers/cat_provider.dart';
import 'onboarding/onboarding_screen.dart';
import '../widgets/cat_photo.dart';

/// Cat profile surface — see `docs/catcare.design` § "Cat profile"
/// (sidebar entry under "CAT"). Displays the active cat's hero
/// photo, identity block, life stage, medical notes, and a set of
/// inline actions (switch / edit / delete).
///
/// Reactive: the screen listens to [CatProvider] so any change in
/// the underlying stream (e.g. another device updated the cat) is
/// reflected without a manual refresh.
class CatProfileScreen extends StatelessWidget {
  const CatProfileScreen({super.key, required this.catId});

  final String catId;

  @override
  Widget build(BuildContext context) {
    return Consumer<CatProvider>(
      builder: (BuildContext context, CatProvider cats, Widget? _) {
        final CatProfile? profile = _find(cats, catId);

        if (!cats.hasLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (profile == null) {
          return const _MissingProfileScaffold();
        }
        return _ProfileBody(profile: profile, cats: cats);
      },
    );
  }

  CatProfile? _find(CatProvider cats, String id) {
    for (final CatProfile c in cats.cats) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.cats});

  final CatProfile profile;
  final CatProvider cats;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CatLifeStage stage = CatLifeStage.fromBirthday(profile.birthday);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
        leading: IconButton(
          tooltip: 'Back to Profile',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.profile),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Switch cat',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.push('/cats/switch'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String action) => _handleMenu(context, action),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: <Widget>[
          SizedBox(
            height: 280,
            width: double.infinity,
            child: FutureBuilder<String?>(
              future: context.read<CatProvider>().localPhotoPath(profile.id),
              builder: (BuildContext context, snapshot) {
                final String? localPath = snapshot.data;
                return CatPhoto(
                  localPath: localPath,
                  networkUrl: localPath == null ? profile.photoUrl : null,
                  variant: CatPhotoVariant.hero,
                  accentHex: profile.themeAccentHex,
                  semanticLabel: 'Photo of ${profile.name}',
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.name, style: text.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  stage.displayLabel,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (profile.sex != null)
                      _Chip(label: _sexLabel(profile.sex!)),
                    if (profile.breed != null) _Chip(label: profile.breed!),
                    if (profile.color != null) _Chip(label: profile.color!),
                    _Chip(
                      label: profile.indoor ? 'Indoor' : 'Indoor + outdoor',
                    ),
                    if (profile.neutered)
                      const _Chip(label: 'Spayed / neutered'),
                    if (profile.weightKg != null)
                      _Chip(
                        label: '${profile.weightKg!.toStringAsFixed(1)} kg',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Health notes',
            children: <Widget>[
              if (profile.allergies.isNotEmpty)
                _NoteRow(
                  label: 'Allergies',
                  value: profile.allergies.join(', '),
                ),
              if (profile.diseases.isNotEmpty)
                _NoteRow(
                  label: 'Conditions',
                  value: profile.diseases.join(', '),
                ),
              if (profile.medications.isNotEmpty)
                _NoteRow(
                  label: 'Medications',
                  value: profile.medications.join(', '),
                ),
              if (profile.notes != null && profile.notes!.isNotEmpty)
                _NoteRow(label: 'Notes', value: profile.notes!),
              if (profile.allergies.isEmpty &&
                  profile.diseases.isEmpty &&
                  profile.medications.isEmpty &&
                  (profile.notes == null || profile.notes!.isEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No health notes yet. Add allergies, conditions, '
                    'and medications so reminders stay accurate.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String action) async {
    switch (action) {
      case 'edit':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OnboardingScreen(editingProfile: profile),
          ),
        );
      case 'delete':
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text('Delete ${profile.name}?'),
            content: const Text(
              'This removes the profile and history. You can\'t undo '
              'this — consider archiving instead if that ships later.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await cats.deleteCat(catId: profile.id, photoUrl: profile.photoUrl);
          if (context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        }
    }
  }

  String _sexLabel(String v) {
    switch (v) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      default:
        return v;
    }
  }
}

class _MissingProfileScaffold extends StatelessWidget {
  const _MissingProfileScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cat profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Card(
                color: const Color(0xFFA9472A),
                elevation: 5,
                shadowColor: const Color(0xFFE09A79).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: const Color(0xFFF3C8B5).withValues(alpha: 0.8),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.go('/cats/switch?returnHome=true'),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 88,
                    child: Center(
                      child: Text(
                        'Pick another cat',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: text.labelSmall?.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
