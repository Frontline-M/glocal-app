class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.weatherCode,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
  });

  final double temperatureC;
  final int weatherCode;
  final DateTime fetchedAt;
  final double latitude;
  final double longitude;

  bool get isStale => DateTime.now().difference(fetchedAt).inHours >= 2;

  Map<String, dynamic> toJson() => {
        'temperatureC': temperatureC,
        'weatherCode': weatherCode,
        'fetchedAt': fetchedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      };

  factory WeatherSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: (json['temperatureC'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
