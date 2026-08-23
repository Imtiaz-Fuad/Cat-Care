import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/feeding_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// CRUD + watch façade for
/// `users/{uid}/cats/{catId}/feedings/{entryId}`.
///
/// Repositories own the path shape, IDs, and timestamps so providers
/// never see `FirebaseFirestore`. Errors are translated into
/// [AppFailure]; the UI surfaces the message.
class FeedingRepository {
  FeedingRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _firestore = firestoreService,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final FirestoreService _firestore;
  final Uuid _uuid;
  final DateTime Function() _clock;

  String newEntryId() => _uuid.v4();

  /// Path of a single feeding entry under a specific owner + cat.
  static String entryDocPath(String ownerId, String catId, String entryId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.feedingsSubcollection}/$entryId';

  /// Path of the feedings collection under a specific owner + cat.
  static String entriesCollectionPath(String ownerId, String catId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.feedingsSubcollection}';

  /// Stream every feeding entry for the given cat, newest first.
  Stream<List<FeedingEntry>> watchFeedings({
    required String ownerId,
    required String catId,
    int? limit,
  }) {
    var query = _firestore.instance
        .collection(entriesCollectionPath(ownerId, catId))
        .orderBy('time', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snap) => snap.docs
          .map(
            (d) => FeedingEntry.fromJson(<String, dynamic>{
              ...d.data(),
              'id': d.id,
              'catId': catId,
            }),
          )
          .toList(growable: false),
    );
  }

  /// One-shot read used in tests + report generation. Returns `[]`
  /// (never null) when the cat has no feedings yet.
  Future<List<FeedingEntry>> getFeedings({
    required String ownerId,
    required String catId,
    DateTime? since,
  }) async {
    var query = _firestore.instance
        .collection(entriesCollectionPath(ownerId, catId))
        .orderBy('time', descending: true);
    if (since != null) {
      query = query.where(
        'time',
        isGreaterThanOrEqualTo: since.toIso8601String(),
      );
    }
    final snap = await query.get();
    return snap.docs
        .map(
          (d) => FeedingEntry.fromJson(<String, dynamic>{
            ...d.data(),
            'id': d.id,
            'catId': catId,
          }),
        )
        .toList(growable: false);
  }

  /// Persist a brand-new feeding entry. Returns the stored
  /// [FeedingEntry] (with `id` and `createdAt` populated).
  Future<FeedingEntry> addEntry({
    required String ownerId,
    required FeedingEntry entry,
  }) async {
    if (entry.foodName.trim().isEmpty) {
      throw const ValidationFailure(
        'Food name is required.',
        code: 'missing-food-name',
      );
    }
    if (entry.amount <= 0) {
      throw const ValidationFailure(
        'Amount must be greater than zero.',
        code: 'invalid-amount',
      );
    }
    final String id = entry.id.isEmpty ? newEntryId() : entry.id;
    final DateTime now = _clock();
    final FeedingEntry stored = entry.copyWith(
      id: id,
      createdAt: entry.createdAt ?? now,
    );
    await _firestore.writeDocument(
      entryDocPath(ownerId, stored.catId, id),
      stored.toJson(),
    );
    AppLogger.i('FeedingRepository.addEntry $ownerId/${stored.catId}/$id');
    return stored;
  }

  /// Patch an existing feeding entry. Pass [note] via the [Clear]
  /// sentinel to set it to `null`; otherwise omit to leave unchanged.
  Future<FeedingEntry> updateEntry({
    required String ownerId,
    required FeedingEntry entry,
    Object? note = _sentinel,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'foodName': entry.foodName.trim(),
      'foodType': entry.foodType,
      'amount': entry.amount,
      'unit': entry.unit,
      'time': entry.time.toIso8601String(),
      'photoUrl': entry.photoUrl,
    };
    if (!identical(note, _sentinel)) {
      patch['note'] = note;
    }
    await _firestore.writeDocument(
      entryDocPath(ownerId, entry.catId, entry.id),
      patch,
      merge: true,
    );
    AppLogger.i('FeedingRepository.updateEntry ${entry.catId}/${entry.id}');
    return entry.copyWith(
      note: identical(note, _sentinel) ? entry.note : note as String?,
    );
  }

  /// Permanently delete a feeding entry.
  Future<void> deleteEntry({
    required String ownerId,
    required String catId,
    required String entryId,
  }) async {
    await _firestore.deleteDocument(entryDocPath(ownerId, catId, entryId));
    AppLogger.i('FeedingRepository.deleteEntry $catId/$entryId');
  }
}

/// Marker value used as the default parameter for nullable fields in
/// [FeedingRepository.updateEntry] so callers can distinguish "don't
/// touch the field" from "set the field to null".
const Object _sentinel = Object();
