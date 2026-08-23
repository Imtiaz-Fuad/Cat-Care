import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/health_record.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';

/// Firestore + Storage bridge for `users/{uid}/cats/{catId}/health/{recordId}`.
///
/// All persistence lives behind [FirestoreService] and [StorageService] so
/// tests can substitute in-memory fakes; this repository never touches
/// `FirebaseFirestore` or `FirebaseStorage` directly.
class HealthRepository {
  HealthRepository({
    required FirestoreService firestoreService,
    required StorageService storageService,
    Uuid? uuid,
  })  : _firestore = firestoreService,
        _storage = storageService,
        _uuid = uuid ?? const Uuid();

  final FirestoreService _firestore;
  final StorageService _storage;
  final Uuid _uuid;

  /// Generate a new document id. Exposed so tests can pin it.
  String newRecordId() => _uuid.v4();

  /// Static path helper for testability.
  static String recordPath(String userId, String catId, String recordId) =>
      '${AppConstants.healthCollectionPath(userId, catId)}/$recordId';

  /// Stream every health record for the cat, newest first.
  Stream<List<HealthRecord>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream<List<HealthRecord>>.value(const <HealthRecord>[]);
    }
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.catsSubcollection)
        .doc(catId)
        .collection(AppConstants.healthSubcollection)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              final Map<String, dynamic> data = <String, dynamic>{
                ...d.data(),
                'id': d.id,
              };
              return HealthRecord.fromJson(data);
            }).toList(growable: false));
  }

  /// Stream a single record so detail screens stay live across devices.
  Stream<HealthRecord?> watchOne(String userId, String catId, String recordId) {
    return _firestore
        .watchDocument(recordPath(userId, catId, recordId))
        .map((Map<String, dynamic>? data) {
      if (data == null) return null;
      return HealthRecord.fromJson(<String, dynamic>{
        ...data,
        'id': recordId,
      });
    });
  }

  Future<String> add(String userId, String catId, HealthRecord record) async {
    final String id = record.id.isEmpty ? newRecordId() : record.id;
    final HealthRecord withId = record.copyWith(
      id: id,
      createdAt: record.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _firestore.writeDocument(
      recordPath(userId, catId, id),
      withId.toJson(),
    );
    AppLogger.i('HealthRepository.add $userId/$catId/$id');
    return id;
  }

  Future<void> update(
    String userId,
    String catId,
    HealthRecord record,
  ) async {
    if (record.id.isEmpty) {
      throw const ValidationFailure(
        'Cannot update a record without an id.',
        code: 'health-missing-id',
      );
    }
    final HealthRecord stamped = record.copyWith(updatedAt: DateTime.now());
    await _firestore.writeDocument(
      recordPath(userId, catId, record.id),
      stamped.toJson(),
    );
    AppLogger.i('HealthRepository.update $userId/$catId/${record.id}');
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    await _firestore.deleteDocument(recordPath(userId, catId, recordId));
    AppLogger.i('HealthRepository.delete $userId/$catId/$recordId');
  }

  /// Uploads an attachment (image or PDF) under the record's folder so it
  /// can be deleted alongside the record without leaking sibling files.
  Future<String> uploadAttachment({
    required String userId,
    required String catId,
    required String recordId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final String path = AppConstants.healthAttachmentStoragePath(
      userId: userId,
      catId: catId,
      recordId: recordId,
      fileName: fileName,
    );
    final String url = await _storage.uploadBytes(
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
    AppLogger.i(
        'HealthRepository.uploadAttachment $userId/$catId/$recordId/$fileName');
    return url;
  }
}
