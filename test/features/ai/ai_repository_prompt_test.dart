// Tests for the live-data prompt blocks: chat context block + weekly
// report user prompt. Confirms the model actually receives the active
// cat's name, breed, totals, distinct-day counts, and recent weights
// in the request body — not just a generic guardrail.
//
// Run with:
//   flutter test test/features/ai/ai_repository_prompt_test.dart

import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/features/ai/models/cat_weekly_summary.dart';
import 'package:cat_care/features/ai/repositories/ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// WeightPoint is re-exported via cat_weekly_summary.dart.

class _CapturedCall {
  _CapturedCall(this.body);
  final Map<String, dynamic> body;
}

class _FakeHttpTransport implements HttpTransport {
  final List<_CapturedCall> calls = <_CapturedCall>[];
  final String replyText;

  _FakeHttpTransport(this.replyText);

  @override
  Future<Map<String, dynamic>> post({
    required String baseUrl,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    calls.add(_CapturedCall(body));
    return <String, dynamic>{
      'candidates': <Map<String, dynamic>>[
        <String, dynamic>{
          'content': <String, dynamic>{
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': replyText},
            ],
          },
        },
      ],
    };
  }
}

final DateTime _t0 = DateTime.utc(2026, 8, 1);

CatProfile _stubCat() => CatProfile(
  id: 'cat-1',
  ownerId: 'user-1',
  name: 'Whiskers',
  breed: 'Persian',
  birthday: DateTime.utc(2024, 3, 15),
);

CatWeeklySummary _summary() => CatWeeklySummary(
  daysWindow: 7,
  feedingCount: 12,
  totalFeedingAmount: 240,
  waterCount: 8,
  totalWaterMl: 1200,
  lastWeights: <WeightPoint>[
    WeightPoint(recordedAt: _t0, kg: 4.3),
    WeightPoint(recordedAt: _t0.subtract(const Duration(days: 7)), kg: 4.2),
  ],
  feedingDaysWithLogs: 5,
  waterDaysWithLogs: 4,
);

/// Extract every text payload inside a Gemini `systemInstruction` so
/// tests can assert on prompt content without caring about the
/// wrapping shape.
String _systemInstructionText(Map<String, dynamic> call) {
  final Map<String, dynamic> instr =
      call['systemInstruction'] as Map<String, dynamic>;
  final List<dynamic> parts = instr['parts'] as List<dynamic>;
  return parts
      .map((dynamic p) => (p as Map<String, dynamic>)['text'] as String)
      .join('\n');
}

String _userPromptText(Map<String, dynamic> call) {
  final List<dynamic> contents = call['contents'] as List<dynamic>;
  final List<dynamic> parts =
      (contents.first as Map<String, dynamic>)['parts'] as List<dynamic>;
  return (parts.first as Map<String, dynamic>)['text'] as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('AiRepository prompt content', () {
    test(
      'chat systemInstruction carries guardrail + live cat/summary context',
      () async {
        final _FakeHttpTransport transport = _FakeHttpTransport('ok');
        final AiRepository repo = AiRepository(
          apiKey: 'test-key',
          httpClient: transport,
        );

        await repo.chat(
          cat: _stubCat(),
          history: const <ChatTurn>[],
          userMessage: 'is my cat ok?',
          summary: _summary(),
          locale: 'en',
        );

        expect(transport.calls, hasLength(1));
        final String sysText = _systemInstructionText(
          transport.calls.single.body,
        );
        // The guardrail unchanged: externalised prompt is still the
        // first part of the systemInstruction.
        expect(
          sysText,
          contains('do not diagnose'),
          reason: 'guardrail prompt missing',
        );
        // Live data: cat name, breed, feeding/water counts.
        expect(sysText, contains('Whiskers'));
        expect(sysText, contains('Persian'));
        expect(sysText, contains('12 feedings'));
        expect(sysText, contains('8 water refills'));
      },
    );

    test('chat context block switches to Bangla when locale=bn', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport('ঠিক আছে');
      final AiRepository repo = AiRepository(
        apiKey: 'test-key',
        httpClient: transport,
      );

      await repo.chat(
        cat: _stubCat(),
        history: const <ChatTurn>[],
        userMessage: 'আমার বিড়াল ঠিক আছে?',
        summary: _summary(),
        locale: 'bn',
      );

      final String sysText = _systemInstructionText(
        transport.calls.single.body,
      );
      expect(sysText, contains('বিড়াল: Whiskers'));
      expect(sysText, contains('Persian'));
      expect(sysText, contains('12টি খাবার'));
      expect(sysText, contains('8টি পানি'));
    });

    test(
      'weekly-report user prompt includes totals + days + recent weights',
      () async {
        final _FakeHttpTransport transport = _FakeHttpTransport('summary');
        final AiRepository repo = AiRepository(
          apiKey: 'test-key',
          httpClient: transport,
        );

        await repo.weeklyReport(
          cat: _stubCat(),
          summary: _summary(),
          weekId: '2026-W34',
          force: true,
          locale: 'en',
        );

        final String prompt = _userPromptText(transport.calls.single.body);
        // Header still carries cat name + week.
        expect(prompt, contains('Cat: Whiskers (Persian'));
        expect(prompt, contains('Week 2026-W34'));
        // Expanded metrics line.
        expect(prompt, contains('total 240'));
        expect(prompt, contains('across 5 days'));
        expect(prompt, contains('total 1200 ml'));
        expect(prompt, contains('across 4 days'));
        // Recent weights appended.
        expect(prompt, contains('Recent weights (kg, newest -> oldest):'));
        expect(prompt, contains('4.30'));
        expect(prompt, contains('4.20'));
        // Final instruction unchanged.
        expect(prompt, contains('{"text":"..."}'));
      },
    );

    test(
      'weekly-report Bangla prompt carries translated metric wording',
      () async {
        final _FakeHttpTransport transport = _FakeHttpTransport('সারাংশ');
        final AiRepository repo = AiRepository(
          apiKey: 'test-key',
          httpClient: transport,
        );

        await repo.weeklyReport(
          cat: _stubCat(),
          summary: _summary(),
          weekId: '2026-W34',
          force: true,
          locale: 'bn',
        );

        final String prompt = _userPromptText(transport.calls.single.body);
        expect(prompt, contains('বিড়াল: Whiskers'));
        expect(prompt, contains('মোট 240'));
        expect(prompt, contains('1200 মিলি'));
        expect(prompt, contains('সাম্প্রতিক ওজন'));
        expect(prompt, contains('4.30'));
      },
    );

    test(
      'weekly-report prompt omits weights line when summary has none',
      () async {
        final _FakeHttpTransport transport = _FakeHttpTransport('সারাংশ');
        final AiRepository repo = AiRepository(
          apiKey: 'test-key',
          httpClient: transport,
        );

        await repo.weeklyReport(
          cat: _stubCat(),
          summary: CatWeeklySummary(
            daysWindow: 7,
            feedingCount: 5,
            totalFeedingAmount: 100,
            waterCount: 3,
            totalWaterMl: 600,
            lastWeights: const <WeightPoint>[],
            feedingDaysWithLogs: 3,
            waterDaysWithLogs: 2,
          ),
          weekId: '2026-W34',
          force: true,
          locale: 'en',
        );

        final String prompt = _userPromptText(transport.calls.single.body);
        expect(prompt, isNot(contains('Recent weights')));
        expect(prompt, contains('5 feedings'));
        expect(prompt, contains('across 3 days'));
      },
    );
  });
}
