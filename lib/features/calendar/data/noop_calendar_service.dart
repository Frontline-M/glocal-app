import '../application/calendar_service.dart';
import '../domain/calendar_event_summary.dart';

class NoopCalendarService implements CalendarService {
  @override
  Future<CalendarEventSummary?> nextUpcomingEvent({
    required DateTime now,
    required Duration within,
  }) async {
    return null;
  }
}
