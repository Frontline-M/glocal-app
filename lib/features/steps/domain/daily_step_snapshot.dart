enum StepDataSource {
  healthConnect,
  samsungHealth,
  localFallback,
  none,
}

class DailyStepSnapshot {
  const DailyStepSnapshot({
    required this.stepsToday,
    required this.capturedAt,
    required this.source,
  });

  final int stepsToday;
  final DateTime capturedAt;
  final StepDataSource source;
}
