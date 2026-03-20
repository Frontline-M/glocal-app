import '../../settings/domain/user_settings.dart';
import '../domain/daily_step_snapshot.dart';

abstract class StepAnnouncementSpeaker {
  Future<void> speakPeriodicSummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  });

  Future<void> speakMilestoneReached({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
    required int milestonePercent,
  });

  Future<void> speakEndOfDaySummary({
    required DateTime now,
    required UserSettings settings,
    required DailyStepSnapshot snapshot,
    required int goalSteps,
  });
}
