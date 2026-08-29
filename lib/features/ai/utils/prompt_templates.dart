import 'package:flutter/services.dart' show rootBundle;

/// Parsed view of `assets/prompts/system_instructions.md`. Loaded once
/// at startup by `PromptTemplates.loadFromBundle` and passed to the
/// `AiRepository` so prompts are not duplicated as Dart strings inside
/// the codebase.
///
/// The Markdown file is intentionally simple: three sections
/// (`# chat`, `# weekly`, `# food_label`), each containing exactly
/// two HTML comments, one per supported locale. The grammar is:
///
///   # <key>
///   <!-- en: <text> -->
///   <!-- bn: <text> -->
///
/// The parser tolerates blank lines and additional prose inside each
/// section but rejects files that are missing a section or a locale
/// comment. A broken template fails loudly at startup rather than
/// silently shipping an empty system instruction.
class PromptTemplates {
  PromptTemplates._({
    required this.chatEn,
    required this.chatBn,
    required this.weeklyEn,
    required this.weeklyBn,
    required this.foodLabelEn,
    required this.foodLabelBn,
  });

  /// Public raw constructor used by `AiRepository` to build the
  /// inline fallback templates (mirrors the wording the repository
  /// had before prompts were externalized). Library-private
  /// callers should prefer [parse] / [loadFromBundle] instead.
  // ignore: non_constant_identifier_names
  PromptTemplates.Raw({
    required String chatEn,
    required String chatBn,
    required String weeklyEn,
    required String weeklyBn,
    required String foodLabelEn,
    required String foodLabelBn,
  }) : this._(
          chatEn: chatEn,
          chatBn: chatBn,
          weeklyEn: weeklyEn,
          weeklyBn: weeklyBn,
          foodLabelEn: foodLabelEn,
          foodLabelBn: foodLabelBn,
        );

  /// English chat system instruction.
  final String chatEn;

  /// Bangla chat system instruction.
  final String chatBn;

  /// English weekly-report system instruction.
  final String weeklyEn;

  /// Bangla weekly-report system instruction.
  final String weeklyBn;

  /// English food-label system instruction.
  final String foodLabelEn;

  /// Bangla food-label system instruction.
  final String foodLabelBn;

  /// Bundle path of the source markdown. Exposed as a `const` so
  /// tests can override it (none do today).
  static const String assetPath = 'assets/prompts/system_instructions.md';

  /// Load + parse the template file shipped as a Flutter asset.
  ///
  /// Throws [PromptTemplateException] if a section or locale is
  /// missing — the caller should let the exception bubble up so the
  /// app crashes on startup rather than rendering AI responses with
  /// empty guardrails.
  static Future<PromptTemplates> loadFromBundle({
    String path = assetPath,
  }) async {
    final String raw = await rootBundle.loadString(path);
    return parse(raw);
  }

  /// Parse an already-loaded markdown body. Public so tests can
  /// exercise the parser against fixtures without a real bundle.
  static PromptTemplates parse(String body) {
    final Map<String, Map<String, String>> sections =
        _extractSections(body);
    String en(String key) =>
        sections[key]?['en'] ?? (throw PromptTemplateException.missing(key, 'en'));
    String bn(String key) =>
        sections[key]?['bn'] ?? (throw PromptTemplateException.missing(key, 'bn'));
    return PromptTemplates._(
      chatEn: en('chat'),
      chatBn: bn('chat'),
      weeklyEn: en('weekly'),
      weeklyBn: bn('weekly'),
      foodLabelEn: en('food_label'),
      foodLabelBn: bn('food_label'),
    );
  }

  /// Returns the system instruction body for [feature] in [locale].
  /// Defaults to English when the requested locale is unknown — the
  /// same fallback behaviour the repository had before the
  /// externalization.
  String systemInstructionFor({
    required PromptFeature feature,
    required String locale,
  }) {
    final bool bangla = locale == 'bn';
    switch (feature) {
      case PromptFeature.chat:
        return bangla ? chatBn : chatEn;
      case PromptFeature.weekly:
        return bangla ? weeklyBn : weeklyEn;
      case PromptFeature.foodLabel:
        return bangla ? foodLabelBn : foodLabelEn;
    }
  }

  /// Wraps [body] in the Gemini `systemInstruction` envelope. Kept
  /// here (rather than in the repository) so the JSON shape is
  /// defined next to the prompt text it carries.
  Map<String, dynamic> envelopeFor({
    required PromptFeature feature,
    required String locale,
  }) {
    return <String, dynamic>{
      'parts': <Map<String, dynamic>>[
        <String, dynamic>{'text': systemInstructionFor(feature: feature, locale: locale)},
      ],
    };
  }

  // ---------------------------------------------------------------------------
  // Parser
  // ---------------------------------------------------------------------------

  static final RegExp _sectionHeader = RegExp(r'^#\s+(\S+)\s*$');
  static final RegExp _localeComment =
      RegExp(r'<!--\s*(en|bn):\s*(.*?)\s*-->', dotAll: true);

  static Map<String, Map<String, String>> _extractSections(String body) {
    final Map<String, Map<String, String>> result =
        <String, Map<String, String>>{};
    String? currentKey;
    final List<String> lines = body.split('\n');
    for (final String line in lines) {
      final RegExpMatch? header = _sectionHeader.firstMatch(line);
      if (header != null) {
        currentKey = header.group(1);
        result.putIfAbsent(currentKey!, () => <String, String>{});
        continue;
      }
      if (currentKey == null) continue;
      for (final RegExpMatch m in _localeComment.allMatches(line)) {
        final String locale = m.group(1)!;
        final String text = m.group(2)!.trim();
        result[currentKey]![locale] = text;
      }
    }
    return result;
  }
}

/// Identifies which system instruction to pick when building a
/// request body. Mirrors the three Gemini call sites in
/// `AiRepository`.
enum PromptFeature { chat, weekly, foodLabel }

/// Thrown when the bundled prompt file is malformed. The repository
/// construction path treats this as fatal because shipping an empty
/// guardrail is worse than crashing on startup.
class PromptTemplateException implements Exception {
  PromptTemplateException(this.message);
  final String message;

  factory PromptTemplateException.missing(String section, String locale) =>
      PromptTemplateException(
        'Prompt template is missing the $locale comment in section "$section". '
        'Check assets/prompts/system_instructions.md.',
      );

  @override
  String toString() => 'PromptTemplateException: $message';
}
