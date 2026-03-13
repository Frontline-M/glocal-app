import '../domain/settings_repository.dart';
import '../domain/user_settings.dart';

class SettingsService {
  SettingsService(this._repository);

  final SettingsRepository _repository;

  Future<UserSettings> load() => _repository.load();

  Future<void> save(UserSettings settings) => _repository.save(settings);
}
