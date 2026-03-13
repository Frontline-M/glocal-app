import '../domain/weather_repository.dart';
import '../domain/weather_snapshot.dart';

class WeatherService {
  WeatherService(this._repository);

  final WeatherRepository _repository;

  Future<WeatherSnapshot?> cached() => _repository.getCached();

  Future<WeatherSnapshot> refresh({required bool lowBandwidth}) {
    return _repository.refresh(lowBandwidth: lowBandwidth);
  }

  String describeCode(int code) {
    if (code == 0) return 'clear sky';
    if (code <= 3) return 'partly cloudy';
    if (code <= 48) return 'foggy';
    if (code <= 67) return 'rainy';
    if (code <= 77) return 'snowy';
    if (code <= 82) return 'showers';
    if (code <= 99) return 'stormy';
    return 'unknown conditions';
  }
}
