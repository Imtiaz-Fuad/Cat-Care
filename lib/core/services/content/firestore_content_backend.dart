import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_backend.dart';

/// Firestore-backed adapter. Reads from the public `content/{category}`
/// collection. Per the security rules (Phase 2), writes are admin-only;
/// client apps only read.
///
/// All content documents are stored as plain maps with `id` matching the
/// document id.
class FirestoreContentBackend implements ContentBackend {
  const FirestoreContentBackend({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  Future<Map<String, dynamic>?> fetchOne({
    required String category,
    required String id,
  }) async {
    // The repository's design treats each entry as its own document at
    // `content/{category}/items/{id}`.
    final top = await firestore
        .collection('content')
        .doc(category)
        .collection('items')
        .doc(id)
        .get();
    return top.exists ? top.data() : null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String category) async {
    final top = await firestore
        .collection('content')
        .doc(category)
        .collection('items')
        .get();
    return top.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data())
        .toList(growable: false);
  }
}