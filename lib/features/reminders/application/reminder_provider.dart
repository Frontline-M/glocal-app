import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/storage/notification_registry.dart';
import '../data/hive_reminder_repository.dart';
import '../domain/reminder_item.dart';
import 'reminder_service.dart';

final speechToTextProvider = Provider<SpeechToText>((ref) => SpeechToText());
final reminderTtsProvider = Provider<FlutterTts>((ref) => FlutterTts());
final reminderRecorderProvider = Provider<AudioRecorder>((ref) => AudioRecorder());
final reminderAudioPlayerProvider = Provider<AudioPlayer>((ref) => AudioPlayer());

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    speechToText: ref.read(speechToTextProvider),
    notifications: NotificationRegistry.plugin,
    repository: HiveReminderRepository.fromHive(),
    tts: ref.read(reminderTtsProvider),
    recorder: ref.read(reminderRecorderProvider),
    audioPlayer: ref.read(reminderAudioPlayerProvider),
  );
});

final remindersProvider = AsyncNotifierProvider<RemindersNotifier, List<ReminderItem>>(
  RemindersNotifier.new,
);

class RemindersNotifier extends AsyncNotifier<List<ReminderItem>> {
  @override
  Future<List<ReminderItem>> build() {
    return ref.read(reminderServiceProvider).list();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(reminderServiceProvider).list());
  }
}

final reminderMuteProvider = StateProvider<bool>((ref) => false);
