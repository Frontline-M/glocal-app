import 'weather_snapshot.dart';

abstract class WeatherRepository {
  Future<WeatherSnapshot?> getCached();
  Future<WeatherSnapshot> refresh({required bool lowBandwidth});
}
