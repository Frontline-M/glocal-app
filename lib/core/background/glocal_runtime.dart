import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive/hive.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';

import '../speech/speech_governance.dart';
import '../../features/announcements/application/announcement_service.dart';
import '../../features/calendar/application/calendar_service.dart';
import '../../features/calendar/data/device_calendar_service.dart';
import '../../features/calendar/data/noop_calendar_service.dart';
import '../../features/calendar/domain/calendar_event_summary.dart';
import '../../features/reminders/application/reminder_service.dart';
import '../../features/reminders/data/hive_reminder_repository.dart';
import '../../features/settings/application/location_profile_service.dart';
import '../../features/settings/application/settings_service.dart';
import '../../features/settings/data/hive_settings_repository.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../features/steps/application/step_announcement_service.dart';
import '../../features/steps/application/step_provider.dart';
import '../../features/steps/application/step_announcement_store.dart';
import '../../features/steps/data/chained_step_data_provider.dart';
import '../../features/steps/data/method_channel_step_data_provider.dart';
import '../../features/steps/data/noop_step_data_provider.dart';
import '../../features/steps/domain/daily_step_snapshot.dart';
import '../../features/weather/application/weather_service.dart';
import '../../features/weather/data/open_meteo_weather_repository.dart';
import '../../features/weather/domain/weather_snapshot.dart';
import '../storage/hive_bootstrap.dart';
import '../storage/notification_bootstrap.dart';
import '../storage/notification_registry.dart';

class GlocalRuntime {
  GlocalRuntime._({
    required ReminderService reminderService,
    required AnnouncementService announcementService,
    required WeatherService weatherService,
    required SettingsService settingsService,
    required LocationProfileService locationProfileService,
    required StepAnnouncementService stepAnnouncementService,
    required Box<dynamic> runtimeBox,
  })  : _reminderService = reminderService,
        _announcementService = announcementService,
        _weatherService = weatherService,
        _settingsService = settingsService,
        _locationProfileService = locationProfileService,
        _stepAnnouncementService = stepAnnouncementService,
        _runtimeBox = runtimeBox;

  static const _lastReminderSlotKey = 'last_reminder_slot';
  static const _lastAnnouncementHourKey = 'last_announcement_hour';
  static const _lastRecoveryAtKey = 'last_recovery_at';

  final ReminderService _reminderService;
  final AnnouncementService _announcementService;
  final WeatherService _weatherService;
  final SettingsService _settingsService;
  final LocationProfileService _locationProfileService;
  final StepAnnouncementService _stepAnnouncementService;
  final Box<dynamic> _runtimeBox;

  static Future<GlocalRuntime> bootstrap() async {
    await HiveBootstrap.init();
    NotificationRegistry.plugin = await NotificationBootstrap.init();
    final runtimeBox = Hive.box<dynamic>(HiveBootstrap.runtimeBox);
    final governanceService = SpeechGovernanceService(
      HiveSpeechGovernanceStore(runtimeBox),
    );
    final settingsService = SettingsService(HiveSettingsRepository.fromHive());

    final reminderService = ReminderService(
      speechToText: SpeechToText(),
      notifications: NotificationRegistry.plugin,
      repository: HiveReminderRepository.fromHive(),
      tts: FlutterTts(),
      recorder: AudioRecorder(),
      audioPlayer: AudioPlayer(),
      settingsService: settingsService,
      governanceService: governanceService,
    );

    final weatherService = WeatherService(
      OpenMeteoWeatherRepository.fromDefaults(),
    );

    CalendarService calendarService;
    if (NotificationBootstrap.isAndroidRuntime) {
      calendarService = DeviceCalendarService();
    } else {
      calendarService = NoopCalendarService();
    }

    final announcementService = AnnouncementService(
      FlutterTts(),
      calendarService,
      governanceService: governanceService,
      fallbackNextEvent: (now, within) async {
        final reminders = await reminderService.list();
        final end = now.add(within);
        for (final reminder in reminders) {
          if (reminder.when.isAfter(now) && reminder.when.isBefore(end)) {
            return CalendarEventSummary(
              title: reminder.title,
              start: reminder.when,
            );
          }
        }
        return null;
      },
    );
    final stepAnnouncementService = StepAnnouncementService(
      provider: ChainedStepDataProvider([
        MethodChannelStepDataProvider(
          channelName: 'glocal/steps/health_connect',
          providerId: 'health_connect',
          source: StepDataSource.healthConnect,
        ),
        MethodChannelStepDataProvider(
          channelName: 'glocal/steps/samsung_health',
          providerId: 'samsung_health',
          source: StepDataSource.samsungHealth,
        ),
        MethodChannelStepDataProvider(
          channelName: 'glocal/steps/local_fallback',
          providerId: 'local_fallback',
          source: StepDataSource.localFallback,
        ),
        NoopStepDataProvider(),
      ]),
      speaker: AnnouncementStepSpeaker(announcementService),
      store: HiveStepAnnouncementStore(runtimeBox),
    );

    return GlocalRuntime._(
      reminderService: reminderService,
      announcementService: announcementService,
      weatherService: weatherService,
      settingsService: settingsService,
      locationProfileService: LocationProfileService(),
      stepAnnouncementService: stepAnnouncementService,
      runtimeBox: runtimeBox,
    );
  }

  Future<void> recoverMissedReminders() async {
    final now = DateTime.now();
    final lastRecoveryAt =
        (_runtimeBox.get(_lastRecoveryAtKey) as num?)?.toInt();
    final recentlyRecovered = lastRecoveryAt != null &&
        now.millisecondsSinceEpoch - lastRecoveryAt <
            const Duration(minutes: 1).inMilliseconds;
    if (recentlyRecovered) {
      return;
    }

    await _reminderService.recoverMissedReminders(now);
    await _runtimeBox.put(_lastRecoveryAtKey, now.millisecondsSinceEpoch);
  }

  Future<void> tick(DateTime now) async {
    final baseSettings = await _settingsService.load();
    final settings = await _locationProfileService.apply(baseSettings);

    await _runReminderCycle(now, settings);
    await _runStepCycle(now, settings);
    await _runHourlyCycle(now, settings);
  }

  Future<void> _runReminderCycle(DateTime now, UserSettings settings) async {
    final reminderCheckEvery = settings.adaptiveBatteryMode
        ? const Duration(seconds: 60)
        : const Duration(seconds: 15);
    final slot =
        now.millisecondsSinceEpoch ~/ reminderCheckEvery.inMilliseconds;
    final lastSlot = (_runtimeBox.get(_lastReminderSlotKey) as num?)?.toInt();
    if (lastSlot == slot) {
      return;
    }

    await _runtimeBox.put(_lastReminderSlotKey, slot);
    await _reminderService.announceDueReminders(now);
  }

  Future<void> _runHourlyCycle(DateTime now, UserSettings settings) async {
    final hourKey =
        (now.year * 1000000) + (now.month * 10000) + (now.day * 100) + now.hour;
    final lastHourKey =
        (_runtimeBox.get(_lastAnnouncementHourKey) as num?)?.toInt();

    if (lastHourKey == null) {
      await _runtimeBox.put(_lastAnnouncementHourKey, hourKey);
      return;
    }

    if (lastHourKey == hourKey) {
      return;
    }

    await _runtimeBox.put(_lastAnnouncementHourKey, hourKey);

    WeatherSnapshot? weather;
    try {
      weather = await _weatherService.refresh(
        lowBandwidth: settings.lowBandwidthMode || settings.adaptiveBatteryMode,
      );
    } catch (_) {
      weather = await _weatherService.cached();
    }

    await _announcementService.speakHourlyBundle(
      now: now,
      settings: settings,
      weather: weather,
    );
  }

  Future<void> _runStepCycle(DateTime now, UserSettings settings) async {
    await _stepAnnouncementService.runCycle(now, settings);
  }
}
