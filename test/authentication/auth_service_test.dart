// Unit tests for `AuthService` — verify it maps Firebase exceptions into
// the typed `AuthFailure` surface the rest of the app consumes.
//
// We exercise the service against `MockFirebaseAuth` and `MockGoogleSignIn`
// from the firebase_auth_mocks + google_sign_in_mocks packages. These
// mocks are pinned to firebase_auth 5.x / firebase_core 3.x (see
// pubspec.yaml) so the test mirrors production wiring.
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  group('AuthService.signInWithEmail', () {
    test('returns a credential for an existing mock user', () async {
      final user = MockUser(
        uid: 'abc',
        email: 'cat@example.com',
        isAnonymous: false,
      );
      final auth = MockFirebaseAuth(signedIn: false, mockUser: user);
      final service = AuthService(instance: auth);

      final credential = await service.signInWithEmail(
        email: 'cat@example.com',
        password: 'purrsecret',
      );

      expect(credential.user, isNotNull);
      expect(credential.user!.uid, 'abc');
      expect(service.currentUser, isNotNull);
    });

    test('maps user-not-found to AuthFailure(user-not-found)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.signInWithEmail(
          email: 'missing@example.com',
          password: 'whatever',
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'user-not-found'),
        ),
      );
    });

    test('maps wrong-password to AuthFailure(wrong-password)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.signInWithEmail(
          email: 'cat@example.com',
          password: 'bad',
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'wrong-password'),
        ),
      );
    });

    test('maps invalid-email to AuthFailure(invalid-email)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.signInWithEmail(email: 'nope', password: 'whatever'),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'invalid-email'),
        ),
      );
    });
  });

  group('AuthService.signUpWithEmail', () {
    test('maps email-already-in-use to AuthFailure(email-already-in-use)',
        () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.signUpWithEmail(
          email: 'cat@example.com',
          password: 'password123',
        ),
        throwsA(isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          'email-already-in-use',
        )),
      );
    });

    test('maps weak-password to AuthFailure(weak-password)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'weak-password'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.signUpWithEmail(email: 'cat@example.com', password: 'x'),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'weak-password'),
        ),
      );
    });
  });

  group('AuthService.sendPasswordReset', () {
    test('maps user-not-found to AuthFailure(user-not-found)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.sendPasswordReset(email: 'missing@example.com'),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'user-not-found'),
        ),
      );
    });
  });

  group('AuthService.signInAsGuest', () {
    test('returns an anonymous credential', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(instance: auth);

      final credential = await service.signInAsGuest();

      expect(credential.user, isNotNull);
      expect(credential.user!.isAnonymous, isTrue);
    });
  });

  group('AuthService.signInWithGoogle', () {
    test('signs in when the user completes the consent sheet', () async {
      final google = MockGoogleSignIn();
      final auth = MockFirebaseAuth();
      final service = AuthService(instance: auth, googleSignIn: google);

      final credential = await service.signInWithGoogle();

      expect(credential.user, isNotNull);
      expect(service.currentUser, isNotNull);
    });

    test('maps GoogleSignInException to AuthFailure with the SDK code name',
        () async {
      // `MockGoogleSignIn.setIsCancelled(true)` throws a raw `'Cancelled'`
      // string, not a `GoogleSignInException`. And `google_sign_in_mocks`'s
      // `MockGoogleSignIn` does not call `maybeThrowException` from its
      // method bodies, so seeding via `whenCalling(...)` on the raw mock
      // is a no-op. We wrap the mock in a tiny subclass that does call
      // `maybeThrowException` so the `on GoogleSignInException` branch in
      // `AuthService` is actually exercised.
      final google = _ThrowingGoogleSignIn();
      whenCalling(Invocation.method(#authenticate, null))
          .on(google)
          .thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'User cancelled',
        ),
      );
      final auth = MockFirebaseAuth();
      final service = AuthService(instance: auth, googleSignIn: google);

      await expectLater(
        () => service.signInWithGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            'canceled',
          ),
        ),
      );
    });

    test('throws AuthFailure when there is no current user to link', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(instance: auth);

      await expectLater(
        () => service.linkGuestWithEmail(
          email: 'cat@example.com',
          password: 'purrsecret',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            'no-current-user',
          ),
        ),
      );
    });
  });

  group('AuthService.signOut', () {
    test('clears the current user', () async {
      final user = MockUser(uid: 'abc', email: 'cat@example.com');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final service = AuthService(instance: auth);

      expect(service.currentUser, isNotNull);
      await service.signOut();
      expect(service.currentUser, isNull);
    });
  });

  // Sanity-check that the google_sign_in mock is usable as a
  // `GoogleSignIn` (compile-time guarantee we wired it right).
  test('MockGoogleSignIn implements GoogleSignIn', () {
    final GoogleSignIn google = MockGoogleSignIn();
    expect(google, isA<GoogleSignIn>());
  });
}

/// Subclass of `MockGoogleSignIn` that opts into `mock_exceptions` by
/// calling `maybeThrowException` at the top of `authenticate()`.
///
/// `google_sign_in_mocks` does not call `maybeThrowException` from inside
/// its methods, so seeding via `whenCalling(...)` on a raw `MockGoogleSignIn`
/// is a no-op. This subclass bridges that gap so tests can drive the
/// `on GoogleSignInException` branch in `AuthService.signInWithGoogle`.
class _ThrowingGoogleSignIn extends MockGoogleSignIn {
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) {
    maybeThrowException(this, Invocation.method(#authenticate, null));
    return super.authenticate(scopeHint: scopeHint);
  }
}
