import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/faq_entry.dart';

class FaqRepository {
  const FaqRepository();

  static const String assetPath = 'assets/faq/faq.json';

  Future<List<FaqEntry>> load() async {
    final String source = await rootBundle.loadString(assetPath);
    final Object? decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('FAQ data must be a list.');
    }
    return decoded
        .map(
          (Object? item) =>
              FaqEntry.fromJson(Map<String, dynamic>.from(item! as Map)),
        )
        .toList(growable: false);
  }
}
