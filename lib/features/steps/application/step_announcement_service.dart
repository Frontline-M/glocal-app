import '../../settings/domain/user_settings.dart';
import '../domain/daily_step_snapshot.dart';
import '../domain/step_announcement_mode.dart';
import '../domain/step_data_provider.dart';
import 'step_announcement_speaker.dart';
import 'step_announcement_store.dart';

class StepAnnouncementService {
  StepAnnouncementService({
    required StepDataProvider provider,
    required StepAnnouncementSpeaker speaker,
    required StepAnnouncementStore store,
  })  : _provider = provider,
        _speaker = speaker,
        _store = store;

  static const _pollMinutes = 5;
  static const _endOfDaySummaryHour = 20;
  static const _periodicSummaryHours = <int>{9, 12, 15, 18};
  static const _milestonePercents = <int>[25, 50, 75, 100];

  static const _lastStepPollSlotKey = 'step_last_poll_slot';
  static const _lastPeriodicSummaryHourKey = 'step_last_periodic_summary_hour';
  static const _lastEndOfDaySummaryDateKey =
      'step_last_end_of_day_summary_date';
  static const _lastAnnouncedMilestoneDateKey =
      'step_last_announced_milestone_date';
  static const _lastAnnouncedMilestonePercentKey =
      'step_last_announced_milestone_percent';

  final StepDataProvider _provider;
  final StepAnnouncementSpeaker _speaker;
  final StepAnnouncementStore _store;

  Future<StepProviderAvailability> availability() => _provider.availability();

  Future<DailyStepSnapshot?> currentSnapshot(DateTime now) {
    return _provider.readToday(now);
  }

  Future<void> runCycle(DateTime now, UserSettings settings) async {
    if (!settings.stepAnnouncementsEnabled) {
      return;
    }

    if (!await _shouldPoll(now, settings)) {
      return;
    }

    final snapshot = await _provider.readToday(now);
    if (snapshot == null) {
      return;
    }

    final todayKey = _dateKey(snapshot.capturedAt);
    await _resetDailyStateIfNeeded(todayKey);

    if (_shouldAnnounceMilestone(settings, snapshot)) {
      final milestonePercent = _highestReachedMilestonePercent(
        stepsToday: snapshot.stepsToday,
        goalSteps: settings.dailyStepGoal,
      );
      if (milestonePercent != null) {
        await _speaker.speakMilestoneReached(
          now: now,
          settings: settings,
          snapshot: snapshot,
          goalSteps: settings.dailyStepGoal,
          milestonePercent: milestonePercent,
        );
        await _store.put(
          _lastAnnouncedMilestonePercentKey,
          milestonePercent,
        );
        await _store.put(_lastAnnouncedMilestoneDateKey, todayKey);
      }
    }

    if (_shouldAnnouncePeriodicSummary(now, settings)) {
      await _speaker.speakPeriodicSummary(
        now: now,
        settings: settings,
        snapshot: snapshot,
        goalSteps: settings.dailyStepGoal,
      );
      await _store.put(_lastPeriodicSummaryHourKey, _hourKey(now));
    }

    if (_shouldAnnounceEndOfDaySummary(now, settings, todayKey)) {
      await _speaker.speakEndOfDaySummary(
        now: now,
        settings: settings,
        snapshot: snapshot,
        goalSteps: settings.dailyStepGoal,
      );
      await _store.put(_lastEndOfDaySummaryDateKey, todayKey);
    }
  }

  Future<bool> _shouldPoll(DateTime now, UserSettings settings) async {
    final pollEvery = settings.adaptiveBatteryMode ? 15 : _pollMinutes;
    final slot = now.millisecondsSinceEpoch ~/
        Duration(minutes: pollEvery).inMilliseconds;
    final lastSlot = (_store.get(_lastStepPollSlotKey) as num?)?.toInt();
    if (lastSlot == slot) {
      return false;
    }
    await _store.put(_lastStepPollSlotKey, slot);
    return true;
  }

  bool _shouldAnnounceMilestone(
    UserSettings settings,
    DailyStepSnapshot snapshot,
  ) {
    if (!settings.stepAnnouncementMode.includesMilestones) {
      return false;
    }

    final reached = _highestReachedMilestonePercent(
      stepsToday: snapshot.stepsToday,
      goalSteps: settings.dailyStepGoal,
    );
    if (reached == null) {
      return false;
    }

    final lastMilestoneDate =
        (_store.get(_lastAnnouncedMilestoneDateKey) as num?)?.toInt();
    final todayKey = _dateKey(snapshot.capturedAt);
    final lastMilestonePercent =
        (_store.get(_lastAnnouncedMilestonePercentKey) as num?)?.toInt() ?? 0;

    if (lastMilestoneDate != todayKey) {
      return true;
    }
    return reached > lastMilestonePercent;
  }

  bool _shouldAnnouncePeriodicSummary(DateTime now, UserSettings settings) {
    if (settings.stepAnnouncementMode !=
        StepAnnouncementMode.periodicAndSummary) {
      return false;
    }
    if (!_periodicSummaryHours.contains(now.hour)) {
      return false;
    }
    final lastHourKey =
        (_store.get(_lastPeriodicSummaryHourKey) as num?)?.toInt();
    return lastHourKey != _hourKey(now);
  }

  bool _shouldAnnounceEndOfDaySummary(
    DateTime now,
    UserSettings settings,
    int todayKey,
  ) {
    if (!settings.stepAnnouncementMode.includesEndOfDaySummary) {
      return false;
    }
    if (now.hour < _endOfDaySummaryHour) {
      return false;
    }
    final lastDate = (_store.get(_lastEndOfDaySummaryDateKey) as num?)?.toInt();
    return lastDate != todayKey;
  }

  int? _highestReachedMilestonePercent({
    required int stepsToday,
    required int goalSteps,
  }) {
    if (goalSteps <= 0 || stepsToday <= 0) {
      return null;
    }

    int? reached;
    for (final percent in _milestonePercents) {
      final target = ((goalSteps * percent) / 100).ceil();
      if (stepsToday >= target) {
        reached = percent;
      }
    }
    return reached;
  }

  Future<void> _resetDailyStateIfNeeded(int todayKey) async {
    final lastMilestoneDate =
        (_store.get(_lastAnnouncedMilestoneDateKey) as num?)?.toInt();
    if (lastMilestoneDate == null || lastMilestoneDate == todayKey) {
      return;
    }

    await _store.put(_lastAnnouncedMilestonePercentKey, 0);
    await _store.delete(_lastPeriodicSummaryHourKey);
    await _store.delete(_lastEndOfDaySummaryDateKey);
  }

  int _dateKey(DateTime dateTime) {
    return (dateTime.year * 10000) + (dateTime.month * 100) + dateTime.day;
  }

  int _hourKey(DateTime now) {
    return (now.year * 1000000) +
        (now.month * 10000) +
        (now.day * 100) +
        now.hour;
  }
}
