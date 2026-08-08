// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:cat_care/core/models/content/breed_info.dart';
import 'package:cat_care/core/models/content/deworming_info.dart';
import 'package:cat_care/core/models/content/emergency_guidance.dart';
import 'package:cat_care/core/models/content/food_item.dart';
import 'package:cat_care/core/models/content/food_recommendation.dart';
import 'package:cat_care/core/models/content/kitten_milestone.dart';
import 'package:cat_care/core/models/content/safety_guidance.dart';
import 'package:cat_care/core/models/content/vaccine_info.dart';
import 'package:cat_care/core/services/content/content_backend.dart';

/// Firestore categories used by the content layer. Centralized so the
/// repository and tests agree on the path shape.
class ContentCategory {
  ContentCategory._();
  static const String food = 'food';
  static const String foodRecommendation = 'food_recommendation';
  static const String safety = 'safety';
  static const String vaccine = 'vaccine';
  static const String deworming = 'deworming';
  static const String breed = 'breed';
  static const String emergency = 'emergency';
  static const String kittenMilestone = 'kitten_milestone';
}

/// Single source of truth for factual content. UI calls this repository
/// and receives typed content models — never raw maps. Per PRD §10,
/// every entry may carry `missingData == true` so the UI must render a
/// `[CONTENT PLACEHOLDER]` banner.
class ContentRepository {
  ContentRepository({
    required ContentBackend primary,
    required ContentBackend fallback,
  })  : _primary = primary,
        _fallback = fallback;

  // Note: the linter suggests `this._primary` style initializing formals.
  // We keep the explicit form so the public surface is `primary` /
  // `fallback` while the storage fields remain private.

  final ContentBackend _primary;
  final ContentBackend _fallback;

  /// Fetch a single document from the primary backend; fall back to the
  /// seed backend when the primary returns `null`.
  Future<Map<String, dynamic>?> _fetchOne({
    required String category,
    required String id,
  }) async {
    final primary = await _primary.fetchOne(category: category, id: id);
    if (primary != null) return primary;
    return _fallback.fetchOne(category: category, id: id);
  }

  /// List all documents from the primary backend; fall back to the
  /// seed backend when the primary returns an empty list.
  Future<List<Map<String, dynamic>>> _fetchAll(String category) async {
    final primary = await _primary.fetchAll(category);
    if (primary.isNotEmpty) return primary;
    return _fallback.fetchAll(category);
  }

  Future<FoodItem?> getFoodItem(String id) async =>
      _decode<FoodItem>(await _fetchOne(category: ContentCategory.food, id: id),
          FoodItem.fromJson);

  Future<List<FoodItem>> listFoodItems() async => _decodeAll<FoodItem>(
        await _fetchAll(ContentCategory.food),
        FoodItem.fromJson,
      );

  Future<FoodRecommendation?> getFoodRecommendation(String id) async =>
      _decode<FoodRecommendation>(
        await _fetchOne(
          category: ContentCategory.foodRecommendation,
          id: id,
        ),
        FoodRecommendation.fromJson,
      );

  Future<List<FoodRecommendation>> listFoodRecommendations() async =>
      _decodeAll<FoodRecommendation>(
        await _fetchAll(ContentCategory.foodRecommendation),
        FoodRecommendation.fromJson,
      );

  Future<SafetyGuidance?> getSafetyGuidance(String id) async =>
      _decode<SafetyGuidance>(
        await _fetchOne(category: ContentCategory.safety, id: id),
        SafetyGuidance.fromJson,
      );

  Future<List<SafetyGuidance>> listSafetyGuidance() async =>
      _decodeAll<SafetyGuidance>(
        await _fetchAll(ContentCategory.safety),
        SafetyGuidance.fromJson,
      );

  Future<VaccineInfo?> getVaccineInfo(String code) async =>
      _decode<VaccineInfo>(
        await _fetchOne(category: ContentCategory.vaccine, id: code),
        VaccineInfo.fromJson,
      );

  Future<List<VaccineInfo>> listVaccineInfo() async => _decodeAll<VaccineInfo>(
        await _fetchAll(ContentCategory.vaccine),
        VaccineInfo.fromJson,
      );

  Future<DewormingInfo?> getDewormingInfo(String id) async =>
      _decode<DewormingInfo>(
        await _fetchOne(category: ContentCategory.deworming, id: id),
        DewormingInfo.fromJson,
      );

  Future<List<DewormingInfo>> listDewormingInfo() async =>
      _decodeAll<DewormingInfo>(
        await _fetchAll(ContentCategory.deworming),
        DewormingInfo.fromJson,
      );

  Future<BreedInfo?> getBreedInfo(String id) async => _decode<BreedInfo>(
        await _fetchOne(category: ContentCategory.breed, id: id),
        BreedInfo.fromJson,
      );

  Future<List<BreedInfo>> listBreedInfo() async => _decodeAll<BreedInfo>(
        await _fetchAll(ContentCategory.breed),
        BreedInfo.fromJson,
      );

  Future<EmergencyGuidance?> getEmergencyGuidance(String id) async =>
      _decode<EmergencyGuidance>(
        await _fetchOne(category: ContentCategory.emergency, id: id),
        EmergencyGuidance.fromJson,
      );

  Future<List<EmergencyGuidance>> listEmergencyGuidance() async =>
      _decodeAll<EmergencyGuidance>(
        await _fetchAll(ContentCategory.emergency),
        EmergencyGuidance.fromJson,
      );

  Future<KittenMilestone?> getKittenMilestone(String id) async =>
      _decode<KittenMilestone>(
        await _fetchOne(category: ContentCategory.kittenMilestone, id: id),
        KittenMilestone.fromJson,
      );

  Future<List<KittenMilestone>> listKittenMilestones() async =>
      _decodeAll<KittenMilestone>(
        await _fetchAll(ContentCategory.kittenMilestone),
        KittenMilestone.fromJson,
      );

  static T? _decode<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) builder,
  ) {
    if (json == null) return null;
    return builder(json);
  }

  static List<T> _decodeAll<T>(
    List<Map<String, dynamic>> rows,
    T Function(Map<String, dynamic>) builder,
  ) {
    return rows.map(builder).toList(growable: false);
  }
}
