import 'package:hive/hive.dart';

abstract class StepAnnouncementStore {
  dynamic get(String key);

  Future<void> put(String key, dynamic value);

  Future<void> delete(String key);
}

class HiveStepAnnouncementStore implements StepAnnouncementStore {
  HiveStepAnnouncementStore(this._box);

  final Box<dynamic> _box;

  @override
  dynamic get(String key) => _box.get(key);

  @override
  Future<void> put(String key, dynamic value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

class MemoryStepAnnouncementStore implements StepAnnouncementStore {
  final Map<String, dynamic> _values = <String, dynamic>{};

  @override
  dynamic get(String key) => _values[key];

  @override
  Future<void> put(String key, dynamic value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
