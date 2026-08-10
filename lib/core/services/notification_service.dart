import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

/// Local notifications wrapper.
///
/// Schedules routine / vaccination / medication reminders shown by the
/// OS even when the app is backgrounded. Push notifications driven by
/// FCM live in [MessagingService]; this class only handles the *local*
/// scheduling surface that the app owns.
///
/// On first use the service initializes the timezone database and
/// resolves the device's IANA zone via `flutter_timezone`, then converts
/// the requested `DateTime` into a `TZDateTime` as required by
/// `flutter_local_notifications.zonedSchedule`.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _timezoneReady = false;

  /// Initialise the platform plugin and the timezone database. Safe to
  /// call multiple times — only the first call has any effect.
  Future<void> initialize() async {
    if (_initialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);

    if (!_timezoneReady) {
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (error, stack) {
        // If the platform channel is unavailable (e.g. test) fall back
        // to UTC — scheduling still works, only wall-clock semantics
        // differ.
        AppLogger.w(
          'NotificationService could not resolve local timezone; '
          'falling back to UTC.',
          error,
          stack,
        );
        tz.setLocalLocation(tz.UTC);
      }
      _timezoneReady = true;
    }

    _initialized = true;
    AppLogger.i('NotificationService initialised');
  }

  /// Ask the OS to surface notifications. Must be called from a user
  /// gesture on iOS or the prompt is suppressed.
  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await androidImpl?.requestNotificationsPermission() ?? true;

    return iosGranted && androidGranted;
  }

  /// Schedule a one-shot notification at [when]. If [when] is in the past
  /// the call is a no-op (logged as a warning).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    if (!when.isAfter(DateTime.now())) {
      AppLogger.w('NotificationService.schedule skipped — time in past: '
          '$id @ $when');
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'catcare_reminders',
        'CatCare reminders',
        channelDescription:
            'Routine, vaccination and medication reminders for your cat.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancel a previously scheduled notification.
  Future<void> cancel(int id) async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id);
  }

  /// Cancel every scheduled notification. Used on logout.
  Future<void> cancelAll() async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
  }

  /// Tap payload of the notification that launched the app (if any).
  /// Returns `null` when the app was not launched from a notification.
  Future<String?> launchPayload() async {
    if (!_initialized) await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }
}