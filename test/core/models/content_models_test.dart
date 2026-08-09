import 'package:cat_care/core/models/content/breed_info.dart';
import 'package:cat_care/core/models/content/deworming_info.dart';
import 'package:cat_care/core/models/content/emergency_guidance.dart';
import 'package:cat_care/core/models/content/food_item.dart';
import 'package:cat_care/core/models/content/food_recommendation.dart';
import 'package:cat_care/core/models/content/kitten_milestone.dart';
import 'package:cat_care/core/models/content/safety_guidance.dart';
import 'package:cat_care/core/models/content/vaccine_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodItem', () {
    test('placeholder JSON decodes with missingData=true', () {
      final FoodItem item = FoodItem.fromJson(<String, dynamic>{
        'id': 'placeholder_food_001',
        'name': '[CONTENT PLACEHOLDER]',
        'foodType': 'dry',
      });
      expect(item.id, 'placeholder_food_001');
      expect(item.missingData, isTrue);
      expect(item.suitableLifeStages, isEmpty);
    });

    test('fromJson → toJson is lossless for required fields', () {
      const FoodItem original = FoodItem(
        id: 'food_42',
        name: 'Sample',
        foodType: 'wet',
        brand: 'Acme',
        suitableLifeStages: <String>['adult', 'senior'],
        typicalServingGrams: 85,
        caloriesPerServing: 95,
        proteinPercent: 10.5,
        fatPercent: 5.5,
        fiberPercent: 1.0,
        moisturePercent: 78.0,
        missingData: false,
      );
      final Map<String, dynamic> json = original.toJson();
      final FoodItem round = FoodItem.fromJson(json);
      expect(round.id, original.id);
      expect(round.name, original.name);
      expect(round.foodType, original.foodType);
      expect(round.suitableLifeStages, original.suitableLifeStages);
      expect(round.typicalServingGrams, original.typicalServingGrams);
      expect(round.proteinPercent, original.proteinPercent);
      expect(round.missingData, isFalse);
    });

    test('missingData defaults to true when absent in JSON', () {
      final FoodItem item = FoodItem.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'x',
        'foodType': 'treat',
      });
      expect(item.missingData, isTrue);
    });
  });

  group('FoodRecommendation', () {
    test('placeholder round-trip preserves missingData', () {
      final FoodRecommendation rec = FoodRecommendation.fromJson(
        <String, dynamic>{
          'id': 'placeholder_rec_kitten_moderate',
          'lifeStage': 'kitten',
          'activityLevel': 'moderate',
        },
      );
      expect(rec.lifeStage, 'kitten');
      expect(rec.missingData, isTrue);
      final Map<String, dynamic> json = rec.toJson();
      final FoodRecommendation again = FoodRecommendation.fromJson(json);
      expect(again.id, rec.id);
      expect(again.missingData, rec.missingData);
    });
  });

  group('SafetyGuidance', () {
    test('decodes severity + empty action lists', () {
      final SafetyGuidance s = SafetyGuidance.fromJson(<String, dynamic>{
        'id': 's1',
        'title': 'Sample',
        'severity': 'high',
      });
      expect(s.severity, 'high');
      expect(s.symptoms, isEmpty);
      expect(s.immediateActions, isEmpty);
      expect(s.missingData, isTrue);
    });
  });

  group('VaccineInfo', () {
    test('boosterIntervalDays is required and parses from int', () {
      final VaccineInfo v = VaccineInfo.fromJson(<String, dynamic>{
        'code': 'FVRCP',
        'name': 'FVRCP',
        'description': '',
        'boosterIntervalDays': 365,
      });
      expect(v.boosterIntervalDays, 365);
      expect(v.core, isTrue);
      expect(v.missingData, isTrue);
    });
  });

  group('DewormingInfo', () {
    test('scheduleMonths parses integer list', () {
      final DewormingInfo d = DewormingInfo.fromJson(<String, dynamic>{
        'id': 'd1',
        'label': 'Sample',
        'intervalDays': 30,
        'scheduleMonths': <int>[1, 2, 3, 6],
      });
      expect(d.scheduleMonths, <int>[1, 2, 3, 6]);
      expect(d.intervalDays, 30);
    });
  });

  group('BreedInfo', () {
    test('typicalWeightKg parses double list', () {
      final BreedInfo b = BreedInfo.fromJson(<String, dynamic>{
        'id': 'b1',
        'name': 'Sample',
        'typicalWeightKg': <double>[3.0, 6.0],
        'activityLevel': 'high',
        'groomingNeeds': 'low',
      });
      expect(b.typicalWeightKg, <double>[3.0, 6.0]);
      expect(b.activityLevel, 'high');
    });
  });

  group('EmergencyGuidance', () {
    test('contactVetImmediately defaults to true when absent', () {
      final EmergencyGuidance e = EmergencyGuidance.fromJson(
        <String, dynamic>{
          'id': 'e1',
          'title': 'Sample',
          'severity': 'urgent',
        },
      );
      expect(e.contactVetImmediately, isTrue);
      expect(e.missingData, isTrue);
    });
  });

  group('KittenMilestone', () {
    test('expectedAgeWeeks parses int', () {
      final KittenMilestone k = KittenMilestone.fromJson(<String, dynamic>{
        'id': 'k1',
        'title': 'Sample',
        'expectedAgeWeeks': 8,
      });
      expect(k.expectedAgeWeeks, 8);
      expect(k.missingData, isTrue);
    });
  });
}