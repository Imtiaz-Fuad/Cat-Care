import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_failure.dart';
import 'app_logger.dart';

/// Thin wrapper around `FirebaseFirestore`.
///
/// Responsibilities:
///  * Expose the singleton instance and a single entry point for tests
///    to override it (via [instanceOverride]).
///  * Translate `FirebaseException` into domain [AppFailure] so callers
///    never see raw SDK errors.
///
/// Repositories use this — providers/UI never reach this far down.
class FirestoreService {
  FirestoreService({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  /// Test seam: a single override instance that the constructor will
  /// pick up when no `instance` is passed. Set to `null` to revert.
  static FirebaseFirestore? instanceOverride;

  final FirebaseFirestore _firestore;
  FirebaseFirestore get instance {
    if (instanceOverride != null) return instanceOverride!;
    return _firestore;
  }

  /// The single root collection for public read-only content (food,
  /// safety, vaccine, etc.). Existence is asserted by Firestore rules.
  static const String contentCollection = 'content';

  /// Per-user private data root. Each user's documents live under
  /// `users/{uid}/...` and are enforced owner-only by security rules.
  static String userCollection(String uid) => 'users/$uid';

  /// Read a single document. Returns `null` when the document is missing.
  Future<Map<String, dynamic>?> readDocument(
    String path, {
    Source source = Source.serverAndCache,
  }) async {
    try {
      final snapshot = await instance.doc(path).get(
            GetOptions(source: source),
          );
      return snapshot.data();
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Firestore read failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  /// Write a single document. Pass [merge] = true to behave like `update`.
  Future<void> writeDocument(
    String path,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      await instance.doc(path).set(data, SetOptions(merge: merge));
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Firestore write failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  /// Delete a single document.
  Future<void> deleteDocument(String path) async {
    try {
      await instance.doc(path).delete();
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Firestore delete failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  /// Stream a single document. Yields `null` when the document is missing.
  Stream<Map<String, dynamic>?> watchDocument(String path) {
    return instance.doc(path).snapshots().map((snapshot) => snapshot.data());
  }

  /// Run a batch of writes atomically. The callback receives a
  /// [WriteBatch] and must enqueue every write before returning.
  Future<void> runBatch(
    Future<void> Function(WriteBatch batch) build,
  ) async {
    try {
      final batch = instance.batch();
      await build(batch);
      await batch.commit();
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Firestore batch failed', error, stack);
      throw _mapError(error, '<batch>');
    }
  }

  AppFailure _mapError(FirebaseException error, String path) {
    switch (error.code) {
      case 'permission-denied':
        return PermissionFailure(
          'You do not have permission to access $path.',
          code: error.code,
        );
      case 'not-found':
        return NotFoundFailure(
          'The requested document does not exist.',
          code: error.code,
        );
      case 'unavailable':
        return NetworkFailure(
          'Network is unavailable. Please check your connection.',
          code: error.code,
        );
      case 'cancelled':
      case 'deadline-exceeded':
        return NetworkFailure(
          'The request timed out. Please try again.',
          code: error.code,
        );
      default:
        return UnknownFailure(
          error.message ?? 'Firestore error on $path',
          code: error.code,
        );
    }
  }
}
