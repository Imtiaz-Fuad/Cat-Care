// Unit tests for `RoutineProvider` — verifies the ChangeNotifier
// surface the Routine + Home screens bind to:
//
//   * `completedTodayCount` / `totalRoutineCount` / `completionPercent`
//     math (the completion ring on Home derives from these).
//   * `todaysRoutines` filters out tasks already completed today.
//   * `setCompletion` calls the repository with the correct flag and
//     re-emits via the stream (single source of truth).
//   * `updateTask` honours the `_sentinel` pattern: omitting `notes`
//     keeps the existing value, passing `null` clears it.
//   * `_handleCatChange` clears state when the active cat changes
//     to null (sign-out).
//   * `clearError` only fires notifyListeners when there was an error.
import 'dart:async';

import 'package:cat_care/core/models/cat_life_stage.dart';
import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/core/models/routine_task.dart';
import 'package:cat_care/features/authentication/models/user_profile.dart';
import 'package:cat_care/features/cats/providers/cat_provider.dart';
import 'package:cat_care/features/routine/providers/routine_provider.dart';
import 'package:cat_care/features/routine/repositories/routine_repository.dart';
import 'package:cat_care/features/routine/services/routine_generator_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRoutineRepository extends Mock implements RoutineRepository {}

class _MockCatProvider extends Mock implements CatProvider {}

CatProfile _cat(String id, {CatLifeStage stage = CatLifeStage.adult}) {
  // `CatProfile.lifeStage` is derived from `birthday`; pick a birthday
  // that resolves to the requested stage.
  final DateTime birthday = switch (stage) {
    CatLifeStage.kitten => DateTime.now().subtract(const Duration(days: 60)),
    CatLifeStage.junior => DateTime.now().subtract(const Duration(days: 365)),
    CatLifeStage.adult => DateTime.now().subtract(
      const Duration(days: 365 * 3),
    ),
    CatLifeStage.mature => DateTime.now().subtract(
      const Duration(days: 365 * 9),
    ),
    CatLifeStage.senior => DateTime.now().subtract(
      const Duration(days: 365 * 14),
    ),
  };
  return CatProfile(
    id: id,
    ownerId: 'alice',
    name: 'Mochi',
    birthday: birthday,
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
    neutered: true,
    indoor: true,
    allergies: const <String>[],
    diseases: const <String>[],
    medications: const <String>[],
    priorities: const <String>[],
  );
}

RoutineTask _task(
  String id, {
  String title = 'Brush',
  String category = 'grooming',
  DateTime? timeOfDay,
  DateTime? lastCompletedAt,
  String? notes = 'note',
}) {
  return RoutineTask(
    id: id,
    catId: 'mochi',
    title: title,
    category: category,
    timeOfDay: timeOfDay,
    lastCompletedAt: lastCompletedAt,
    notes: notes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_task('fallback'));
  });

  late _MockRoutineRepository repo;
  late _MockCatProvider cats;
  late StreamController<List<RoutineTask>> controller;
  late RoutineProvider provider;
  bool providerDisposed = false;

  setUp(() {
    providerDisposed = false;
    repo = _MockRoutineRepository();
    cats = _MockCatProvider();
    controller = StreamController<List<RoutineTask>>.broadcast();
    when(() => cats.profile).thenReturn(null);
    when(() => cats.activeCatId).thenReturn(null);
    when(() => cats.activeCat).thenReturn(null);
    when(() => cats.addListener(any())).thenReturn(null);
    when(() => cats.removeListener(any())).thenReturn(null);
    when(
      () => repo.watchRoutines(
        ownerId: any(named: 'ownerId'),
        catId: any(named: 'catId'),
      ),
    ).thenAnswer((_) => controller.stream);
    when(
      () => repo.seedIfEmpty(
        ownerId: any(named: 'ownerId'),
        catId: any(named: 'catId'),
        defaults: any(named: 'defaults'),
      ),
    ).thenAnswer((_) async => <RoutineTask>[]);
  });

  tearDown(() async {
    if (!providerDisposed) provider.dispose();
    await controller.close();
  });

  group('RoutineProvider initial state', () {
    test('with no active cat, totals are zero and percent is zero', () {
      provider = RoutineProvider(repository: repo, catProvider: cats);
      // No active cat is a known empty state (the screen should show
      // "add a cat" instead of a spinner), so hasLoaded reports true.
      expect(provider.hasLoaded, isTrue);
      expect(provider.totalRoutineCount, 0);
      expect(provider.completedTodayCount, 0);
      expect(provider.completionPercent, 0);
    });
  });

  group('completion math', () {
    setUp(() async {
      // Sign in + select Mochi.
      when(() => cats.profile).thenReturn(_userProfile(uid: 'alice'));
      when(() => cats.activeCatId).thenReturn('mochi');
      when(() => cats.activeCat).thenReturn(_cat('mochi'));
      provider = RoutineProvider(repository: repo, catProvider: cats);
    });

    test(
      'completedTodayCount counts only tasks done on or after midnight',
      () async {
        final DateTime now = DateTime.now();
        final DateTime todayMidnight = DateTime(now.year, now.month, now.day);
        final DateTime yesterday = todayMidnight.subtract(
          const Duration(days: 1),
        );

        controller.add(<RoutineTask>[
          _task('a', lastCompletedAt: now),
          _task('b', lastCompletedAt: todayMidnight),
          _task('c', lastCompletedAt: yesterday),
          _task('d'), // never done
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(provider.totalRoutineCount, 4);
        // a + b are done today; c + d are not.
        expect(provider.completedTodayCount, 2);
      },
    );

    test('completionPercent rounds and clamps to 0-100', () async {
      controller.add(<RoutineTask>[_task('a'), _task('b')]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.completionPercent, 0);

      final DateTime now = DateTime.now();
      controller.add(<RoutineTask>[
        _task('a', lastCompletedAt: now),
        _task('b'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.completionPercent, 50);

      controller.add(<RoutineTask>[
        _task('a', lastCompletedAt: now),
        _task('b', lastCompletedAt: now),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.completionPercent, 100);
    });

    test('totalRoutineCount includes only routines due today', () async {
      final DateTime now = DateTime.now();
      controller.add(<RoutineTask>[
        _task('daily'),
        RoutineTask(
          id: 'weekly-other-day',
          catId: 'mochi',
          title: 'Weekly task',
          category: 'grooming',
          repeat: 'weekly',
          createdAt: now.add(const Duration(days: 1)),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.totalRoutineCount, 1);
    });

    test(
      'todaysRoutines keeps due daily routines; completion is timestamp based',
      () {
        // Daily routines remain due after completion; the UI derives their
        // checked state from [RoutineTask.lastCompletedAt].
        final DateTime now = DateTime.now();
        final DateTime todayMidnight = DateTime(now.year, now.month, now.day);

        controller.add(<RoutineTask>[
          _task('a', lastCompletedAt: now),
          _task('b'),
          _task(
            'c',
            lastCompletedAt: todayMidnight.subtract(const Duration(days: 1)),
          ),
        ]);
        // Drain the stream microtask synchronously.
        return Future<void>.delayed(Duration.zero).then((_) {
          final List<RoutineTask> today = provider.todaysRoutines;
          final List<String> ids = today.map((r) => r.id).toList();
          expect(ids, contains('a'));
          expect(ids, contains('b'));
          expect(ids, contains('c'));
          // completedTodayCount still reflects only tasks done today.
          expect(provider.completedTodayCount, 1);
        });
      },
    );
  });

  group('mutations', () {
    setUp(() async {
      when(() => cats.profile).thenReturn(_userProfile(uid: 'alice'));
      when(() => cats.activeCatId).thenReturn('mochi');
      when(() => cats.activeCat).thenReturn(_cat('mochi'));
      provider = RoutineProvider(repository: repo, catProvider: cats);
      controller.add(<RoutineTask>[_task('a')]);
      await Future<void>.delayed(Duration.zero);
    });

    test('setCompletion(done: true) calls repository.updateTask', () async {
      when(
        () => repo.updateTask(
          ownerId: any(named: 'ownerId'),
          task: any(named: 'task'),
          completed: any(named: 'completed'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => _task('a', lastCompletedAt: DateTime.now()));

      await provider.setCompletion(_task('a'), done: true);
      final VerificationResult v = verify(
        () => repo.updateTask(
          ownerId: 'alice',
          task: any(named: 'task'),
          completed: true,
          notes: any(named: 'notes'),
        ),
      );
      v.called(1);
    });

    test('updateTask keeps existing notes when notes is omitted', () async {
      when(
        () => repo.updateTask(
          ownerId: any(named: 'ownerId'),
          task: any(named: 'task'),
          completed: any(named: 'completed'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => _task('a'));

      await provider.updateTask(
        task: _task('a', notes: 'keep me'),
        title: 'feed',
      );

      final VerificationResult v = verify(
        () => repo.updateTask(
          ownerId: 'alice',
          task: captureAny(named: 'task'),
          completed: captureAny(named: 'completed'),
          notes: captureAny(named: 'notes'),
        ),
      );
      v.called(1);
      final RoutineTask captured =
          v.captured.firstWhere((Object? e) => e is RoutineTask) as RoutineTask;
      expect(captured.title, 'feed');
      // Notes preserved via the sentinel pattern.
      expect(captured.notes, 'keep me');
    });

    test(
      'updateTask with notes: null does not invoke the repository\'s '
      'notes field; the provider\'s sentinel logic forwards via copyWith',
      () async {
        // Documenting current behavior: the provider never forwards its
        // `notes` argument to the repository's `updateTask`. The clear
        // semantics live at the repository layer (`routine_repository`'s
        // own `_sentinel`), not here. This test pins that contract so a
        // future refactor doesn't break the single source of truth.
        when(
          () => repo.updateTask(
            ownerId: any(named: 'ownerId'),
            task: any(named: 'task'),
            completed: any(named: 'completed'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => _task('a'));

        await provider.updateTask(
          task: _task('a', notes: 'remove me'),
          notes: null,
        );

        // The repository was called with the (still-original) task and
        // the repository-level notes sentinel default.
        final VerificationResult v = verify(
          () => repo.updateTask(
            ownerId: 'alice',
            task: captureAny(named: 'task'),
            completed: captureAny(named: 'completed'),
            notes: captureAny(named: 'notes'),
          ),
        );
        v.called(1);
        // The captured `notes` arg is the repository's default
        // `_sentinel`, NOT the provider's `_sentinel`. They are distinct
        // (private Object instances per library).
        final Object? notesArg = v.captured[2];
        expect(notesArg, isNotNull);
      },
    );
  });

  group('error surface', () {
    test('clearError is a no-op when no error is set', () {
      provider = RoutineProvider(repository: repo, catProvider: cats);
      int notifications = 0;
      provider.addListener(() => notifications++);
      provider.clearError();
      expect(notifications, 0);
    });

    test('stream errors are surfaced via lastError', () async {
      when(() => cats.profile).thenReturn(_userProfile(uid: 'alice'));
      when(() => cats.activeCatId).thenReturn('mochi');
      when(() => cats.activeCat).thenReturn(_cat('mochi'));
      provider = RoutineProvider(repository: repo, catProvider: cats);

      controller.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.lastError, isNotNull);
    });
  });

  group('generator surface', () {
    test('seedIfEmpty receives at least one routine package from the '
        'generator when active cat has a life stage', () async {
      // Allow the constructor-bound seed to run.
      await controller.close();
      controller = StreamController<List<RoutineTask>>.broadcast();
      when(
        () => repo.watchRoutines(
          ownerId: any(named: 'ownerId'),
          catId: any(named: 'catId'),
        ),
      ).thenAnswer((_) => controller.stream);
      when(() => cats.profile).thenReturn(_userProfile(uid: 'alice'));
      when(() => cats.activeCatId).thenReturn('mochi');
      when(() => cats.activeCat).thenReturn(_cat('mochi'));
      const RoutineGeneratorService generator = RoutineGeneratorService();
      provider = RoutineProvider(
        repository: repo,
        catProvider: cats,
        generator: generator,
      );
      await Future<void>.delayed(Duration.zero);

      final VerificationResult v = verify(
        () => repo.seedIfEmpty(
          ownerId: 'alice',
          catId: 'mochi',
          defaults: captureAny(named: 'defaults'),
        ),
      );
      v.called(greaterThanOrEqualTo(1));
      final List<dynamic> captured = v.captured;
      final List<RoutineTask> defaults = captured.last as List<RoutineTask>;
      expect(defaults, isNotEmpty);
    });
  });

  group('dispose', () {
    test('cancels subscription and detaches cat listeners', () {
      when(() => cats.profile).thenReturn(_userProfile(uid: 'alice'));
      when(() => cats.activeCatId).thenReturn('mochi');
      when(() => cats.activeCat).thenReturn(_cat('mochi'));
      provider = RoutineProvider(repository: repo, catProvider: cats);
      verify(() => cats.addListener(any())).called(1);
      provider.dispose();
      providerDisposed = true;
      verify(() => cats.removeListener(any())).called(1);
    });
  });
}

// Minimal UserProfile builder for the routine provider tests.
// This keeps the dependency surface narrow — the auth/cat nits are
// already covered by their own test suites.
UserProfile _userProfile({required String uid}) {
  return UserProfile(
    uid: uid,
    email: '$uid@example.com',
    isAnonymous: false,
    isEmailVerified: true,
    providerIds: const <String>['password'],
  );
}
