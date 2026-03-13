import '../../../core/l10n/spoken_phrases.dart';
import '../domain/weather_repository.dart';
import '../domain/weather_snapshot.dart';

class WeatherService {
  WeatherService(this._repository);

  final WeatherRepository _repository;

  Future<WeatherSnapshot?> cached() => _repository.getCached();

  Future<WeatherSnapshot> refresh({required bool lowBandwidth}) {
    return _repository.refresh(lowBandwidth: lowBandwidth);
  }

  String describeCode(int code, {String languageCode = 'en'}) {
    return SpokenPhrases.weatherDescription(languageCode, code);
  }
}
