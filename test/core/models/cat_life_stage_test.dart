import 'package:cat_care/core/models/cat_life_stage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anchor used by every birthday-relative test. Choosing a fixed
/// reference date keeps the boundary math stable across CI runs.
final DateTime _today = DateTime.utc(2024, 6, 15);

DateTime _monthsAgo(int months) {
  final DateTime base = _today;
  final int year = base.year;
  final int month = base.month - months;
  int adjustedYear = year;
  int adjustedMonth = month;
  while (adjustedMonth <= 0) {
    adjustedMonth += 12;
    adjustedYear -= 1;
  }
  return DateTime.utc(adjustedYear, adjustedMonth, base.day);
}

void main() {
  group('CatLifeStage.fromBirthday', () {
    test('null birthday falls back to adult', () {
      expect(
        CatLifeStage.fromBirthday(null, now: _today),
        CatLifeStage.adult,
      );
    });

    test('future birthday clamps to kitten', () {
      final DateTime future = _today.add(const Duration(days: 7));
      expect(
        CatLifeStage.fromBirthday(future, now: _today),
        CatLifeStage.kitten,
      );
    });

    test('3-month-old is a kitten', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(3), now: _today),
        CatLifeStage.kitten,
      );
    });

    test('6-month-old crosses into junior', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(6), now: _today),
        CatLifeStage.junior,
      );
    });

    test('11-month-old is still junior', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(11), now: _today),
        CatLifeStage.junior,
      );
    });

    test('12-month-old is adult', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(12), now: _today),
        CatLifeStage.adult,
      );
    });

    test('6-year-old is adult', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(72), now: _today),
        CatLifeStage.adult,
      );
    });

    test('7-year-old is mature', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(84), now: _today),
        CatLifeStage.mature,
      );
    });

    test('10-year-old is mature', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(120), now: _today),
        CatLifeStage.mature,
      );
    });

    test('11-year-old is senior', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(132), now: _today),
        CatLifeStage.senior,
      );
    });

    test('15-year-old is senior', () {
      expect(
        CatLifeStage.fromBirthday(_monthsAgo(180), now: _today),
        CatLifeStage.senior,
      );
    });
  });

  group('CatLifeStage.fromStorageKey', () {
    test('parses known keys', () {
      expect(
        CatLifeStage.fromStorageKey('kitten'),
        CatLifeStage.kitten,
      );
      expect(
        CatLifeStage.fromStorageKey('senior'),
        CatLifeStage.senior,
      );
    });

    test('null and unknown keys fall back to adult', () {
      expect(CatLifeStage.fromStorageKey(null), CatLifeStage.adult);
      expect(
        CatLifeStage.fromStorageKey('not-a-stage'),
        CatLifeStage.adult,
      );
    });
  });

  group('CatLifeStage.storageKey round-trip', () {
    test('every value survives fromStorageKey → storageKey', () {
      for (final stage in CatLifeStage.values) {
        expect(
          CatLifeStage.fromStorageKey(stage.storageKey),
          stage,
        );
      }
    });
  });
}