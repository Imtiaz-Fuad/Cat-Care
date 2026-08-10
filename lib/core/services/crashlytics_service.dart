import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app_logger.dart';

/// Thin wrapper around `FirebaseCrashlytics`.
///
/// Crashlytics stays opt-in until the user has actually authenticated
/// OR explicitly opted in to anonymous telemetry. The `enabled` flag
/// is a separate concern from `FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled`
/// and is the single source of truth for *this* app's policy.
class CrashlyticsService {
  CrashlyticsService({FirebaseCrashlytics? instance})
      : _crashlytics = instance ?? FirebaseCrashlytics.instance;

  /// Test seam.
  static FirebaseCrashlytics? instanceOverride;

  final FirebaseCrashlytics _crashlytics;
  FirebaseCrashlytics get instance {
    if (instanceOverride != null) return instanceOverride!;
    return _crashlytics;
  }

  bool _enabled = false;

  /// Whether the app is currently forwarding crashes / non-fatal errors
  /// to Crashlytics.
  bool get enabled => _enabled;

  /// Enable or disable Crashlytics collection. Disabling also clears
  /// the user identifier so we never attribute data to a stale session.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await instance.setCrashlyticsCollectionEnabled(value);
    if (!value) {
      await instance.setUserIdentifier('');
    }
    AppLogger.i('Crashlytics enabled=$value');
  }

  /// Tag the current session with the authenticated user's uid (or
  /// 'guest' for anonymous sessions). No-op when Crashlytics is off.
  Future<void> tagUser(String userId) async {
    if (!_enabled) return;
    await instance.setUserIdentifier(userId);
  }

  /// Record a caught, non-fatal error. No-op when Crashlytics is off.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String reason = '',
    bool fatal = false,
  }) async {
    if (!_enabled) return;
    try {
      await instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } on FirebaseException catch (caught, caughtStack) {
      AppLogger.w(
        'Crashlytics.recordError failed; suppressing.',
        caught,
        caughtStack,
      );
    }
  }

  /// Log a breadcrumb that appears in the Crashlytics report for any
  /// crash / non-fatal that follows. No-op when disabled.
  Future<void> log(String message) async {
    if (!_enabled) return;
    await instance.log(message);
  }
}
