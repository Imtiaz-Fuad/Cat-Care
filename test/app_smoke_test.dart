import 'dart:io';

import 'package:cat_care/core/theme/app_theme.dart';
import 'package:cat_care/core/widgets/placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 0 baseline', () {
    testWidgets('PlaceholderScreen renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const PlaceholderScreen(
            title: 'Test Title',
            subtitle: 'Test subtitle',
          ),
        ),
      );

      // Title appears in both AppBar and body.
      expect(find.text('Test Title'), findsNWidgets(2));
      expect(find.text('Test subtitle'), findsOneWidget);
    });

    test('AppTheme.light() builds a Material 3 theme', () {
      final ThemeData theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('AppTheme.dark() builds a Material 3 dark theme', () {
      final ThemeData theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('Architectural layering', () {
    test('UI code does not import Firebase SDKs directly', () async {
      final featuresRoot = Directory('lib/features');
      if (!featuresRoot.existsSync()) return;

      final violations = <String>[];
      final importPattern =
          RegExp(r"^\s*import\s+'package:(firebase_[a-z]+|cloud_firestore)\/");

      await for (final entity in featuresRoot.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final parts = entity.path.replaceAll('\\', '/').split('/');
        // Expecting lib / features / <feature> / <screens|widgets> / file.dart
        if (parts.length < 5) continue;
        if (parts[3] != 'screens' && parts[3] != 'widgets') continue;
        final lines = await entity.readAsLines();
        for (var i = 0; i < lines.length; i++) {
          final m = importPattern.firstMatch(lines[i]);
          if (m == null) continue;
          violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Widgets/screens must not import Firebase directly. '
            'Move calls into a Repository under lib/features/<feature>/data/.',
      );
    });
  });
}