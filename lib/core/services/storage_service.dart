import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_failure.dart';
import 'app_logger.dart';

/// Thin wrapper around `FirebaseStorage`.
///
/// Repositories use this to upload cat photos, profile avatars, and any
/// other user-supplied binary blobs. The bucket name is read from the
/// active [FirebaseApp.options]; permissions are enforced by Storage
/// security rules, not client-side checks.
class StorageService {
  StorageService({FirebaseStorage? instance})
      : _storage = instance ?? FirebaseStorage.instance;

  /// Test seam.
  static FirebaseStorage? instanceOverride;

  final FirebaseStorage _storage;
  FirebaseStorage get instance {
    if (instanceOverride != null) return instanceOverride!;
    return _storage;
  }

  /// Resolve a full storage reference from a public `gs://...` or
  /// `https://...` URL.
  Reference refForUrl(String url) => instance.refFromURL(url);

  /// Resolve a storage reference by path (relative to the bucket root).
  Reference ref(String path) => instance.ref(path);

  /// Upload bytes to the given path and return the resulting download
  /// URL (token-bearing) once the upload completes.
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
    Map<String, String>? metadata,
  }) async {
    try {
      final ref = instance.ref(path);
      final task = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: metadata,
        ),
      );
      AppLogger.i('Storage upload ok: $path (${bytes.length} bytes)');
      return await task.ref.getDownloadURL();
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Storage upload failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  /// Delete the object at [path]. Missing objects are treated as success.
  Future<void> delete(String path) async {
    try {
      await instance.ref(path).delete();
    } on FirebaseException catch (error, stack) {
      // The Storage SDK returns 'object-not-found' when the path is
      // already gone — surface that as a no-op so retries are safe.
      if (error.code == 'object-not-found') {
        AppLogger.w('Storage delete no-op (already gone): $path');
        return;
      }
      AppLogger.e('Storage delete failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  /// Resolve the current download URL for [path] without uploading.
  Future<String> downloadUrl(String path) async {
    try {
      return await instance.ref(path).getDownloadURL();
    } on FirebaseException catch (error, stack) {
      AppLogger.e('Storage downloadUrl failed: $path', error, stack);
      throw _mapError(error, path);
    }
  }

  AppFailure _mapError(FirebaseException error, String path) {
    switch (error.code) {
      case 'unauthorized':
      case 'permission-denied':
        return PermissionFailure(
          'You do not have permission to access this file.',
          code: error.code,
        );
      case 'object-not-found':
        return NotFoundFailure(
          'The requested file does not exist.',
          code: error.code,
        );
      case 'canceled':
      case 'unknown':
        return NetworkFailure(
          'Storage request did not complete. Please try again.',
          code: error.code,
        );
      default:
        return UnknownFailure(
          error.message ?? 'Storage error on $path',
          code: error.code,
        );
    }
  }
}