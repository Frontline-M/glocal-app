import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/config/app_languages.dart';
import '../../../core/utils/time_formatters.dart';
import '../../calendar/application/calendar_service.dart';
import '../../calendar/domain/calendar_event_summary.dart';
import '../../settings/domain/user_settings.dart';
import '../../weather/application/weather_service.dart';
import '../../weather/domain/weather_snapshot.dart';

class AnnouncementService {
  AnnouncementService(
    this._tts,
    this._weatherService,
    this._calendarService, {
    this.fallbackNextEvent,
  });

  final FlutterTts _tts;
  final WeatherService _weatherService;
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

    final formatted = formatHourAnnouncement(now, language);
    final phrase = _localized(language, 'time');
    var message = '$phrase $formatted';

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

    final descriptor = _weatherService.describeCode(snapshot.weatherCode);
    final ageMinutes = now.difference(snapshot.fetchedAt).inMinutes;
    final weatherPhrase = _localized(language, 'weather');

    if (snapshot.isStale) {
      final staleMessage = _buildStaleWeatherMessage(
        language: language,
        ageMinutes: ageMinutes,
        descriptor: descriptor,
        temperatureC: snapshot.temperatureC,
      );
      await _tts.speak(staleMessage);
      return;
    }

    await _tts.speak(
      '$weatherPhrase $descriptor, ${snapshot.temperatureC.toStringAsFixed(0)} degrees Celsius.',
    );
  }

  String _buildStaleWeatherMessage({
    required String language,
    required int ageMinutes,
    required String descriptor,
    required double temperatureC,
  }) {
    final weatherPhrase = _localized(language, 'weather');
    final temperature = temperatureC.toStringAsFixed(0);
    return 'Using cached weather. $weatherPhrase $descriptor, $temperature degrees Celsius.';
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
    final locale = await _resolveTtsLocale(languageCode);

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
        // fallback below
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

    final label = _localized(lang, 'nextEvent');
    if (minutes < 60) {
      return '$label ${event.title} in $minutes minutes';
    }

    final hours = (minutes / 60).floor();
    final remaining = minutes % 60;
    if (remaining == 0) {
      return '$label ${event.title} in $hours hours';
    }
    return '$label ${event.title} in $hours hours and $remaining minutes';
  }

  Future<String> _resolveTtsLocale(String languageCode) async {
    final available = await _availableTtsLocales();
    if (available.isEmpty) {
      return languageCode;
    }

    final normalized = languageCode.toLowerCase();
    final direct = _matchLocale(available, normalized);
    if (direct != null) {
      return direct;
    }

    final hinted = _preferredLocaleHints[normalized];
    if (hinted != null) {
      final hintMatch = _matchLocale(available, hinted.toLowerCase());
      if (hintMatch != null) {
        return hintMatch;
      }
    }

    final languageOnlyMatch = available.firstWhere(
      (locale) {
        final lower = locale.toLowerCase();
        return lower.startsWith('$normalized-') || lower.startsWith('${normalized}_');
      },
      orElse: () => '',
    );
    if (languageOnlyMatch.isNotEmpty) {
      return languageOnlyMatch;
    }

    final english = _matchLocale(available, 'en-us') ??
        _matchLocale(available, 'en-gb') ??
        _matchLocale(available, 'en');
    return english ?? available.first;
  }

  String? _matchLocale(List<String> available, String target) {
    final exact = available.where((e) => e.toLowerCase() == target).toList();
    if (exact.isNotEmpty) {
      return exact.first;
    }

    final dashNormalized = target.replaceAll('_', '-');
    final fuzzy = available.where((e) {
      final lower = e.toLowerCase().replaceAll('_', '-');
      return lower == dashNormalized;
    }).toList();
    if (fuzzy.isNotEmpty) {
      return fuzzy.first;
    }

    return null;
  }

  Future<List<String>> _availableTtsLocales() async {
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {
      // Ignore and fallback to default.
    }
    return const [];
  }

  static const _preferredLocaleHints = <String, String>{
    'en': 'en-US',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'de': 'de-DE',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'yo': 'yo-NG',
    'ha': 'ha-NG',
    'ig': 'ig-NG',
    'sw': 'sw-KE',
    'ak': 'ak-GH',
    'tw': 'ak-GH',
    'am': 'am-ET',
    'om': 'om-ET',
    'ja': 'ja-JP',
    'zh': 'zh-CN',
  };

  String _localized(String lang, String key) {
    const map = {
      'en': {
        'time': 'The time is',
        'weather': 'Current weather is',
        'nextEvent': 'Next event',
      },
      'fr': {
        'time': 'Il est',
        'weather': 'La meteo actuelle est',
        'nextEvent': 'Prochain evenement',
      },
      'es': {
        'time': 'La hora es',
        'weather': 'El clima actual es',
        'nextEvent': 'Proximo evento',
      },
      'de': {
        'time': 'Es ist',
        'weather': 'Aktuelles Wetter ist',
        'nextEvent': 'Nachstes Ereignis',
      },
      'hi': {
        'time': 'Samay hai',
        'weather': 'Vartaman mausam hai',
        'nextEvent': 'Agla karyakram',
      },
      'ar': {
        'time': 'Alwaqt alaan',
        'weather': 'Altqs alhaliy hu',
        'nextEvent': 'alhadath altali',
      },
    };

    return map[lang]?[key] ?? map['en']![key]!;
  }
}




