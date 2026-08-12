import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/cat_draft.dart';

/// CRUD + photo-upload façade over Firestore and Storage for
/// `users/{uid}/cats/{catId}`.
///
/// The repository owns the path shape, IDs, and timestamps; providers
/// call into it without ever seeing `FirebaseFirestore`.
class CatRepository {
  CatRepository({
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
  String newCatId() => _uuid.v4();

  /// Path of a cat document under a given user.
  static String catDocPath(String ownerId, String catId) =>
      '${AppConstants.usersCollection}/$ownerId/'
      '${AppConstants.catsSubcollection}/$catId';

  /// Stream every cat belonging to [ownerId], newest first.
  ///
  /// Implementation note: this uses the underlying `FirebaseFirestore`
  /// collection reference (still inside the data layer — widgets never
  /// see this). Firestore offline persistence configured at app start
  /// means the same stream re-emits the cached list on cold start.
  Stream<List<CatProfile>> watchCats(String ownerId) {
    return _firestore.instance
        .collection(AppConstants.usersCollection)
        .doc(ownerId)
        .collection(AppConstants.catsSubcollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CatProfile.fromJson(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                  'ownerId': ownerId,
                }))
            .toList(growable: false));
  }

  /// Stream a single cat. Emits `null` if the document was deleted.
  Stream<CatProfile?> watchCat({
    required String ownerId,
    required String catId,
  }) {
    return _firestore
        .watchDocument(catDocPath(ownerId, catId))
        .map((data) {
      if (data == null) return null;
      return CatProfile.fromJson(<String, dynamic>{
        ...data,
        'id': catId,
        'ownerId': ownerId,
      });
    });
  }

  /// One-shot read of a single cat. Useful in onboarding when the
  /// caller knows the id but the stream subscription would be wasted.
  Future<CatProfile?> getCat({
    required String ownerId,
    required String catId,
  }) async {
    final Map<String, dynamic>? data =
        await _firestore.readDocument(catDocPath(ownerId, catId));
    if (data == null) return null;
    return CatProfile.fromJson(<String, dynamic>{
      ...data,
      'id': catId,
      'ownerId': ownerId,
    });
  }

  /// Persist a freshly drafted cat. The repository assigns `id` and
  /// timestamps and writes the document under `users/{uid}/cats/{id}`.
  Future<CatProfile> createCat({
    required String ownerId,
    required CatDraft draft,
  }) async {
    if (!draft.isValid) {
      throw const ValidationFailure(
        'Cat name is required.',
        code: 'missing-name',
      );
    }
    final String id = newCatId();
    final CatProfile profile = draft.toProfile(id: id, ownerId: ownerId);
    await _firestore.writeDocument(
      catDocPath(ownerId, id),
      profile.toJson(),
    );
    AppLogger.i('CatRepository.createCat $ownerId/$id (${profile.name})');
    return profile;
  }

  /// Patch an existing cat. Pass any subset of fields; omitted fields
  /// are left untouched (uses `set(..., merge: true)`).
  ///
  /// To explicitly *clear* a nullable field (set it back to null),
  /// pass the [clearField] sentinel via the corresponding named arg
  /// wrapped in a [Clear]. See [updateBirthday] / [updateColor] for
  /// helpers.
  Future<CatProfile> updateCat({
    required String ownerId,
    required String catId,
    CatDraft? draft,
    Object? name = _sentinel,
    Object? birthday = _sentinel,
    Object? sex = _sentinel,
    Object? breed = _sentinel,
    bool? neutered,
    bool? indoor,
    Object? color = _sentinel,
    Object? weightKg = _sentinel,
    List<String>? allergies,
    List<String>? diseases,
    List<String>? medications,
    Object? notes = _sentinel,
    Object? photoUrl = _sentinel,
    Object? themeAccentHex = _sentinel,
    List<String>? priorities,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (draft != null) {
      final CatProfile next = draft.toProfile(
        id: catId,
        ownerId: ownerId,
        now: DateTime.now(),
      );
      patch.addAll(next.toJson());
    } else {
      if (!identical(name, _sentinel)) {
        patch['name'] = (name as String?)?.trim() ?? (name as String);
      }
      if (!identical(birthday, _sentinel)) {
        patch['birthday'] = (birthday as DateTime?)?.toIso8601String();
      }
      if (!identical(sex, _sentinel)) patch['sex'] = sex;
      if (!identical(breed, _sentinel)) patch['breed'] = breed;
      if (neutered != null) patch['neutered'] = neutered;
      if (indoor != null) patch['indoor'] = indoor;
      if (!identical(color, _sentinel)) patch['color'] = color;
      if (!identical(weightKg, _sentinel)) {
        patch['weightKg'] = weightKg;
      }
      if (allergies != null) patch['allergies'] = allergies;
      if (diseases != null) patch['diseases'] = diseases;
      if (medications != null) patch['medications'] = medications;
      if (!identical(notes, _sentinel)) patch['notes'] = notes;
      if (!identical(photoUrl, _sentinel)) patch['photoUrl'] = photoUrl;
      if (!identical(themeAccentHex, _sentinel)) {
        patch['themeAccentHex'] = themeAccentHex;
      }
      if (priorities != null) patch['priorities'] = priorities;
    }

    await _firestore.writeDocument(
      catDocPath(ownerId, catId),
      patch,
      merge: true,
    );
    final CatProfile? fresh = await getCat(ownerId: ownerId, catId: catId);
    if (fresh == null) {
      throw const NotFoundFailure(
        'Cat disappeared during update.',
        code: 'cat-missing',
      );
    }
    AppLogger.i('CatRepository.updateCat $ownerId/$catId');
    return fresh;
  }

  /// Permanently delete a cat. The cat photo is also removed from
  /// Storage when [photoUrl] is supplied (best-effort; missing objects
  /// are silently ignored by [StorageService.delete]).
  Future<void> deleteCat({
    required String ownerId,
    required String catId,
    String? photoUrl,
  }) async {
    await _firestore.deleteDocument(catDocPath(ownerId, catId));
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        await _storage.delete(_photoStoragePath(photoUrl));
      } on AppFailure catch (failure) {
        // A stray Storage delete failure must not block the Firestore
        // deletion — log and continue.
        AppLogger.w(
          'CatRepository.deleteCat: photo cleanup failed: $failure',
        );
      }
    }
    AppLogger.i('CatRepository.deleteCat $ownerId/$catId');
  }

  /// Upload a cat photo to Storage and return its download URL. The
  /// path is owner-scoped so security rules can enforce that only the
  /// owner writes to their own bucket prefix.
  Future<String> uploadCatPhoto({
    required String ownerId,
    required String catId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final String path = 'users/$ownerId/cats/$catId/photo.jpg';
    final String url = await _storage.uploadBytes(
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
    AppLogger.i('CatRepository.uploadCatPhoto $ownerId/$catId');
    return url;
  }

  /// Compute the Storage object path for a download URL.
  ///
  /// Storage URLs returned by `getDownloadURL` look like
  /// `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?…`.
  /// We only need the encoded path tail to delete the right object;
  /// unknown shapes fall through to the raw input so the caller's
  /// best-effort cleanup still happens.
  String _photoStoragePath(String downloadUrl) {
    try {
      final Uri uri = Uri.parse(downloadUrl);
      final List<String> segments = uri.pathSegments;
      final int oIdx = segments.indexOf('o');
      if (oIdx >= 0 && oIdx + 1 < segments.length) {
        return Uri.decodeComponent(segments.sublist(oIdx + 1).join('/'));
      }
    } catch (_) {
      // Fall through.
    }
    return downloadUrl;
  }
}

/// Marker value used as the default parameter for nullable fields in
/// [CatRepository.updateCat] so callers can distinguish "don't touch
/// the field" from "set the field to null".
const Object _sentinel = Object();
