import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/services/app_logger.dart';
import '../models/cat_weekly_summary.dart';
import '../utils/prompt_templates.dart';
import '../utils/weekly_report_cache.dart';

/// Client-side entry point for every AI surface (chat, weekly report,
/// food-label photo extraction).
///
/// The Gemini API key is read from `.env` at startup (`GEMINI_API_KEY`,
/// via `flutter_dotenv`) and passed into this repository at wiring
/// time. We POST directly to
/// `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=…`
/// with a JSON body shaped as the Gemini `generateContent` API
/// expects (`contents[].parts[]`, plus an optional `systemInstruction`).
///
/// No Firebase ID token is attached — there is no backend in front
/// of Gemini anymore. The per-device rate limiter is the only thing
/// standing between a runaway UI loop and the free-tier quota, and
/// it is split per feature so a chat-heavy day does not lock the user
/// out of the weekly report. See `docs/CLIENT_GEMINI_KEY.md` for the
/// accepted trade-off (key is recoverable from the AAB; cap is
/// best-effort, not a security boundary).
///
/// Responsibilities:
///   * Translate Flutter DTOs (cat profile + summary + history +
///     image bytes) into the Gemini `generateContent` JSON body.
///   * Translate every [DioException] into the matching
///     [AppFailure] subclass (400 → Validation, 401/403 → Auth/
///     Permission, 429 → Quota, 5xx → Network).
///   * Enforce a per-feature daily cap via [SharedPreferences]
///     (default: chat 20/day, weekly report 5/day, food-label
///     5/day; resets at UTC midnight).
///
/// [HttpTransport] is injected so tests can substitute a fake
/// without dragging `dio` adapters into the unit-test process.
/// [clock] is injectable for deterministic tests of the
/// rate-limiter UTC reset.
class AiRepository {
  AiRepository({
    required String apiKey,
    HttpTransport? httpClient,
    SharedPreferences? prefs,
    Duration? requestTimeout,
    RateLimitBuckets? buckets,
    DateTime Function()? clock,
    PromptTemplates? templates,
    WeeklyReportCache? cache,
    String model = defaultModel,
    String baseUrl = defaultBaseUrl,
  }) : _apiKey = apiKey,
       _http = httpClient ?? DioHttpTransport(),
       _prefs = prefs,
       _requestTimeout = requestTimeout ?? const Duration(seconds: 60),
       _buckets = buckets ?? RateLimitBuckets.defaults,
       _clock = clock ?? DateTime.now,
       _templates = templates ?? _inlineFallbackTemplates(),
       _cache = cache ?? WeeklyReportCache(prefs: prefs),
       _model = model,
       _baseUrl = _stripTrailingSlash(baseUrl);

  /// Gemini model id used for every AI surface. Pinned here so the
  /// whole app upgrades in lockstep. Override for tests.
  static const String defaultModel = 'gemini-1.5-flash';

  /// Gemini REST endpoint. Stable per-model path; the API key is
  /// passed as `?key=` per Google's documented contract.
  static const String defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String _stripTrailingSlash(String v) {
    var s = v;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Inline fallback templates. Mirrors the wording that lived in
  /// the old private helpers so unit tests (and any future caller
  /// that forgets to inject prompts) still get a sane system
  /// instruction instead of an empty string.
  static PromptTemplates _inlineFallbackTemplates() {
    const String chatEn =
        'You are a caring assistant for cat owners in Bangladesh. '
        'You do not diagnose — always recommend confirming with a vet.';
    const String chatBn =
        'আপনি বাংলাদেশের বিড়াল মালিকদের জন্য একটি সহানুভূতিশীল সহকারী। '
        'রোগ নির্ণয় করবেন না — প্রয়োজনে পশুচিকিত্সকের কাছে যাওয়ার পরামর্শ দিন।';
    const String weeklyEn =
        'You write a friendly weekly summary for a cat owner. '
        "Reply in the user's language (English or বাংলা). "
        'Keep it short and actionable. Do not diagnose.';
    const String weeklyBn =
        'আপনি বিড়ালের যত্নের একটি সাপ্তাহিক সারাংশ লেখেন। '
        'উত্তর সংক্ষিপ্ত, বন্ধুসুলভ এবং কার্যকর পরামর্শযুক্ত রাখুন। '
        'রোগ নির্ণয় করবেন না।';
    const String foodLabelEn =
        'You extract guaranteed-analysis fields from cat-food label '
        'photos. Reply with a single JSON object using the exact keys: '
        'brand, foodName, guaranteedAnalysis { proteinPct, fatPct, '
        'fiberPct, moisturePct }, ingredientsRaw, notes, missingData '
        '(boolean). If you cannot read a field, set it to null. If the '
        'photo is unreadable, set missingData to true.';
    const String foodLabelBn = foodLabelEn;
    return PromptTemplates.Raw(
      chatEn: chatEn,
      chatBn: chatBn,
      weeklyEn: weeklyEn,
      weeklyBn: weeklyBn,
      foodLabelEn: foodLabelEn,
      foodLabelBn: foodLabelBn,
    );
  }

  final String _apiKey;
  final HttpTransport _http;
  final SharedPreferences? _prefs;
  final Duration _requestTimeout;
  final RateLimitBuckets _buckets;
  final DateTime Function() _clock;
  final PromptTemplates _templates;
  final WeeklyReportCache _cache;
  final String _model;
  final String _baseUrl;
  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  /// Send a user message to the chat assistant.
  ///
  /// Builds a Gemini `generateContent` body with the rolling chat
  /// history and a system instruction that primes the model with the
  /// active cat's name + the guardrail ("assist, do not diagnose").
  Future<ChatReply> chat({
    required CatProfile cat,
    required List<ChatTurn> history,
    required String userMessage,
    required CatWeeklySummary summary,
    String locale = 'en',
  }) async {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure(
        'Message must not be empty.',
        code: 'ai-empty-message',
      );
    }
    if (cat.id.isEmpty) {
      throw const ValidationFailure(
        'Select an active cat before chatting with the assistant.',
        code: 'ai-no-active-cat',
      );
    }
    if (_apiKey.isEmpty) {
      throw const NetworkFailure(
        'Gemini API key is missing. Set GEMINI_API_KEY in .env and rebuild.',
        code: 'ai-missing-key',
      );
    }

    await _enforceRateLimit(RateLimitFeature.chat);

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': _chatSystemInstruction(
        locale: locale,
        cat: cat,
        summary: summary,
      ),
      'contents': _chatContents(history: history, userMessage: trimmed),
      'generationConfig': <String, dynamic>{
        'temperature': 0.4,
        'maxOutputTokens': 512,
      },
    };
    final Map<String, dynamic> response = await _post(body);
    final String text = _readReplyText(response);
    return ChatReply(text: text, language: locale);
  }

  /// Generate the weekly narrative for [cat] using the pre-aggregated
  /// [summary]. [weekId] is echoed back in the result so the UI can
  /// render "Week 2024-W42" without recomputing it.
  Future<WeeklyReportResult> weeklyReport({
    required CatProfile cat,
    required CatWeeklySummary summary,
    required String weekId,
    bool force = false,
    String locale = 'en',
  }) async {
    if (cat.id.isEmpty) {
      throw const ValidationFailure(
        'Select an active cat to generate a weekly report.',
        code: 'ai-no-active-cat',
      );
    }

    // Short-circuit when the summary has no data: skipping the
    // model call here is the single biggest quota-saver.
    if (summary.isEmpty) {
      return WeeklyReportResult(
        text: '',
        weekId: weekId,
        generatedAt: _clock(),
        fromCache: false,
        noData: true,
      );
    }

    // Cache hit short-circuits the API call (and the rate-limit
    // counter) within the same ISO week. `force: true` always
    // re-runs and overwrites the cached entry.
    if (!force) {
      final WeeklyReportResult? cached = await _cache.get(cat.id, weekId);
      if (cached != null) return cached;
    }

    if (_apiKey.isEmpty) {
      throw const NetworkFailure(
        'Gemini API key is missing. Set GEMINI_API_KEY in .env and rebuild.',
        code: 'ai-missing-key',
      );
    }

    await _enforceRateLimit(RateLimitFeature.weeklyReport);

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': _weeklySystemInstruction(locale: locale),
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': _weeklyUserPrompt(
                cat: cat,
                summary: summary,
                weekId: weekId,
                locale: locale,
              ),
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.3,
        'maxOutputTokens': 600,
        'responseMimeType': 'application/json',
      },
    };
    final Map<String, dynamic> response = await _post(body);
    final String text = _readReplyText(response);
    final bool noData = text.trim().isEmpty;
    final WeeklyReportResult result = WeeklyReportResult(
      text: text,
      weekId: weekId,
      generatedAt: _clock(),
      fromCache: false,
      noData: noData,
    );
    await _cache.put(cat.id, weekId, result);
    return result;
  }

  /// Wipe the on-device weekly-report cache. Called from
  /// [AiProvider.reset] on sign-out so the next user does not
  /// inherit the previous owner's cached reports.
  Future<void> clearWeeklyReportCache() => _cache.clear();

  /// Extract the guaranteed-analysis fields from a cat-food label
  /// photo. The image is sent inline as base64 in the request body's
  /// `parts[]`. The model is asked for JSON via `responseMimeType`.
  Future<FoodLabelExtraction> extractFoodLabel({
    required String imageBase64,
    required String mimeType,
    String locale = 'en',
  }) async {
    if (imageBase64.isEmpty) {
      throw const ValidationFailure(
        'Image must not be empty.',
        code: 'ai-empty-image',
      );
    }
    final int approxBytes = (imageBase64.length * 3) ~/ 4;
    if (approxBytes > 5 * 1024 * 1024) {
      throw const ValidationFailure(
        'Image is larger than 5 MB — please pick a smaller one.',
        code: 'ai-image-too-large',
      );
    }
    if (_apiKey.isEmpty) {
      throw const NetworkFailure(
        'Gemini API key is missing. Set GEMINI_API_KEY in .env and rebuild.',
        code: 'ai-missing-key',
      );
    }

    await _enforceRateLimit(RateLimitFeature.foodLabel);

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': _foodLabelSystemInstruction(),
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'inlineData': <String, dynamic>{
                'mimeType': mimeType,
                'data': imageBase64,
              },
            },
            <String, dynamic>{'text': _foodLabelUserPrompt(locale: locale)},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.1,
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json',
      },
    };
    final Map<String, dynamic> response = await _post(body);
    final String text = _readReplyText(response);
    final Map<String, dynamic> parsed = _parseJsonLenient(text);
    return FoodLabelExtraction.fromMap(parsed);
  }

  // ---------------------------------------------------------------------------
  // Prompt assembly
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _chatContents({
    required List<ChatTurn> history,
    required String userMessage,
  }) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final ChatTurn turn in history) {
      out.add(<String, dynamic>{
        'role': turn.role == 'model' ? 'model' : 'user',
        'parts': <Map<String, dynamic>>[
          <String, dynamic>{'text': turn.text},
        ],
      });
    }
    out.add(<String, dynamic>{
      'role': 'user',
      'parts': <Map<String, dynamic>>[
        <String, dynamic>{'text': userMessage},
      ],
    });
    return out;
  }

  /// System instruction for chat turns. The first part is the
  /// externalised guardrail prompt (English or Bangla, loaded from
  /// `assets/prompts/system_instructions.md`); the second part is a
  /// compact live-context block so the model can answer with the
  /// active cat's name + recent stats in scope.
  ///
  /// The Gemini API accepts multiple `parts[]` inside one
  /// `systemInstruction` — they are concatenated as a single system
  /// message. Keeping the guardrail first preserves the
  /// "do not diagnose / always recommend a vet" framing regardless
  /// of how the model prioritises the later context block.
  Map<String, dynamic> _chatSystemInstruction({
    required String locale,
    required CatProfile cat,
    required CatWeeklySummary summary,
  }) {
    final Map<String, dynamic> base = _templates.envelopeFor(
      feature: PromptFeature.chat,
      locale: locale,
    );
    final List<dynamic> parts = List<dynamic>.from(
      base['parts'] as List<dynamic>,
    );
    parts.add(<String, dynamic>{
      'text': _chatContextBlock(cat: cat, summary: summary, locale: locale),
    });
    return <String, dynamic>{'parts': parts};
  }

  /// Compact live-context string for chat. The wording is identical
  /// in both locales to the weekly-report header/metrics so the
  /// model sees the same numbers across surfaces — only the
  /// surrounding gloss changes.
  String _chatContextBlock({
    required CatProfile cat,
    required CatWeeklySummary summary,
    required String locale,
  }) {
    final bool bangla = locale == 'bn';
    final String header = bangla
        ? 'বিড়াল: ${cat.name} (${cat.breed ?? "unknown breed"}, '
              '${cat.birthday != null ? "জন্ম ${cat.birthday}" : "age unknown"}).'
        : 'Cat: ${cat.name} (${cat.breed ?? "unknown breed"}, '
              '${cat.birthday != null ? "born ${cat.birthday}" : "age unknown"}).';
    final String metrics = bangla
        ? 'গত ${summary.daysWindow} দিনে: '
              '${summary.feedingCount}টি খাবার, '
              '${summary.waterCount}টি পানি, '
              '${summary.lastWeights.length}টি ওজন রেকর্ড।'
        : 'Past ${summary.daysWindow} days: '
              '${summary.feedingCount} feedings, '
              '${summary.waterCount} water refills, '
              '${summary.lastWeights.length} weight entries.';
    return '$header $metrics';
  }

  Map<String, dynamic> _weeklySystemInstruction({required String locale}) {
    return _templates.envelopeFor(
      feature: PromptFeature.weekly,
      locale: locale,
    );
  }

  String _weeklyUserPrompt({
    required CatProfile cat,
    required CatWeeklySummary summary,
    required String weekId,
    required String locale,
  }) {
    final String header = locale == 'bn'
        ? 'বিড়াল: ${cat.name} (${cat.breed ?? "unknown breed"}, '
              '${cat.birthday != null ? "জন্ম ${cat.birthday}" : "age unknown"}). '
              'সপ্তাহ $weekId।'
        : 'Cat: ${cat.name} (${cat.breed ?? "unknown breed"}, '
              '${cat.birthday != null ? "born ${cat.birthday}" : "age unknown"}). '
              'Week $weekId.';
    final String metrics = locale == 'bn'
        ? 'গত ${summary.daysWindow} দিনে: '
              '${summary.feedingCount}টি খাবার '
              '(মোট ${_fmtAmount(summary.totalFeedingAmount)}) '
              '${summary.feedingDaysWithLogs} দিনে, '
              '${summary.waterCount}টি পানি '
              '(মোট ${_fmtAmount(summary.totalWaterMl)} মিলি) '
              '${summary.waterDaysWithLogs} দিনে, '
              '${summary.lastWeights.length}টি ওজন রেকর্ড।'
        : 'Past ${summary.daysWindow} days: '
              '${summary.feedingCount} feedings '
              '(total ${_fmtAmount(summary.totalFeedingAmount)}) '
              'across ${summary.feedingDaysWithLogs} days, '
              '${summary.waterCount} water refills '
              '(total ${_fmtAmount(summary.totalWaterMl)} ml) '
              'across ${summary.waterDaysWithLogs} days, '
              '${summary.lastWeights.length} weight entries.';
    final String weightsLine = _weeklyWeightsLine(
      summary: summary,
      locale: locale,
    );
    final String ask = locale == 'bn'
        ? 'এই সপ্তাহের একটি সংক্ষিপ্ত সারাংশ (৪-৬ বাক্য) লিখুন এবং '
              'একটি JSON অবজেক্ট {"text":"..."} রিটার্ন করুন।'
        : 'Write a short weekly summary (4-6 sentences) and return it as '
              'a JSON object {"text":"..."}.';
    final String tail = weightsLine.isEmpty ? '' : '\n$weightsLine';
    return '$header\n$metrics\n$ask$tail';
  }

  /// Render the last recorded weights as a compact string the model
  /// can quote. Returns the empty string when there are no entries
  /// — the caller omits the line in that case.
  String _weeklyWeightsLine({
    required CatWeeklySummary summary,
    required String locale,
  }) {
    if (summary.lastWeights.isEmpty) return '';
    final String joined = summary.lastWeights
        .map((WeightPoint w) => w.kg.toStringAsFixed(2))
        .join(locale == 'bn' ? ', ' : ', ');
    return locale == 'bn'
        ? 'সাম্প্রতিক ওজন (কেজি, নতুন → পুরাতন): $joined'
        : 'Recent weights (kg, newest -> oldest): $joined';
  }

  /// Format a mixed-unit total with at most one decimal. Locale is
  /// unused today — the value already mixes grams/cups/cans from the
  /// feeding log, so this is intentionally a numeric string only.
  static String _fmtAmount(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Map<String, dynamic> _foodLabelSystemInstruction() {
    return _templates.envelopeFor(
      feature: PromptFeature.foodLabel,
      locale: 'en',
    );
  }

  String _foodLabelUserPrompt({required String locale}) {
    return locale == 'bn'
        ? 'এই ছবি থেকে guaranteed-analysis পড়ুন।'
        : 'Read the guaranteed-analysis from this photo.';
  }

  /// Parses the Gemini `candidates[0].content.parts[].text` field
  /// out of the response envelope. The shape is documented at
  /// https://ai.google.dev/api/generate-content#v1beta.GenerateContentResponse.
  String _readReplyText(Map<String, dynamic> response) {
    final List<dynamic>? candidates = response['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return '';
    final Map<String, dynamic>? first = candidates.first is Map
        ? Map<String, dynamic>.from(candidates.first as Map)
        : null;
    final Map<String, dynamic>? content = first?['content'] is Map
        ? Map<String, dynamic>.from(first!['content'] as Map)
        : null;
    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return '';
    final StringBuffer buf = StringBuffer();
    for (final dynamic part in parts) {
      if (part is Map && part['text'] is String) {
        buf.write(part['text'] as String);
      }
    }
    return buf.toString();
  }

  /// Best-effort JSON parse for responses that ask for
  /// `responseMimeType: application/json`. Strips surrounding
  /// markdown fences and locates the outermost `{...}` block.
  Map<String, dynamic> _parseJsonLenient(String text) {
    var s = text.trim();
    if (s.startsWith('```')) {
      final int firstNewline = s.indexOf('\n');
      if (firstNewline >= 0) s = s.substring(firstNewline + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
      s = s.trim();
    }
    final int first = s.indexOf('{');
    final int last = s.lastIndexOf('}');
    if (first >= 0 && last > first) {
      s = s.substring(first, last + 1);
    }
    try {
      final dynamic decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Fall through: caller will see an empty map.
    }
    return const <String, dynamic>{};
  }

  // ---------------------------------------------------------------------------
  // HTTP transport
  //
  // The repository talks directly to the Gemini REST API:
  //   https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
  // Auth is the API key in the `?key=` query parameter — no Firebase
  // token, no Authorization header. The transport seam is kept so
  // tests can substitute a fake.
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    try {
      final Map<String, dynamic> raw = await _http.post(
        baseUrl: _baseUrl,
        path: '$_model:generateContent',
        queryParameters: <String, dynamic>{'key': _apiKey},
        headers: <String, String>{'Content-Type': 'application/json'},
        body: body,
        timeout: _requestTimeout,
      );
      return raw;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on AppFailure {
      rethrow;
    } catch (e, s) {
      AppLogger.e('AiRepository._post unexpected', e, s);
      throw UnknownFailure('AI request failed: $e', code: 'ai-unexpected');
    }
  }

  AppFailure _mapDioException(DioException e) {
    AppLogger.w('AiRepository HTTP failure: ${e.type} ${e.message}');
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(
          'AI service timed out. Please try again.',
          code: 'ai-timeout',
        );
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'No internet connection — AI requests need the network.',
          code: 'ai-no-connection',
        );
      case DioExceptionType.badCertificate:
        return const NetworkFailure(
          'Could not verify AI service certificate.',
          code: 'ai-tls',
        );
      case DioExceptionType.cancel:
        return const UnknownFailure(
          'AI request was cancelled.',
          code: 'ai-cancelled',
        );
      case DioExceptionType.badResponse:
        return _mapGeminiError(e.response);
      case DioExceptionType.unknown:
        return const NetworkFailure(
          'AI service is unreachable. Please try again.',
          code: 'ai-unreachable',
        );
    }
  }

  /// Map a Gemini-shaped error envelope to an [AppFailure]. The
  /// Generative Language API returns HTTP 4xx/5xx with a JSON body
  /// shaped like:
  ///
  /// ```json
  /// { "error": { "code": 429, "message": "...", "status": "RESOURCE_EXHAUSTED" } }
  /// ```
  ///
  /// Status-code semantics are the same as before — 400 → validation,
  /// 401/403 → auth/permission, 429 → quota, 5xx → transient network.
  AppFailure _mapGeminiError(Response<dynamic>? response) {
    final int? status = response?.statusCode;
    final Map<String, dynamic>? body = response?.data is Map
        ? Map<String, dynamic>.from(response!.data as Map)
        : null;
    final Map<String, dynamic>? err = body?['error'] is Map
        ? Map<String, dynamic>.from(body!['error'] as Map)
        : null;
    final String code =
        (err?['code'] as String?) ??
        (err?['status'] as String?) ??
        'gemini-error';
    final String message =
        (err?['message'] as String?) ?? 'AI request failed (HTTP $status).';
    switch (status) {
      case 400:
        return ValidationFailure(message, code: code);
      case 401:
        return const AuthFailure(
          'Your Gemini API key was rejected. Check GEMINI_API_KEY in .env.',
          code: 'gemini-unauthorized',
        );
      case 403:
        return const PermissionFailure(
          'Gemini refused the request — your key may lack access to this model.',
          code: 'gemini-forbidden',
        );
      case 429:
        return const AiQuotaExceededFailure(
          'AI free-tier limit reached. Please try again in a few minutes.',
          code: 'gemini-quota',
        );
      case 502:
      case 503:
      case 504:
        return const NetworkFailure(
          'AI service is temporarily unavailable. Please try again.',
          code: 'gemini-unavailable',
        );
      default:
        return UnknownFailure(message, code: code);
    }
  }

  // ---------------------------------------------------------------------------
  // Per-device rate limiter
  //
  // One independent counter per [RateLimitFeature], all reset on the
  // next UTC midnight. The cap for each feature is read from the
  // injected [RateLimitBuckets]; tests can lower the caps to one.
  // ---------------------------------------------------------------------------

  Future<void> _enforceRateLimit(RateLimitFeature feature) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return; // No prefs in tests → unlimited.
    final String today = _utcDayKey(_clock());
    final String dateKey = feature.datePrefKey;
    final String countKey = feature.countPrefKey;
    final String storedDay = prefs.getString(dateKey) ?? '';
    int count = 0;
    if (storedDay == today) {
      count = prefs.getInt(countKey) ?? 0;
    }
    final int limit = _buckets.limitFor(feature);
    if (count >= limit) {
      throw AiQuotaExceededFailure(
        'Daily limit reached for ${feature.label}. '
        'Resets at 00:00 UTC.',
        code: 'ai-local-daily-cap',
      );
    }
    await prefs.setInt(countKey, count + 1);
    await prefs.setString(dateKey, today);
  }

  static String _utcDayKey(DateTime t) {
    final DateTime utc = t.toUtc();
    final String y = utc.year.toString().padLeft(4, '0');
    final String m = utc.month.toString().padLeft(2, '0');
    final String d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Minimal transport seam over [Dio] so tests can substitute a fake
/// without instantiating a full HTTP client.
abstract class HttpTransport {
  Future<Map<String, dynamic>> post({
    required String baseUrl,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required Duration timeout,
  });
}

class DioHttpTransport extends HttpTransport {
  DioHttpTransport({Dio? dio}) {
    _dio = dio ?? Dio();
  }

  late final Dio _dio;

  @override
  Future<Map<String, dynamic>> post({
    required String baseUrl,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '$baseUrl$path',
      queryParameters: queryParameters,
      data: body,
      options: Options(
        headers: headers,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const UnknownFailure(
      'Backend returned a non-object response.',
      code: 'ai-malformed-response',
    );
  }
}

// ===========================================================================
// Public types — kept identical to the previous Cloud-Function-backed
// implementation so the provider + screens do not need to change.
// ===========================================================================

class ChatTurn {
  const ChatTurn({required this.role, required this.text});
  final String role;
  final String text;
}

class ChatReply {
  const ChatReply({
    required this.text,
    required this.language,
    this.fromCache = false,
  });
  final String text;
  final String language;
  final bool fromCache;
}

class WeeklyReportResult {
  const WeeklyReportResult({
    required this.text,
    required this.weekId,
    this.generatedAt,
    this.fromCache = false,
    this.noData = false,
  });
  final String text;
  final String weekId;
  final DateTime? generatedAt;
  final bool fromCache;
  final bool noData;
}

class FoodLabelExtraction {
  const FoodLabelExtraction({
    required this.brand,
    required this.foodName,
    required this.guaranteedAnalysis,
    required this.ingredientsRaw,
    this.notes,
    this.missingData = false,
  });

  factory FoodLabelExtraction.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> ga = map['guaranteedAnalysis'] is Map
        ? Map<String, dynamic>.from(map['guaranteedAnalysis'] as Map)
        : const <String, dynamic>{};
    return FoodLabelExtraction(
      brand: (map['brand'] as String?) ?? '',
      foodName: (map['foodName'] as String?) ?? '',
      guaranteedAnalysis: GuaranteedAnalysis(
        proteinPct: _asDouble(ga['proteinPct']),
        fatPct: _asDouble(ga['fatPct']),
        fiberPct: _asDouble(ga['fiberPct']),
        moisturePct: _asDouble(ga['moisturePct']),
      ),
      ingredientsRaw: (map['ingredientsRaw'] as String?) ?? '',
      notes: map['notes'] as String?,
      missingData: map['missingData'] == true,
    );
  }

  final String brand;
  final String foodName;
  final GuaranteedAnalysis guaranteedAnalysis;
  final String ingredientsRaw;
  final String? notes;
  final bool missingData;

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class GuaranteedAnalysis {
  const GuaranteedAnalysis({
    this.proteinPct,
    this.fatPct,
    this.fiberPct,
    this.moisturePct,
  });
  final double? proteinPct;
  final double? fatPct;
  final double? fiberPct;
  final double? moisturePct;

  bool get hasAny =>
      proteinPct != null ||
      fatPct != null ||
      fiberPct != null ||
      moisturePct != null;
}

/// Features that hit the Gemini API. Each one gets its own daily
/// counter in [SharedPreferences] and its own cap in [RateLimitBuckets].
/// The counters reset on UTC day rollover (00:00 UTC).
enum RateLimitFeature {
  chat('Chat', 'ai.local.calls.chat', 'ai.local.date.chat'),
  weeklyReport(
    'Weekly report',
    'ai.local.calls.weekly',
    'ai.local.date.weekly',
  ),
  foodLabel('Food label scan', 'ai.local.calls.food', 'ai.local.date.food');

  const RateLimitFeature(this.label, this.countPrefKey, this.datePrefKey);
  final String label;
  final String countPrefKey;
  final String datePrefKey;
}

/// Per-feature daily caps. The defaults are intentionally well below
/// the AI Studio free-tier RPD (1500) so that a single runaway device
/// cannot drain the project's quota for everyone else — see
/// `docs/CLIENT_GEMINI_KEY.md` for the reasoning.
class RateLimitBuckets {
  const RateLimitBuckets({
    this.chat = 20,
    this.weeklyReport = 5,
    this.foodLabel = 5,
  });

  /// Sensible defaults: 20 chat turns + 5 weekly reports + 5 label
  /// scans per device per UTC day.
  static const RateLimitBuckets defaults = RateLimitBuckets();

  final int chat;
  final int weeklyReport;
  final int foodLabel;

  int limitFor(RateLimitFeature feature) {
    switch (feature) {
      case RateLimitFeature.chat:
        return chat;
      case RateLimitFeature.weeklyReport:
        return weeklyReport;
      case RateLimitFeature.foodLabel:
        return foodLabel;
    }
  }
}
