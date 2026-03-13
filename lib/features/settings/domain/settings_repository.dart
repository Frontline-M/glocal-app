import '../domain/user_settings.dart';

abstract class SettingsRepository {
  Future<UserSettings> load();
  Future<void> save(UserSettings settings);
}
