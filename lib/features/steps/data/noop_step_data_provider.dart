import '../domain/daily_step_snapshot.dart';
import '../domain/step_data_provider.dart';

class NoopStepDataProvider implements StepDataProvider {
  @override
  String get providerId => 'noop';

  @override
  StepDataSource get source => StepDataSource.none;

  @override
  Future<StepProviderAvailability> availability() async {
    return StepProviderAvailability.unavailable;
  }

  @override
  Future<DailyStepSnapshot?> readToday(DateTime now) async {
    return null;
  }
}
