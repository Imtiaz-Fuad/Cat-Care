import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_life_stage.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/services/app_logger.dart';
import '../../cats/providers/cat_provider.dart';
import '../repositories/routine_repository.dart';
import '../services/routine_generator_service.dart';

/// State machine for the "routine" feature surface.
///
/// The provider:
///   * subscribes to [CatProvider] and rebinds its Firestore stream to
///     whichever cat is currently active;
///   * exposes the full routine list, today's view, and per-bucket
///     counts (so Home can render the completion ring);
///   * fires the [RoutineGeneratorService] the first time a fresh cat
///     has no routines, so the user always has a sensible starting
///     list;
///   * drives every mutation through [RoutineRepository] and surfaces
///     failures via [lastError].
class RoutineProvider extends ChangeNotifier {
  RoutineProvider({
    required RoutineRepository repository,
    required CatProvider catProvider,
    RoutineGeneratorService? generator,
    // ignore: prefer_initializing_formals
  }) : repository = repository,
       // ignore: prefer_initializing_formals
       catProvider = catProvider,
       _generator = generator ?? const RoutineGeneratorService() {
    catProvider.addListener(_handleCatChange);
    _catListeners.add(_handleCatChange);
    // Kick the first bind off the current active cat.
    _handleCatChange();
  }

  final RoutineRepository repository;
  final CatProvider catProvider;
  final RoutineGeneratorService _generator;

  StreamSubscription<List<RoutineTask>>? _sub;
  final List<VoidCallback> _catListeners = <VoidCallback>[];

  List<RoutineTask> _routines = const <RoutineTask>[];
  bool _streamReady = false;
  bool _seededForActive = false;
  bool _busy = false;
  bool _disposed = false;
  AppFailure? _lastError;

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  /// All routines tracked for the active cat.
  List<RoutineTask> get routines => List<RoutineTask>.unmodifiable(_routines);

  /// Routines the active cat should perform *today*. Done / not-done
  /// is derived from [RoutineTask.lastCompletedAt] being on or after
  /// today's local midnight.
  List<RoutineTask> get todaysRoutines {
    final DateTime midnight = _todayMidnight();
    final DateTime tomorrow = midnight.add(const Duration(days: 1));
    return _routines
        .where(
          (r) =>
              r.timeOfDay == null ||
              (r.timeOfDay!.isAfter(
                    midnight.subtract(const Duration(seconds: 1)),
                  ) &&
                  r.timeOfDay!.isBefore(tomorrow)) ||
              r.lastCompletedAt == null ||
              r.lastCompletedAt!.isBefore(midnight),
        )
        .toList(growable: false);
  }

  /// Number of routines completed today.
  int get completedTodayCount {
    final DateTime midnight = _todayMidnight();
    return _routines
        .where(
          (r) =>
              r.lastCompletedAt != null &&
              !r.lastCompletedAt!.isBefore(midnight),
        )
        .length;
  }

  /// Total number of routines the user has set up. Drives the Home
  /// completion ring denominator; "0" prompts users to add their
  /// first routine.
  int get totalRoutineCount => _routines.length;

  /// Completion percentage for today (0–100, integer).
  int get completionPercent {
    final int total = _routines.length;
    if (total == 0) return 0;
    final int done = completedTodayCount;
    return ((done / total) * 100).round().clamp(0, 100);
  }

  /// Stream-ready flag; used by the UI to differentiate "empty
  /// because still loading" from "empty because the cat has no
  /// routines yet".
  bool get hasLoaded => _streamReady;

  bool get isBusy => _busy;

  AppFailure? get lastError => _lastError;

  /// Toggle the completion state for [task]. Persists through the
  /// repository; the watcher re-emits so the UI updates from a single
  /// source of truth.
  Future<void> setCompletion(RoutineTask task, {required bool done}) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await repository.updateTask(
        ownerId: ownerId,
        task: task,
        completed: done,
      );
    });
  }

  /// Create a brand-new routine for the active cat. Returns the
  /// stored task on success, `null` on failure.
  Future<RoutineTask?> createTask({
    required String title,
    required String category,
    DateTime? timeOfDay,
    String repeat = 'daily',
    bool reminder = false,
    String? notes,
  }) async {
    final String? ownerId = _ownerId;
    final String? catId = catProvider.activeCatId;
    if (ownerId == null || catId == null) return null;
    RoutineTask? created;
    _runGuarded(() async {
      created = await repository.createTask(
        ownerId: ownerId,
        task: RoutineTask(
          id: '',
          catId: catId,
          title: title,
          category: category,
          timeOfDay: timeOfDay,
          repeat: repeat,
          reminder: reminder,
          notes: notes,
        ),
      );
    });
    return created;
  }

  /// Persist edits to an existing task.
  Future<void> updateTask({
    required RoutineTask task,
    String? title,
    String? category,
    DateTime? timeOfDay,
    String? repeat,
    bool? reminder,
    Object? notes = _sentinel,
  }) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await repository.updateTask(
        ownerId: ownerId,
        task: task.copyWith(
          title: title ?? task.title,
          category: category ?? task.category,
          timeOfDay: timeOfDay ?? task.timeOfDay,
          repeat: repeat ?? task.repeat,
          reminder: reminder ?? task.reminder,
          notes: identical(notes, _sentinel) ? task.notes : notes as String?,
        ),
      );
    });
  }

  Future<void> deleteTask(RoutineTask task) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await repository.deleteTask(
        ownerId: ownerId,
        catId: task.catId,
        taskId: task.id,
      );
    });
  }

  /// Re-seed the active cat's defaults if it currently has zero
  /// routines. Called automatically on first bind; exposed for the
  /// "regenerate" button on the Routine screen.
  Future<int> reseedDefaults() async {
    final String? ownerId = _ownerId;
    final CatProfile? cat = catProvider.activeCat;
    if (ownerId == null || cat == null) return 0;
    final List<RoutineTask> defaults = _generator.generate(
      lifeStage: cat.lifeStage,
      priorities: cat.priorities,
      catId: cat.id,
    );
    int added = 0;
    _runGuarded(() async {
      final List<RoutineTask> addedTasks = await repository.seedIfEmpty(
        ownerId: ownerId,
        catId: cat.id,
        defaults: defaults,
      );
      added = addedTasks.length;
    });
    return added;
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  String? get _ownerId => catProvider.profile?.uid;

  void _handleCatChange() {
    final String? ownerId = _ownerId;
    final String? catId = catProvider.activeCatId;
    if (ownerId == null || catId == null) {
      // No active cat yet. Drop the stream and flip [_streamReady]
      // true so the UI exits the loading state and shows the empty /
      // no-active-cat view instead of spinning forever.
      _sub?.cancel();
      _sub = null;
      _routines = const <RoutineTask>[];
      _streamReady = true;
      _seededForActive = false;
      notifyListeners();
      return;
    }
    final CatProfile? cat = catProvider.activeCat;
    _bind(
      ownerId: ownerId,
      catId: catId,
      lifeStage: cat?.lifeStage,
      priorities: cat?.priorities ?? const <String>[],
      force: false,
    );
  }

  void _bind({
    required String ownerId,
    required String catId,
    required CatLifeStage? lifeStage,
    required List<String> priorities,
    required bool force,
  }) {
    if (_disposed) return;
    if (!force) {
      // Always subscribe to the cat's routines, even when seeding —
      // the seed call uses `seedIfEmpty` so it can race safely.
      _sub?.cancel();
      _seededForActive = false;
      _sub = repository
          .watchRoutines(ownerId: ownerId, catId: catId)
          .listen(
            (List<RoutineTask> next) {
              _routines = next;
              _streamReady = true;
              notifyListeners();
            },
            onError: (Object error, StackTrace stack) {
              AppLogger.e('RoutineProvider: stream error', error, stack);
              _lastError = error is AppFailure
                  ? error
                  : UnknownFailure(
                      error.toString(),
                      code: 'routine-stream-error',
                    );
              notifyListeners();
            },
          );
    }

    if (!_seededForActive && lifeStage != null) {
      _seededForActive = true;
      _runGuarded(() async {
        final List<RoutineTask> defaults = _generator.generate(
          lifeStage: lifeStage,
          priorities: priorities,
          catId: catId,
        );
        await repository.seedIfEmpty(
          ownerId: ownerId,
          catId: catId,
          defaults: defaults,
        );
      });
    }
  }

  void _runGuarded(Future<void> Function() action) {
    if (_disposed) return;
    _setBusy(true);
    clearError();
    () async {
      try {
        await action();
      } on AppFailure catch (failure) {
        _lastError = failure;
        AppLogger.w('RoutineProvider action failed: $failure');
      } catch (error, stack) {
        _lastError = UnknownFailure(error.toString(), code: 'routine-unknown');
        AppLogger.e('RoutineProvider: unexpected error', error, stack);
      } finally {
        if (!_disposed) _setBusy(false);
      }
    }();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  static DateTime _todayMidnight() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    for (final VoidCallback listener in _catListeners) {
      catProvider.removeListener(listener);
    }
    _catListeners.clear();
    super.dispose();
  }
}

const Object _sentinel = Object();
