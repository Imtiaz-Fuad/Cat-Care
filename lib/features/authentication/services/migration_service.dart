import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/errors/app_failure.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/auth_service.dart';

/// Orchestrates "guest → real account" upgrade.
///
/// Two scenarios are supported:
///   * [upgradeGuestWithEmail] — anonymous user supplies email +
///     password. Firebase's `linkWithCredential` upgrades the user
///     in place (same uid), so existing Firestore documents under
///     `users/{anonUid}/` remain reachable. No data copy needed.
///   * [upgradeGuestWithGoogle] — same outcome via the Google SDK.
///
/// Both methods are no-ops (throwing [AuthFailure]) when the current
/// user is not anonymous, so the UI can call them without first
/// checking state.
class MigrationService {
  MigrationService({required AuthService authService})
      // ignore: prefer_initializing_formals
      : _authService = authService;

  final AuthService _authService;

  /// Result of a successful upgrade — the freshly upgraded
  /// [UserProfile] (use it to refresh the `AuthProvider`).
  ///
  /// Throws [AuthFailure] when the user is not signed in as a guest,
  /// or when Firebase rejects the link (email already in use,
  /// invalid credential, network failure, etc.).
  Future<fb.User> upgradeGuestWithEmail({
    required String email,
    required String password,
  }) async {
    _assertGuest();
    try {
      final credential = await _authService.linkGuestWithEmail(
        email: email,
        password: password,
      );
      AppLogger.i(
        'MigrationService: linked guest ${credential.user?.uid} '
        'with email account',
      );
      return credential.user!;
    } on AppFailure catch (failure) {
      AppLogger.w('MigrationService.email upgrade failed: $failure');
      rethrow;
    }
  }

  /// Variant for the Google Sign-In flow. The current anonymous
  /// account is linked with the Google OAuth credential produced
  /// by a fresh Google sign-in attempt.
  Future<fb.User> upgradeGuestWithGoogle() async {
    _assertGuest();
    try {
      // We piggy-back on AuthService.signInWithGoogle(), which uses
      // the current `GoogleSignIn.instance` to run the consent flow
      // and then signs in. After this call the user is no longer
      // anonymous — same uid, real provider attached.
      final credential = await _authService.signInWithGoogle();
      AppLogger.i(
        'MigrationService.google upgrade linked '
        '${credential.user?.uid} with google.com',
      );
      return credential.user!;
    } on AppFailure catch (failure) {
      AppLogger.w('MigrationService.google upgrade failed: $failure');
      rethrow;
    }
  }

  void _assertGuest() {
    final fb.User? current = _authService.currentUser;
    if (current == null) {
      throw const AuthFailure(
        'No signed-in user to upgrade.',
        code: 'no-current-user',
      );
    }
    if (!current.isAnonymous) {
      throw const AuthFailure(
        'Already signed in with a real account.',
        code: 'not-a-guest',
      );
    }
  }
}