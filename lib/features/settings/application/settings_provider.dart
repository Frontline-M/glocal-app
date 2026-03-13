import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_settings_repository.dart';
import '../domain/user_settings.dart';
import 'settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(HiveSettingsRepository.fromHive());
});

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final service = ref.read(settingsServiceProvider);
    return service.load();
  }

  Future<void> saveSettings(UserSettings settings) async {
    state = AsyncData(settings);
    await ref.read(settingsServiceProvider).save(settings);
  }
}

