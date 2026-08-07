/// CI-friendly layering guard.
///
/// Scans `lib/features/**` for direct Firebase imports inside `screens/` or
/// `widgets/`. The CatCare BD architecture (see `docs/architecture.md`) requires
/// UI code to access data exclusively through Provider → Repository → Service,
/// so any Firebase import under those subtrees is a violation.
///
/// Run locally with:
///   dart run tools/check_layering.dart
///
/// Returns exit code 0 on success, 1 if any violations are found.
library;

import 'dart:io';

const _forbiddenSubdirs = <String>{'screens', 'widgets'};

Future<int> main() async {
  final featuresRoot = Directory('lib/features');
  if (!featuresRoot.existsSync()) {
    stderr.writeln('Layering check: lib/features not found, skipping.');
    return 0;
  }

  final violations = <String>[];

  await for (final entity in featuresRoot.list(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    // Expecting lib / features / <feature> / <screens|widgets> / file.dart
    if (parts.length < 5) continue;
    final subdir = parts[3];
    if (!_forbiddenSubdirs.contains(subdir)) continue;

    final lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = RegExp(
        r"^\s*import\s+'package:(firebase_[a-z]+|cloud_firestore)\/",
      ).firstMatch(line);
      if (match == null) continue;
      violations.add(
        '${entity.path}:${i + 1} -> ${match.group(0)!.trim()}'
        '\n   widgets/screens must not import Firebase directly',
      );
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Layering check passed: no direct Firebase imports in UI.');
    return 0;
  }

  stderr.writeln(
    'Layering check FAILED. Move these calls into a Repository under'
    ' lib/features/<feature>/data/ and consume via a Provider.',
  );
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  return 1;
}