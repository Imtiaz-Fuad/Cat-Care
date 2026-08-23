import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/vaccination.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/vaccinations/{docId}`.
class VaccinationRepository {
  VaccinationRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
  }) : _firestore = firestoreService,
       _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  String newRecordId() => _uuid.v4();

  static String recordPath(String userId, String catId, String recordId) =>
      '${AppConstants.vaccinationCollectionPath(userId, catId)}/$recordId';

  Stream<List<Vaccination>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream<List<Vaccination>>.value(const <Vaccination>[]);
    }
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.catsSubcollection)
        .doc(catId)
        .collection(AppConstants.vaccinationsSubcollection)
        .orderBy('administeredAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) {
                return Vaccination.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                });
              })
              .toList(growable: false),
        );
  }

  Future<String> add(String userId, String catId, Vaccination record) async {
    final String id = record.id.isEmpty ? newRecordId() : record.id;
    final Vaccination stamped = record.copyWith(id: id);
    await _firestore.writeDocument(
      recordPath(userId, catId, id),
      stamped.toJson(),
    );
    AppLogger.i('VaccinationRepository.add $userId/$catId/$id');
    return id;
  }

  Future<void> update(String userId, String catId, Vaccination record) async {
    if (record.id.isEmpty) {
      throw const ValidationFailure(
        'Cannot update a vaccination without an id.',
        code: 'vaccination-missing-id',
      );
    }
    await _firestore.writeDocument(
      recordPath(userId, catId, record.id),
      record.toJson(),
    );
    AppLogger.i('VaccinationRepository.update $userId/$catId/${record.id}');
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    await _firestore.deleteDocument(recordPath(userId, catId, recordId));
    AppLogger.i('VaccinationRepository.delete $userId/$catId/$recordId');
  }
}
