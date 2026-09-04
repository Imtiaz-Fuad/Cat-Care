import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// CRUD + watch façade for `users/{uid}/cats/{catId}/routines/{taskId}`
/// and an aggregate stream of *today's* routines (filtered client-side
/// from the full list).
///
/// Repositories own the path shape, IDs, and timestamps so providers
/// never see `FirebaseFirestore`. Errors are translated into
/// [AppFailure]; the UI surfaces the message.
class RoutineRepository {
  RoutineRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
  })  : _firestore = firestoreService,
        _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  /// Generate a new task id. Exposed so tests can pin it.
  String newTaskId() => _uuid.v4();

  /// Path of a single task under a specific owner + cat.
  static String taskDocPath(String ownerId, String catId, String taskId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.routinesSubcollection}/$taskId';

  /// Path of the routines collection under a specific owner + cat.
  static String tasksCollectionPath(String ownerId, String catId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.routinesSubcollection}';

  /// Stream every routine for the given cat, newest updated first.
  /// Completed state persists per task (no server-side aggregation);
  /// the UI derives "done today" from [RoutineTask.lastCompletedAt].
  Stream<List<RoutineTask>> watchRoutines({
    required String ownerId,
    required String catId,
  }) {
    return _firestore.instance
        .collection(tasksCollectionPath(ownerId, catId))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => RoutineTask.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                  'catId': catId,
                }),
              )
              .toList(growable: false),
        );
  }

  /// One-shot read used in tests + the RoutineGenerator bootstrap
  /// path. Returns `[]` (never null) when the cat has no routines
  /// yet.
  Future<List<RoutineTask>> getRoutines({
    required String ownerId,
    required String catId,
  }) async {
    final snap = await _firestore.instance
        .collection(tasksCollectionPath(ownerId, catId))
        .get();
    return snap.docs
        .map(
          (d) => RoutineTask.fromJson(<String, dynamic>{
            ...d.data(),
            'id': d.id,
            'catId': catId,
          }),
        )
        .toList(growable: false);
  }

  /// Persist a brand-new routine. Returns the stored [RoutineTask]
  /// (with `id`, `createdAt`, `updatedAt` populated).
  Future<RoutineTask> createTask({
    required String ownerId,
    required RoutineTask task,
  }) async {
    if (task.title.trim().isEmpty) {
      throw const ValidationFailure(
        'Routine title is required.',
        code: 'missing-title',
      );
    }
    final String id = task.id.isEmpty ? newTaskId() : task.id;
    final DateTime now = DateTime.now();
    final RoutineTask stored = task.copyWith(
      id: id,
      createdAt: task.createdAt ?? now,
      updatedAt: now,
    );
    await _firestore.writeDocument(
      taskDocPath(ownerId, stored.catId, id),
      stored.toJson(),
    );
    AppLogger.i('RoutineRepository.createTask $ownerId/${stored.catId}/$id');
    return stored;
  }

  /// Patch an existing routine. [completed] is treated as a flag the
  /// caller can flip; [lastCompletedAt] is set to "now" automatically
  /// when [completed] is `true`. Setting it back to `false` clears the
  /// completion timestamp so all daily surfaces agree it is undone.
  ///
  /// To clear a nullable field (set it to null), pass the [Clear]
  /// sentinel via the matching named argument.
  Future<RoutineTask> updateTask({
    required String ownerId,
    required RoutineTask task,
    bool? completed,
    Object? notes = _sentinel,
  }) async {
    final DateTime now = DateTime.now();
    final Map<String, dynamic> patch = <String, dynamic>{
      'title': task.title.trim(),
      'category': task.category,
      'timeOfDay': task.timeOfDay?.toIso8601String(),
      'repeat': task.repeat,
      'reminder': task.reminder,
      'updatedAt': now.toIso8601String(),
    };
    if (!identical(notes, _sentinel)) {
      patch['notes'] = notes;
    }
    if (completed != null) {
      patch['completed'] = completed;
      if (completed) {
        patch['lastCompletedAt'] = now.toIso8601String();
      } else {
        patch['lastCompletedAt'] = null;
      }
    }

    await _firestore.writeDocument(
      taskDocPath(ownerId, task.catId, task.id),
      patch,
      merge: true,
    );
    AppLogger.i('RoutineRepository.updateTask ${task.catId}/${task.id}');
    return task.copyWith(
      completed: completed ?? task.completed,
      lastCompletedAt: completed == true
          ? now
          : completed == false
          ? null
          : task.lastCompletedAt,
      updatedAt: now,
    );
  }

  /// Permanently delete a routine task.
  Future<void> deleteTask({
    required String ownerId,
    required String catId,
    required String taskId,
  }) async {
    await _firestore.deleteDocument(taskDocPath(ownerId, catId, taskId));
    AppLogger.i('RoutineRepository.deleteTask $catId/$taskId');
  }

  /// Seed default routines for the given (owner, cat). Used by
  /// onboarding / "regenerate" — never overwrites the existing list;
  /// only inserts new tasks whose `title + timeOfDay` is not already
  /// present.
  Future<List<RoutineTask>> seedIfEmpty({
    required String ownerId,
    required String catId,
    required List<RoutineTask> defaults,
  }) async {
    final List<RoutineTask> existing = await getRoutines(
      ownerId: ownerId,
      catId: catId,
    );
    final List<RoutineTask> added = <RoutineTask>[];
    for (final RoutineTask draft in defaults) {
      final bool duplicate = existing.any((t) =>
          t.title.trim() == draft.title.trim() &&
          _sameTimeOfDay(t.timeOfDay, draft.timeOfDay));
      if (duplicate) continue;
      final RoutineTask stored = await createTask(ownerId: ownerId, task: draft);
      added.add(stored);
    }
    return added;
  }

  static bool _sameTimeOfDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.hour == b.hour && a.minute == b.minute;
  }
}

/// Marker value used as the default parameter for nullable fields in
/// [RoutineRepository.updateTask] so callers can distinguish "don't
/// touch the field" from "set the field to null".
const Object _sentinel = Object();
