import 'package:cat_care/features/cats/models/cat_draft.dart';
import 'package:cat_care/features/cats/screens/onboarding/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('details step requires an estimated weight', () {
    final OnboardingController controller = OnboardingController();
    addTearDown(controller.dispose);

    controller.next();
    controller.updateDraft((CatDraft draft) => draft.copyWith(name: 'Mimi'));
    controller.next();

    expect(controller.step, 2);
    expect(controller.canAdvance, isFalse);

    controller.updateDraft((CatDraft draft) => draft.copyWith(weightKg: 4.2));

    expect(controller.canAdvance, isTrue);
  });

  test('details step rejects an out-of-range estimated weight', () {
    final OnboardingController controller = OnboardingController(
      initial: CatDraft(name: 'Mimi', weightKg: 15.1),
    );
    addTearDown(controller.dispose);

    controller.goTo(2);

    expect(controller.canAdvance, isFalse);
  });
}
