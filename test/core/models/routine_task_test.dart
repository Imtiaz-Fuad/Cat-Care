import 'package:cat_care/core/models/routine_task.dart';
import 'package:flutter_test/flutter_test.dart';

RoutineTask _task({
  String repeat = 'daily',
  DateTime? createdAt,
  DateTime? lastCompletedAt,
}) {
  return RoutineTask(
    id: 'routine-1',
    catId: 'cat-1',
    title: 'Breakfast',
    category: 'feeding',
    repeat: repeat,
    createdAt: createdAt,
    lastCompletedAt: lastCompletedAt,
  );
}

void main() {
  group('RoutineTask daily state', () {
    test('completion belongs only to its local calendar day', () {
      final RoutineTask task = _task(
        lastCompletedAt: DateTime(2026, 9, 4, 23, 59),
      );

      expect(task.isCompletedOn(DateTime(2026, 9, 4)), isTrue);
      expect(task.isCompletedOn(DateTime(2026, 9, 5)), isFalse);
    });

    test('copyWith can explicitly clear completion timestamp', () {
      final RoutineTask task = _task(lastCompletedAt: DateTime(2026, 9, 4, 10));

      expect(task.copyWith(lastCompletedAt: null).lastCompletedAt, isNull);
    });

    test('weekdays exclude Saturday and Sunday', () {
      final RoutineTask task = _task(repeat: 'weekdays');

      expect(task.occursOn(DateTime(2026, 9, 4)), isTrue); // Friday
      expect(task.occursOn(DateTime(2026, 9, 5)), isFalse); // Saturday
      expect(task.occursOn(DateTime(2026, 9, 6)), isFalse); // Sunday
    });

    test('weekly routines use their creation weekday', () {
      final RoutineTask task = _task(
        repeat: 'weekly',
        createdAt: DateTime(2026, 9, 4),
      );

      expect(task.occursOn(DateTime(2026, 9, 11)), isTrue);
      expect(task.occursOn(DateTime(2026, 9, 12)), isFalse);
    });
  });
}
