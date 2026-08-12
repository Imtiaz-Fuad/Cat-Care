import 'package:flutter/foundation.dart';

import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/accent_color_extractor.dart';
import '../../models/cat_draft.dart';

/// Owns the in-progress [CatDraft] while the user walks through
/// onboarding. Lives above the screen tree (created by
/// `OnboardingScreen`) so the same draft can be edited across the
/// five step widgets.
class OnboardingController extends ChangeNotifier {
  OnboardingController({CatDraft? initial}) : _draft = initial ?? CatDraft();

  /// Total number of steps. Centralized so the step indicator and
  /// `PageController` agree.
  static const int stepCount = 5;

  CatDraft _draft;
  int _step = 0;

  /// Whether the draft is currently being analyzed (accent color
  /// extraction). The photo step listens to this for its spinner.
  bool _busy = false;

  CatDraft get draft => _draft;
  int get step => _step;
  bool get isBusy => _busy;

  /// Whether the user can move forward from the current step. The
  /// photo step (0) is always skippable; the name step (1) requires
  /// a non-empty name; everything else is optional.
  bool get canAdvance {
    switch (_step) {
      case 0:
        return true; // photo optional
      case 1:
        return _draft.name.trim().isNotEmpty;
      default:
        return true;
    }
  }

  /// True once [canAdvance] is satisfied for the current step AND we
  /// are on the last screen — the "Done" button only enables then.
  bool get canFinish => _step == stepCount - 1 && canAdvance;

  void next() {
    if (!canAdvance) return;
    if (_step < stepCount - 1) {
      _step += 1;
      notifyListeners();
    }
  }

  void back() {
    if (_step > 0) {
      _step -= 1;
      notifyListeners();
    }
  }

  void goTo(int step) {
    if (step < 0 || step >= stepCount) return;
    // Forward jumps require the current step to be valid; backward
    // jumps are always allowed.
    if (step > _step && !canAdvance) return;
    _step = step;
    notifyListeners();
  }

  void updateDraft(CatDraft Function(CatDraft) update) {
    _draft = update(_draft);
    notifyListeners();
  }

  /// Run accent-color extraction on a freshly picked photo. Called by
  /// the photo step after [CatPhotoPicker] returns bytes. Updates
  /// [draft.accentHex] and `draft.photoPath` (a memory pointer so
  /// the preview widget can re-render immediately).
  Future<void> analyzePhoto({
    required Uint8List bytes,
    String? localPath,
  }) async {
    _setBusy(true);
    try {
      final String? hex = await AccentColorExtractor.extractHex(bytes);
      _draft = _draft.copyWith(
        photoPath: localPath,
        photoUrl: null,
        accentHex: hex,
      );
      notifyListeners();
    } catch (error, stack) {
      AppLogger.w('OnboardingController: accent extract failed', error, stack);
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
