import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/errors/app_failure.dart';
import '../../../core/services/auth_service.dart';
import '../models/auth_state.dart';
import '../models/user_profile.dart';

/// Repository that translates `AuthService` events into the sealed
/// [AuthState] the UI consumes.
///
/// All sign-in methods return the resulting [UserProfile] so the
/// caller can navigate based on the new state without subscribing.
/// All errors surface as [AppFailure] subclasses (mostly
/// [AuthFailure]).
class AuthRepository {
  AuthRepository({required AuthService service})
      // ignore: prefer_initializing_formals
      : _service = service,
        _controller = StreamController<AuthState>.broadcast() {
    _subscribe();
  }

  final AuthService _service;
  final StreamController<AuthState> _controller;
  StreamSubscription<fb.User?>? _authSub;

  /// Current snapshot, or [AuthStateUnknown] until Firebase reports.
  AuthState get current => _current ?? const AuthStateUnknown();
  AuthState? _current;

  /// Live stream of [AuthState]. Replays the current value to new
  /// listeners on subscription (broadcast-as-state-stream).
  Stream<AuthState> watch() async* {
    yield current;
    yield* _controller.stream;
  }

  /// Sign in with email + password.
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _service.signInWithEmail(
        email: email,
        password: password,
      );
      return _toProfile(credential.user!);
    } on AppFailure {
      rethrow;
    }
  }

  /// Register a new email/password account.
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _service.signUpWithEmail(
        email: email,
        password: password,
      );
      return _toProfile(credential.user!);
    } on AppFailure {
      rethrow;
    }
  }

  /// Send a password-reset email. Errors when the address is
  /// unknown or malformed surface as [AuthFailure].
  Future<void> sendPasswordReset({required String email}) {
    return _service.sendPasswordReset(email: email);
  }

  /// Sign in with Google. Throws [AuthFailure] if the user cancels.
  Future<UserProfile> signInWithGoogle() async {
    try {
      final credential = await _service.signInWithGoogle();
      return _toProfile(credential.user!);
    } on AppFailure {
      rethrow;
    }
  }

  /// Sign in as an anonymous guest. Returns a profile that the UI
  /// treats as [AuthStateGuest].
  Future<UserProfile> signInAsGuest() async {
    try {
      final credential = await _service.signInAsGuest();
      return _toProfile(credential.user!);
    } on AppFailure {
      rethrow;
    }
  }

  /// Sign out the current user. After the call returns the stream
  /// emits [AuthStateUnauthenticated].
  Future<void> signOut() => _service.signOut();

  /// Release the underlying subscription + stream. Call from
  /// `dispose()` on the owning provider or in tests.
  Future<void> dispose() async {
    await _authSub?.cancel();
    await _controller.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _subscribe() {
    _authSub = _service.authStateChanges().listen(
      (user) {
        final next = _toAuthState(user);
        _current = next;
        if (!_controller.isClosed) _controller.add(next);
      },
      onError: (Object error, StackTrace stack) {
        // We don't emit failure states on the auth stream — Firebase
        // surface errors via the per-call methods (signInWith*).
        // Silently drop stream errors.
      },
    );
  }

  AuthState _toAuthState(fb.User? user) {
    if (user == null) return const AuthStateUnauthenticated();
    final profile = _toProfile(user);
    return profile.isAnonymous
        ? AuthStateGuest(profile: profile)
        : AuthStateAuthenticated(profile: profile);
  }

  UserProfile _toProfile(fb.User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      isAnonymous: user.isAnonymous,
      isEmailVerified: user.emailVerified,
      providerIds: user.providerData
          .map((info) => info.providerId)
          .toList(growable: false),
      creationTime: user.metadata.creationTime,
      lastSignInTime: user.metadata.lastSignInTime,
    );
  }
}