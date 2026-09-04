import 'package:cat_care/core/models/routine_task.dart';
import 'package:cat_care/core/services/firestore_service.dart';
import 'package:cat_care/features/routine/repositories/routine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  test('marking a routine undone clears its completion timestamp', () async {
    final _MockFirestoreService firestore = _MockFirestoreService();
    final RoutineRepository repository = RoutineRepository(
      firestoreService: firestore,
    );
    final RoutineTask task = RoutineTask(
      id: 'routine-1',
      catId: 'cat-1',
      title: 'Breakfast',
      category: 'feeding',
      completed: true,
      lastCompletedAt: DateTime(2026, 9, 4, 8),
    );
    when(
      () => firestore.writeDocument(
        any<String>(),
        any<Map<String, dynamic>>(),
        merge: any<bool>(named: 'merge'),
      ),
    ).thenAnswer((_) async {});

    final RoutineTask updated = await repository.updateTask(
      ownerId: 'owner-1',
      task: task,
      completed: false,
    );

    final List<Object?> captured = verify(
      () => firestore.writeDocument(
        any<String>(),
        captureAny<Map<String, dynamic>>(),
        merge: true,
      ),
    ).captured;
    final Map<String, dynamic> patch = captured.single! as Map<String, dynamic>;
    expect(patch['completed'], isFalse);
    expect(patch['lastCompletedAt'], isNull);
    expect(updated.completed, isFalse);
    expect(updated.lastCompletedAt, isNull);
  });
}
