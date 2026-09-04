class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.questionEn,
    required this.questionBn,
    required this.answerEn,
    required this.answerBn,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    return FaqEntry(
      id: _requiredString(json, 'id'),
      category: _requiredString(json, 'category'),
      questionEn: _requiredString(json, 'question_en'),
      questionBn: _requiredString(json, 'question_bn'),
      answerEn: _requiredString(json, 'answer_en'),
      answerBn: _requiredString(json, 'answer_bn'),
    );
  }

  final String id;
  final String category;
  final String questionEn;
  final String questionBn;
  final String answerEn;
  final String answerBn;

  String questionFor(String language) =>
      language == 'bn' ? questionBn : questionEn;

  String answerFor(String language) => language == 'bn' ? answerBn : answerEn;

  static String _requiredString(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('FAQ entry is missing $key.');
  }
}
