import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_logger.dart';

/// Thin wrapper around `FirebaseMessaging` for FCM push notifications.
///
/// Push messages are *separate* from the local notifications scheduled
/// by [NotificationService] — when a message arrives in the foreground
/// the host app decides whether to surface it; when it arrives in the
/// background the OS shows it automatically once the integration is
/// configured.
class MessagingService {
  MessagingService({FirebaseMessaging? instance})
      : _messaging = instance ?? FirebaseMessaging.instance;

  /// Test seam.
  static FirebaseMessaging? instanceOverride;

  final FirebaseMessaging _messaging;
  FirebaseMessaging get instance {
    if (instanceOverride != null) return instanceOverride!;
    return _messaging;
  }

  bool _initialized = false;

  /// Initialise the FCM plugin. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await instance.setAutoInitEnabled(true);
      // We request notification permission lazily so the app can boot
      // without forcing a prompt. The login screen / settings toggle
      // can call [requestPermission] on user gesture.
      _initialized = true;
      AppLogger.i('MessagingService initialised');
    } on FirebaseException catch (error, stack) {
      AppLogger.w(
        'MessagingService.initialize failed; push notifications disabled.',
        error,
        stack,
      );
    }
  }

  /// Ask the OS to allow FCM to surface notifications. Returns the
  /// granted status; honours iOS prompt rules (must be called from a
  /// user gesture for the prompt to appear reliably).
  Future<NotificationSettings?> requestPermission() async {
    if (!_initialized) await initialize();
    try {
      final settings = await instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.i(
        'FCM permission: ${settings.authorizationStatus.name}',
      );
      return settings;
    } on FirebaseException catch (error, stack) {
      AppLogger.w('FCM requestPermission failed', error, stack);
      return null;
    }
  }

  /// Retrieve (and refresh) the device's FCM token. Returns `null` when
  /// the SDK cannot produce one yet.
  Future<String?> currentToken() async {
    if (!_initialized) await initialize();
    try {
      return await instance.getToken();
    } on FirebaseException catch (error, stack) {
      AppLogger.w('FCM getToken failed', error, stack);
      return null;
    }
  }

  /// Stream of refreshed FCM tokens (e.g. after Firebase rotates keys).
  Stream<String> onTokenRefresh() {
    return instance.onTokenRefresh;
  }

  /// Stream of push messages received while the app is in the
  /// foreground. Background messages are handled by the OS once the
  /// background handler is installed.
  Stream<RemoteMessage> onForegroundMessage() {
    return FirebaseMessaging.onMessage;
  }

  /// Stream of taps on notifications that opened the app from the
  /// background.
  Stream<RemoteMessage> onMessageOpenedApp() {
    return FirebaseMessaging.onMessageOpenedApp;
  }
}
