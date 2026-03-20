import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/features/settings/domain/user_settings.dart';
import 'package:glocal/features/steps/application/step_announcement_service.dart';
import 'package:glocal/features/steps/application/step_announcement_speaker.dart';
import 'package:glocal/features/steps/application/step_announcement_store.dart';
import 'package:glocal/features/steps/data/chained_step_data_provider.dart';
import 'package:glocal/features/steps/domain/daily_step_snapshot.dart';
import 'package:glocal/features/steps/domain/step_announcement_mode.dart';
import 'package:glocal/features/steps/domain/step_data_provider.dart';

void main() {
  group('StepAnnouncementService', () {
    test('announces a new milestone once per day', () async {
      final provider = _FakeStepDataProvider(
        snapshot: DailyStepSnapshot(
          stepsToday: 4200,
          capturedAt: DateTime(2026, 3, 20, 10, 0),
          source: StepDataSource.localFallback,
        ),
      );
      final speaker = _FakeStepAnnouncementSpeaker();
      final service = StepAnnouncementService(
        provider: provider,
        speaker: speaker,
        store: MemoryStepAnnouncementStore(),
      );
      final settings = UserSettings.defaults().copyWith(
        stepAnnouncementsEnabled: true,
        stepAnnouncementMode: StepAnnouncementMode.milestonesOnly,
        dailyStepGoal: 8000,
        adaptiveBatteryMode: false,
      );

      await service.runCycle(DateTime(2026, 3, 20, 10, 0), settings);
      await service.runCycle(DateTime(2026, 3, 20, 10, 5), settings);

      expect(speaker.milestones, [50]);
      expect(speaker.periodicSummaries, 0);
      expect(speaker.endOfDaySummaries, 0);
    });

    test('announces periodic summary in periodic plus summary mode', () async {
      final provider = _FakeStepDataProvider(
        snapshot: DailyStepSnapshot(
          stepsToday: 3600,
          capturedAt: DateTime(2026, 3, 20, 12, 0),
          source: StepDataSource.localFallback,
        ),
      );
      final speaker = _FakeStepAnnouncementSpeaker();
      final service = StepAnnouncementService(
        provider: provider,
        speaker: speaker,
        store: MemoryStepAnnouncementStore(),
      );
      final settings = UserSettings.defaults().copyWith(
        stepAnnouncementsEnabled: true,
        stepAnnouncementMode: StepAnnouncementMode.periodicAndSummary,
        adaptiveBatteryMode: false,
      );

      await service.runCycle(DateTime(2026, 3, 20, 12, 0), settings);

      expect(speaker.periodicSummaries, 1);
      expect(speaker.endOfDaySummaries, 0);
    });

    test('announces end of day summary once after threshold hour', () async {
      final provider = _FakeStepDataProvider(
        snapshot: DailyStepSnapshot(
          stepsToday: 9100,
          capturedAt: DateTime(2026, 3, 20, 20, 0),
          source: StepDataSource.localFallback,
        ),
      );
      final speaker = _FakeStepAnnouncementSpeaker();
      final service = StepAnnouncementService(
        provider: provider,
        speaker: speaker,
        store: MemoryStepAnnouncementStore(),
      );
      final settings = UserSettings.defaults().copyWith(
        stepAnnouncementsEnabled: true,
        stepAnnouncementMode: StepAnnouncementMode.summaryOnly,
        adaptiveBatteryMode: false,
      );

      await service.runCycle(DateTime(2026, 3, 20, 20, 0), settings);
      await service.runCycle(DateTime(2026, 3, 20, 20, 5), settings);

      expect(speaker.endOfDaySummaries, 1);
      expect(speaker.periodicSummaries, 0);
      expect(speaker.milestones, isEmpty);
    });
  });

  group('ChainedStepDataProvider', () {
    test('returns the first available provider snapshot', () async {
      final provider = ChainedStepDataProvider([
        _FakeStepDataProvider(
          availabilityValue: StepProviderAvailability.unavailable,
        ),
        _FakeStepDataProvider(
          snapshot: DailyStepSnapshot(
            stepsToday: 1234,
            capturedAt: DateTime(2026, 3, 20, 9, 0),
            source: StepDataSource.healthConnect,
          ),
        ),
      ]);

      final snapshot = await provider.readToday(DateTime(2026, 3, 20, 9, 0));

      expect(snapshot?.stepsToday, 1234);
      expect(snapshot?.source, StepDataSource.healthConnect);
    });
  });
}

class _FakeStepDataProvider implements StepDataProvider {
  _FakeStepDataProvider({
    this.snapshot,
    this.availabilityValue = StepProviderAvailability.available,
  });

  final DailyStepSnapshot? snapshot;
  final StepProviderAvailability availabilityValue;

  @override
  String get providerId => 'fake';

  @override
  StepDataSource get source => snapshot?.source ?? StepDataSource.none;

  @override
  Future<StepProviderAvailability> availability() async => availabilityValue;

  @override
  Future<bool> requestAccess() async =>
      availabilityValue == StepProviderAvailability.available;

  @override
  Future<DailyStepSnapshot?> readToday(DateTime now) async => snapshot;
}

class _FakeStepAnnouncementSpeaker implements StepAnnouncementSpeaker {
  final List<int> milestones = <int>[];
  int periodicSummaries = 0;
  int endOfDaySummaries = 0;

  @override
  Future<void> speakEndOfDaySummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  }) async {
    endOfDaySummaries += 1;
  }

  @override
  Future<void> speakMilestoneReached({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
    required int milestonePercent,
  }) async {
    milestones.add(milestonePercent);
  }

  @override
  Future<void> speakPeriodicSummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  }) async {
    periodicSummaries += 1;
  }
}
