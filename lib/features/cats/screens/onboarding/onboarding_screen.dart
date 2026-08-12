import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/app_failure.dart';
import '../../providers/cat_provider.dart';
import '../../services/cat_photo_picker.dart';
import '../../widgets/onboarding_step_indicator.dart';
import 'onboarding_controller.dart';
import 'onboarding_steps.dart';

/// 5-step onboarding flow. Owns its own [OnboardingController] for
/// the duration of the user's session — the controller is rebuilt
/// per visit so going back doesn't accidentally carry state.
///
/// On successful save:
///   1. The draft is converted to a [CatProfile] via
///      [CatRepository.createCat] (called inside [CatProvider]).
///   2. The new cat id becomes active.
///   3. We pop the navigator and let `AuthGate` redirect to either
///      `/home` (if the user now has cats) or stay on a refreshed
///      onboarding screen (rare, e.g. manual reset).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pages = PageController();
  late final OnboardingController _controller = OnboardingController();
  late final CatPhotoPicker _picker = CatPhotoPicker();

  static const List<String> _stepLabels = <String>[
    'Photo',
    'Name',
    'Details',
    'Priorities',
    'Done',
  ];

  @override
  void dispose() {
    _pages.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int step) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pick({required bool fromCamera}) async {
    try {
      final PickedCatPhoto? picked = fromCamera
          ? await _picker.takePhoto()
          : await _picker.pickFromGallery();
      if (picked == null) return;
      await _controller.analyzePhoto(
        bytes: picked.bytes,
        localPath: picked.path,
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load photo: $error')),
      );
    }
  }

  Future<void> _finish() async {
    if (!_controller.canFinish) return;
    final CatProvider cats = context.read<CatProvider>();
    final Object? result = await cats.createCat(_controller.draft);
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cat profile saved')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else if (cats.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cats.lastError!.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a cat'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            OnboardingStepIndicator(
              current: _controller.step,
              total: OnboardingController.stepCount,
              label: _stepLabels[_controller.step],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  return PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int i) {
                      // PageView fires for both directions; gate via
                      // controller so a stale drag can't push us past
                      // a step the user hasn't unlocked.
                      _controller.goTo(i);
                    },
                    children: <Widget>[
                      OnboardingPhotoStep(
                        controller: _controller,
                        onPickFromGallery: () => _pick(fromCamera: false),
                        onTakePhoto: () => _pick(fromCamera: true),
                      ),
                      OnboardingNameStep(controller: _controller),
                      OnboardingDetailsStep(controller: _controller),
                      OnboardingPrioritiesStep(controller: _controller),
                      OnboardingDoneStep(controller: _controller),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  final bool atLast =
                      _controller.step == OnboardingController.stepCount - 1;
                  return Row(
                    children: <Widget>[
                      if (_controller.step > 0)
                        TextButton.icon(
                          onPressed: () {
                            _controller.back();
                            _animateTo(_controller.step);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        )
                      else
                        TextButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                          child: const Text('Skip for now'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: atLast
                            ? (_controller.canFinish ? _finish : null)
                            : (_controller.canAdvance
                                ? () {
                                    _controller.next();
                                    _animateTo(_controller.step);
                                  }
                                : null),
                        child: Text(atLast ? 'Finish' : 'Next'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}