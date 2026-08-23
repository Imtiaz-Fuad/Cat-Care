import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/medication.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/medications/{docId}`.
class MedicationRepository {
  MedicationRepository({required FirestoreService firestoreService, Uuid? uuid})
    : _firestore = firestoreService,
      _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  String newRecordId() => _uuid.v4();

  static String recordPath(String userId, String catId, String recordId) =>
      '${AppConstants.medicationCollectionPath(userId, catId)}/$recordId';

  Stream<List<Medication>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream<List<Medication>>.value(const <Medication>[]);
    }
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.catsSubcollection)
        .doc(catId)
        .collection(AppConstants.medicationsSubcollection)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                return Medication.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                });
              })
              .toList(growable: false),
        );
  }

  Future<String> add(String userId, String catId, Medication record) async {
    final String id = record.id.isEmpty ? newRecordId() : record.id;
    final Medication stamped = record.copyWith(
      id: id,
      updatedAt: DateTime.now(),
    );
    await _firestore.writeDocument(
      recordPath(userId, catId, id),
      stamped.toJson(),
    );
    AppLogger.i('MedicationRepository.add $userId/$catId/$id');
    return id;
  }

  Future<void> update(String userId, String catId, Medication record) async {
    if (record.id.isEmpty) {
      throw const ValidationFailure(
        'Cannot update a medication without an id.',
        code: 'medication-missing-id',
      );
    }
    final Medication stamped = record.copyWith(updatedAt: DateTime.now());
    await _firestore.writeDocument(
      recordPath(userId, catId, record.id),
      stamped.toJson(),
    );
    AppLogger.i('MedicationRepository.update $userId/$catId/${record.id}');
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    await _firestore.deleteDocument(recordPath(userId, catId, recordId));
    AppLogger.i('MedicationRepository.delete $userId/$catId/$recordId');
  }
}
