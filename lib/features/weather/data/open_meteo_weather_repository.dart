import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/storage/hive_bootstrap.dart';
import '../domain/weather_repository.dart';
import '../domain/weather_snapshot.dart';

class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository(this._client, this._box);

  final http.Client _client;
  final Box<dynamic> _box;

  static const _weatherKey = 'latest';

  factory OpenMeteoWeatherRepository.fromDefaults() {
    return OpenMeteoWeatherRepository(
      http.Client(),
      Hive.box<dynamic>(HiveBootstrap.weatherBox),
    );
  }

  @override
  Future<WeatherSnapshot?> getCached() async {
    final dynamic raw = _box.get(_weatherKey);
    if (raw is Map) {
      final snapshot = WeatherSnapshot.fromJson(raw);
      final cacheAge = DateTime.now().difference(snapshot.fetchedAt);
      final hasInvalidCode = snapshot.weatherCode < 0 || snapshot.weatherCode > 99;
      if (cacheAge.inDays > 3 || hasInvalidCode) {
        await _box.delete(_weatherKey);
        return null;
      }
      return snapshot;
    }
    return null;
  }

  @override
  Future<WeatherSnapshot> refresh({required bool lowBandwidth}) async {
    final location = await _resolveLocation();
    final uri = Uri.parse(
      '${AppConfig.weatherBaseUrl}?latitude=${location.latitude}&longitude=${location.longitude}&${AppConfig.weatherQuery}',
    );

    final retryDelays = lowBandwidth
        ? const [Duration(seconds: 2), Duration(seconds: 6)]
        : const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

    Object? lastError;
    for (final delay in retryDelays) {
      try {
        final response = await _client.get(uri);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final current = data['current'] as Map<String, dynamic>;
          final snapshot = WeatherSnapshot(
            temperatureC: (current['temperature_2m'] as num).toDouble(),
            weatherCode: (current['weather_code'] as num).toInt(),
            fetchedAt: DateTime.now(),
            latitude: location.latitude,
            longitude: location.longitude,
          );
          await _box.put(_weatherKey, snapshot.toJson());
          return snapshot;
        }
        lastError = Exception('Weather API responded with ${response.statusCode}');
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(delay);
    }

    final cached = await getCached();
    if (cached != null) {
      return cached;
    }
    throw Exception('Unable to fetch weather: $lastError');
  }

  Future<Position> _resolveLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 8),
    );
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}

