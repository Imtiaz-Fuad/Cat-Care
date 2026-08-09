import 'package:cat_care/core/models/content/food_item.dart';
import 'package:cat_care/core/models/content/safety_guidance.dart';
import 'package:cat_care/core/models/content/vaccine_info.dart';
import 'package:cat_care/core/services/content/content_backend.dart';
import 'package:cat_care/core/services/content/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory `ContentBackend` that returns canned maps and tracks which
/// categories + ids were requested. Used to assert that the repository
/// falls back deterministically when the primary backend has gaps.
class _FakeBackend implements ContentBackend {
  _FakeBackend({
    this.byId = const <String, Map<String, dynamic>>{},
    this.byCategory = const <String, List<Map<String, dynamic>>>{},
  });

  final Map<String, Map<String, dynamic>> byId;
  final Map<String, List<Map<String, dynamic>>> byCategory;

  String _key(String category, String id) => '$category::$id';

  @override
  Future<Map<String, dynamic>?> fetchOne({
    required String category,
    required String id,
  }) async {
    return byId[_key(category, id)];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String category) async {
    return byCategory[category] ?? const <Map<String, dynamic>>[];
  }
}

Map<String, dynamic> _foodJson(String id) => <String, dynamic>{
      'id': id,
      'name': 'Sample $id',
      'foodType': 'dry',
      'missingData': false,
    };

Map<String, dynamic> _safetyJson(String id) => <String, dynamic>{
      'id': id,
      'title': 'Sample $id',
      'severity': 'medium',
      'missingData': false,
    };

Map<String, dynamic> _vaccineJson(String code) => <String, dynamic>{
      'code': code,
      'name': 'Sample $code',
      'description': 'desc',
      'boosterIntervalDays': 365,
      'missingData': false,
    };

void main() {
  group('ContentRepository primary → fallback behaviour', () {
    test('getFoodItem falls back when primary returns null', () async {
      final _FakeBackend primary = _FakeBackend();
      final _FakeBackend fallback = _FakeBackend(
        byId: <String, Map<String, dynamic>>{
          'food::placeholder_food_001': _foodJson('placeholder_food_001'),
        },
      );
      final ContentRepository repo = ContentRepository(
        primary: primary,
        fallback: fallback,
      );
      final FoodItem? item =
          await repo.getFoodItem('placeholder_food_001');
      expect(item, isNotNull);
      expect(item!.id, 'placeholder_food_001');
      expect(item.missingData, isFalse);
    });

    test('getFoodItem returns null when both backends miss', () async {
      final ContentRepository repo = ContentRepository(
        primary: _FakeBackend(),
        fallback: _FakeBackend(),
      );
      expect(await repo.getFoodItem('missing'), isNull);
    });

    test('primary result wins over fallback for getFoodItem', () async {
      final _FakeBackend primary = _FakeBackend(
        byId: <String, Map<String, dynamic>>{
          'food::f': _foodJson('f')..['name'] = 'from-primary',
        },
      );
      final _FakeBackend fallback = _FakeBackend(
        byId: <String, Map<String, dynamic>>{
          'food::f': _foodJson('f')..['name'] = 'from-fallback',
        },
      );
      final ContentRepository repo = ContentRepository(
        primary: primary,
        fallback: fallback,
      );
      final FoodItem? item = await repo.getFoodItem('f');
      expect(item, isNotNull);
      expect(item!.name, 'from-primary');
    });

    test('listSafetyGuidance falls back when primary list is empty', () async {
      final _FakeBackend primary = _FakeBackend(
        byCategory: <String, List<Map<String, dynamic>>>{
          'safety': <Map<String, dynamic>>[],
        },
      );
      final _FakeBackend fallback = _FakeBackend(
        byCategory: <String, List<Map<String, dynamic>>>{
          'safety': <Map<String, dynamic>>[
            _safetyJson('s1'),
            _safetyJson('s2'),
          ],
        },
      );
      final ContentRepository repo = ContentRepository(
        primary: primary,
        fallback: fallback,
      );
      final List<SafetyGuidance> items = await repo.listSafetyGuidance();
      expect(items, hasLength(2));
      expect(items.first.title, 'Sample s1');
    });

    test('listSafetyGuidance returns primary list when non-empty', () async {
      final _FakeBackend primary = _FakeBackend(
        byCategory: <String, List<Map<String, dynamic>>>{
          'safety': <Map<String, dynamic>>[_safetyJson('primary_only')],
        },
      );
      final _FakeBackend fallback = _FakeBackend(
        byCategory: <String, List<Map<String, dynamic>>>{
          'safety': <Map<String, dynamic>>[_safetyJson('fallback_should_ignore')],
        },
      );
      final ContentRepository repo = ContentRepository(
        primary: primary,
        fallback: fallback,
      );
      final List<SafetyGuidance> items = await repo.listSafetyGuidance();
      expect(items, hasLength(1));
      expect(items.first.id, 'primary_only');
    });

    test('getVaccineInfo parses via code key', () async {
      final _FakeBackend fallback = _FakeBackend(
        byId: <String, Map<String, dynamic>>{
          'vaccine::FVRCP': _vaccineJson('FVRCP'),
        },
      );
      final ContentRepository repo = ContentRepository(
        primary: _FakeBackend(),
        fallback: fallback,
      );
      final VaccineInfo? v = await repo.getVaccineInfo('FVRCP');
      expect(v, isNotNull);
      expect(v!.code, 'FVRCP');
      expect(v.boosterIntervalDays, 365);
    });
  });
}