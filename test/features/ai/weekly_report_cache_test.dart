// Tests for the on-device weekly-report cache.
//
// Verifies that:
//   * `get` returns null when nothing is stored.
//   * `put` round-trips through SharedPreferences.
//   * `get` flags `fromCache` so the UI can render a "(cached)" badge.
//   * `clear` wipes every entry under the cache prefix.
//   * Missing prefs (tests without `setMockInitialValues`) is a no-op.
//
// Run with:
//   flutter test test/features/ai/weekly_report_cache_test.dart
import 'package:cat_care/features/ai/repositories/ai_repository.dart'
    show WeeklyReportResult;
import 'package:cat_care/features/ai/utils/weekly_report_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeeklyReportCache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('get returns null when nothing is stored', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeeklyReportCache cache = WeeklyReportCache(prefs: prefs);
      expect(await cache.get('cat-1', '2026-W34'), isNull);
    });

    test('put + get round-trip and flag fromCache=true', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeeklyReportCache cache = WeeklyReportCache(prefs: prefs);
      final DateTime now = DateTime.utc(2026, 8, 24, 12, 0, 0);
      await cache.put(
        'cat-1',
        '2026-W34',
        const WeeklyReportResult(
          text: 'cached summary',
          weekId: '2026-W34',
          fromCache: false,
        ).copyWith(generatedAt: now),
      );

      final WeeklyReportResult? got = await cache.get('cat-1', '2026-W34');
      expect(got, isNotNull);
      expect(got!.text, 'cached summary');
      expect(got.weekId, '2026-W34');
      expect(got.fromCache, isTrue);
      expect(got.generatedAt, equals(now));
      expect(got.noData, isFalse);
    });

    test('keys are namespaced by prefix so clear() leaves other prefs alone',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'other.key': 'leave-me',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai.weeklyReport.cat-1.2026-W34', 'old');
      await prefs.setString('ai.weeklyReport.cat-1.2026-W35', 'old');
      await prefs.setString('ai.weeklyReport.cat-2.2026-W34', 'old');

      final WeeklyReportCache cache = WeeklyReportCache(prefs: prefs);
      await cache.clear();

      expect(prefs.getString('other.key'), 'leave-me');
      expect(prefs.getString('ai.weeklyReport.cat-1.2026-W34'), isNull);
      expect(prefs.getString('ai.weeklyReport.cat-1.2026-W35'), isNull);
      expect(prefs.getString('ai.weeklyReport.cat-2.2026-W34'), isNull);
    });

    test('custom prefix is honoured', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final WeeklyReportCache cache =
          WeeklyReportCache(prefs: prefs, prefix: 'test.cache');
      await cache.put(
        'cat-9',
        '2026-W34',
        const WeeklyReportResult(
          text: 'scoped',
          weekId: '2026-W34',
        ),
      );

      expect(
        prefs.getString('test.cache.cat-9.2026-W34'),
        isNotNull,
      );
      expect(
        prefs.getString('ai.weeklyReport.cat-9.2026-W34'),
        isNull,
      );
    });

    test('no-prefs constructor is a safe no-op', () async {
      final WeeklyReportCache cache = WeeklyReportCache();
      expect(await cache.get('cat-1', '2026-W34'), isNull);
      await cache.put(
        'cat-1',
        '2026-W34',
        const WeeklyReportResult(text: 'x', weekId: '2026-W34'),
      );
      await cache.clear();
    });

    test('corrupt entry returns null instead of throwing', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'ai.weeklyReport.cat-1.2026-W34',
        '{not valid json',
      );
      final WeeklyReportCache cache = WeeklyReportCache(prefs: prefs);
      expect(await cache.get('cat-1', '2026-W34'), isNull);
    });
  });
}

extension on WeeklyReportResult {
  WeeklyReportResult copyWith({DateTime? generatedAt}) {
    return WeeklyReportResult(
      text: text,
      weekId: weekId,
      generatedAt: generatedAt ?? this.generatedAt,
      fromCache: fromCache,
      noData: noData,
    );
  }
}