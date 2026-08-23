import 'dart:typed_data';

import 'package:cat_care/core/constants/app_constants.dart';
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/health_record.dart';
import 'package:cat_care/core/services/firestore_service.dart';
import 'package:cat_care/core/services/logger.dart';
import 'package:cat_care/core/services/storage_service.dart';

/// Firestore + Storage bridge for `users/{uid}/cats/{catId}/health/{recordId}`.
///
/// All persistence lives behind [FirestoreService] and [StorageService] so
/// tests can substitute in-memory fakes; this repository never touches
/// `FirebaseFirestore` or `FirebaseStorage` directly.
class HealthRepository {
  HealthRepository({
    FirestoreService? firestore,
    StorageService? storage,
    AppLogger? logger,
  })  : _firestore = firestore ?? FirestoreService(),
        _storage = storage ?? StorageService(),
        _log = logger ?? AppLogger();

  final FirestoreService _firestore;
  final StorageService _storage;
  final AppLogger _log;

  /// Streams every health record for the cat, newest first.
  Stream<List<HealthRecord>> watchForCat(String userId, String catId) {
    if (userId.isEmpty || catId.isEmpty) {
      return Stream.value(const <HealthRecord>[]);
    }
    final path =
        AppConstants.healthCollectionPath(userId, catId);
    return _firestore
        .streamCollection(
      path,
      orderBy: 'visitDate',
      descending: true,
    )
        .map((docs) => docs
            .map((doc) {
              final data = Map<String, dynamic>.from(doc.data as Map);
              data['id'] = doc.id;
              return HealthRecord.fromJson(data);
            })
            .toList())
        .handleError((Object error, StackTrace stack) {
      _log.e('HealthRepository.watchForCat failed', error: error, stack: stack);
      throw AppFailure.fromException(error);
    });
  }

  /// Streams a single record so detail screens stay live across devices.
  Stream<HealthRecord?> watchOne(String userId, String catId, String recordId) {
    final path =
        '${AppConstants.healthCollectionPath(userId, catId)}/$recordId';
    return _firestore.streamDocument(path).map((doc) {
      if (doc == null || doc.data == null) return null;
      final data = Map<String, dynamic>.from(doc.data as Map);
      data['id'] = doc.id;
      return HealthRecord.fromJson(data);
    }).handleError((Object error, StackTrace stack) {
      _log.e('HealthRepository.watchOne failed', error: error, stack: stack);
      throw AppFailure.fromException(error);
    });
  }

  Future<String> add(String userId, String catId, HealthRecord record) async {
    try {
      final docId = record.id.isEmpty ? null : record.id;
      final json = record.toJson()..remove('id');
      final newId = await _firestore.addDocument(
        AppConstants.healthCollectionPath(userId, catId),
        json,
        documentId: docId,
      );
      _log.i('HealthRepository.add -> $newId');
      return newId;
    } catch (e, st) {
      _log.e('HealthRepository.add failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> update(
    String userId,
    String catId,
    HealthRecord record,
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
        '${AppConstants.healthCollectionPath(userId, catId)}/${record.id}',
        json,
      );
      _log.i('HealthRepository.update -> ${record.id}');
    } catch (e, st) {
      _log.e('HealthRepository.update failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> delete(String userId, String catId, String recordId) async {
    try {
      await _firestore.deleteDocument(
        '${AppConstants.healthCollectionPath(userId, catId)}/$recordId',
      );
      _log.i('HealthRepository.delete -> $recordId');
    } catch (e, st) {
      _log.e('HealthRepository.delete failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
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
    try {
      final path = AppConstants.healthAttachmentStoragePath(
        userId: userId,
        catId: catId,
        recordId: recordId,
        fileName: fileName,
      );
      final url = await _storage.uploadFile(path, bytes, contentType);
      _log.i('HealthRepository.uploadAttachment -> $url');
      return url;
    } catch (e, st) {
      _log.e('HealthRepository.uploadAttachment failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }

  Future<void> deleteAttachment(String storageUrl) async {
    try {
      await _storage.deleteFile(storageUrl);
      _log.i('HealthRepository.deleteAttachment -> $storageUrl');
    } catch (e, st) {
      _log.e('HealthRepository.deleteAttachment failed', error: e, stack: st);
      throw AppFailure.fromException(e);
    }
  }
}
