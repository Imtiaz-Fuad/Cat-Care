// Tests for `assets/prompts/system_instructions.md` parser.
//
// Verifies that:
//   * A complete file with all three sections and both locales
//     round-trips through `PromptTemplates.parse`.
//   * The Gemini envelope shape (`parts[0].text`) is correct.
//   * Missing sections / missing locales throw
//     `PromptTemplateException`.
//
// Run with:
//   flutter test test/features/ai/prompt_templates_test.dart
import 'package:cat_care/features/ai/utils/prompt_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String fullBody = '''
# chat

<!-- en: english chat prompt -->
<!-- bn: বাংলা চ্যাট প্রম্পট -->

# weekly

<!-- en: english weekly prompt -->
<!-- bn: বাংলা সাপ্তাহিক প্রম্পট -->

# food_label

<!-- en: english food label prompt -->
<!-- bn: বাংলা ফুড লেবেল প্রম্পট -->
''';

  group('PromptTemplates.parse', () {
    test('parses all six strings from a complete file', () {
      final PromptTemplates t = PromptTemplates.parse(fullBody);
      expect(t.chatEn, 'english chat prompt');
      expect(t.chatBn, 'বাংলা চ্যাট প্রম্পট');
      expect(t.weeklyEn, 'english weekly prompt');
      expect(t.weeklyBn, 'বাংলা সাপ্তাহিক প্রম্পট');
      expect(t.foodLabelEn, 'english food label prompt');
      expect(t.foodLabelBn, 'বাংলা ফুড লেবেল প্রম্পট');
    });

    test('throws when a section is missing', () {
      const String withoutFoodLabel = '''
# chat
<!-- en: chat en -->
<!-- bn: chat bn -->

# weekly
<!-- en: weekly en -->
<!-- bn: weekly bn -->
''';
      expect(
        () => PromptTemplates.parse(withoutFoodLabel),
        throwsA(isA<PromptTemplateException>()),
      );
    });

    test('throws when a locale comment is missing', () {
      const String missingBn = '''
# chat
<!-- en: chat en -->

# weekly
<!-- en: weekly en -->
<!-- bn: weekly bn -->

# food_label
<!-- en: food en -->
<!-- bn: food bn -->
''';
      expect(
        () => PromptTemplates.parse(missingBn),
        throwsA(isA<PromptTemplateException>()),
      );
    });

    test('returns last comment when a section has both locales', () {
      // Parser preserves the last write per (section, locale).
      const String duplicateEn = '''
# chat
<!-- en: first chat en -->
<!-- en: second chat en -->
<!-- bn: chat bn -->

# weekly
<!-- en: weekly en -->
<!-- bn: weekly bn -->

# food_label
<!-- en: food en -->
<!-- bn: food bn -->
''';
      final PromptTemplates t = PromptTemplates.parse(duplicateEn);
      expect(t.chatEn, 'second chat en');
    });
  });

  group('PromptTemplates.systemInstructionFor', () {
    final PromptTemplates t = PromptTemplates.parse(fullBody);

    test('returns English by default and for unknown locales', () {
      expect(
        t.systemInstructionFor(feature: PromptFeature.chat, locale: 'en'),
        'english chat prompt',
      );
      expect(
        t.systemInstructionFor(feature: PromptFeature.chat, locale: 'fr-FR'),
        'english chat prompt',
      );
    });

    test('returns Bengali when locale is bn', () {
      expect(
        t.systemInstructionFor(feature: PromptFeature.chat, locale: 'bn'),
        'বাংলা চ্যাট প্রম্পট',
      );
      expect(
        t.systemInstructionFor(feature: PromptFeature.weekly, locale: 'bn'),
        'বাংলা সাপ্তাহিক প্রম্পট',
      );
      expect(
        t.systemInstructionFor(feature: PromptFeature.foodLabel, locale: 'bn'),
        'বাংলা ফুড লেবেল প্রম্পট',
      );
    });
  });

  group('PromptTemplates.envelopeFor', () {
    final PromptTemplates t = PromptTemplates.parse(fullBody);

    test('wraps the prompt in the Gemini systemInstruction shape', () {
      final Map<String, dynamic> env = t.envelopeFor(
        feature: PromptFeature.chat,
        locale: 'en',
      );
      expect(env, isA<Map<String, dynamic>>());
      final List<dynamic> parts = env['parts'] as List<dynamic>;
      expect(parts, hasLength(1));
      final Map<String, dynamic> first = parts.first as Map<String, dynamic>;
      expect(first['text'], 'english chat prompt');
    });
  });
}