import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/weight_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/weights/{docId}`.
class WeightRepository {
  WeightRepository({
    required FirestoreService firestoreService,
    Uuid? uuid,
  })  : _firestore = firestoreService,
        _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  String newRecordId() => _uuid.v4();

  static String recordPath(String userId, String catId, String recordId) =>
      '${AppConstants.weightCollectionPath(userId, catId)}/$recordId';

  Stream<List<WeightEntry>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream<List<WeightEntry>>.value(const <WeightEntry>[]);
    }
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.catsSubcollection)
        .doc(catId)
        .collection(AppConstants.weightsSubcollection)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
              return WeightEntry.fromJson(<String, dynamic>{
                ...d.data(),
                'id': d.id,
              });
            }).toList(growable: false));
  }

  Future<String> add(String userId, String catId, WeightEntry entry) async {
    final String id = entry.id.isEmpty ? newRecordId() : entry.id;
    final WeightEntry stamped = entry.copyWith(id: id);
    await _firestore.writeDocument(
      recordPath(userId, catId, id),
      stamped.toJson(),
    );
    AppLogger.i('WeightRepository.add $userId/$catId/$id');
    return id;
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    await _firestore.deleteDocument(recordPath(userId, catId, recordId));
    AppLogger.i('WeightRepository.delete $userId/$catId/$recordId');
  }
}
