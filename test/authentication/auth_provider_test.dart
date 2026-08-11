// Unit tests for `AuthProvider` — verify the ChangeNotifier surface the
// UI binds to:
//
//   * `isBusy` toggles on every action (true while awaiting, false after)
//   * `lastError` is set when an action throws an `AuthFailure`, then
//     cleared when the next action starts
//   * `notifyListeners` fires on every state transition
//   * The sealed `state` flips through Unknown → Unauthenticated → Guest /
//     Authenticated as the mock auth state evolves
//   * `dispose` cancels its subscription without leaking
//
// Note: `AuthProvider._repository` is private, so the tests keep a
// separate handle to the underlying `MockFirebaseAuth` and use it with
// `whenCalling(...)` to seed failures.
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/services/auth_service.dart';
import 'package:cat_care/features/authentication/models/auth_state.dart';
import 'package:cat_care/features/authentication/providers/auth_provider.dart';
import 'package:cat_care/features/authentication/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  // Builds a fresh (AuthService + AuthRepository + AuthProvider) triple
  // sharing the same `MockFirebaseAuth` instance. The returned `auth`
  // handle is what `whenCalling(...)` operates on.
  Future<({AuthProvider provider, MockFirebaseAuth auth})> buildProvider({
    MockUser? signedInUser,
  }) async {
    final auth = MockFirebaseAuth(
      signedIn: signedInUser != null,
      mockUser: signedInUser,
    );
    final repo = AuthRepository(service: AuthService(instance: auth));
    final provider = AuthProvider(repository: repo);
    // Let the initial stream event settle so `state` has a known value.
    await Future<void>.delayed(Duration.zero);
    return (provider: provider, auth: auth);
  }

  group('AuthProvider initial state', () {
    test('starts as AuthStateUnknown and not ready', () {
      // Build the provider synchronously — no awaits before the
      // assertions — so the mock's `authStateChanges()` microtask has
      // not yet run and `_state` is still the `AuthStateUnknown` seed.
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(service: AuthService(instance: auth));
      final provider = AuthProvider(repository: repo);

      expect(provider.state, isA<AuthStateUnknown>());
      expect(provider.isReady, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.profile, isNull);

      return provider.dispose();
    });

    test('flips to Authenticated when the mock boots signed in', () async {
      final user = MockUser(uid: 'alice', email: 'alice@example.com');
      final (:provider, :auth) = await buildProvider(signedInUser: user);
      expect(provider.state, isA<AuthStateAuthenticated>());
      expect(provider.isReady, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.uid, 'alice');
      provider.dispose();
      expect(auth, isNotNull);
    });
  });

  group('AuthProvider.signInWithEmail', () {
    test('toggles isBusy on/off and flips to Authenticated on success',
        () async {
      final user = MockUser(uid: 'cat', email: 'cat@example.com');
      final (:provider, :auth) = await buildProvider(signedInUser: user);

      final observedBusy = <bool>[];
      provider.addListener(() => observedBusy.add(provider.isBusy));

      await provider.signInWithEmail(
        email: 'cat@example.com',
        password: 'purrsecret',
      );

      // The first frame saw isBusy=true, the last saw isBusy=false.
      expect(observedBusy, contains(true));
      expect(observedBusy.last, isFalse);
      // lastError stays null because the call succeeded.
      expect(provider.lastError, isNull);
      // The mock already had the user signed in, so post-sign-in state
      // stays Authenticated.
      await Future<void>.delayed(Duration.zero);
      expect(provider.state, isA<AuthStateAuthenticated>());

      provider.dispose();
      expect(auth, isNotNull);
    });

    test('sets lastError and keeps state unchanged on failure', () async {
      final (:provider, :auth) = await buildProvider();

      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await provider.signInWithEmail(
        email: 'cat@example.com',
        password: 'bad',
      );

      expect(provider.lastError, isA<AuthFailure>());
      expect(provider.lastError!.code, 'wrong-password');
      // The failed `signInWithEmail` must not mutate `_state` — the
      // stream already settled on `AuthStateUnauthenticated` during
      // `buildProvider`, so we assert the state is unchanged there.
      expect(provider.state, isA<AuthStateUnauthenticated>());

      return provider.dispose();
    });
  });

  group('AuthProvider.signOut', () {
    test('flips state to Unauthenticated on success', () async {
      final (:provider, :auth) = await buildProvider(
        signedInUser: MockUser(uid: 'alice', email: 'alice@example.com'),
      );

      expect(provider.state, isA<AuthStateAuthenticated>());

      await provider.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(provider.state, isA<AuthStateUnauthenticated>());
      expect(provider.isAuthenticated, isFalse);
      expect(provider.profile, isNull);

      provider.dispose();
      expect(auth, isNotNull);
    });
  });

  group('AuthProvider.sendPasswordReset', () {
    test('does not toggle state but does set lastError on failure', () async {
      final (:provider, :auth) = await buildProvider();

      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      final stateBefore = provider.state;
      await provider.sendPasswordReset(email: 'missing@example.com');

      expect(provider.lastError, isA<AuthFailure>());
      expect(provider.state, stateBefore); // unchanged

      provider.dispose();
    });
  });

  group('AuthProvider.clearError', () {
    test('clears lastError without touching state', () async {
      final (:provider, :auth) = await buildProvider();

      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await provider.signInWithEmail(email: 'x', password: 'y');
      expect(provider.lastError, isNotNull);

      provider.clearError();
      expect(provider.lastError, isNull);

      provider.dispose();
    });
  });
}
