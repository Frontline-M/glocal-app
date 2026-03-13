import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_provider.dart';
import '../data/open_meteo_weather_repository.dart';
import '../domain/weather_snapshot.dart';
import 'weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService(OpenMeteoWeatherRepository.fromDefaults());
});

final weatherProvider = AsyncNotifierProvider<WeatherNotifier, WeatherSnapshot?>(
  WeatherNotifier.new,
);

class WeatherNotifier extends AsyncNotifier<WeatherSnapshot?> {
  @override
  Future<WeatherSnapshot?> build() async {
    return ref.read(weatherServiceProvider).cached();
  }

  Future<void> refresh() async {
    final settings = ref.read(settingsProvider).value ??
        ref.read(settingsProvider).asData?.value;
    final lowBandwidth =
        (settings?.lowBandwidthMode ?? true) || (settings?.adaptiveBatteryMode ?? false);

    state = const AsyncLoading();
    final latest = await ref
        .read(weatherServiceProvider)
        .refresh(lowBandwidth: lowBandwidth);
    state = AsyncData(latest);
  }
}

