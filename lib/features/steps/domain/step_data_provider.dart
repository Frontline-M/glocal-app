import 'daily_step_snapshot.dart';

enum StepProviderAvailability {
  available,
  permissionRequired,
  unsupported,
  unavailable,
}

abstract class StepDataProvider {
  String get providerId;

  StepDataSource get source;

  Future<StepProviderAvailability> availability();

  Future<bool> requestAccess();

  Future<DailyStepSnapshot?> readToday(DateTime now);
}
