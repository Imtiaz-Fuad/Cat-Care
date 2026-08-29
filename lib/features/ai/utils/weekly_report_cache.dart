import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/ai_repository.dart' show WeeklyReportResult;

/// On-device cache for the weekly AI report.
///
/// One entry per `(catId, weekId)` pair. The `weekId` is the ISO week
/// id computed by the UI (e.g. `2026-W34`) so the cache naturally
/// expires when the user opens the screen in a new week — no TTL
/// bookkeeping needed beyond writing the new entry.
///
/// Values are JSON-encoded [WeeklyReportResult] payloads minus
/// `weekId` (it's already in the key) and `fromCache` (always false
/// when written, true when read back).
///
/// The cache is intentionally not a [ChangeNotifier]; the
/// [AiProvider] already owns that lifecycle and refreshes on
/// `reset()` (sign-out).
class WeeklyReportCache {
  WeeklyReportCache({SharedPreferences? prefs, String? prefix})
      : _prefs = prefs,
        _prefix = prefix ?? defaultPrefix;

  /// Default key prefix used in production. Exposed for tests that
  /// want a clean namespace.
  static const String defaultPrefix = 'ai.weeklyReport';

  final SharedPreferences? _prefs;
  final String _prefix;

  String _key(String catId, String weekId) => '$_prefix.$catId.$weekId';

  /// Returns the cached report for `(catId, weekId)` or `null` when
  /// no entry exists or the stored value is malformed.
  ///
  /// The returned [WeeklyReportResult.fromCache] is always `true`.
  Future<WeeklyReportResult?> get(String catId, String weekId) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return null;
    final String? raw = prefs.getString(_key(catId, weekId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final String text = (map['text'] as String?) ?? '';
      final String? generatedAtIso = map['generatedAt'] as String?;
      final DateTime? generatedAt = generatedAtIso == null
          ? null
          : DateTime.tryParse(generatedAtIso);
      final bool noData = map['noData'] == true;
      return WeeklyReportResult(
        text: text,
        weekId: weekId,
        generatedAt: generatedAt,
        fromCache: true,
        noData: noData,
      );
    } catch (_) {
      // Corrupt cache entry → ignore. The screen will fall back to
      // a fresh API call.
      return null;
    }
  }

  /// Persist [result] under `(catId, weekId)`. Overwrites any
  /// existing entry. Failures are swallowed — losing a cache entry
  /// is never worse than re-running the API call.
  Future<void> put(
    String catId,
    String weekId,
    WeeklyReportResult result,
  ) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final Map<String, dynamic> map = <String, dynamic>{
      'text': result.text,
      'noData': result.noData,
      if (result.generatedAt != null)
        'generatedAt': result.generatedAt!.toIso8601String(),
    };
    await prefs.setString(_key(catId, weekId), jsonEncode(map));
  }

  /// Remove every cached report. Called from [AiProvider.reset]
  /// on sign-out so the next user does not inherit the previous
  /// owner's reads.
  Future<void> clear() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final List<String> keys = prefs
        .getKeys()
        .where((String k) => k.startsWith('$_prefix.'))
        .toList();
    for (final String k in keys) {
      await prefs.remove(k);
    }
  }
}
