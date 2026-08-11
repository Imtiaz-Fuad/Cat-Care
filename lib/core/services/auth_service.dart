import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../errors/app_failure.dart';

/// Thin wrapper around `FirebaseAuth` translating Firebase exceptions
/// into domain [AppFailure] for the repository / provider layer.
///
/// Three identity modes are exposed:
///  * **Email/password** — [signInWithEmail], [signUpWithEmail],
///    [sendPasswordReset].
///  * **Google** — [signInWithGoogle].
///  * **Guest** — [signInAsGuest] (anonymous Firebase auth).
///
/// The active user is broadcast via [authStateChanges] and the current
/// snapshot via [currentUser]. Sign-out is [signOut].
///
/// The `google_sign_in` 7.x package is a singleton with explicit
/// `initialize()`. We defer the call to the first [signInWithGoogle]
/// so the rest of the app boots without the Google SDK being live.
class AuthService {
  AuthService({
    FirebaseAuth? instance,
    GoogleSignIn? googleSignIn,
  })  : _auth = instance ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Test seam.
  static FirebaseAuth? instanceOverride;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  FirebaseAuth get instance {
    if (instanceOverride != null) return instanceOverride!;
    return _auth;
  }

  /// Current Firebase user, or `null` when signed out.
  User? get currentUser => instance.currentUser;

  /// Stream of Firebase auth state changes. Yields the current user
  /// (or `null`) on every transition.
  Stream<User?> authStateChanges() => instance.authStateChanges();

  /// Sign in with email + password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Register a new email/password user.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Send a password-reset email. Does not require the user to be
  /// signed in. Throws [AuthFailure] when the address is unknown.
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Sign in with Google. Throws [AuthFailure] when the user cancels
  /// the consent sheet.
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        await _googleSignIn.initialize();
        _googleInitialized = true;
      }
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return await instance.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      throw AuthFailure(
        error.description ?? 'Google sign-in was cancelled.',
        code: error.code.name,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Sign in as an anonymous guest user. The returned uid is stable
  /// for the lifetime of the install; upgrade it via `MigrationService`.
  Future<UserCredential> signInAsGuest() async {
    try {
      return await instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Link the current anonymous account with an email/password
  /// credential. On success the anonymous uid is preserved (but the
  /// active user changes) — `MigrationService` uses this to copy
  /// guest data into the linked account before the anon user is
  /// deleted.
  ///
  /// Throws [AuthFailure] when there is no signed-in user, or when
  /// the credential is already linked to a different account
  /// (`credential-already-in-use`).
  Future<UserCredential> linkGuestWithEmail({
    required String email,
    required String password,
  }) async {
    final User? current = instance.currentUser;
    if (current == null) {
      throw const AuthFailure(
        'No guest session to upgrade.',
        code: 'no-current-user',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await current.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Delete the currently signed-in user (used by `MigrationService`
  /// to remove the now-empty anonymous account after upgrade).
  /// Throws [AuthFailure] when there is no current user.
  Future<void> deleteCurrentUser() async {
    final User? current = instance.currentUser;
    if (current == null) return;
    try {
      await current.delete();
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  /// Sign out the current user. No-op when already signed out.
  Future<void> signOut() async {
    try {
      // Always try to clear the Google session — calling it when the
      // user is not Google-authenticated is a documented no-op.
      if (_googleInitialized) {
        await _googleSignIn.signOut();
      }
      await instance.signOut();
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapGenericError(error);
    }
  }

  AuthFailure _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return const AuthFailure(
          'The email address is not valid.',
          code: 'invalid-email',
        );
      case 'user-disabled':
        return const AuthFailure(
          'This account has been disabled.',
          code: 'user-disabled',
        );
      case 'user-not-found':
        return const AuthFailure(
          'No account matches that email.',
          code: 'user-not-found',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFailure(
          'The email or password is incorrect.',
          code: 'wrong-password',
        );
      case 'email-already-in-use':
        return const AuthFailure(
          'An account already exists for that email.',
          code: 'email-already-in-use',
        );
      case 'weak-password':
        return const AuthFailure(
          'The password is too weak. Use at least six characters.',
          code: 'weak-password',
        );
      case 'too-many-requests':
        return const AuthFailure(
          'Too many attempts. Please try again later.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const AuthFailure(
          'Network is unavailable. Please check your connection.',
          code: 'network-request-failed',
        );
      case 'operation-not-allowed':
        return const AuthFailure(
          'This sign-in method is not enabled.',
          code: 'operation-not-allowed',
        );
      default:
        return AuthFailure(
          error.message ?? 'Authentication failed.',
          code: error.code,
        );
    }
  }

  AuthFailure _mapGenericError(FirebaseException error) {
    return AuthFailure(
      error.message ?? 'Authentication failed.',
      code: error.code,
    );
  }
}
