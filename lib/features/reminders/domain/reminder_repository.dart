import 'reminder_item.dart';

abstract class ReminderRepository {
  Future<List<ReminderItem>> all();
  Future<void> save(ReminderItem item);
  Future<void> delete(String id);
}
