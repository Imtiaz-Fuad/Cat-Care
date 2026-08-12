// ignore_for_file: directives_ordering
import 'dart:math' as math;

import '../../../core/models/cat_life_stage.dart';

/// Daily-range guidance for a cat's intake, used by the Home + Nutrition
/// screens to render "today vs target" progress widgets.
///
/// All values are computed at provider time from the active cat's
/// weight + life stage — there is no Firestore persistence for this
/// model (it's a derivation, not data).
class NutritionTarget {
  const NutritionTarget({
    required this.dailyFoodGrams,
    required this.dailyWaterMl,
    required this.dailyKcal,
    required this.mealsPerDay,
  });

  /// Recommended total grams of food per day (all meals combined).
  final double dailyFoodGrams;

  /// Recommended total water intake (ml/day).
  final double dailyWaterMl;

  /// Estimated daily energy requirement (kcal).
  final double dailyKcal;

  /// Recommended number of meals per day.
  final int mealsPerDay;

  /// Returns sensible defaults for a cat without a recorded weight.
  static const NutritionTarget fallback = NutritionTarget(
    dailyFoodGrams: 70,
    dailyWaterMl: 200,
    dailyKcal: 220,
    mealsPerDay: 3,
  );

  /// Compute a [NutritionTarget] from a cat's profile.
  ///
  /// Numbers are conservative mid-range estimates aligned with
  /// common veterinary sources (NRC/AAHA ballpark). The UI must
  /// always show *suggested* ranges, not medical prescriptions.
  factory NutritionTarget.forCat({
    required CatLifeStage lifeStage,
    double? weightKg,
    bool neutered = true,
    bool indoor = true,
  }) {
    final double w = (weightKg == null || weightKg <= 0) ? 4.0 : weightKg;
    // Resting energy requirement: 70 * kg^0.75 (NRC).
    final double rer = 70 * math.pow(w, 0.75).toDouble();
    // Daily energy requirement depends on life stage + activity.
    final double factor = _factorFor(lifeStage, neutered, indoor);
    final double kcal = rer * factor;
    // Convert kcal -> grams of dry food (≈ 3.5 kcal/g "average kibble").
    // We round to nearest 5g for nicer UI chips.
    final double gramsPerDay = (kcal / 3.5).roundToDouble();
    final double gramsPerDayRounded = (gramsPerDay / 5).round() * 5.0;
    // Water: ≈ 50ml/kg typical indoor cat baseline, bump for kittens.
    final double water = (w * _waterFactorFor(lifeStage)).roundToDouble();
    final int meals = _mealsFor(lifeStage);
    return NutritionTarget(
      dailyFoodGrams: gramsPerDayRounded,
      dailyWaterMl: water,
      dailyKcal: kcal.roundToDouble(),
      mealsPerDay: meals,
    );
  }

  static double _factorFor(CatLifeStage stage, bool neutered, bool indoor) {
    switch (stage) {
      case CatLifeStage.kitten:
        return 2.5; // growth
      case CatLifeStage.junior:
        return 2.0; // still growing
      case CatLifeStage.adult:
        return neutered ? 1.2 : 1.4 * (indoor ? 0.85 : 1.0);
      case CatLifeStage.mature:
        return neutered ? 1.1 : 1.3 * (indoor ? 0.8 : 1.0);
      case CatLifeStage.senior:
        return 1.0;
    }
  }

  static double _waterFactorFor(CatLifeStage stage) {
    switch (stage) {
      case CatLifeStage.kitten:
        return 70;
      case CatLifeStage.junior:
        return 60;
      case CatLifeStage.adult:
        return 50;
      case CatLifeStage.mature:
        return 50;
      case CatLifeStage.senior:
        return 55;
    }
  }

  static int _mealsFor(CatLifeStage stage) {
    switch (stage) {
      case CatLifeStage.kitten:
        return 4;
      case CatLifeStage.junior:
        return 3;
      case CatLifeStage.adult:
      case CatLifeStage.mature:
      case CatLifeStage.senior:
        return 2;
    }
  }
}
