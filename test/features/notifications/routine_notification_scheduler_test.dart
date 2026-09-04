import 'package:cat_care/core/models/cat_profile.dart';
import 'package:cat_care/core/models/notification_schedule.dart';
import 'package:cat_care/core/models/routine_task.dart';
import 'package:cat_care/core/services/notification_service.dart';
import 'package:cat_care/features/authentication/models/user_profile.dart';
import 'package:cat_care/features/cats/providers/cat_provider.dart';
import 'package:cat_care/features/notifications/repositories/notification_schedule_repository.dart';
import 'package:cat_care/features/notifications/services/notification_scheduler_service.dart';
import 'package:cat_care/features/routine/providers/routine_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockScheduleRepository extends Mock
    implements NotificationScheduleRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockRoutineProvider extends Mock implements RoutineProvider {}

class _MockCatProvider extends Mock implements CatProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      NotificationSchedule(
        id: 'fallback',
        catId: 'cat-1',
        channelKey: 'routine',
        title: 'Fallback',
        body: 'Fallback',
        fireAt: DateTime(2026),
      ),
    );
  });

  test('weekday routine installs five weekday recurring reminders', () async {
    final _MockScheduleRepository repository = _MockScheduleRepository();
    final _MockNotificationService notifications = _MockNotificationService();
    final _MockRoutineProvider routines = _MockRoutineProvider();
    final _MockCatProvider cats = _MockCatProvider();
    final RoutineTask task = RoutineTask(
      id: 'breakfast',
      catId: 'cat-1',
      title: 'Breakfast',
      category: 'feeding',
      timeOfDay: DateTime(2026, 9, 4, 8),
      repeat: 'weekdays',
      reminder: true,
      createdAt: DateTime(2026, 9, 4),
    );

    when(() => routines.addListener(any())).thenReturn(null);
    when(() => routines.removeListener(any())).thenReturn(null);
    when(() => routines.routines).thenReturn(<RoutineTask>[task]);
    when(() => cats.addListener(any())).thenReturn(null);
    when(() => cats.removeListener(any())).thenReturn(null);
    when(() => cats.profile).thenReturn(
      const UserProfile(
        uid: 'owner-1',
        email: 'owner@example.com',
        isAnonymous: false,
        isEmailVerified: true,
        providerIds: <String>['password'],
      ),
    );
    when(() => cats.activeCatId).thenReturn('cat-1');
    when(() => cats.activeCat).thenReturn(
      CatProfile(
        id: 'cat-1',
        ownerId: 'owner-1',
        name: 'Mimi',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(() => notifications.initialize()).thenAnswer((_) async {});
    when(
      () => notifications.schedule(
        id: any<int>(named: 'id'),
        title: any<String>(named: 'title'),
        body: any<String>(named: 'body'),
        when: any<DateTime>(named: 'when'),
        payload: any<String?>(named: 'payload'),
        matchDateTimeComponents: any<DateTimeComponents?>(
          named: 'matchDateTimeComponents',
        ),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.upsert(
        ownerId: 'owner-1',
        schedule: any(named: 'schedule'),
      ),
    ).thenAnswer(
      (Invocation call) async =>
          call.namedArguments[#schedule]! as NotificationSchedule,
    );
    when(
      () => repository.watchSchedules(ownerId: 'owner-1'),
    ).thenAnswer((_) => Stream<List<NotificationSchedule>>.value(const []));

    final NotificationSchedulerService scheduler = NotificationSchedulerService(
      repository: repository,
      notificationService: notifications,
      routineProvider: routines,
      catProvider: cats,
      clock: () => DateTime(2026, 9, 4, 12),
    );

    await scheduler.syncNow();
    await Future<void>.delayed(Duration.zero);

    verify(
      () => notifications.schedule(
        id: any<int>(named: 'id'),
        title: any<String>(named: 'title'),
        body: any<String>(named: 'body'),
        when: any<DateTime>(named: 'when'),
        payload: any<String?>(named: 'payload'),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      ),
    ).called(5);
    scheduler.dispose();
  });
}
