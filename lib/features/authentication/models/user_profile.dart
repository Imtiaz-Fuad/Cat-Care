/// A normalized snapshot of the signed-in Firebase user.
///
/// Mirrors the fields of `firebase_auth.User` that the UI and
/// repositories actually consume, while staying platform-agnostic and
/// trivially testable (no Firebase dependency). Built in
/// `AuthRepository` from the raw `User` returned by `AuthService`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.isAnonymous,
    required this.isEmailVerified,
    required this.providerIds,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.creationTime,
    this.lastSignInTime,
  });

  /// Stable per-account user id used to scope Firestore reads/writes.
  final String uid;

  /// Email address, or `null` when the user signed in via Google
  /// without exposing one, or signed in anonymously.
  final String? email;

  /// Display name from Google / email account, or `null` when
  /// unavailable (typical for anonymous sign-in).
  final String? displayName;

  /// Profile photo URL, or `null` when not set.
  final String? photoUrl;

  /// Phone number when the user signed in with phone auth, else `null`.
  final String? phoneNumber;

  /// True when the user is signed in via Firebase's anonymous
  /// provider (`signInAnonymously`).
  final bool isAnonymous;

  /// True when the email has been verified. Always false for guest
  /// sessions. UI surfaces a "Verify your email" banner when this is
  /// false on an email/password sign-in.
  final bool isEmailVerified;

  /// Ordered list of provider ids attached to the account. Common
  /// values: `password`, `google.com`, `anonymous`. Used by the
  /// `LoginScreen` to choose which sign-in methods to show as
  /// "already linked".
  final List<String> providerIds;

  /// Account creation timestamp.
  final DateTime? creationTime;

  /// Last sign-in timestamp.
  final DateTime? lastSignInTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.uid == uid &&
          other.email == email &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl &&
          other.phoneNumber == phoneNumber &&
          other.isAnonymous == isAnonymous &&
          other.isEmailVerified == isEmailVerified &&
          _listEq(other.providerIds, providerIds) &&
          other.creationTime == creationTime &&
          other.lastSignInTime == lastSignInTime;

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        displayName,
        photoUrl,
        phoneNumber,
        isAnonymous,
        isEmailVerified,
        Object.hashAll(providerIds),
        creationTime,
        lastSignInTime,
      );

  @override
  String toString() =>
      'UserProfile(uid: $uid, email: $email, anon: $isAnonymous, '
      'verified: $isEmailVerified, providers: $providerIds)';
}

bool _listEq(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}