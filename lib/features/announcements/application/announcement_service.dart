import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/config/app_languages.dart';
import '../../../core/l10n/spoken_phrases.dart';
import '../../../core/utils/tts_locale_resolver.dart';
import '../../calendar/application/calendar_service.dart';
import '../../calendar/domain/calendar_event_summary.dart';
import '../../settings/domain/user_settings.dart';
import '../../weather/domain/weather_snapshot.dart';

class AnnouncementService {
  AnnouncementService(
    this._tts,
    this._calendarService, {
    this.fallbackNextEvent,
  });

  final FlutterTts _tts;
  final CalendarService _calendarService;
  final Future<CalendarEventSummary?> Function(DateTime now, Duration within)?
      fallbackNextEvent;

  Future<void> speakHourlyTime(DateTime now, UserSettings settings) async {
    if (!settings.timeAnnouncementsEnabled || _isQuietHours(now, settings)) {
      return;
    }

    final language = _effectiveLanguage(settings, now);
    final sceneVoice = settings.multiVoiceSceneEnabled
        ? settings.timeVoiceName
        : settings.voiceName;
    await _applyTtsSettings(
      settings,
      language,
      sceneVoiceName: sceneVoice,
      sceneType: 'time',
    );

    var message = SpokenPhrases.timeAnnouncement(language, now);

    CalendarEventSummary? event;
    try {
      event = await _calendarService.nextUpcomingEvent(
        now: now,
        within: const Duration(hours: 6),
      );
    } catch (_) {
      // Keep hourly flow stable if calendar provider fails.
    }

    if (event == null && fallbackNextEvent != null) {
      try {
        event = await fallbackNextEvent!(now, const Duration(hours: 6));
      } catch (_) {
        // Ignore fallback source failures.
      }
    }

    final extra = _calendarSnippet(event, now, language);
    if (extra.isNotEmpty) {
      message = '$message. $extra';
    }

    await _tts.speak(message);
  }

  Future<void> speakWeather(
    WeatherSnapshot? snapshot,
    UserSettings settings,
    DateTime now,
  ) async {
    if (!settings.weatherAnnouncementsEnabled || snapshot == null) {
      return;
    }

    final language = _effectiveLanguage(settings, now);
    final sceneVoice = settings.multiVoiceSceneEnabled
        ? settings.weatherVoiceName
        : settings.voiceName;
    await _applyTtsSettings(
      settings,
      language,
      sceneVoiceName: sceneVoice,
      sceneType: 'weather',
    );

    if (snapshot.isStale) {
      final staleMessage = _buildStaleWeatherMessage(
        language: language,
        weatherCode: snapshot.weatherCode,
        temperatureC: snapshot.temperatureC,
      );
      await _tts.speak(staleMessage);
      return;
    }

    await _tts.speak(
      SpokenPhrases.weatherAnnouncement(
        language,
        weatherCode: snapshot.weatherCode,
        temperatureC: snapshot.temperatureC,
      ),
    );
  }

  String _buildStaleWeatherMessage({
    required String language,
    required int weatherCode,
    required double temperatureC,
  }) {
    return SpokenPhrases.weatherAnnouncement(
      language,
      weatherCode: weatherCode,
      temperatureC: temperatureC,
      cached: true,
    );
  }

  bool _isQuietHours(DateTime now, UserSettings settings) {
    final hour = now.hour;

    if (settings.quietHoursStart == settings.quietHoursEnd) {
      return false;
    }

    if (settings.quietHoursStart < settings.quietHoursEnd) {
      return hour >= settings.quietHoursStart && hour < settings.quietHoursEnd;
    }
    return hour >= settings.quietHoursStart || hour < settings.quietHoursEnd;
  }

  String _effectiveLanguage(UserSettings settings, DateTime now) {
    if (!settings.languageRotationEnabled) {
      return settings.languageCode;
    }
    final codes = AppLanguages.rotationCodes;
    if (codes.isEmpty) {
      return settings.languageCode;
    }
    return codes[now.hour % codes.length];
  }

  Future<void> _applyTtsSettings(
    UserSettings settings,
    String languageCode, {
    String? sceneVoiceName,
    String? sceneType,
  }) async {
    final locale = await TtsLocaleResolver.resolveLocale(_tts, languageCode);

    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }

    await _tts.awaitSpeakCompletion(true);

    var volume = settings.announcementVolume.clamp(0.0, 1.0);
    if (settings.adaptiveBatteryMode) {
      volume = volume > 0.6 ? 0.6 : volume;
      await _tts.setSpeechRate(0.46);
    } else {
      await _tts.setSpeechRate(0.5);
    }
    await _tts.setVolume(volume);

    if (settings.multiVoiceSceneEnabled) {
      if (sceneType == 'time') {
        await _tts.setPitch(1.1);
      } else if (sceneType == 'weather') {
        await _tts.setPitch(0.9);
      }
    } else {
      await _tts.setPitch(1.0);
    }

    final chosenVoice = (sceneVoiceName ?? '').trim();
    if (chosenVoice.isNotEmpty) {
      try {
        await _tts.setVoice({'name': chosenVoice});
        return;
      } catch (_) {
        // Fallback below.
      }
    }

    if (settings.voiceName.isNotEmpty) {
      try {
        await _tts.setVoice({'name': settings.voiceName});
      } catch (_) {
        // Keep default voice when selected voice is unavailable.
      }
    }
  }

  String _calendarSnippet(
    CalendarEventSummary? event,
    DateTime now,
    String lang,
  ) {
    if (event == null) {
      return '';
    }

    final minutes = event.start.difference(now).inMinutes;
    if (minutes <= 0) {
      return '';
    }

    return SpokenPhrases.nextEventSnippet(
      lang,
      title: event.title,
      minutes: minutes,
    );
  }
}
