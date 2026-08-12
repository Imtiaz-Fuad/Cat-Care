import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/water_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// CRUD + watch façade for
/// `users/{uid}/cats/{catId}/water/{entryId}`.
///
/// Repositories own the path shape, IDs, and timestamps so providers
/// never see `FirebaseFirestore`. Errors are translated into
/// [AppFailure]; the UI surfaces the message.
class WaterRepository {
  WaterRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _firestore = firestoreService,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final FirestoreService _firestore;
  final Uuid _uuid;
  final DateTime Function() _clock;

  String newEntryId() => _uuid.v4();

  /// Path of a single water entry under a specific owner + cat.
  static String entryDocPath(String ownerId, String catId, String entryId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.waterSubcollection}/$entryId';

  /// Path of the water collection under a specific owner + cat.
  static String entriesCollectionPath(String ownerId, String catId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId/'
      '${AppConstants.waterSubcollection}';

  /// Stream every water entry for the given cat, newest first.
  Stream<List<WaterEntry>> watchWater({
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
                (d) => WaterEntry.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                  'catId': catId,
                }),
              )
              .toList(growable: false),
        );
  }

  /// One-shot read used in tests + report generation. Returns `[]`
  /// (never null) when the cat has no water entries yet.
  Future<List<WaterEntry>> getWater({
    required String ownerId,
    required String catId,
    DateTime? since,
  }) async {
    var query = _firestore.instance
        .collection(entriesCollectionPath(ownerId, catId))
        .orderBy('time', descending: true);
    if (since != null) query = query.where('time', isGreaterThanOrEqualTo: since.toIso8601String());
    final snap = await query.get();
    return snap.docs
        .map(
          (d) => WaterEntry.fromJson(<String, dynamic>{
            ...d.data(),
            'id': d.id,
            'catId': catId,
          }),
        )
        .toList(growable: false);
  }

  /// Persist a brand-new water entry. Returns the stored [WaterEntry]
  /// (with `id` and `createdAt` populated).
  Future<WaterEntry> addEntry({
    required String ownerId,
    required WaterEntry entry,
  }) async {
    if (entry.amountMl <= 0) {
      throw const ValidationFailure(
        'Water amount must be greater than zero.',
        code: 'invalid-amount',
      );
    }
    final String id = entry.id.isEmpty ? newEntryId() : entry.id;
    final DateTime now = _clock();
    final WaterEntry stored = entry.copyWith(
      id: id,
      createdAt: entry.createdAt ?? now,
    );
    await _firestore.writeDocument(
      entryDocPath(ownerId, stored.catId, id),
      stored.toJson(),
    );
    AppLogger.i('WaterRepository.addEntry $ownerId/${stored.catId}/$id');
    return stored;
  }

  /// Patch an existing water entry. Pass [note] via the [Clear]
  /// sentinel to set it to `null`; otherwise omit to leave unchanged.
  Future<WaterEntry> updateEntry({
    required String ownerId,
    required WaterEntry entry,
    Object? note = _sentinel,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'amountMl': entry.amountMl,
      'time': entry.time.toIso8601String(),
    };
    if (!identical(note, _sentinel)) {
      patch['note'] = note;
    }
    await _firestore.writeDocument(
      entryDocPath(ownerId, entry.catId, entry.id),
      patch,
      merge: true,
    );
    AppLogger.i('WaterRepository.updateEntry ${entry.catId}/${entry.id}');
    return entry.copyWith(note: identical(note, _sentinel) ? entry.note : note as String?);
  }

  /// Permanently delete a water entry.
  Future<void> deleteEntry({
    required String ownerId,
    required String catId,
    required String entryId,
  }) async {
    await _firestore.deleteDocument(entryDocPath(ownerId, catId, entryId));
    AppLogger.i('WaterRepository.deleteEntry $catId/$entryId');
  }
}

/// Marker value used as the default parameter for nullable fields in
/// [WaterRepository.updateEntry] so callers can distinguish "don't
/// touch the field" from "set the field to null".
const Object _sentinel = Object();