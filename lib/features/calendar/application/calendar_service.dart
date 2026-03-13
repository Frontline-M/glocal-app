import '../domain/calendar_event_summary.dart';

abstract class CalendarService {
  Future<CalendarEventSummary?> nextUpcomingEvent({
    required DateTime now,
    required Duration within,
  });
}
