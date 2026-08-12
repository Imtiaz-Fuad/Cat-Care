import '../../../core/models/cat_life_stage.dart';
import '../../../core/models/routine_task.dart';

/// Priority keys, also stored verbatim in `CatProfile.priorities`.
class RoutinePriorities {
  RoutinePriorities._();

  static const String feeding = 'feeding';
  static const String medicine = 'medicine';
  static const String water = 'water';
  static const String play = 'play';
  static const String brushing = 'brushing';
  static const String litter = 'litter';
  static const String exercise = 'exercise';
  static const String sleep = 'sleep';
  static const String grooming = 'grooming';
  static const String health = 'health';
  static const String vaccinations = 'vaccinations';

  static const List<String> all = <String>[
    feeding,
    medicine,
    water,
    play,
    brushing,
    litter,
    exercise,
    sleep,
    grooming,
    health,
    vaccinations,
  ];
}

/// Stable categories used inside [RoutineTask.category]. Drives the
/// Routine screen's icon and the timeline grouping.
class RoutineCategories {
  RoutineCategories._();

  static const String feeding = 'feeding';
  static const String medicine = 'medicine';
  static const String water = 'water';
  static const String play = 'play';
  static const String brushing = 'brushing';
  static const String litter = 'litter';
  static const String exercise = 'exercise';
  static const String sleep = 'sleep';
  static const String grooming = 'grooming';
}

/// Deterministic, rule-based default-routine generator.
///
/// Replaced by a Cloud Function later (per the implementation plan);
/// today this is the authoritative source of the starter routine set
/// every fresh cat gets. The output is stable: same input -> same
/// list (ids are intentionally blank so the repository can mint them
/// on write).
///
/// Rules of thumb:
///   * Adult baseline: 4 meals + water + play + litter + brushing.
///   * Kitten: 4 meals + play (more frequent) + litter + brushing.
///   * Senior: 3 meals + water + gentle play + litter.
///   * Any time the user has flagged `medicine`, `vaccinations`,
///     `grooming`, or `exercise` as a priority, the matching task is
///     appended (deduplicated by title).
class RoutineGeneratorService {
  const RoutineGeneratorService();

  List<RoutineTask> generate({
    required CatLifeStage lifeStage,
    required List<String> priorities,
    required String catId,
  }) {
    final List<RoutineTask> tasks = <RoutineTask>[];

    switch (lifeStage) {
      case CatLifeStage.kitten:
        tasks.addAll(<RoutineTask>[
          _task(catId, 'Morning meal', RoutineCategories.feeding, _h(7)),
          _task(catId, 'Mid-morning meal', RoutineCategories.feeding, _h(10)),
          _task(catId, 'Afternoon meal', RoutineCategories.feeding, _h(14)),
          _task(catId, 'Evening meal', RoutineCategories.feeding, _h(18)),
          _task(catId, 'Fresh water', RoutineCategories.water, _h(8)),
          _task(catId, 'Play session', RoutineCategories.play, _h(11)),
          _task(catId, 'Play session', RoutineCategories.play, _h(16)),
          _task(catId, 'Litter check', RoutineCategories.litter, _h(9)),
          _task(catId, 'Gentle brushing', RoutineCategories.brushing, _h(20)),
        ]);
      case CatLifeStage.junior:
        tasks.addAll(<RoutineTask>[
          _task(catId, 'Breakfast', RoutineCategories.feeding, _h(7, 30)),
          _task(catId, 'Lunch', RoutineCategories.feeding, _h(13)),
          _task(catId, 'Dinner', RoutineCategories.feeding, _h(19)),
          _task(catId, 'Fresh water', RoutineCategories.water, _h(9)),
          _task(catId, 'Play session', RoutineCategories.play, _h(17)),
          _task(catId, 'Litter check', RoutineCategories.litter, _h(10)),
          _task(catId, 'Brushing', RoutineCategories.brushing, _h(20)),
        ]);
      case CatLifeStage.adult:
        tasks.addAll(<RoutineTask>[
          _task(catId, 'Breakfast', RoutineCategories.feeding, _h(8)),
          _task(catId, 'Lunch', RoutineCategories.feeding, _h(13)),
          _task(catId, 'Dinner', RoutineCategories.feeding, _h(19)),
          _task(catId, 'Fresh water', RoutineCategories.water, _h(9)),
          _task(catId, 'Play session', RoutineCategories.play, _h(18)),
          _task(catId, 'Litter check', RoutineCategories.litter, _h(10)),
          _task(catId, 'Brushing', RoutineCategories.brushing, _h(20)),
        ]);
      case CatLifeStage.mature:
        tasks.addAll(<RoutineTask>[
          _task(catId, 'Breakfast', RoutineCategories.feeding, _h(8)),
          _task(catId, 'Lunch', RoutineCategories.feeding, _h(13, 30)),
          _task(catId, 'Dinner', RoutineCategories.feeding, _h(19)),
          _task(catId, 'Fresh water', RoutineCategories.water, _h(9)),
          _task(catId, 'Light play', RoutineCategories.play, _h(17)),
          _task(catId, 'Litter check', RoutineCategories.litter, _h(10)),
        ]);
      case CatLifeStage.senior:
        tasks.addAll(<RoutineTask>[
          _task(catId, 'Breakfast', RoutineCategories.feeding, _h(8)),
          _task(catId, 'Lunch', RoutineCategories.feeding, _h(13)),
          _task(catId, 'Dinner', RoutineCategories.feeding, _h(18, 30)),
          _task(catId, 'Fresh water', RoutineCategories.water, _h(9)),
          _task(catId, 'Litter check', RoutineCategories.litter, _h(10)),
          _task(catId, 'Quiet cuddle', RoutineCategories.play, _h(19)),
        ]);
    }

    if (priorities.contains(RoutinePriorities.medicine) &&
        !tasks.any((t) => t.category == RoutineCategories.medicine)) {
      tasks.add(_task(
        catId,
        'Medication',
        RoutineCategories.medicine,
        _h(8),
        reminder: true,
      ));
    }
    if (priorities.contains(RoutinePriorities.grooming) &&
        !tasks.any((t) => t.category == RoutineCategories.grooming)) {
      tasks.add(_task(
        catId,
        'Nail trim & grooming',
        RoutineCategories.grooming,
        _h(11),
      ));
    }
    if (priorities.contains(RoutinePriorities.exercise) &&
        !tasks.any(
          (t) =>
              t.title.toLowerCase().contains('exercise') ||
              t.category == RoutineCategories.exercise,
        )) {
      tasks.add(_task(
        catId,
        'Exercise / wand toy',
        RoutineCategories.exercise,
        _h(17),
      ));
    }

    tasks.sort((a, b) {
      final DateTime? ta = a.timeOfDay;
      final DateTime? tb = b.timeOfDay;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      final int byHour = ta.hour.compareTo(tb.hour);
      if (byHour != 0) return byHour;
      return ta.minute.compareTo(tb.minute);
    });

    return List<RoutineTask>.unmodifiable(tasks);
  }

  RoutineTask _task(
    String catId,
    String title,
    String category,
    DateTime time, {
    bool reminder = false,
  }) {
    return RoutineTask(
      id: '',
      catId: catId,
      title: title,
      category: category,
      timeOfDay: time,
      reminder: reminder,
    );
  }

  DateTime _h(int hour, [int minute = 0]) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
