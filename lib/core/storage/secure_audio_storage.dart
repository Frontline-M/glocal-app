import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class PreparedAudioPlayback {
  const PreparedAudioPlayback({
    required this.path,
    required this.deleteAfterPlayback,
  });

  final String path;
  final bool deleteAfterPlayback;
}

class SecureAudioStorage {
  static const _secureStorage = FlutterSecureStorage();
  static const _audioKeyName = 'glocal_audio_file_encryption_key';
  static const encryptedExtension = '.glocalaudio';

  static Future<String> finalizeRecording({
    required String reminderId,
    required String sourcePath,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Recorded audio file not found', sourcePath);
    }

    final cipher = await _buildCipher();
    final clearBytes = Uint8List.fromList(await sourceFile.readAsBytes());
    final encryptedBytes = Uint8List(cipher.maxEncryptedSize(clearBytes));
    final encryptedLength = cipher.encrypt(
      clearBytes,
      0,
      clearBytes.length,
      encryptedBytes,
      0,
    );

    final dir = await getApplicationSupportDirectory();
    final encryptedPath = '${dir.path}/reminder_$reminderId$encryptedExtension';
    final encryptedFile = File(encryptedPath);
    await encryptedFile.writeAsBytes(
      encryptedBytes.sublist(0, encryptedLength),
      flush: true,
    );

    await sourceFile.delete();
    return encryptedPath;
  }

  static Future<PreparedAudioPlayback?> preparePlayback(String path) async {
    if (path.isEmpty) {
      return null;
    }

    final storedFile = File(path);
    if (!await storedFile.exists()) {
      return null;
    }

    if (!path.endsWith(encryptedExtension)) {
      return PreparedAudioPlayback(path: path, deleteAfterPlayback: false);
    }

    final cipher = await _buildCipher();
    final encryptedBytes = Uint8List.fromList(await storedFile.readAsBytes());
    final clearBytes = Uint8List(encryptedBytes.length);
    final clearLength = cipher.decrypt(
      encryptedBytes,
      0,
      encryptedBytes.length,
      clearBytes,
      0,
    );

    final dir = await getTemporaryDirectory();
    final tempPath = '${dir.path}/playback_${DateTime.now().microsecondsSinceEpoch}.m4a';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(clearBytes.sublist(0, clearLength), flush: true);

    return PreparedAudioPlayback(path: tempPath, deleteAfterPlayback: true);
  }

  static Future<void> disposePreparedPlayback(
    PreparedAudioPlayback? playback,
  ) async {
    if (playback == null || !playback.deleteAfterPlayback) {
      return;
    }

    final tempFile = File(playback.path);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }

  static Future<void> deleteStoredAudio(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<HiveAesCipher> _buildCipher() async {
    final existing = await _secureStorage.read(key: _audioKeyName);
    if (existing != null) {
      return HiveAesCipher(base64Decode(existing));
    }

    final key = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _audioKeyName,
      value: base64Encode(key),
    );
    return HiveAesCipher(key);
  }
}
