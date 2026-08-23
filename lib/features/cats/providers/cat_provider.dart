import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/models/user_profile.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/cat_draft.dart';
import '../repositories/cat_repository.dart';

/// State machine for the "cats" feature surface.
///
/// The provider owns four pieces of state:
///   * [_cats] — the current user's cats, streamed from Firestore.
///   * [_activeCatId] — id of the cat currently focused in Home /
///     Routine / Nutrition / Profile. Persisted to SharedPreferences
///     so the choice survives relaunches even before the Firestore
///     stream emits its first value.
///   * [_busy] — UX flag for the onboarding + edit forms.
///   * [_lastError] — surfaces repository failures to the UI.
///
/// Wiring:
///   * `CatProvider` listens to [AuthProvider] so it swaps streams
///     automatically when the user signs in / out / swaps identities.
///   * All repository errors are caught and re-surfaced through
///     [lastError]; the UI's "retry" button simply re-invokes the
///     same action.
class CatProvider extends ChangeNotifier {
  CatProvider._({
    required CatRepository repository,
    required AuthProvider authProvider,
    required SharedPreferences? prefs,
    required String? initialActiveCatId,
    // Field-name collisions with the parameter names below would
    // leak the singletons past the constructor; we want explicit
    // assignments so the static factory in [create] can pre-resolve
    // the prefs Future without exposing that pattern to callers.
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // ignore: prefer_initializing_formals
       _auth = authProvider,
       // ignore: prefer_initializing_formals
       _prefs = prefs,
       // Boot-time fallback so Home renders the right cat before the
       // Firestore stream emits. The id is re-validated against the
       // list in [_handleAuthChange].
       _activeCatId = initialActiveCatId {
    _auth.addListener(_handleAuthChange);
    _authListeners.add(_handleAuthChange);
    if (_activeCatId != null && _activeCatId!.isEmpty) {
      _activeCatId = null;
    }
    _handleAuthChange();
  }

  final CatRepository _repository;
  final AuthProvider _auth;
  SharedPreferences? _prefs;

  StreamSubscription<List<CatProfile>>? _catsSub;
  // Plain ChangeNotifier.addListener doesn't return an unsubscribe
  // token, so we keep a sentinel and unsubscribe by clearing it in
  // [dispose].
  final List<VoidCallback> _authListeners = <VoidCallback>[];

  List<CatProfile> _cats = const <CatProfile>[];
  bool _streamReady = false;

  String? _activeCatId;
  bool _busy = false;
  bool _disposed = false;
  AppFailure? _lastError;

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  /// Unmodifiable list of every cat the current user owns.
  List<CatProfile> get cats => List<CatProfile>.unmodifiable(_cats);

  /// True once the underlying stream has emitted at least one value
  /// (used by onboarding to decide whether to show a "no cats yet"
  /// screen vs. a spinner).
  bool get hasLoaded => _streamReady;

  /// The currently-focused cat, or `null` when there are none yet.
  CatProfile? get activeCat {
    if (_cats.isEmpty) return null;
    if (_activeCatId != null) {
      for (final CatProfile c in _cats) {
        if (c.id == _activeCatId) return c;
      }
    }
    // Active cat id was forgotten (deleted by another device, signed
    // out + signed in as another user, etc.) — fall back to the
    // first available.
    return _cats.first;
  }

  /// The id that the UI should use when highlighting which cat is
  /// active (separate from [activeCat] which returns the object).
  String? get activeCatId {
    if (_activeCatId == null) return null;
    for (final CatProfile c in _cats) {
      if (c.id == _activeCatId) return _activeCatId;
    }
    return null;
  }

  /// Convenience: the signed-in user's profile (or `null` when
  /// signed out). Exposed so feature providers can scope writes
  /// without importing [AuthProvider] directly.
  UserProfile? get profile => _auth.profile;

  /// Whether a long-running repository call (create / upload /
  /// delete) is in flight.
  bool get isBusy => _busy;

  /// Most recent repository failure. Cleared automatically on the
  /// next call.
  AppFailure? get lastError => _lastError;

  /// Make [catId] the active one. Persists the choice so the next
  /// cold-start lands on the same cat.
  Future<void> setActiveCat(String catId) async {
    if (_activeCatId == catId) return;
    _activeCatId = catId;
    await _persistActiveCat(catId);
    notifyListeners();
  }

  /// Create a brand-new cat from an onboarding draft.
  Future<CatProfile?> createCat(CatDraft draft) async {
    final String? uid = _uidForWrite();
    if (uid == null) return null;
    CatProfile? created;
    AppFailure? failure;
    try {
      _setBusy(true);
      clearError();
      created = await _repository.createCat(ownerId: uid, draft: draft);
      await setActiveCat(created.id);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('CatProvider action failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'cats-unknown');
      AppLogger.e('CatProvider: unexpected error', error, stack);
    } finally {
      if (failure != null) _lastError = failure;
      if (!_disposed) _setBusy(false);
    }
    return failure == null ? created : null;
  }

  /// Apply a draft over an existing cat.
  Future<void> updateCat({
    required String catId,
    required CatDraft draft,
  }) async {
    final String? uid = _uidForWrite();
    if (uid == null) return;
    _runGuarded(
      () async =>
          _repository.updateCat(ownerId: uid, catId: catId, draft: draft),
    );
  }

  /// Delete a cat, with optional photo cleanup.
  Future<void> deleteCat({required String catId, String? photoUrl}) async {
    final String? uid = _uidForWrite();
    if (uid == null) return;
    _runGuarded(() async {
      await _repository.deleteCat(
        ownerId: uid,
        catId: catId,
        photoUrl: photoUrl,
      );
      if (_activeCatId == catId) {
        _activeCatId = null;
        await _persistActiveCat(null);
      }
    });
  }

  /// Upload a photo and attach the resulting URL to the cat
  /// document. Returns the download URL on success, `null` on
  /// failure.
  Future<String?> uploadPhoto({
    required String catId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final String? uid = _uidForWrite();
    if (uid == null) return null;
    String? url;
    _runGuarded(() async {
      url = await _repository.uploadCatPhoto(
        ownerId: uid,
        catId: catId,
        bytes: bytes,
        contentType: contentType,
      );
      if (url != null) {
        await _repository.updateCat(ownerId: uid, catId: catId, photoUrl: url);
      }
    });
    return url;
  }

  /// Clear any surfaced error.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Build a `CatProvider` that hands back its own dependencies once
  /// both [prefs] and the auth state are stable. Used by `main.dart`.
  static Future<CatProvider> create({
    required CatRepository repository,
    required AuthProvider authProvider,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return CatProvider._(
      repository: repository,
      authProvider: authProvider,
      prefs: prefs,
      initialActiveCatId: prefs.getString(AppConstants.activeCatIdKey),
    );
  }

  void _handleAuthChange() {
    final String? uid = _auth.profile?.uid;
    if (uid == null) {
      // Signed out — drop everything. Flip [_streamReady] true so the
      // UI's loading branch exits and shows the sign-in / no-active-cat
      // empty state instead of spinning forever while auth resolves.
      _catsSub?.cancel();
      _catsSub = null;
      _cats = const <CatProfile>[];
      _streamReady = true;
      _activeCatId = null;
      notifyListeners();
      return;
    }
    _catsSub?.cancel();
    _catsSub = _repository
        .watchCats(uid)
        .listen(
          (List<CatProfile> next) {
            _cats = next;
            _streamReady = true;

            // Validate the active id against the new list. If the
            // active cat was deleted, fall back to the first available.
            bool activePresent = false;
            for (final CatProfile c in next) {
              if (c.id == _activeCatId) {
                activePresent = true;
                break;
              }
            }
            if (!activePresent) {
              _activeCatId = next.isEmpty ? null : next.first.id;
              unawaited(_persistActiveCat(_activeCatId));
            }
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            AppLogger.e('CatProvider: stream error', error, stack);
            _lastError = error is AppFailure
                ? error
                : UnknownFailure(error.toString(), code: 'cats-stream-error');
            // Mark the stream "ready" so the UI exits its loading
            // branch and shows the error / empty state instead of
            // spinning forever.
            _streamReady = true;
            notifyListeners();
          },
        );
  }

  Future<void> _persistActiveCat(String? catId) async {
    try {
      final SharedPreferences prefs =
          _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      if (catId == null) {
        await prefs.remove(AppConstants.activeCatIdKey);
      } else {
        await prefs.setString(AppConstants.activeCatIdKey, catId);
      }
    } catch (error, stack) {
      AppLogger.w('CatProvider: prefs persist failed', error, stack);
    }
  }

  String? _uidForWrite() {
    final String? uid = _auth.profile?.uid;
    if (uid == null) {
      _lastError = const AuthFailure(
        'Sign in before managing cats.',
        code: 'no-current-user',
      );
      notifyListeners();
    }
    return uid;
  }

  void _runGuarded(Future<void> Function() action) {
    if (_disposed) return;
    _setBusy(true);
    clearError();
    () async {
      try {
        await action();
      } on AppFailure catch (failure) {
        _lastError = failure;
        AppLogger.w('CatProvider action failed: $failure');
      } catch (error, stack) {
        _lastError = UnknownFailure(error.toString(), code: 'cats-unknown');
        AppLogger.e('CatProvider: unexpected error', error, stack);
      } finally {
        if (!_disposed) _setBusy(false);
      }
    }();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _catsSub?.cancel();
    for (final VoidCallback listener in _authListeners) {
      _auth.removeListener(listener);
    }
    _authListeners.clear();
    super.dispose();
  }
}
