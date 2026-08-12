import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/models/feeding_entry.dart';
import '../../../core/models/water_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../cats/providers/cat_provider.dart';
import '../models/nutrition_target.dart';
import '../repositories/feeding_repository.dart';
import '../repositories/water_repository.dart';

/// Aggregate state for the "nutrition" feature surface.
///
/// Owns two stream subscriptions (feedings + water) and rebinds them
/// whenever the active cat changes. Exposes:
///   * today's totals (grams / ml / meals)
///   * a [NutritionTarget] derived from the active cat's profile
///   * 7-day daily aggregates (for the Home sparkline / reports)
///   * mutation actions (add / update / delete) that route through
///     the two repositories
///
/// All errors are translated into [AppFailure] via [lastError].
class NutritionProvider extends ChangeNotifier {
  NutritionProvider({
    required FeedingRepository feedingRepository,
    required WaterRepository waterRepository,
    required CatProvider catProvider,
    DateTime Function()? clock,
    // ignore: prefer_initializing_formals
  })  : feedingRepository = feedingRepository,
        // ignore: prefer_initializing_formals
        waterRepository = waterRepository,
        catProvider = catProvider,
        _clock = clock ?? DateTime.now {
    catProvider.addListener(_handleCatChange);
    _catListeners.add(_handleCatChange);
    _handleCatChange();
  }

  final FeedingRepository feedingRepository;
  final WaterRepository waterRepository;
  final CatProvider catProvider;
  final DateTime Function() _clock;

  StreamSubscription<List<FeedingEntry>>? _feedingSub;
  StreamSubscription<List<WaterEntry>>? _waterSub;
  final List<VoidCallback> _catListeners = <VoidCallback>[];

  List<FeedingEntry> _feedings = const <FeedingEntry>[];
  List<WaterEntry> _water = const <WaterEntry>[];
  bool _streamReady = false;
  bool _busy = false;
  bool _disposed = false;
  AppFailure? _lastError;

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  /// All feeding entries for the active cat, newest first.
  List<FeedingEntry> get feedings => _feedings;

  /// All water entries for the active cat, newest first.
  List<WaterEntry> get water => _water;

  /// True after at least one snapshot has been emitted.
  bool get hasLoaded => _streamReady;

  bool get isBusy => _busy;
  AppFailure? get lastError => _lastError;

  /// The currently active cat (or null if signed out / no cat yet).
  CatProfile? get activeCat => catProvider.activeCat;

  /// Recommended daily intake for the active cat based on its profile.
  /// Falls back to [NutritionTarget.fallback] when there's no active cat.
  NutritionTarget get target {
    final CatProfile? cat = activeCat;
    if (cat == null) return NutritionTarget.fallback;
    return NutritionTarget.forCat(
      lifeStage: cat.lifeStage,
      weightKg: cat.weightKg,
      neutered: cat.neutered,
      indoor: cat.indoor,
    );
  }

  /// Feedings whose `time` falls on today's local date.
  List<FeedingEntry> get todaysFeedings {
    final DateTime start = _todayMidnight();
    final DateTime end = start.add(const Duration(days: 1));
    return _feedings
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList(growable: false);
  }

  /// Water entries whose `time` falls on today's local date.
  List<WaterEntry> get todaysWater {
    final DateTime start = _todayMidnight();
    final DateTime end = start.add(const Duration(days: 1));
    return _water
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList(growable: false);
  }

  /// Total grams of food (g) consumed today.
  double get todaysFoodGrams {
    double sum = 0;
    for (final FeedingEntry entry in todaysFeedings) {
      // Only count gram-denominated entries toward the food target.
      if (entry.unit == 'g') sum += entry.amount;
    }
    return sum;
  }

  /// Total water (ml) consumed today.
  double get todaysWaterMl {
    double sum = 0;
    for (final WaterEntry entry in todaysWater) {
      sum += entry.amountMl;
    }
    return sum;
  }

  /// Number of meals (feeding entries) logged today.
  int get todaysMealCount => todaysFeedings.length;

  /// Food progress `0.0 - 1.0+` (can exceed 1.0 if overfed).
  double get foodProgress {
    final double dailyTarget = target.dailyFoodGrams;
    if (dailyTarget <= 0) return 0;
    return todaysFoodGrams / dailyTarget;
  }

  /// Water progress `0.0 - 1.0+`.
  double get waterProgress {
    final double dailyTarget = target.dailyWaterMl;
    if (dailyTarget <= 0) return 0;
    return todaysWaterMl / dailyTarget;
  }

  /// Daily totals for the past 7 days, oldest → newest, indexed by
  /// local-day offset (0 = 6 days ago, 6 = today).
  List<DailyTotals> get last7Days {
    final DateTime today = _todayMidnight();
    final List<DailyTotals> out = List<DailyTotals>.generate(7, (int i) {
      final DateTime day = today.subtract(Duration(days: 6 - i));
      return DailyTotals(day: day, foodGrams: 0, waterMl: 0, meals: 0);
    });
    for (final FeedingEntry entry in _feedings) {
      final int? idx = _indexOfDay(entry.time, today);
      if (idx == null) continue;
      if (entry.unit == 'g') {
        out[idx] = out[idx].copyWith(
          foodGrams: out[idx].foodGrams + entry.amount,
          meals: out[idx].meals + 1,
        );
      }
    }
    for (final WaterEntry entry in _water) {
      final int? idx = _indexOfDay(entry.time, today);
      if (idx == null) continue;
      out[idx] = out[idx].copyWith(
        waterMl: out[idx].waterMl + entry.amountMl,
      );
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Log a new feeding entry for the active cat.
  Future<FeedingEntry?> addFeeding({
    required String foodName,
    required String foodType,
    required double amount,
    String unit = 'g',
    DateTime? time,
    String? note,
    String? photoUrl,
  }) async {
    final String? ownerId = _ownerId;
    final String? catId = catProvider.activeCatId;
    if (ownerId == null || catId == null) return null;
    FeedingEntry? created;
    _runGuarded(() async {
      created = await feedingRepository.addEntry(
        ownerId: ownerId,
        entry: FeedingEntry(
          id: '',
          catId: catId,
          foodName: foodName,
          foodType: foodType,
          amount: amount,
          unit: unit,
          time: time ?? _clock(),
          photoUrl: photoUrl,
          note: note,
        ),
      );
    });
    return created;
  }

  /// Patch an existing feeding entry.
  Future<void> updateFeeding({
    required FeedingEntry entry,
    String? foodName,
    String? foodType,
    double? amount,
    String? unit,
    DateTime? time,
    Object? note = _sentinel,
    Object? photoUrl = _sentinel,
  }) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await feedingRepository.updateEntry(
        ownerId: ownerId,
        entry: entry.copyWith(
          foodName: foodName ?? entry.foodName,
          foodType: foodType ?? entry.foodType,
          amount: amount ?? entry.amount,
          unit: unit ?? entry.unit,
          time: time ?? entry.time,
          note: identical(note, _sentinel) ? entry.note : note as String?,
          photoUrl: identical(photoUrl, _sentinel)
              ? entry.photoUrl
              : photoUrl as String?,
        ),
      );
    });
  }

  /// Delete a feeding entry.
  Future<void> deleteFeeding(FeedingEntry entry) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await feedingRepository.deleteEntry(
        ownerId: ownerId,
        catId: entry.catId,
        entryId: entry.id,
      );
    });
  }

  /// Log a new water entry for the active cat.
  Future<WaterEntry?> addWater({
    required double amountMl,
    DateTime? time,
    String? note,
  }) async {
    final String? ownerId = _ownerId;
    final String? catId = catProvider.activeCatId;
    if (ownerId == null || catId == null) return null;
    WaterEntry? created;
    _runGuarded(() async {
      created = await waterRepository.addEntry(
        ownerId: ownerId,
        entry: WaterEntry(
          id: '',
          catId: catId,
          amountMl: amountMl,
          time: time ?? _clock(),
          note: note,
        ),
      );
    });
    return created;
  }

  /// Patch an existing water entry.
  Future<void> updateWater({
    required WaterEntry entry,
    double? amountMl,
    DateTime? time,
    Object? note = _sentinel,
  }) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await waterRepository.updateEntry(
        ownerId: ownerId,
        entry: entry.copyWith(
          amountMl: amountMl ?? entry.amountMl,
          time: time ?? entry.time,
          note: identical(note, _sentinel) ? entry.note : note as String?,
        ),
      );
    });
  }

  /// Delete a water entry.
  Future<void> deleteWater(WaterEntry entry) async {
    final String? ownerId = _ownerId;
    if (ownerId == null) return;
    _runGuarded(() async {
      await waterRepository.deleteEntry(
        ownerId: ownerId,
        catId: entry.catId,
        entryId: entry.id,
      );
    });
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
      _feedingSub?.cancel();
      _waterSub?.cancel();
      _feedingSub = null;
      _waterSub = null;
      _feedings = const <FeedingEntry>[];
      _water = const <WaterEntry>[];
      _streamReady = false;
      notifyListeners();
      return;
    }
    _bind(ownerId: ownerId, catId: catId);
  }

  void _bind({required String ownerId, required String catId}) {
    if (_disposed) return;
    _feedingSub?.cancel();
    _waterSub?.cancel();
    _feedingSub = feedingRepository
        .watchFeedings(ownerId: ownerId, catId: catId, limit: 200)
        .listen(
      (List<FeedingEntry> next) {
        _feedings = next;
        _streamReady = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        AppLogger.e('NutritionProvider: feeding stream error', error, stack);
        _lastError = error is AppFailure
            ? error
            : UnknownFailure(error.toString(), code: 'nutrition-feeding-stream');
        notifyListeners();
      },
    );
    _waterSub = waterRepository
        .watchWater(ownerId: ownerId, catId: catId, limit: 200)
        .listen(
      (List<WaterEntry> next) {
        _water = next;
        _streamReady = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        AppLogger.e('NutritionProvider: water stream error', error, stack);
        _lastError = error is AppFailure
            ? error
            : UnknownFailure(error.toString(), code: 'nutrition-water-stream');
        notifyListeners();
      },
    );
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
        AppLogger.w('NutritionProvider action failed: $failure');
      } catch (error, stack) {
        _lastError =
            UnknownFailure(error.toString(), code: 'nutrition-unknown');
        AppLogger.e('NutritionProvider: unexpected error', error, stack);
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

  DateTime _todayMidnight() {
    final DateTime now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  int? _indexOfDay(DateTime time, DateTime today) {
    final DateTime t = DateTime(time.year, time.month, time.day);
    final int diff = today.difference(t).inDays;
    if (diff < 0 || diff > 6) return null;
    return 6 - diff;
  }

  @override
  void dispose() {
    _disposed = true;
    _feedingSub?.cancel();
    _waterSub?.cancel();
    for (final VoidCallback listener in _catListeners) {
      catProvider.removeListener(listener);
    }
    _catListeners.clear();
    super.dispose();
  }
}

/// One bucket of the 7-day history.
class DailyTotals {
  const DailyTotals({
    required this.day,
    required this.foodGrams,
    required this.waterMl,
    required this.meals,
  });

  final DateTime day;
  final double foodGrams;
  final double waterMl;
  final int meals;

  DailyTotals copyWith({
    DateTime? day,
    double? foodGrams,
    double? waterMl,
    int? meals,
  }) {
    return DailyTotals(
      day: day ?? this.day,
      foodGrams: foodGrams ?? this.foodGrams,
      waterMl: waterMl ?? this.waterMl,
      meals: meals ?? this.meals,
    );
  }
}

/// Marker value used as the default parameter for nullable fields in
/// NutritionProvider so callers can distinguish "don't touch the field"
/// from "set the field to null".
const Object _sentinel = Object();

/// Public re-export of the sentinel so feature code (edit sheets, tests)
/// can reference the same instance when patching fields via [Object?]
/// parameters on this provider.
Object get clearFieldSentinel => _sentinel;
