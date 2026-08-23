import 'package:cat_care/core/constants/app_constants.dart';
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/vaccination.dart';
import 'package:cat_care/core/services/firestore_service.dart';
import 'package:cat_care/core/services/logger.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/vaccinations/{docId}`.
class VaccinationRepository {
  VaccinationRepository({
    FirestoreService? firestore,
    AppLogger? logger,
  })  : _firestore = firestore ?? FirestoreService(),
        _log = logger ?? AppLogger();

  final FirestoreService _firestore;
  final AppLogger _log;

  Stream<List<Vaccination>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream.value(const <Vaccination>[]);
    }
    final path =
        AppConstants.vaccinationCollectionPath(userId, catId);
    return _firestore
        .streamCollection(path, orderBy: 'date', descending: true)
        .map((docs) => docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data as Map);
              data['id'] = doc.id;
              return Vaccination.fromJson(data);
            }).toList())
        .handleError((Object error, StackTrace stack) {
      _log.e('VaccinationRepository.watchForCat failed',
          error: error, stack: stack);
      throw AppFailure.fromException(error);
    });
  }

  Future<String> add(String userId, String catId, Vaccination record) async {
    try {
      final docId = record.id.isEmpty ? null : record.id;
      final json = record.toJson()..remove('id');
      final newId = await _firestore.addDocument(
        AppConstants.vaccinationCollectionPath(userId, catId),
        json,
        documentId: docId,
      );
      _log.i('VaccinationRepository.add -> $newId');
      return newId;
    } catch (e, st) {
      _log.e('VaccinationRepository.add failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> update(
    String userId,
    String catId,
    Vaccination record,
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
        '${AppConstants.vaccinationCollectionPath(userId, catId)}/${record.id}',
        json,
      );
      _log.i('VaccinationRepository.update -> ${record.id}');
    } catch (e, st) {
      _log.e('VaccinationRepository.update failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    try {
      await _firestore.deleteDocument(
        '${AppConstants.vaccinationCollectionPath(userId, catId)}/$recordId',
      );
      _log.i('VaccinationRepository.delete -> $recordId');
    } catch (e, st) {
      _log.e('VaccinationRepository.delete failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }
}
