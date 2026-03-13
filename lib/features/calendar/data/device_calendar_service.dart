import 'package:eventide/eventide.dart';

import '../application/calendar_service.dart';
import '../domain/calendar_event_summary.dart';

class DeviceCalendarService implements CalendarService {
  DeviceCalendarService([Eventide? eventide])
      : _eventide = eventide ?? Eventide();

  final Eventide _eventide;

  @override
  Future<CalendarEventSummary?> nextUpcomingEvent({
    required DateTime now,
    required Duration within,
  }) async {
    try {
      final calendars = await _eventide.retrieveCalendars(
        onlyWritableCalendars: false,
      );
      if (calendars.isEmpty) {
        return null;
      }

      final end = now.add(within);
      final utcNow = now.toUtc();
      final utcEnd = end.toUtc();

      ETEvent? nearest;

      for (final calendar in calendars) {
        final events = await _eventide.retrieveEvents(
          calendarId: calendar.id,
          startDate: utcNow,
          endDate: utcEnd,
        );

        for (final event in events) {
          final title = event.title.trim();
          final startLocal = event.startDate.toLocal();
          if (title.isEmpty) {
            continue;
          }
          if (startLocal.isBefore(now) || startLocal.isAfter(end)) {
            continue;
          }

          if (nearest == null ||
              startLocal.isBefore(nearest.startDate.toLocal())) {
            nearest = event;
          }
        }
      }

      if (nearest == null) {
        return null;
      }

      final title = nearest.title.trim();
      if (title.isEmpty) {
        return null;
      }

      return CalendarEventSummary(
        title: title,
        start: nearest.startDate.toLocal(),
      );
    } on ETPermissionException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
