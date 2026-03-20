import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/config/app_languages.dart';
import '../../../core/l10n/spoken_phrases.dart';
import '../../../core/speech/speech_governance.dart';
import '../../../core/speech/speech_talkativeness.dart';
import '../../../core/utils/tts_locale_resolver.dart';
import '../../calendar/application/calendar_service.dart';
import '../../calendar/domain/calendar_event_summary.dart';
import '../../settings/domain/user_settings.dart';
import '../../weather/domain/weather_snapshot.dart';

class AnnouncementService {
  AnnouncementService(
    this._tts,
    this._calendarService, {
    required SpeechGovernanceService governanceService,
    this.fallbackNextEvent,
  }) : _governanceService = governanceService;

  final FlutterTts _tts;
  final CalendarService _calendarService;
  final SpeechGovernanceService _governanceService;
  final Future<CalendarEventSummary?> Function(DateTime now, Duration within)?
      fallbackNextEvent;
  static const _hourlyEventWindow = Duration(hours: 6);
  static const _urgentEventWindow = Duration(hours: 1);

  Future<HourlySpeechPreview> previewHourlyBundle({
    required DateTime now,
    required UserSettings settings,
    WeatherSnapshot? weather,
  }) async {
    if (_isQuietHours(now, settings)) {
      return const HourlySpeechPreview(
        willSpeak: false,
        suppressionReason: 'quiet_hours',
        message: '',
      );
    }

    final language = _effectiveLanguage(settings, now);
    final bundle = await _buildHourlyBundle(
      now: now,
      settings: settings,
      language: language,
      weather: weather,
    );
    if (bundle == null) {
      return const HourlySpeechPreview(
        willSpeak: false,
        suppressionReason: 'no_content',
        message: '',
      );
    }

    final decision = await _governanceService.evaluate(
      SpeechRequest(
        kind: bundle.kind,
        now: now,
        talkativenessMode: settings.talkativenessMode,
        bypassRecentSuppression: bundle.bypassRecentSuppression,
      ),
    );

    return HourlySpeechPreview(
      willSpeak: decision.shouldSpeak,
      suppressionReason: decision.reason,
      message: bundle.message,
      includesTime: bundle.includesTime,
      includesEvent: bundle.includesEvent,
      includesWeather: bundle.includesWeather,
      bypassRecentSuppression: bundle.bypassRecentSuppression,
    );
  }

  Future<void> speakHourlyBundle({
    required DateTime now,
    required UserSettings settings,
    WeatherSnapshot? weather,
  }) async {
    if (_isQuietHours(now, settings)) {
      return;
    }

    final language = _effectiveLanguage(settings, now);
    final bundle = await _buildHourlyBundle(
      now: now,
      settings: settings,
      language: language,
      weather: weather,
    );
    if (bundle == null) {
      return;
    }

    final decision = await _governanceService.evaluate(
      SpeechRequest(
        kind: bundle.kind,
        now: now,
        talkativenessMode: settings.talkativenessMode,
        bypassRecentSuppression: bundle.bypassRecentSuppression,
      ),
    );
    if (!decision.shouldSpeak) {
      return;
    }

    final sceneVoice = settings.multiVoiceSceneEnabled
        ? (bundle.prefersWeatherScene
            ? settings.weatherVoiceName
            : settings.timeVoiceName)
        : settings.voiceName;
    await _applyTtsSettings(
      settings,
      language,
      sceneVoiceName: sceneVoice,
      sceneType: bundle.prefersWeatherScene ? 'weather' : 'time',
    );
    await _tts.speak(bundle.message);
    await _governanceService.markSpoken(
      SpeechRequest(
        kind: bundle.kind,
        now: now,
        talkativenessMode: settings.talkativenessMode,
        bypassRecentSuppression: bundle.bypassRecentSuppression,
      ),
    );
  }

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

  Future<void> speakStepProgressSummary({
    required DateTime now,
    required UserSettings settings,
    required int stepsToday,
    required int goalSteps,
  }) async {
    await _speakStepMessage(
      now: now,
      settings: settings,
      messageBuilder: (language) => SpokenPhrases.stepProgressSummary(
        language,
        stepsToday: stepsToday,
        goalSteps: goalSteps,
      ),
    );
  }

  Future<void> speakStepMilestoneReached({
    required DateTime now,
    required UserSettings settings,
    required int stepsToday,
    required int goalSteps,
    required int milestonePercent,
  }) async {
    await _speakStepMessage(
      now: now,
      settings: settings,
      messageBuilder: (language) => SpokenPhrases.stepMilestoneReached(
        language,
        milestonePercent: milestonePercent,
        stepsToday: stepsToday,
        goalSteps: goalSteps,
      ),
    );
  }

  Future<void> speakEndOfDayStepSummary({
    required DateTime now,
    required UserSettings settings,
    required int stepsToday,
    required int goalSteps,
  }) async {
    await _speakStepMessage(
      now: now,
      settings: settings,
      messageBuilder: (language) => SpokenPhrases.stepEndOfDaySummary(
        language,
        stepsToday: stepsToday,
        goalSteps: goalSteps,
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

  Future<_HourlyBundle?> _buildHourlyBundle({
    required DateTime now,
    required UserSettings settings,
    required String language,
    required WeatherSnapshot? weather,
  }) async {
    final timeMessage = settings.timeAnnouncementsEnabled
        ? SpokenPhrases.timeAnnouncement(language, now)
        : '';
    final event = settings.timeAnnouncementsEnabled
        ? await _loadUpcomingEvent(now)
        : null;
    final eventSnippet = _calendarSnippet(event, now, language);
    final eventUrgent =
        event != null && !event.start.isAfter(now.add(_urgentEventWindow));

    final weatherMessage =
        settings.weatherAnnouncementsEnabled && weather != null
            ? (weather.isStale
                ? _buildStaleWeatherMessage(
                    language: language,
                    weatherCode: weather.weatherCode,
                    temperatureC: weather.temperatureC,
                  )
                : SpokenPhrases.weatherAnnouncement(
                    language,
                    weatherCode: weather.weatherCode,
                    temperatureC: weather.temperatureC,
                  ))
            : '';

    if (timeMessage.isEmpty && weatherMessage.isEmpty && eventSnippet.isEmpty) {
      return null;
    }

    final primary = timeMessage.isNotEmpty ? timeMessage : weatherMessage;
    if (primary.isEmpty) {
      return null;
    }

    final includeEventSnippet = eventSnippet.isNotEmpty &&
        (settings.talkativenessMode != SpeechTalkativenessMode.minimal ||
            eventUrgent);

    final secondaryParts = <String>[];
    if (includeEventSnippet) {
      secondaryParts.add(eventSnippet);
    }
    if (weatherMessage.isNotEmpty && weatherMessage != primary) {
      final allowWeatherSecondary = switch (settings.talkativenessMode) {
        SpeechTalkativenessMode.minimal => false,
        SpeechTalkativenessMode.balanced => true,
        SpeechTalkativenessMode.expressive => true,
      };
      if (allowWeatherSecondary) {
        secondaryParts.add(weatherMessage);
      }
    }

    final kinds = <SpeechAnnouncementKind>[];
    if (timeMessage.isNotEmpty) {
      kinds.add(SpeechAnnouncementKind.hourlyTime);
    }
    if (includeEventSnippet) {
      kinds.add(SpeechAnnouncementKind.event);
    }
    if (weatherMessage.isNotEmpty) {
      kinds.add(SpeechAnnouncementKind.weather);
    }

    final kind = _governanceService.highestPriorityKind(kinds);
    final message = _governanceService.mergeAnnouncementParts(
      primary: primary,
      secondaryParts: secondaryParts,
      mode: settings.talkativenessMode,
    );

    return _HourlyBundle(
      message: message,
      kind: kind,
      bypassRecentSuppression: eventUrgent,
      prefersWeatherScene: timeMessage.isEmpty &&
          weatherMessage.isNotEmpty &&
          eventSnippet.isEmpty,
      includesTime: timeMessage.isNotEmpty,
      includesEvent: includeEventSnippet,
      includesWeather: weatherMessage.isNotEmpty,
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

  Future<CalendarEventSummary?> _loadUpcomingEvent(DateTime now) async {
    CalendarEventSummary? event;
    try {
      event = await _calendarService.nextUpcomingEvent(
        now: now,
        within: _hourlyEventWindow,
      );
    } catch (_) {
      // Keep hourly flow stable if calendar provider fails.
    }

    if (event == null && fallbackNextEvent != null) {
      try {
        event = await fallbackNextEvent!(now, _hourlyEventWindow);
      } catch (_) {
        // Ignore fallback source failures.
      }
    }

    return event;
  }

  Future<void> _speakStepMessage({
    required DateTime now,
    required UserSettings settings,
    required String Function(String language) messageBuilder,
  }) async {
    if (_isQuietHours(now, settings)) {
      return;
    }

    final language = _effectiveLanguage(settings, now);
    final decision = await _governanceService.evaluate(
      SpeechRequest(
        kind: SpeechAnnouncementKind.stepMilestone,
        now: now,
        talkativenessMode: settings.talkativenessMode,
      ),
    );
    if (!decision.shouldSpeak) {
      return;
    }

    await _applyTtsSettings(
      settings,
      language,
      sceneVoiceName: settings.voiceName,
      sceneType: 'time',
    );
    await _tts.speak(messageBuilder(language));
    await _governanceService.markSpoken(
      SpeechRequest(
        kind: SpeechAnnouncementKind.stepMilestone,
        now: now,
        talkativenessMode: settings.talkativenessMode,
      ),
    );
  }
}

class _HourlyBundle {
  const _HourlyBundle({
    required this.message,
    required this.kind,
    required this.bypassRecentSuppression,
    required this.prefersWeatherScene,
    required this.includesTime,
    required this.includesEvent,
    required this.includesWeather,
  });

  final String message;
  final SpeechAnnouncementKind kind;
  final bool bypassRecentSuppression;
  final bool prefersWeatherScene;
  final bool includesTime;
  final bool includesEvent;
  final bool includesWeather;
}

class HourlySpeechPreview {
  const HourlySpeechPreview({
    required this.willSpeak,
    required this.suppressionReason,
    required this.message,
    this.includesTime = false,
    this.includesEvent = false,
    this.includesWeather = false,
    this.bypassRecentSuppression = false,
  });

  final bool willSpeak;
  final String? suppressionReason;
  final String message;
  final bool includesTime;
  final bool includesEvent;
  final bool includesWeather;
  final bool bypassRecentSuppression;
}
