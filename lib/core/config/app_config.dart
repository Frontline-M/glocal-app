class AppConfig {
  static const weatherBaseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const weatherQuery =
      'current=temperature_2m,weather_code&hourly=temperature_2m,weather_code&forecast_days=1';
}
