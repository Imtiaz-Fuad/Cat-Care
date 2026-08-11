import 'user_profile.dart';

/// Sealed representation of the authentication state surfaced to the
/// UI layer.
///
/// * [AuthStateUnknown] — emitted once on app boot before Firebase
///   has reported the current user (kept by `AuthProvider` until
///   `markReady()` is called). Drives `SplashScreen`.
/// * [AuthStateUnauthenticated] — no user signed in. Drives
///   `LoginScreen`.
/// * [AuthStateGuest] — anonymous Firebase user. UI shows the home
///   shell with a "Guest mode" banner offering upgrade.
/// * [AuthStateAuthenticated] — a real account. Drives the
///   signed-in experience.
///
/// Sealed so call sites can `switch` exhaustively.
sealed class AuthState {
  const AuthState();
}

/// Boot sentinel: emitted once until the first Firebase event fires.
final class AuthStateUnknown extends AuthState {
  const AuthStateUnknown();
}

/// No user signed in.
final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

/// Anonymous / guest session. The user can browse the app but their
/// data is local-only until they upgrade via `MigrationService`.
final class AuthStateGuest extends AuthState {
  const AuthStateGuest({required this.profile});
  final UserProfile profile;
}

/// Authenticated user (email/password or Google).
final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated({required this.profile});
  final UserProfile profile;
}