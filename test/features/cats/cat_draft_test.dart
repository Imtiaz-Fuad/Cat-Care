import 'package:cat_care/features/cats/models/cat_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatDraft.isValid', () {
    test('empty draft is invalid', () {
      expect(CatDraft().isValid, isFalse);
    });

    test('whitespace-only name is invalid', () {
      expect(CatDraft(name: '   ').isValid, isFalse);
    });

    test('name without weight is invalid', () {
      expect(CatDraft(name: 'Mimi').isValid, isFalse);
    });

    test('name and estimated weight are valid', () {
      expect(CatDraft(name: 'Mimi', weightKg: 4.2).isValid, isTrue);
    });

    test('weight must be greater than zero and no more than 15 kg', () {
      expect(CatDraft(name: 'Mimi', weightKg: 0).isValid, isFalse);
      expect(CatDraft(name: 'Mimi', weightKg: 15).isValid, isTrue);
      expect(CatDraft(name: 'Mimi', weightKg: 15.1).isValid, isFalse);
    });
  });

  group('CatDraft.copyWith', () {
    test('preserves untouched fields', () {
      final CatDraft original = CatDraft(name: 'Mimi', breed: 'Bengal');
      final CatDraft copy = original.copyWith(name: 'Mimi Two');
      expect(copy.name, 'Mimi Two');
      expect(copy.breed, 'Bengal');
    });

    test('clears nullable fields with explicit null via sentinel', () {
      final CatDraft original = CatDraft(
        name: 'Mimi',
        photoPath: '/tmp/cat.jpg',
        color: 'brown',
      );
      final CatDraft cleared = original.copyWith(photoPath: null, color: null);
      expect(cleared.photoPath, isNull);
      expect(cleared.color, isNull);
      expect(cleared.name, 'Mimi');
    });

    test('updating allergies list replaces the reference', () {
      final CatDraft original = CatDraft(allergies: <String>['pollen']);
      final CatDraft updated = original.copyWith(
        allergies: <String>['pollen', 'fish'],
      );
      expect(updated.allergies, <String>['pollen', 'fish']);
    });
  });

  group('CatDraft.toProfile', () {
    test('trims whitespace from name', () {
      final CatDraft draft = CatDraft(name: '  Mimi  ');
      final profile = draft.toProfile(id: 'cat-1', ownerId: 'user-1');
      expect(profile.name, 'Mimi');
    });

    test('uses injected id and ownerId', () {
      final CatDraft draft = CatDraft(name: 'Mimi');
      final profile = draft.toProfile(id: 'cat-1', ownerId: 'user-1');
      expect(profile.id, 'cat-1');
      expect(profile.ownerId, 'user-1');
    });

    test('preserves created == updated timestamps', () {
      final DateTime fixed = DateTime.utc(2024, 6, 15, 12);
      final CatDraft draft = CatDraft(name: 'Mimi');
      final profile = draft.toProfile(
        id: 'cat-1',
        ownerId: 'user-1',
        now: fixed,
      );
      expect(profile.createdAt, fixed);
      expect(profile.updatedAt, fixed);
    });

    test('carries photo url and accent through', () {
      final CatDraft draft = CatDraft(
        name: 'Mimi',
        photoUrl: 'https://example.com/mimi.jpg',
        accentHex: '#A1B2C3',
      );
      final profile = draft.toProfile(id: 'cat-1', ownerId: 'user-1');
      expect(profile.photoUrl, 'https://example.com/mimi.jpg');
      expect(profile.themeAccentHex, '#A1B2C3');
    });

    test('priorities list is unmodifiable in the resulting profile', () {
      final CatDraft draft = CatDraft(
        name: 'Mimi',
        priorities: <String>['routine', 'nutrition'],
      );
      final profile = draft.toProfile(id: 'cat-1', ownerId: 'user-1');
      expect(() => profile.priorities.add('x'), throwsUnsupportedError);
    });
  });

  group('CatPriority', () {
    test('all contains every constant identifier', () {
      expect(
        CatPriority.all,
        containsAll(<String>[
          CatPriority.routine,
          CatPriority.nutrition,
          CatPriority.grooming,
          CatPriority.health,
          CatPriority.vaccinations,
        ]),
      );
    });

    test('all has no duplicates', () {
      expect(CatPriority.all.toSet().length, CatPriority.all.length);
    });
  });
}
