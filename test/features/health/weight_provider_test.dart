import 'package:cat_care/core/models/weight_entry.dart';
import 'package:cat_care/features/authentication/models/user_profile.dart';
import 'package:cat_care/features/authentication/providers/auth_provider.dart';
import 'package:cat_care/features/health/providers/weight_provider.dart';
import 'package:cat_care/features/health/repositories/weight_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWeightRepository extends Mock implements WeightRepository {}

class _MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      WeightEntry(id: '', catId: '', weightKg: 1, recordedAt: DateTime(2025)),
    );
  });

  test(
    'initial onboarding weight uses a stable ID and supplied date',
    () async {
      final _MockWeightRepository repository = _MockWeightRepository();
      final _MockAuthProvider auth = _MockAuthProvider();
      final DateTime timestamp = DateTime(2026, 9, 4, 18, 30);
      when(() => auth.profile).thenReturn(
        const UserProfile(
          uid: 'user-1',
          email: 'user@example.com',
          isAnonymous: false,
          isEmailVerified: true,
          providerIds: <String>['password'],
        ),
      );
      when(
        () => repository.add('user-1', 'cat-1', any()),
      ).thenAnswer((_) async => 'onboarding');
      final WeightProvider provider = WeightProvider.create(
        repository: repository,
        authProvider: auth,
      );
      addTearDown(provider.dispose);

      final WeightEntry? created = await provider.addInitial(
        catId: 'cat-1',
        weightKg: 4.2,
        recordedAt: timestamp,
      );

      expect(created, isNotNull);
      final WeightEntry stored =
          verify(
                () => repository.add('user-1', 'cat-1', captureAny()),
              ).captured.single
              as WeightEntry;
      expect(stored.id, 'onboarding');
      expect(stored.catId, 'cat-1');
      expect(stored.weightKg, 4.2);
      expect(stored.recordedAt, timestamp);
      expect(stored.createdAt, timestamp);
    },
  );
}
