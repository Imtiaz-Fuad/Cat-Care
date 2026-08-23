import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/content/vaccine_info.dart';
import '../../../core/models/notification_schedule.dart';
import '../../../core/models/vaccination.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/content/content_repository.dart';
import '../../../core/services/notification_service.dart';
import '../../health/providers/vaccination_provider.dart';
import '../../health/services/vaccination_manager.dart';
import '../repositories/notification_schedule_repository.dart';
import 'notification_scheduler_service.dart' show NotificationSchedulerService;

/// Watches the active cat's vaccinations and schedules a reminder
/// `warningWindowDays` before `nextDue` for any vaccine with
/// `reminderEnabled == true` and a known cadence.
///
/// Cancellation: when a vaccination is removed or its `reminderEnabled`
/// flag flips to false, the matching schedule doc + local
/// notification are deleted.
class VaccinationReminderScheduler extends ChangeNotifier {
  VaccinationReminderScheduler({
    required this._repository,
    required this._notificationService,
    required this._provider,
    required this._manager,
    required this._content,
    required this._catIdProvider,
    this._warningWindowDays = 7,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now {
    _provider.addListener(_handleChanged);
    _listenerHandles.add(_handleChanged);
  }

  final NotificationScheduleRepository _repository;
  final NotificationService _notificationService;
  final VaccinationProvider _provider;
  final VaccinationManager _manager;
  final ContentRepository _content;
  final String Function() _catIdProvider;
  final int _warningWindowDays;
  final DateTime Function() _clock;

  final List<VoidCallback> _listenerHandles = <VoidCallback>[];
  bool _busy = false;
  bool get isBusy => _busy;

  Future<void> syncNow() => _sync();
  Future<void> cancelAll() async => _notificationService.cancelAll();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _handleChanged() => _sync();

  Future<void> _sync() async {
    if (_busy) return;
    final catId = _catIdProvider();
    _busy = true;
    try {
      await _notificationService.initialize();
      final List<Vaccination> items = _provider.records
          .where((Vaccination v) => v.reminderEnabled)
          .toList();
      final List<_Planned> planned = <_Planned>[];
      for (final Vaccination v in items) {
        final _Planned? p = await _planFromVaccination(v, catId);
        if (p != null) planned.add(p);
      }
      for (final _Planned p in planned) {
        await _repository.upsert(ownerId: catId, schedule: p.schedule);
        await _notificationService.schedule(
          id: p.notificationId,
          title: p.schedule.title,
          body: p.schedule.body,
          when: p.schedule.fireAt,
          payload: p.schedule.payload,
        );
      }
      // ignore: unawaited_futures
      _pruneStale(catId: catId, keep: planned);
    } catch (error, stack) {
      AppLogger.w('VaccinationReminderScheduler.sync failed', error, stack);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<_Planned?> _planFromVaccination(
    Vaccination v,
    String catId,
  ) async {
    try {
      final VaccineInfo? info =
          await _content.getVaccineInfo(v.vaccineCode);
      if (info == null) return null;
      final DateTime? due = _manager.nextDue(vaccination: v, info: info);
      if (due == null) return null;
      final DateTime fire = due.subtract(Duration(days: _warningWindowDays));
      if (!fire.isAfter(_clock())) {
        // Already inside the warning window or past it — skip; the
        // dashboard surfaces overdue state separately.
        return null;
      }
      final String key = 'vaccination:${v.id}';
      final NotificationSchedule schedule = NotificationSchedule(
        id: key,
        catId: catId,
        channelKey: AppConstants.notificationsChannelVaccines,
        title: 'Vaccine due soon \u2014 ${info.name}',
        body: 'Booster for ${info.name} is due on '
            '${_friendlyDate(due)}.',
        fireAt: fire,
        payload: 'vaccination/${v.id}',
        sourceType: 'vaccination',
        sourceId: v.id,
      );
      return _Planned(
        key: key,
        schedule: schedule,
        notificationId:
            NotificationSchedulerService.idForKey(key),
      );
    } catch (error, stack) {
      AppLogger.w(
        'VaccinationReminderScheduler.plan failed for ${v.id}',
        error,
        stack,
      );
      return null;
    }
  }

  static String _friendlyDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pruneStale({
    required String catId,
    required List<_Planned> keep,
  }) async {
    final Set<String> keepKeys = keep.map((p) => p.key).toSet();
    try {
      final stream = _repository.watchSchedules(ownerId: catId);
      final List<NotificationSchedule> existing = await stream.first;
      for (final NotificationSchedule s in existing) {
        if (s.sourceType != 'vaccination') continue;
        if (keepKeys.contains(s.id)) continue;
        await _repository.delete(ownerId: catId, scheduleId: s.id);
        await _notificationService
            .cancel(NotificationSchedulerService.idForKey(s.id));
      }
    } catch (error, stack) {
      AppLogger.w(
        'VaccinationReminderScheduler.pruneStale failed',
        error,
        stack,
      );
    }
  }

  @override
  void dispose() {
    for (final VoidCallback listener in _listenerHandles) {
      _provider.removeListener(listener);
    }
    _listenerHandles.clear();
    super.dispose();
  }
}

class _Planned {
  const _Planned({
    required this.key,
    required this.schedule,
    required this.notificationId,
  });
  final String key;
  final NotificationSchedule schedule;
  final int notificationId;
}