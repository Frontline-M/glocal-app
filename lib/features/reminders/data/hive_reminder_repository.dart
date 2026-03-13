import 'package:hive/hive.dart';

import '../../../core/storage/hive_bootstrap.dart';
import '../domain/reminder_item.dart';
import '../domain/reminder_repository.dart';

class HiveReminderRepository implements ReminderRepository {
  HiveReminderRepository(this._box);

  final Box<dynamic> _box;

  factory HiveReminderRepository.fromHive() {
    return HiveReminderRepository(Hive.box<dynamic>(HiveBootstrap.remindersBox));
  }

  @override
  Future<List<ReminderItem>> all() async {
    return _box.values
        .whereType<Map>()
        .map((e) => ReminderItem.fromJson(e))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
  }

  @override
  Future<void> save(ReminderItem item) async {
    await _box.put(item.id, item.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
