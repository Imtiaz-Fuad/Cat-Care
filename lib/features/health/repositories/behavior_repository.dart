import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/behavior_log.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';

/// Firestore bridge for `users/{uid}/cats/{catId}/behavior/{docId}`.
class BehaviorRepository {
  BehaviorRepository({required FirestoreService firestoreService, Uuid? uuid})
    : _firestore = firestoreService,
      _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final Uuid _uuid;

  String newRecordId() => _uuid.v4();

  static String recordPath(String userId, String catId, String recordId) =>
      '${AppConstants.behaviorCollectionPath(userId, catId)}/$recordId';

  Stream<List<BehaviorLog>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream<List<BehaviorLog>>.value(const <BehaviorLog>[]);
    }
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.catsSubcollection)
        .doc(catId)
        .collection(AppConstants.behaviorsSubcollection)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                return BehaviorLog.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                });
              })
              .toList(growable: false),
        );
  }

  Future<String> add(String userId, String catId, BehaviorLog record) async {
    final String id = record.id.isEmpty ? newRecordId() : record.id;
    final BehaviorLog stamped = record.copyWith(id: id);
    await _firestore.writeDocument(
      recordPath(userId, catId, id),
      stamped.toJson(),
    );
    AppLogger.i('BehaviorRepository.add $userId/$catId/$id');
    return id;
  }

  Future<void> update(String userId, String catId, BehaviorLog record) async {
    if (record.id.isEmpty) {
      throw const ValidationFailure(
        'Cannot update a behavior log without an id.',
        code: 'behavior-missing-id',
      );
    }
    await _firestore.writeDocument(
      recordPath(userId, catId, record.id),
      record.toJson(),
    );
    AppLogger.i('BehaviorRepository.update $userId/$catId/${record.id}');
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    await _firestore.deleteDocument(recordPath(userId, catId, recordId));
    AppLogger.i('BehaviorRepository.delete $userId/$catId/$recordId');
  }
}
