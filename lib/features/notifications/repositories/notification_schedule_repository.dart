import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/notification_schedule.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// CRUD + watch fa\u00e7ade for
/// `users/{uid}/notification_schedules/{scheduleId}`.
///
/// Stores the canonical schedule for every reminder the app
/// promises the OS. Each [NotificationSchedule] maps 1:1 to a local
/// notification (id = stable hash of `sourceType:sourceId` so the
/// scheduler can update / cancel the right OS-level reminder).
class NotificationScheduleRepository {
  NotificationScheduleRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
  })  : _firestore = firestoreService,
        _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  String newScheduleId() => _uuid.v4();

  static String scheduleDocPath(String ownerId, String id) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.notificationSchedulesSubcollection}/$id';

  static String schedulesCollectionPath(String ownerId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.notificationSchedulesSubcollection}';

  /// Stream every schedule owned by the user.
  Stream<List<NotificationSchedule>> watchSchedules({
    required String ownerId,
  }) {
    return _firestore.instance
        .collection(schedulesCollectionPath(ownerId))
        .orderBy('fireAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => NotificationSchedule.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }),
              )
              .toList(growable: false),
        );
  }

  /// Upsert (create or replace) a schedule document. Returns the
  /// stored [NotificationSchedule] with `id` + `createdAt`.
  Future<NotificationSchedule> upsert({
    required String ownerId,
    required NotificationSchedule schedule,
  }) async {
    final String id =
        schedule.id.isEmpty ? newScheduleId() : schedule.id;
    final DateTime now = DateTime.now();
    final NotificationSchedule stored = schedule.copyWith(
      id: id,
      createdAt: schedule.createdAt ?? now,
    );
    await _firestore.writeDocument(
      scheduleDocPath(ownerId, id),
      stored.toJson(),
    );
    AppLogger.i('NotificationScheduleRepository.upsert $ownerId/$id');
    return stored;
  }

  /// Delete a single schedule document.
  Future<void> delete({
    required String ownerId,
    required String scheduleId,
  }) async {
    await _firestore.deleteDocument(
      scheduleDocPath(ownerId, scheduleId),
    );
    AppLogger.i('NotificationScheduleRepository.delete $ownerId/$scheduleId');
  }

  /// Delete every schedule for the owner (used on sign-out).
  Future<void> deleteAllForOwner({required String ownerId}) async {
    final snap = await _firestore.instance
        .collection(schedulesCollectionPath(ownerId))
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    AppLogger.i(
        'NotificationScheduleRepository.deleteAllForOwner $ownerId (${snap.docs.length})');
  }
}