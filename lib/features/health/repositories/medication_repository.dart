import 'package:cat_care/core/constants/app_constants.dart';
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/medication.dart';
import 'package:cat_care/core/services/firestore_service.dart';
import 'package:cat_care/core/services/logger.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/medications/{docId}`.
class MedicationRepository {
  MedicationRepository({
    FirestoreService? firestore,
    AppLogger? logger,
  })  : _firestore = firestore ?? FirestoreService(),
        _log = logger ?? AppLogger();

  final FirestoreService _firestore;
  final AppLogger _log;

  Stream<List<Medication>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream.value(const <Medication>[]);
    }
    final path =
        AppConstants.medicationCollectionPath(userId, catId);
    return _firestore
        .streamCollection(path, orderBy: 'startDate', descending: true)
        .map((docs) => docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data as Map);
              data['id'] = doc.id;
              return Medication.fromJson(data);
            }).toList())
        .handleError((Object error, StackTrace stack) {
      _log.e('MedicationRepository.watchForCat failed',
          error: error, stack: stack);
      throw AppFailure.fromException(error);
    });
  }

  /// Streams only medications whose [startDate, endDate] window contains
  /// [today] (or are open-ended). Used by the Routine screen for the daily
  /// check-off card.
  Stream<List<Medication>> watchActiveForCat(
    String userId,
    String catId, {
    DateTime? now,
  }) {
    return watchForCat(userId, catId).map((all) {
      final today = now ?? DateTime.now();
      return all.where((med) => med.isActiveOn(today)).toList();
    });
  }

  Future<String> add(String userId, String catId, Medication record) async {
    try {
      final docId = record.id.isEmpty ? null : record.id;
      final json = record.toJson()..remove('id');
      final newId = await _firestore.addDocument(
        AppConstants.medicationCollectionPath(userId, catId),
        json,
        documentId: docId,
      );
      _log.i('MedicationRepository.add -> $newId');
      return newId;
    } catch (e, st) {
      _log.e('MedicationRepository.add failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> update(
    String userId,
    String catId,
    Medication record,
  ) async {
    if (record.id.isEmpty) {
      throw const AppFailure(
        kind: AppFailureKind.invalidInput,
        messageKey: 'error.health.updateMissingId',
      );
    }
    try {
      final json = record.toJson()..remove('id');
      await _firestore.updateDocument(
        '${AppConstants.medicationCollectionPath(userId, catId)}/${record.id}',
        json,
      );
      _log.i('MedicationRepository.update -> ${record.id}');
    } catch (e, st) {
      _log.e('MedicationRepository.update failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    try {
      await _firestore.deleteDocument(
        '${AppConstants.medicationCollectionPath(userId, catId)}/$recordId',
      );
      _log.i('MedicationRepository.delete -> $recordId');
    } catch (e, st) {
      _log.e('MedicationRepository.delete failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }
}