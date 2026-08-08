import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'content_backend.dart';

/// Loads seed JSON from the Flutter asset bundle using `rootBundle`.
/// Categories are mapped to `assets/content/<category>.json`; the
/// `pubspec.yaml` is updated to bundle this directory.
///
/// This is the only place in `core/services/content/` that imports
/// `package:flutter/services.dart` — every other consumer reaches the
/// loader through the [ContentSeedLoader] interface, which keeps tests
/// pure-Dart.
class AssetContentSeedLoader implements ContentSeedLoader {
  const AssetContentSeedLoader();

  @override
  Future<List<Map<String, dynamic>>?> loadCategory(String category) async {
    final data = await rootBundle.loadString('assets/content/$category.json');
    return _decodeList(data);
  }

  static List<Map<String, dynamic>> _decodeList(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    }
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return items
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
