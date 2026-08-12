// Unit tests for `NotificationSchedulerService.idForKey` — the
// deterministic notification-id generator that backs the
// `routine:{taskId}` schedules. Stability of this id is critical:
// if the same task produced a different id between syncs, the OS
// would treat them as unrelated notifications and the user would
// see duplicates or ghost reminders.
//
// We assert three properties:
//
//   * Same input → same output (purity).
//   * Different inputs → different outputs (collision-free for the
//     routine-id namespace we care about).
//   * Output is non-negative and fits in a 31-bit signed int
//     (Android notification ids are 32-bit signed; we mask to the
//     positive half so the OS never interprets the id as negative).
import 'package:cat_care/features/notifications/services/notification_scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationSchedulerService.idForKey', () {
    test('is stable for the same input', () {
      expect(
        NotificationSchedulerService.idForKey('routine:abc'),
        NotificationSchedulerService.idForKey('routine:abc'),
      );
    });

    test('produces distinct ids for distinct routine ids', () {
      final List<int> ids = <String>[
        'routine:abc',
        'routine:def',
        'routine:xyz',
        'routine:1',
        'routine:2',
        'routine:mochi-1234',
      ].map(NotificationSchedulerService.idForKey).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('output is in the 31-bit positive range', () {
      // The implementation masks with `& 0x7fffffff` so we know the
      // upper bound exactly. The lower bound is 0 (no negative ids).
      for (final String key in <String>[
        'routine:a',
        'routine:very-long-task-id-with-dashes',
        'routine:!@#\$%^&*()',
        'routine:',
      ]) {
        final int id = NotificationSchedulerService.idForKey(key);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('empty key is deterministic', () {
      // Empty input is a degenerate case; document the value rather
      // than asserting on it (the OS doesn't schedule empty ids).
      final int a = NotificationSchedulerService.idForKey('');
      final int b = NotificationSchedulerService.idForKey('');
      expect(a, b);
    });

    test('mirrors the documented hashing polynomial', () {
      // The generation rule is `hash(n) = hash(n-1) * 31 + code` with
      // a 31-bit positive mask. For a single-char input we can hand-
      // compute the expected value.
      // 'a' = 0x61 (97). hash = (0 * 31 + 97) & 0x7fffffff = 97.
      expect(NotificationSchedulerService.idForKey('a'), 97);
    });
  });
}
