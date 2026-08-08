import 'dart:async';

/// Backend abstraction for the content layer. The repository calls this
/// to fetch JSON-shaped documents; the Firestore adapter returns live
/// data, the seed adapter returns in-memory placeholders. Implementations
/// must return raw maps (or `null` when missing) — typed models are
/// produced by the repository.
abstract class ContentBackend {
  /// Fetch a single document by category + id. Returns `null` when absent.
  Future<Map<String, dynamic>?> fetchOne({
    required String category,
    required String id,
  });

  /// List all documents in a category. Missing categories return `[]`.
  Future<List<Map<String, dynamic>>> fetchAll(String category);
}

/// Lazy loader for bundled seed JSON. Separated so tests can pass a
/// fake implementation that yields custom maps without touching the
/// file system or asset bundle.
abstract class ContentSeedLoader {
  Future<List<Map<String, dynamic>>?> loadCategory(String category);
}

/// Concrete adapter that loads content from a [ContentSeedLoader]
/// (typically a bundled JSON file under `assets/content/`). Used at
/// first-launch, in tests, and as a fallback when the Firestore
/// collection is empty or unreachable.
class SeedContentBackend implements ContentBackend {
  const SeedContentBackend({
    required this.seedLoader,
    this.fallbackChecked = true,
  });

  final ContentSeedLoader seedLoader;

  /// When `true`, missing seed files surface as empty results. When
  /// `false`, the caller handles the null. Used by tests to assert
  /// fallback paths behave deterministically.
  final bool fallbackChecked;

  @override
  Future<Map<String, dynamic>?> fetchOne({
    required String category,
    required String id,
  }) async {
    final docs = await fetchAll(category);
    for (final doc in docs) {
      if (doc['id'] == id) return doc;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String category) async {
    final loaded = await seedLoader.loadCategory(category);
    if (loaded != null) return loaded;
    if (fallbackChecked) return const <Map<String, dynamic>>[];
    throw StateError('Seed content missing for category: $category');
  }
}