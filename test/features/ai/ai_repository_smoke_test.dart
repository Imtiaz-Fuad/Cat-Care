// Smoke test for the client-side `AiRepository`.
//
// After dropping the Vercel backend the Flutter client talks to the
// Generative Language API directly with a `?key=` query parameter.
// These tests stub the HTTP transport so they run offline.
//
// Run with:
//   flutter test test/features/ai/ai_repository_smoke_test.dart
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/features/ai/models/cat_weekly_summary.dart';
import 'package:cat_care/features/ai/repositories/ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturedCall {
  _CapturedCall(
    this.path,
    this.baseUrl,
    this.body,
    this.headers,
    this.queryParameters,
  );

  final String path;
  final String baseUrl;
  final Map<String, dynamic> body;
  final Map<String, String> headers;
  final Map<String, dynamic> queryParameters;
}

class _FakeHttpTransport implements HttpTransport {
  final List<_CapturedCall> calls = <_CapturedCall>[];
  final Map<String, dynamic> reply;
  int _replyIndex = 0;

  _FakeHttpTransport(this.reply);

  @override
  Future<Map<String, dynamic>> post({
    required String baseUrl,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    calls.add(_CapturedCall(path, baseUrl, body, headers, queryParameters));
    final Object? queuedReply = reply['reply_$_replyIndex'] ?? reply['reply'];
    _replyIndex++;
    if (queuedReply is Map<String, dynamic>) return queuedReply;
    return const <String, dynamic>{};
  }
}

final DateTime _t0 = DateTime.utc(2024, 5, 1);

CatProfile _stubCat({String id = 'cat-1'}) =>
    CatProfile(id: id, ownerId: 'user-1', name: 'Whiskers');

CatWeeklySummary _emptySummary({int daysWindow = 7}) => CatWeeklySummary(
      daysWindow: daysWindow,
      feedingCount: 0,
      totalFeedingAmount: 0,
      waterCount: 0,
      totalWaterMl: 0,
      lastWeights: const <WeightPoint>[],
      feedingDaysWithLogs: 0,
      waterDaysWithLogs: 0,
    );

CatWeeklySummary _populatedSummary({int daysWindow = 7}) => CatWeeklySummary(
      daysWindow: daysWindow,
      feedingCount: 12,
      totalFeedingAmount: 240,
      waterCount: 8,
      totalWaterMl: 1200,
      lastWeights: <WeightPoint>[WeightPoint(recordedAt: _t0, kg: 4.2)],
      feedingDaysWithLogs: 5,
      waterDaysWithLogs: 4,
    );

Map<String, dynamic> _geminiTextReply(String text) => <String, dynamic>{
      'candidates': <Map<String, dynamic>>[
        <String, dynamic>{
          'content': <String, dynamic>{
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': text},
            ],
          },
        },
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('AiRepository (client-side Gemini)', () {
    test('chat POSTs to Gemini with ?key= and history parts', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        <String, dynamic>{'reply': _geminiTextReply('hello from gemini')},
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
      );

      final ChatReply reply = await repo.chat(
        cat: _stubCat(),
        history: const <ChatTurn>[
          ChatTurn(role: 'user', text: 'hi'),
          ChatTurn(role: 'model', text: 'hello back'),
        ],
        userMessage: 'how is she doing?',
        summary: _populatedSummary(),
        locale: 'en-US',
      );

      expect(reply.text, 'hello from gemini');
      expect(reply.language, 'en-US');
      expect(transport.calls, hasLength(1));
      final _CapturedCall call = transport.calls.single;
      expect(call.path, 'gemini-1.5-flash:generateContent');
      expect(
        call.baseUrl,
        'https://generativelanguage.googleapis.com/v1beta/models',
      );
      expect(call.queryParameters['key'], 'test-key');
      expect(call.headers.containsKey('Authorization'), isFalse);
      expect(call.headers['Content-Type'], 'application/json');
      expect(call.body['systemInstruction'], isA<Map<String, dynamic>>());
      final List<dynamic> contents = call.body['contents'] as List<dynamic>;
      expect(contents, hasLength(3));
      expect((contents.first as Map<String, dynamic>)['role'], 'user');
      expect((contents[1] as Map<String, dynamic>)['role'], 'model');
      expect((contents.last as Map<String, dynamic>)['role'], 'user');
    });

    test('chat rejects empty user message without hitting the network',
        () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        const <String, dynamic>{},
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
      );

      await expectLater(
        () => repo.chat(
          cat: _stubCat(),
          history: const <ChatTurn>[],
          userMessage: '',
          summary: _populatedSummary(),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(transport.calls, isEmpty);
    });

    test('weeklyReport short-circuits on empty summary', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        const <String, dynamic>{},
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
        clock: () => DateTime.utc(2024, 5, 1),
      );

      final WeeklyReportResult result = await repo.weeklyReport(
        cat: _stubCat(),
        summary: _emptySummary(),
        weekId: 'w-2024-05',
      );

      expect(result.noData, isTrue);
      expect(result.text, isEmpty);
      expect(result.weekId, 'w-2024-05');
      expect(transport.calls, isEmpty);
    });

    test('weeklyReport sends JSON-mime generationConfig', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        <String, dynamic>{
          'reply': _geminiTextReply('looks like a steady week'),
        },
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
      );

      final WeeklyReportResult result = await repo.weeklyReport(
        cat: _stubCat(),
        summary: _populatedSummary(),
        weekId: 'w-2024-05',
        force: false,
        locale: 'en-US',
      );

      expect(result.noData, isFalse);
      expect(result.text, 'looks like a steady week');
      final _CapturedCall call = transport.calls.single;
      expect(call.path, 'gemini-1.5-flash:generateContent');
      expect(call.queryParameters['key'], 'test-key');
      final Map<String, dynamic> cfg =
          call.body['generationConfig'] as Map<String, dynamic>;
      expect(cfg['responseMimeType'], 'application/json');
    });

    test('extractFoodLabel sends inline image + parses lenient JSON',
        () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        <String, dynamic>{
          'reply': _geminiTextReply(
            '{"brand":"Acme","foodName":"Salmon Feast",'
            '"guaranteedAnalysis":{"proteinPct":10,"fatPct":5,'
            '"fiberPct":2,"moisturePct":80},'
            '"ingredientsRaw":"salmon, water, taurine",'
            '"notes":"wet food","missingData":false}',
          ),
        },
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
      );

      final FoodLabelExtraction result = await repo.extractFoodLabel(
        imageBase64: 'aGVsbG8=',
        mimeType: 'image/jpeg',
        locale: 'en-US',
      );

      expect(result.brand, 'Acme');
      expect(result.foodName, 'Salmon Feast');
      expect(result.guaranteedAnalysis.proteinPct, 10.0);
      expect(result.guaranteedAnalysis.fatPct, 5.0);
      expect(result.ingredientsRaw, 'salmon, water, taurine');
      expect(result.missingData, isFalse);
      final _CapturedCall call = transport.calls.single;
      expect(call.path, 'gemini-1.5-flash:generateContent');
      final List<dynamic> parts = ((call.body['contents'] as List<dynamic>)
              .first as Map<String, dynamic>)['parts']
          as List<dynamic>;
      expect(parts, hasLength(2));
      final Map<String, dynamic> inline =
          parts.first as Map<String, dynamic>;
      expect(inline['inlineData'], isA<Map<String, dynamic>>());
      expect(
        (inline['inlineData'] as Map<String, dynamic>)['mimeType'],
        'image/jpeg',
      );
      expect(
        (inline['inlineData'] as Map<String, dynamic>)['data'],
        'aGVsbG8=',
      );
    });

    test('rate limiter enforces per-feature daily cap', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final _FakeHttpTransport transport = _FakeHttpTransport(
        <String, dynamic>{'reply': _geminiTextReply('ok')},
      );
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
        prefs: prefs,
        buckets: const RateLimitBuckets(
          chat: 1,
          weeklyReport: 0,
          foodLabel: 0,
        ),
        clock: () => DateTime.utc(2024, 5, 1),
      );

      await repo.chat(
        cat: _stubCat(),
        history: const <ChatTurn>[],
        userMessage: 'first',
        summary: _populatedSummary(),
      );
      await expectLater(
        () => repo.chat(
          cat: _stubCat(),
          history: const <ChatTurn>[],
          userMessage: 'second',
          summary: _populatedSummary(),
        ),
        throwsA(isA<AiQuotaExceededFailure>()),
      );
      await expectLater(
        () => repo.weeklyReport(
          cat: _stubCat(),
          summary: _populatedSummary(),
          weekId: 'w-2024-05',
        ),
        throwsA(isA<AiQuotaExceededFailure>()),
      );
    });
  });
}