import '../domain/daily_step_snapshot.dart';
import '../domain/step_data_provider.dart';

class ChainedStepDataProvider implements StepDataProvider {
  ChainedStepDataProvider(this._providers);

  final List<StepDataProvider> _providers;

  @override
  String get providerId => _providers.isEmpty ? 'noop' : 'chain';

  @override
  StepDataSource get source => StepDataSource.none;

  @override
  Future<StepProviderAvailability> availability() async {
    for (final provider in _providers) {
      final availability = await provider.availability();
      if (availability == StepProviderAvailability.available ||
          availability == StepProviderAvailability.permissionRequired) {
        return availability;
      }
    }
    return StepProviderAvailability.unavailable;
  }

  @override
  Future<DailyStepSnapshot?> readToday(DateTime now) async {
    for (final provider in _providers) {
      final availability = await provider.availability();
      if (availability != StepProviderAvailability.available) {
        continue;
      }

      final snapshot = await provider.readToday(now);
      if (snapshot != null) {
        return snapshot;
      }
    }
    return null;
  }
}
