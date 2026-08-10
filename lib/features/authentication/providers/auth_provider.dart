import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/app_logger.dart';
import '../models/auth_state.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

/// `ChangeNotifier` that wraps [AuthRepository] for the UI.
///
/// Exposes:
///  * [state] — the latest [AuthState].
///  * [isBusy] — true while a sign-in / sign-up / sign-out call is
///    in flight (so the `LoginScreen` can show a spinner and disable
///    buttons).
///  * [lastError] — the most recent [AppFailure] (cleared on every
///    new attempt).
///  * [clearError] — dismiss the banner manually.
///
/// Auth lifecycle (sign-in / sign-out) returns the resulting
/// [AuthState] so callers can navigate immediately. They should NOT
/// rely on the listener callback for the navigation trigger — the
/// state may not yet have flipped when `signInWithX` resolves.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository repository})
      // ignore: prefer_initializing_formals
      : _repository = repository {
    _subscribe();
  }

  final AuthRepository _repository;
  StreamSubscription<AuthState>? _sub;

  AuthState _state = const AuthStateUnknown();
  AuthState get state => _state;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  AppFailure? _lastError;
  AppFailure? get lastError => _lastError;

  /// Convenience flags used by `AuthGate` and `LoginScreen`.
  bool get isReady => _state is! AuthStateUnknown;
  bool get isAuthenticated =>
      _state is AuthStateAuthenticated || _state is AuthStateGuest;

  UserProfile? get profile => switch (_state) {
        AuthStateGuest(:final profile) => profile,
        AuthStateAuthenticated(:final profile) => profile,
        AuthStateUnauthenticated() || AuthStateUnknown() => null,
      };

  /// Convenience: profile iff the user is fully authenticated (not
  /// a guest).
  UserProfile? get authenticatedProfile => switch (_state) {
        AuthStateAuthenticated(:final profile) => profile,
        _ => null,
      };

  /// Convenience: profile iff the user is signed in as a guest.
  UserProfile? get guestProfile => switch (_state) {
        AuthStateGuest(:final profile) => profile,
        _ => null,
      };

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  Future<AuthState> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _run(() => _repository.signInWithEmail(email: email, password: password));

  Future<AuthState> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _run(() => _repository.signUpWithEmail(email: email, password: password));

  Future<AuthState> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<AuthState> signInAsGuest() => _run(_repository.signInAsGuest);

  Future<void> sendPasswordReset({required String email}) async {
    _setBusy(true);
    clearError();
    try {
      await _repository.sendPasswordReset(email: email);
    } on AppFailure catch (failure) {
      _lastError = failure;
      AppLogger.w('AuthProvider.sendPasswordReset failed: $failure');
    } finally {
      _setBusy(false);
    }
  }

  Future<AuthState> signOut() async {
    _setBusy(true);
    clearError();
    try {
      await _repository.signOut();
      return _state;
    } on AppFailure catch (failure) {
      _lastError = failure;
      AppLogger.w('AuthProvider.signOut failed: $failure');
      return _state;
    } finally {
      _setBusy(false);
    }
  }

  /// Clear the latest error so the UI banner dismisses.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _repository.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<AuthState> _run(Future<UserProfile?> Function() action) async {
    _setBusy(true);
    clearError();
    try {
      await action();
      return _state;
    } on AppFailure catch (failure) {
      _lastError = failure;
      AppLogger.w('AuthProvider action failed: $failure');
      return _state;
    } finally {
      _setBusy(false);
    }
  }

  void _subscribe() {
    _sub = _repository.watch().listen((next) {
      _state = next;
      notifyListeners();
    });
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }
}