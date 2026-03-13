import 'package:hive/hive.dart';

import '../../../core/storage/hive_bootstrap.dart';
import '../domain/settings_repository.dart';
import '../domain/user_settings.dart';

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this._box);

  final Box<dynamic> _box;
  static const _settingsKey = 'user_settings';

  factory HiveSettingsRepository.fromHive() {
    final box = Hive.box<dynamic>(HiveBootstrap.settingsBox);
    return HiveSettingsRepository(box);
  }

  @override
  Future<UserSettings> load() async {
    final dynamic raw = _box.get(_settingsKey);
    if (raw is Map) {
      return UserSettings.fromJson(raw);
    }
    return UserSettings.defaults();
  }

  @override
  Future<void> save(UserSettings settings) async {
    await _box.put(_settingsKey, settings.toJson());
  }
}
