import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/features/announcements/data/hourly_announcement_scheduler.dart';

void main() {
  test('scheduler runs once per hour', () {
    final scheduler = HourlyAnnouncementScheduler();

    final first = DateTime(2026, 3, 5, 10, 0);
    final sameHour = DateTime(2026, 3, 5, 10, 0, 20);
    final nextHour = DateTime(2026, 3, 5, 11, 0);

    expect(scheduler.shouldRun(first), isTrue);
    expect(scheduler.shouldRun(sameHour), isFalse);
    expect(scheduler.shouldRun(nextHour), isTrue);
  });
}
