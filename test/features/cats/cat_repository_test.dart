import 'dart:typed_data';

import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/core/services/firestore_service.dart';
import 'package:cat_care/core/services/storage_service.dart';
import 'package:cat_care/features/cats/models/cat_draft.dart';
import 'package:cat_care/features/cats/repositories/cat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

class _MockStorageService extends Mock implements StorageService {}

class _FixedUuid extends Uuid {
  _FixedUuid(this._id) : super();
  final String _id;
  @override
  String v4({Map<String, dynamic>? options, dynamic config}) => _id;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  group('CatRepository.createCat', () {
    late _MockFirestoreService firestore;
    late _MockStorageService storage;
    late CatRepository repo;

    setUp(() {
      firestore = _MockFirestoreService();
      storage = _MockStorageService();
      repo = CatRepository(
        firestoreService: firestore,
        storageService: storage,
        uuid: _FixedUuid('cat-42'),
      );
    });

    test('writes under users/{uid}/cats/{catId} and returns the profile',
        () async {
      when(() => firestore.writeDocument(
            any<String>(),
            any<Map<String, dynamic>>(),
          )).thenAnswer((_) async {});

      final CatProfile created = await repo.createCat(
        ownerId: 'alice',
        draft: CatDraft(name: 'Mimi'),
      );

      expect(created.id, 'cat-42');
      expect(created.ownerId, 'alice');
      expect(created.name, 'Mimi');

      final captured = verify(
        () => firestore.writeDocument(
          captureAny<String>(),
          captureAny<Map<String, dynamic>>(),
        ),
      ).captured;
      expect(captured[0] as String, 'users/alice/cats/cat-42');
      expect((captured[1] as Map<String, dynamic>)['name'], 'Mimi');
    });

    test('rejects an empty-name draft with ValidationFailure', () async {
      expect(
        () => repo.createCat(
          ownerId: 'alice',
          draft: CatDraft(name: '  '),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(() => firestore.writeDocument(
            any<String>(),
            any<Map<String, dynamic>>(),
          ));
    });

    test('wraps a repository failure as UnknownFailure', () async {
      when(() => firestore.writeDocument(
            any<String>(),
            any<Map<String, dynamic>>(),
          )).thenThrow(const UnknownFailure('boom', code: 'unknown'));

      await expectLater(
        repo.createCat(
          ownerId: 'alice',
          draft: CatDraft(name: 'Mimi'),
        ),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('CatRepository.updateCat', () {
    late _MockFirestoreService firestore;
    late _MockStorageService storage;
    late CatRepository repo;

    setUp(() {
      firestore = _MockFirestoreService();
      storage = _MockStorageService();
      repo = CatRepository(
        firestoreService: firestore,
        storageService: storage,
        uuid: _FixedUuid('cat-42'),
      );
    });

    Map<String, dynamic> sampleDoc() {
      return <String, dynamic>{
        'name': 'Mimi Two',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2024, 6, 1).toIso8601String(),
        'neutered': false,
        'indoor': true,
        'allergies': <String>[],
        'diseases': <String>[],
        'medications': <String>[],
        'priorities': <String>[],
      };
    }

    test('writes a merge patch with updatedAt and the new fields',
        () async {
      when(() => firestore.writeDocument(
            any<String>(),
            any<Map<String, dynamic>>(),
            merge: any<bool>(named: 'merge'),
          )).thenAnswer((_) async {});
      when(() => firestore.readDocument(any<String>()))
          .thenAnswer((_) async => sampleDoc());

      final CatProfile updated = await repo.updateCat(
        ownerId: 'alice',
        catId: 'cat-42',
        name: 'Mimi Two',
        neutered: true,
      );

      expect(updated.name, 'Mimi Two');
      final captured = verify(
        () => firestore.writeDocument(
          captureAny<String>(),
          captureAny<Map<String, dynamic>>(),
          merge: captureAny<bool>(named: 'merge'),
        ),
      ).captured;
      expect(captured[2], isTrue, reason: 'merge flag must be true');
      final patch = captured[1] as Map<String, dynamic>;
      expect(patch['name'], 'Mimi Two');
      expect(patch['neutered'], true);
      expect(patch['updatedAt'], isA<String>());
    });

    test('trims name on update', () async {
      when(() => firestore.writeDocument(
            any<String>(),
            any<Map<String, dynamic>>(),
            merge: any<bool>(named: 'merge'),
          )).thenAnswer((_) async {});
      when(() => firestore.readDocument(any<String>()))
          .thenAnswer((_) async => sampleDoc());

      await repo.updateCat(
        ownerId: 'alice',
        catId: 'cat-42',
        name: '  Mimi Two  ',
      );

      final captured = verify(
        () => firestore.writeDocument(
          any<String>(),
          captureAny<Map<String, dynamic>>(),
          merge: any<bool>(named: 'merge'),
        ),
      ).captured;
      final patch = captured.single as Map<String, dynamic>;
      expect(patch['name'], 'Mimi Two');
    });
  });

  group('CatRepository.uploadCatPhoto', () {
    late _MockFirestoreService firestore;
    late _MockStorageService storage;
    late CatRepository repo;

    setUp(() {
      firestore = _MockFirestoreService();
      storage = _MockStorageService();
      repo = CatRepository(
        firestoreService: firestore,
        storageService: storage,
        uuid: _FixedUuid('cat-42'),
      );
    });

    test('uploads to users/{uid}/cats/{catId}/photo.jpg', () async {
      when(() => storage.uploadBytes(
            path: any<String>(named: 'path'),
            bytes: any<Uint8List>(named: 'bytes'),
            contentType: any<String>(named: 'contentType'),
          )).thenAnswer((_) async => 'https://example.com/mimi.jpg');

      final String url = await repo.uploadCatPhoto(
        ownerId: 'alice',
        catId: 'cat-42',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(url, 'https://example.com/mimi.jpg');
      final captured = verify(() => storage.uploadBytes(
            path: captureAny<String>(named: 'path'),
            bytes: any<Uint8List>(named: 'bytes'),
            contentType: any<String>(named: 'contentType'),
          )).captured;
      expect(captured.single as String, 'users/alice/cats/cat-42/photo.jpg');
    });
  });

  group('CatRepository.deleteCat', () {
    late _MockFirestoreService firestore;
    late _MockStorageService storage;
    late CatRepository repo;

    setUp(() {
      firestore = _MockFirestoreService();
      storage = _MockStorageService();
      repo = CatRepository(
        firestoreService: firestore,
        storageService: storage,
        uuid: _FixedUuid('cat-42'),
      );
    });

    test('deletes the firestore document and skips storage when no url',
        () async {
      when(() => firestore.deleteDocument(any<String>()))
          .thenAnswer((_) async {});

      await repo.deleteCat(ownerId: 'alice', catId: 'cat-42');

      verify(() => firestore.deleteDocument('users/alice/cats/cat-42'))
          .called(1);
      verifyNever(() => storage.delete(any<String>()));
    });

    test('best-effort cleans up storage when photoUrl is provided',
        () async {
      const String url =
          'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Falice%2Fcats%2Fcat-42%2Fphoto.jpg';
      when(() => firestore.deleteDocument(any<String>()))
          .thenAnswer((_) async {});
      when(() => storage.delete(any<String>())).thenAnswer((_) async {});

      await repo.deleteCat(
        ownerId: 'alice',
        catId: 'cat-42',
        photoUrl: url,
      );

      final captured = verify(() => storage.delete(captureAny<String>()))
          .captured;
      expect(captured.single, 'users/alice/cats/cat-42/photo.jpg');
    });

    test('storage failure does NOT block the firestore deletion', () async {
      const String url = 'https://example.com/mimi.jpg';
      when(() => firestore.deleteDocument(any<String>()))
          .thenAnswer((_) async {});
      when(() => storage.delete(any<String>())).thenThrow(
        const UnknownFailure('storage down', code: 'unknown'),
      );

      await repo.deleteCat(
        ownerId: 'alice',
        catId: 'cat-42',
        photoUrl: url,
      );

      verify(() => firestore.deleteDocument('users/alice/cats/cat-42'))
          .called(1);
    });
  });

  group('CatRepository.catDocPath', () {
    test('formats under users/{owner}/cats/{id}', () {
      expect(
        CatRepository.catDocPath('alice', 'cat-42'),
        'users/alice/cats/cat-42',
      );
    });
  });
}
