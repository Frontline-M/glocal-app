import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/storage/hive_bootstrap.dart';
import '../../announcements/application/announcement_provider.dart';
import '../../announcements/application/announcement_service.dart';
import '../../settings/application/settings_provider.dart';
import '../../settings/domain/user_settings.dart';
import '../data/chained_step_data_provider.dart';
import '../data/method_channel_step_data_provider.dart';
import '../data/noop_step_data_provider.dart';
import '../domain/daily_step_snapshot.dart';
import '../domain/step_data_provider.dart';
import 'step_announcement_service.dart';
import 'step_announcement_speaker.dart';
import 'step_announcement_store.dart';

final stepDataProviderProvider = Provider<StepDataProvider>((ref) {
  return ChainedStepDataProvider([
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
  ]);
});

final stepAnnouncementSpeakerProvider =
    Provider<StepAnnouncementSpeaker>((ref) {
  return AnnouncementStepSpeaker(ref.read(announcementServiceProvider));
});

final stepAnnouncementServiceProvider =
    Provider<StepAnnouncementService>((ref) {
  return StepAnnouncementService(
    provider: ref.read(stepDataProviderProvider),
    speaker: ref.read(stepAnnouncementSpeakerProvider),
    store:
        HiveStepAnnouncementStore(Hive.box<dynamic>(HiveBootstrap.runtimeBox)),
  );
});

final stepAnnouncementControllerProvider =
    Provider<StepAnnouncementController>((ref) {
  return StepAnnouncementController(ref);
});

class StepAnnouncementController {
  StepAnnouncementController(this._ref);

  final Ref _ref;

  Future<void> run(DateTime now) async {
    final asyncSettings = _ref.read(settingsProvider);
    var settings = asyncSettings.value ?? asyncSettings.asData?.value;
    if (settings == null) {
      return;
    }

    settings = await _ref.read(locationProfileServiceProvider).apply(settings);
    await _ref.read(stepAnnouncementServiceProvider).runCycle(now, settings);
  }
}

class AnnouncementStepSpeaker implements StepAnnouncementSpeaker {
  AnnouncementStepSpeaker(this._announcementService);

  final AnnouncementService _announcementService;

  @override
  Future<void> speakEndOfDaySummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  }) {
    return _announcementService.speakEndOfDayStepSummary(
      now: now,
      settings: settings,
      stepsToday: snapshot.stepsToday,
      goalSteps: goalSteps,
    );
  }

  @override
  Future<void> speakMilestoneReached({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
    required int milestonePercent,
  }) {
    return _announcementService.speakStepMilestoneReached(
      now: now,
      settings: settings,
      stepsToday: snapshot.stepsToday,
      goalSteps: goalSteps,
      milestonePercent: milestonePercent,
    );
  }

  @override
  Future<void> speakPeriodicSummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  }) {
    return _announcementService.speakStepProgressSummary(
      now: now,
      settings: settings,
      stepsToday: snapshot.stepsToday,
      goalSteps: goalSteps,
    );
  }
}
