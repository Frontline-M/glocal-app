import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../calendar/application/calendar_service.dart';
import '../../calendar/data/device_calendar_service.dart';
import '../../calendar/data/noop_calendar_service.dart';
import '../../calendar/domain/calendar_event_summary.dart';
import '../../reminders/application/reminder_provider.dart';
import '../../settings/application/location_profile_service.dart';
import '../../settings/application/settings_provider.dart';
import '../../weather/application/weather_provider.dart';
import 'announcement_service.dart';

final ttsProvider = Provider<FlutterTts>((ref) => FlutterTts());

final voicesProvider = FutureProvider<List<String>>((ref) async {
  final raw = await ref.read(ttsProvider).getVoices;
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => (e['name'] ?? '').toString())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  if (kIsWeb) {
    return NoopCalendarService();
  }
  return DeviceCalendarService();
});

final locationProfileServiceProvider =
    Provider<LocationProfileService>((ref) => LocationProfileService());

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService(
    ref.read(ttsProvider),
    ref.read(calendarServiceProvider),
    fallbackNextEvent: (now, within) async {
      final reminders = await ref.read(reminderServiceProvider).list();
      reminders.sort((a, b) => a.when.compareTo(b.when));
      final end = now.add(within);
      for (final reminder in reminders) {
        if (reminder.when.isAfter(now) && reminder.when.isBefore(end)) {
          return CalendarEventSummary(title: reminder.title, start: reminder.when);
        }
      }
      return null;
    },
  );
});

final hourlyAnnouncementControllerProvider =
    Provider<HourlyAnnouncementController>((ref) {
  return HourlyAnnouncementController(ref);
});

class HourlyAnnouncementController {
  HourlyAnnouncementController(this._ref);

  final Ref _ref;

  Future<void> run(DateTime now) async {
    final asyncSettings = _ref.read(settingsProvider);
    var settings = asyncSettings.value ?? asyncSettings.asData?.value;
    if (settings == null) return;

    settings = await _ref.read(locationProfileServiceProvider).apply(settings);

    final service = _ref.read(announcementServiceProvider);
    await service.speakHourlyTime(now, settings);
    final weather = _ref.read(weatherProvider).value;
    await service.speakWeather(weather, settings, now);
  }
}
