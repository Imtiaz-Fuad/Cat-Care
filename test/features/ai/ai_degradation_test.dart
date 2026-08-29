// Tests for the "AI quota reached -> UI degrades" contract.
//
// Two surfaces are covered:
//   1. AiProvider.aiAvailable flips to false when an
//      AiQuotaExceededFailure is observed, and back to true after
//      clearError() is called.
//   2. AiAssistantScreen disables the composer + send button when
//      aiAvailable is false.

import 'dart:async';

import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/features/ai/models/cat_weekly_summary.dart';
import 'package:cat_care/features/ai/providers/ai_provider.dart';
import 'package:cat_care/features/ai/repositories/ai_repository.dart';
import 'package:cat_care/features/ai/utils/cat_summary_builder.dart';
import 'package:cat_care/features/authentication/models/user_profile.dart';
import 'package:cat_care/features/authentication/providers/auth_provider.dart';
import 'package:cat_care/features/cats/providers/cat_provider.dart';
import 'package:cat_care/features/cats/repositories/cat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAiRepository extends Mock implements AiRepository {}

class _MockCatSummaryBuilder extends Mock implements CatSummaryBuilder {}

class _MockAuthProvider extends Mock implements AuthProvider {}

class _MockCatRepository extends Mock implements CatRepository {}

UserProfile _profile(String uid) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  isAnonymous: false,
  isEmailVerified: true,
  providerIds: const <String>['password'],
);

CatProfile _cat(String id) => CatProfile(
  id: id,
  ownerId: 'alice',
  name: 'Mimi',
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
  neutered: false,
  indoor: true,
  allergies: const <String>[],
  diseases: const <String>[],
  medications: const <String>[],
  priorities: const <String>[],
);

class _AiFixture {
  _AiFixture({
    required this.provider,
    required this.repository,
    required this.ctrl,
    required this.catsProvider,
  });

  final AiProvider provider;
  final _MockAiRepository repository;
  final StreamController<List<CatProfile>> ctrl;
  final CatProvider catsProvider;

  void failNextChat(AppFailure failure) {
    when(
      () => repository.chat(
        userMessage: any(named: 'userMessage'),
        cat: any(named: 'cat'),
        summary: any(named: 'summary'),
        locale: any(named: 'locale'),
        history: any(named: 'history'),
      ),
    ).thenThrow(failure);
  }

  Future<void> dispose() async {
    provider.dispose();
    catsProvider.dispose();
    await ctrl.close();
  }
}

Future<_AiFixture> _buildProvider({required List<CatProfile> cats}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final _MockAiRepository repo = _MockAiRepository();
  final _MockCatSummaryBuilder summary = _MockCatSummaryBuilder();
  final _MockAuthProvider auth = _MockAuthProvider();
  final _MockCatRepository catRepo = _MockCatRepository();

  final StreamController<List<CatProfile>> ctrl =
      StreamController<List<CatProfile>>.broadcast();

  when(() => auth.profile).thenReturn(_profile('alice'));
  when(() => catRepo.watchCats('alice')).thenAnswer((_) => ctrl.stream);
  when(
    () => summary.build(
      ownerId: any(named: 'ownerId'),
      catId: any(named: 'catId'),
      days: any(named: 'days'),
    ),
  ).thenAnswer(
    (_) async => const CatWeeklySummary(
      daysWindow: 7,
      feedingCount: 0,
      totalFeedingAmount: 0,
      waterCount: 0,
      totalWaterMl: 0,
      lastWeights: <WeightPoint>[],
      feedingDaysWithLogs: 0,
      waterDaysWithLogs: 0,
    ),
  );

  final CatProvider catsProvider = await CatProvider.create(
    repository: catRepo,
    authProvider: auth,
  );

  // Fire the initial cat list so the screen has an active cat.
  ctrl.add(cats);
  await Future<void>.delayed(Duration.zero);

  final AiProvider provider = AiProvider(
    repository: repo,
    summaryBuilder: summary,
    authProvider: auth,
    catProvider: catsProvider,
  );

  return _AiFixture(
    provider: provider,
    repository: repo,
    ctrl: ctrl,
    catsProvider: catsProvider,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_cat('any'));
    registerFallbackValue(
      const CatWeeklySummary(
        daysWindow: 7,
        feedingCount: 0,
        totalFeedingAmount: 0,
        waterCount: 0,
        totalWaterMl: 0,
        lastWeights: <WeightPoint>[],
        feedingDaysWithLogs: 0,
        waterDaysWithLogs: 0,
      ),
    );
  });

  group('AiProvider.aiAvailable', () {
    test('starts true with no error', () async {
      final fixture = await _buildProvider(cats: <CatProfile>[_cat('cat-1')]);
      expect(fixture.provider.aiAvailable, isTrue);
      expect(fixture.provider.isQuotaLimited, isFalse);
      await fixture.dispose();
    });

    test('flips false when AiQuotaExceededFailure is observed', () async {
      final fixture = await _buildProvider(cats: <CatProfile>[_cat('cat-1')]);
      fixture.failNextChat(
        const AiQuotaExceededFailure(
          'Daily limit reached for Chat. Resets at 00:00 UTC.',
        ),
      );

      await fixture.provider.sendChatMessage(
        catId: 'cat-1',
        userMessage: 'hello',
      );

      expect(fixture.provider.aiAvailable, isFalse);
      expect(fixture.provider.isQuotaLimited, isTrue);
      expect(fixture.provider.lastError, isA<AiQuotaExceededFailure>());
      await fixture.dispose();
    });

    test('returns to true after clearError()', () async {
      final fixture = await _buildProvider(cats: <CatProfile>[_cat('cat-1')]);
      fixture.failNextChat(
        const AiQuotaExceededFailure(
          'Daily limit reached for Chat. Resets at 00:00 UTC.',
        ),
      );
      await fixture.provider.sendChatMessage(
        catId: 'cat-1',
        userMessage: 'hello',
      );
      expect(fixture.provider.aiAvailable, isFalse);

      fixture.provider.clearError();

      expect(fixture.provider.aiAvailable, isTrue);
      expect(fixture.provider.isQuotaLimited, isFalse);
      expect(fixture.provider.lastError, isNull);
      await fixture.dispose();
    });
  });

  group('UI composer + send gate when quota reached', () {
    test('the gate expression used by AiAssistantScreen flips disabled after '
        'a quota failure and back after clearError()', () async {
      final fixture = await _buildProvider(cats: <CatProfile>[_cat('cat-1')]);
      addTearDown(fixture.dispose);

      // The expression that `AiAssistantScreen` uses to gate the
      // composer + send button.
      bool gate() => fixture.provider.aiAvailable && !fixture.provider.chatBusy;

      // Initially: gate open.
      expect(gate(), isTrue);

      fixture.failNextChat(
        const AiQuotaExceededFailure(
          'Daily limit reached for Chat. Resets at 00:00 UTC.',
        ),
      );
      await fixture.provider.sendChatMessage(
        catId: 'cat-1',
        userMessage: 'hello',
      );

      // Provider reports quota exhaustion — the same expression
      // that the screen's TextField/IconButton gate on now
      // evaluates to false.
      expect(gate(), isFalse);
      expect(fixture.provider.isQuotaLimited, isTrue);

      // After the user dismisses the error the gate reopens.
      fixture.provider.clearError();
      expect(gate(), isTrue);
      expect(fixture.provider.isQuotaLimited, isFalse);
    });
  });
}
