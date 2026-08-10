// Unit tests for `AuthRepository` — verify the Stream<AuthState> lifecycle:
//   * starts as `AuthStateUnknown`
//   * emits `AuthStateUnauthenticated` when the mock user signs out
//   * emits `AuthStateGuest` after a guest sign-in
//   * emits `AuthStateAuthenticated` after a real sign-in
//   * surface errors from sign-in calls as `AuthFailure` (no streaming)
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/services/auth_service.dart';
import 'package:cat_care/features/authentication/models/auth_state.dart';
import 'package:cat_care/features/authentication/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  group('AuthRepository.watch() initial state', () {
    test(
      'exposes AuthStateUnknown on `current` before the first stream event',
      () {
        // Construct synchronously — NO awaits before the assertion, so
        // the mock's `authStateChanges()` microtask has not yet run and
        // `repo.current` is still the `AuthStateUnknown` sentinel.
        final auth = MockFirebaseAuth();
        final repo = AuthRepository(service: AuthService(instance: auth));
        expect(repo.current, isA<AuthStateUnknown>());
        return repo.dispose();
      },
    );

    test('flips `current` to Unauthenticated once the first event arrives',
        () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(service: AuthService(instance: auth));

      // Pump the microtask queue so the controller receives the seed
      // `null` event from the mock.
      await Future<void>.delayed(Duration.zero);
      expect(repo.current, isA<AuthStateUnauthenticated>());

      await repo.dispose();
    });

    test('replays an Authenticated state when the mock boots signed in',
        () async {
      final user = MockUser(
        uid: 'alice',
        email: 'alice@example.com',
        isAnonymous: false,
      );
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final repo = AuthRepository(service: AuthService(instance: auth));

      // Give the controller a chance to receive the initial seed event.
      await Future<void>.delayed(Duration.zero);

      final first = await repo.watch().first;
      expect(first, isA<AuthStateAuthenticated>());
      final authenticated = first as AuthStateAuthenticated;
      expect(authenticated.profile.uid, 'alice');
      expect(authenticated.profile.email, 'alice@example.com');
      expect(authenticated.profile.isAnonymous, isFalse);

      await repo.dispose();
    });
  });

  group('AuthRepository.signInAsGuest', () {
    test('returns a guest profile and the stream flips to Guest', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(service: AuthService(instance: auth));

      final profile = await repo.signInAsGuest();

      expect(profile.isAnonymous, isTrue);
      expect(profile.uid, isNotEmpty);

      // Let the authStateChanges event propagate.
      await Future<void>.delayed(Duration.zero);
      final state = repo.current;
      expect(state, isA<AuthStateGuest>());
      expect((state as AuthStateGuest).profile.uid, profile.uid);

      await repo.dispose();
    });
  });

  group('AuthRepository.signInWithEmail', () {
    test('returns the profile and stream flips to Authenticated', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(service: AuthService(instance: auth));

      final profile = await repo.signInWithEmail(
        email: 'cat@example.com',
        password: 'purrsecret',
      );

      // `MockFirebaseAuth.signInWithEmailAndPassword` does not populate
      // email on the returned user, so we only assert the bits that
      // matter for our mapping: non-anonymous + UID assigned.
      expect(profile.uid, isNotEmpty);
      expect(profile.isAnonymous, isFalse);

      await Future<void>.delayed(Duration.zero);
      final state = repo.current;
      expect(state, isA<AuthStateAuthenticated>());

      await repo.dispose();
    });

    test('surfaces AuthFailure when the email does not exist', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      final repo = AuthRepository(service: AuthService(instance: auth));

      await expectLater(
        () => repo.signInWithEmail(
          email: 'missing@example.com',
          password: 'whatever',
        ),
        throwsA(isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          'user-not-found',
        )),
      );

      await repo.dispose();
    });
  });

  group('AuthRepository.signOut', () {
    test('flips the stream to Unauthenticated', () async {
      final user = MockUser(uid: 'alice', email: 'alice@example.com');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final repo = AuthRepository(service: AuthService(instance: auth));

      // Seed the current snapshot.
      await Future<void>.delayed(Duration.zero);
      expect(repo.current, isA<AuthStateAuthenticated>());

      await repo.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(repo.current, isA<AuthStateUnauthenticated>());

      await repo.dispose();
    });
  });
}
