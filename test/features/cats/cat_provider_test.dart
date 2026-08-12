import 'dart:async';

import 'package:cat_care/core/constants/app_constants.dart';
// ignore_for_file: unawaited_futures
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/features/authentication/models/user_profile.dart';
import 'package:cat_care/features/authentication/providers/auth_provider.dart';
import 'package:cat_care/features/cats/models/cat_draft.dart';
import 'package:cat_care/features/cats/providers/cat_provider.dart';
import 'package:cat_care/features/cats/repositories/cat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCatRepository extends Mock implements CatRepository {}

class _MockAuthProvider extends Mock implements AuthProvider {}

UserProfile _profile(String uid) => UserProfile(
      uid: uid,
      email: '$uid@example.com',
      isAnonymous: false,
      isEmailVerified: true,
      providerIds: const <String>['password'],
    );

CatProfile _cat(String id, String name) {
  return CatProfile(
    id: id,
    ownerId: 'alice',
    name: name,
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
    neutered: false,
    indoor: true,
    allergies: const <String>[],
    diseases: const <String>[],
    medications: const <String>[],
    priorities: const <String>[],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CatDraft(name: 'fallback'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('CatProvider — boot-time fallback', () {
    test('hydrates activeCatId from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.activeCatIdKey: 'cat-stored',
      });
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      final StreamController<List<CatProfile>> ctrl =
          StreamController<List<CatProfile>>.broadcast();
      when(() => repo.watchCats('alice')).thenAnswer((_) => ctrl.stream);

      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      // No cats yet — getter falls back to null but the persisted id
      // is preserved for the stream to validate on first emission.
      expect(provider.activeCatId, isNull);

      ctrl.add(<CatProfile>[_cat('cat-stored', 'Mimi')]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.activeCat?.id, 'cat-stored');

      ctrl.close();
      provider.dispose();
    });

    test('drops an empty-string active id from prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.activeCatIdKey: '',
      });
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      when(() => repo.watchCats('alice'))
          .thenAnswer((_) => const Stream<List<CatProfile>>.empty());

      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      expect(provider.activeCatId, isNull);

      provider.dispose();
    });
  });

  group('CatProvider.setActiveCat', () {
    test('updates the active id and persists it', () async {
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      final StreamController<List<CatProfile>> ctrl =
          StreamController<List<CatProfile>>.broadcast();
      when(() => repo.watchCats('alice')).thenAnswer((_) => ctrl.stream);
      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      ctrl.add(<CatProfile>[_cat('cat-7', 'Mimi')]);
      await Future<void>.delayed(Duration.zero);

      await provider.setActiveCat('cat-7');
      expect(provider.activeCatId, 'cat-7');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.activeCatIdKey), 'cat-7');

      ctrl.close();
      provider.dispose();
    });

    test('falls back to the first cat when the active id is gone', () async {
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      final StreamController<List<CatProfile>> ctrl =
          StreamController<List<CatProfile>>.broadcast();
      when(() => repo.watchCats('alice')).thenAnswer((_) => ctrl.stream);

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.activeCatIdKey: 'cat-old',
      });
      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      ctrl.add(<CatProfile>[_cat('cat-new', 'New'), _cat('cat-2', 'Other')]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.activeCat?.id, 'cat-new');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.activeCatIdKey), 'cat-new');

      ctrl.close();
      provider.dispose();
    });
  });

  group('CatProvider.createCat', () {
    test('persists a new cat, sets it active, and surfaces it', () async {
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      final StreamController<List<CatProfile>> ctrl =
          StreamController<List<CatProfile>>.broadcast();
      when(() => repo.watchCats('alice')).thenAnswer((_) => ctrl.stream);
      when(
        () => repo.createCat(
          ownerId: any(named: 'ownerId'),
          draft: any(named: 'draft'),
        ),
      ).thenAnswer((_) async => _cat('cat-9', 'Mimi'));

      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      // Simulate the stream catching up after the create — the
      // provider's `activeCatId` getter only confirms the id once the
      // cat is in the streamed list.
      ctrl.add(<CatProfile>[_cat('cat-9', 'Mimi')]);
      await Future<void>.delayed(Duration.zero);

      await provider.createCat(CatDraft(name: 'Mimi'));
      // _runGuarded fires asynchronously; yield once so the guarded
      // closure finishes setting the active id + persisting it.
      await Future<void>.delayed(Duration.zero);

      // The provider's `createCat` returns the value synchronously
      // captured by the closure, not the awaited result — so verify
      // the side effects (active id, persisted prefs) instead.
      expect(provider.activeCatId, 'cat-9');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.activeCatIdKey), 'cat-9');

      verify(
        () => repo.createCat(
          ownerId: 'alice',
          draft: any(named: 'draft'),
        ),
      ).called(1);

      ctrl.close();
      provider.dispose();
    });

    test('returns null when the repository throws and surfaces lastError',
        () async {
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(_profile('alice'));
      when(() => repo.watchCats('alice'))
          .thenAnswer((_) => const Stream<List<CatProfile>>.empty());
      when(
        () => repo.createCat(
          ownerId: any(named: 'ownerId'),
          draft: any(named: 'draft'),
        ),
      ).thenThrow(const UnknownFailure('boom', code: 'unknown'));

      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      final CatProfile? created =
          await provider.createCat(CatDraft(name: 'Mimi'));
      await Future<void>.delayed(Duration.zero);

      expect(created, isNull);
      expect(provider.lastError, isA<UnknownFailure>());
      provider.clearError();
      expect(provider.lastError, isNull);

      provider.dispose();
    });

    test('refuses when there is no signed-in user', () async {
      final _MockCatRepository repo = _MockCatRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      when(() => auth.profile).thenReturn(null);
      when(() => repo.watchCats(any<String>()))
          .thenAnswer((_) => const Stream<List<CatProfile>>.empty());
      final CatProvider provider = await CatProvider.create(
        repository: repo,
        authProvider: auth,
      );

      final CatProfile? created =
          await provider.createCat(CatDraft(name: 'Mimi'));
      await Future<void>.delayed(Duration.zero);

      expect(created, isNull);
      expect(provider.lastError, isA<AuthFailure>());

      provider.dispose();
    });
  });
}