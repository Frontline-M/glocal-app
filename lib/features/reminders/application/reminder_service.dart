import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/storage/hive_bootstrap.dart';
import '../data/hive_reminder_repository.dart';
import '../domain/reminder_categories.dart';
import '../domain/reminder_item.dart';

class ReminderService {
  ReminderService({
    required SpeechToText speechToText,
    required FlutterLocalNotificationsPlugin notifications,
    required HiveReminderRepository repository,
    required FlutterTts tts,
    required AudioRecorder recorder,
    required AudioPlayer audioPlayer,
  })  : _speechToText = speechToText,
        _notifications = notifications,
        _repository = repository,
        _tts = tts,
        _recorder = recorder,
        _audioPlayer = audioPlayer,
        _muted = _loadPersistedMute();

  final SpeechToText _speechToText;
  final FlutterLocalNotificationsPlugin _notifications;
  final HiveReminderRepository _repository;
  final FlutterTts _tts;
  final AudioRecorder _recorder;
  final AudioPlayer _audioPlayer;

  static const _muteKey = 'reminder_muted';

  bool _muted;

  bool get muted => _muted;

  Future<List<ReminderItem>> list() => _repository.all();

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (Hive.isBoxOpen(HiveBootstrap.runtimeBox)) {
      await Hive.box<dynamic>(HiveBootstrap.runtimeBox).put(_muteKey, value);
    }
    if (_muted) {
      await stopSpeaking();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // no-op
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {
      // no-op
    }
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {
      // no-op
    }
  }

  Future<void> stopTranscription() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {
      // no-op
    }
  }

  static bool _loadPersistedMute() {
    if (!Hive.isBoxOpen(HiveBootstrap.runtimeBox)) {
      return false;
    }
    return Hive.box<dynamic>(HiveBootstrap.runtimeBox).get(_muteKey) as bool? ?? false;
  }

  Future<bool> isTtsLanguageAvailable(String languageCode) async {
    final available = await _availableTtsLocales();
    if (available.isEmpty) return false;

    final normalized = languageCode.toLowerCase();
    if (_matchLocale(available, normalized) != null) {
      return true;
    }

    final hinted = _preferredLocaleHints[normalized];
    if (hinted != null &&
        _matchLocale(available, hinted.toLowerCase()) != null) {
      return true;
    }

    return available.any((locale) {
      final lower = locale.toLowerCase();
      return lower.startsWith('$normalized-') ||
          lower.startsWith('${normalized}_');
    });
  }

  Future<String?> startCustomReminderRecording(String reminderId) async {
    final hasPermission = await _recorder.hasPermission(request: true);
    if (!hasPermission) {
      return null;
    }

    await stopTranscription();

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/reminder_$reminderId.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    return path;
  }

  Future<String?> stopCustomReminderRecording() async {
    return _recorder.stop();
  }

  Future<String> transcribeSingleUtterance({String? languageCode}) async {
    String latestWords = '';
    final completer = Completer<String>();

    final available = await _speechToText.initialize(
      onStatus: (status) {
        final done = status == 'done' || status == 'notListening';
        if (done && !completer.isCompleted) {
          completer.complete(latestWords.trim());
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(latestWords.trim());
        }
      },
    );

    if (!available) {
      throw Exception('Speech recognition unavailable on this device');
    }

    final localeId = await _resolveSpeechLocaleId(languageCode);

    await _speechToText.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          latestWords = words;
        }
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(latestWords.trim());
        }
      },
    );

    final text = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => latestWords.trim(),
    );

    await stopTranscription();
    return text.trim();
  }

  Future<void> createReminder({
    required String id,
    required String title,
    required DateTime when,
    required String languageCode,
    required String voiceName,
    required bool repeatDaily,
    required String category,
    String? customAudioPath,
  }) async {
    final item = ReminderItem(
      id: id,
      title: title,
      when: when,
      createdAt: DateTime.now(),
      languageCode: languageCode,
      voiceName: voiceName,
      repeatDaily: repeatDaily,
      category: ReminderCategories.normalize(category),
      customAudioPath: customAudioPath,
    );
    await _repository.save(item);
    await _schedule(item);
  }

  Future<void> snoozeReminder(String id, Duration duration) async {
    final reminders = await _repository.all();
    ReminderItem? item;
    for (final entry in reminders) {
      if (entry.id == id) {
        item = entry;
        break;
      }
    }
    if (item == null) {
      return;
    }

    final next = item.copyWith(
      when: DateTime.now().add(duration),
      clearSpokenAt: true,
    );
    await _repository.save(next);
    await _schedule(next);
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _notifications.cancel(id: id.hashCode);
    } catch (_) {
      // Ignore notification-cancel failures and still delete persisted reminder.
    }
    await _repository.delete(id);
  }

  Future<void> dismissDueReminders(DateTime now) async {
    final reminders = await _repository.all();
    for (final item in reminders) {
      final isDue = !item.when.isAfter(now);
      if (!isDue) {
        continue;
      }
      if (item.repeatDaily) {
        final nextWhen = _nextFutureDaily(item.when, now);
        final next = item.copyWith(when: nextWhen, clearSpokenAt: true);
        await _repository.save(next);
        await _schedule(next);
      } else {
        await deleteReminder(item.id);
      }
    }
    await stopSpeaking();
  }

  Future<void> recoverMissedReminders(
    DateTime now, {
    Duration lookback = const Duration(hours: 12),
  }) async {
    final cutoff = now.subtract(lookback);
    final missed = <ReminderItem>[];

    final reminders = await _repository.all();
    for (final item in reminders) {
      final olderThanGrace =
          item.when.isBefore(now.subtract(const Duration(minutes: 1)));
      final withinWindow = item.when.isAfter(cutoff);
      if (olderThanGrace && withinWindow) {
        missed.add(item);
      }
    }

    if (missed.isEmpty) {
      return;
    }

    if (!_muted) {
      await _speakRecoverySummary(missed);
    }

    for (final item in missed) {
      if (item.repeatDaily) {
        final nextWhen = _nextFutureDaily(item.when, now);
        final next = item.copyWith(when: nextWhen, clearSpokenAt: true);
        await _repository.save(next);
        await _schedule(next);
      } else {
        await deleteReminder(item.id);
      }
    }
  }

  Future<void> announceDueReminders(DateTime now) async {
    final reminders = await _repository.all();

    for (final item in reminders) {
      final isDue = !item.when.isAfter(now);
      if (!isDue) {
        continue;
      }

      if (item.repeatDaily) {
        final nextWhen = _nextFutureDaily(item.when, now);
        final next = item.copyWith(when: nextWhen, clearSpokenAt: true);
        await _repository.save(next);
        await _schedule(next);
      } else {
        await deleteReminder(item.id);
      }

      try {
        await _fireDueAlert(item);
        await _speakReminder(item);
      } catch (_) {
        // Continue lifecycle even if speech playback fails.
      }
    }
  }

  DateTime _nextFutureDaily(DateTime when, DateTime now) {
    var nextWhen = when.add(const Duration(days: 1));
    while (!nextWhen.isAfter(now)) {
      nextWhen = nextWhen.add(const Duration(days: 1));
    }
    return nextWhen;
  }

  Future<void> _fireDueAlert(ReminderItem item) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'glocal_reminders_due',
        'Glocal due reminders',
        channelDescription: 'Immediate due reminder alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: true),
    );

    try {
      await _notifications.show(
        id: item.id.hashCode + 1,
        title: 'Reminder due',
        body: item.title,
        notificationDetails: details,
      );
    } catch (_) {
      // Ignore local-notification runtime failures.
    }
  }

  Future<void> _speakReminder(ReminderItem item) async {
    if (_muted) {
      return;
    }

    if (item.customAudioPath != null && item.customAudioPath!.isNotEmpty) {
      final file = File(item.customAudioPath!);
      if (await file.exists()) {
        for (var i = 0; i < 3; i++) {
          if (_muted) break;
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(item.customAudioPath!));
          await _audioPlayer.onPlayerComplete.first;
        }
        return;
      }
    }

    final locale = await _resolveTtsLocale(item.languageCode);

    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }

    if (item.voiceName.isNotEmpty) {
      try {
        await _tts.setVoice({'name': item.voiceName, 'locale': locale});
      } catch (_) {
        // Keep default language voice when exact voice is unavailable.
      }
    }

    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _tts.stop();

    final prefix = ReminderCategories.spokenPrefixFor(item.category);
    for (var i = 0; i < 3; i++) {
      if (_muted) {
        break;
      }
      await _tts.speak('$prefix. ${item.title}');
    }
  }

  Future<void> _speakRecoverySummary(List<ReminderItem> missed) async {
    if (missed.isEmpty) {
      return;
    }

    final first = missed.first;
    final locale = await _resolveTtsLocale(first.languageCode);
    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }

    if (first.voiceName.isNotEmpty) {
      try {
        await _tts.setVoice({'name': first.voiceName, 'locale': locale});
      } catch (_) {
        // Keep default voice when exact voice is unavailable.
      }
    }

    final count = missed.length;
    final preview = missed.take(2).map((r) => r.title).join(', ');
    final suffix = count > 2 ? ', and others' : '';
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(
        'You missed $count reminder${count == 1 ? '' : 's'}. $preview$suffix.');
  }

  Future<void> _schedule(ReminderItem item) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'glocal_reminders',
        'Glocal reminders',
        channelDescription: 'Reminder and alarm notifications',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: item.id.hashCode,
      title: 'Glocal Reminder',
      body: item.title,
      scheduledDate: tz.TZDateTime.from(item.when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<String?> _resolveSpeechLocaleId(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) {
      return null;
    }

    final languageLower = languageCode.toLowerCase();
    final locales = await _speechToText.locales();

    for (final locale in locales) {
      if (locale.localeId.toLowerCase() == languageLower) {
        return locale.localeId;
      }
    }

    for (final locale in locales) {
      final id = locale.localeId.toLowerCase();
      if (id.startsWith('$languageLower-') ||
          id.startsWith('${languageLower}_')) {
        return locale.localeId;
      }
    }

    return null;
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
        return lower.startsWith('$normalized-') ||
            lower.startsWith('${normalized}_');
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
      // Ignore and fallback to defaults.
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
}



