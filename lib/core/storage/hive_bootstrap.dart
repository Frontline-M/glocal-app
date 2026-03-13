import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveBootstrap {
  static const settingsBox = 'settings';
  static const remindersBox = 'reminders';
  static const weatherBox = 'weather';
  static const runtimeBox = 'runtime';

  static const _secureStorage = FlutterSecureStorage();
  static const _reminderKeyName = 'glocal_reminder_encryption_key';
  static const _settingsKeyName = 'glocal_settings_encryption_key';
  static const _weatherKeyName = 'glocal_weather_encryption_key';
  static const _runtimeKeyName = 'glocal_runtime_encryption_key';

  static Future<void> init() async {
    await Hive.initFlutter();

    final settingsCipher = await _buildCipher(_settingsKeyName);
    final reminderCipher = await _buildCipher(_reminderKeyName);
    final weatherCipher = await _buildCipher(_weatherKeyName);
    final runtimeCipher = await _buildCipher(_runtimeKeyName);

    await Future.wait([
      _openEncryptedBoxWithMigration(
        boxName: settingsBox,
        cipher: settingsCipher,
      ),
      Hive.openBox<dynamic>(remindersBox, encryptionCipher: reminderCipher),
      _openEncryptedBoxWithMigration(
        boxName: weatherBox,
        cipher: weatherCipher,
      ),
      _openEncryptedBoxWithMigration(
        boxName: runtimeBox,
        cipher: runtimeCipher,
      ),
    ]);
  }

  static Future<HiveAesCipher> _buildCipher(String keyName) async {
    final existing = await _secureStorage.read(key: keyName);
    if (existing != null) {
      return HiveAesCipher(base64Decode(existing));
    }

    final key = Hive.generateSecureKey();
    await _secureStorage.write(
      key: keyName,
      value: base64Encode(key),
    );
    return HiveAesCipher(key);
  }

  static Future<Box<dynamic>> _openEncryptedBoxWithMigration({
    required String boxName,
    required HiveAesCipher cipher,
  }) async {
    try {
      return await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: cipher,
      );
    } catch (_) {
      final legacyBox = await Hive.openBox<dynamic>(boxName);
      final legacyData = Map<dynamic, dynamic>.from(legacyBox.toMap());
      await legacyBox.close();
      await Hive.deleteBoxFromDisk(boxName);

      final encryptedBox = await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: cipher,
      );
      if (legacyData.isNotEmpty) {
        await encryptedBox.putAll(legacyData);
      }
      return encryptedBox;
    }
  }
}
