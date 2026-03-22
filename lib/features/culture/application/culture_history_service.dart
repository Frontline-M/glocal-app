import 'package:hive/hive.dart';

import '../domain/culture_models.dart';

abstract class CultureHistoryStore {
  dynamic get(String key);

  Future<void> put(String key, dynamic value);
}

class HiveCultureHistoryStore implements CultureHistoryStore {
  HiveCultureHistoryStore(this._box);

  final Box<dynamic> _box;

  @override
  dynamic get(String key) => _box.get(key);

  @override
  Future<void> put(String key, dynamic value) => _box.put(key, value);
}

class MemoryCultureHistoryStore implements CultureHistoryStore {
  final Map<String, dynamic> _values = <String, dynamic>{};

  @override
  dynamic get(String key) => _values[key];

  @override
  Future<void> put(String key, dynamic value) async {
    _values[key] = value;
  }
}

class CultureHistoryService {
  CultureHistoryService(this._store);

  static const _usageStateKey = 'culture_usage_state';
  static const _maxRecentEntries = 16;

  final CultureHistoryStore _store;

  Future<CultureUsageState> load(DateTime now) async {
    final raw = _store.get(_usageStateKey);
    final state = raw is Map<dynamic, dynamic>
        ? CultureUsageState.fromJson(raw)
        : CultureUsageState.empty(dateKeyFor(now));
    final normalized = _normalize(state, now);
    await _store.put(_usageStateKey, normalized.toJson());
    return normalized;
  }

  Future<void> recordSelection(CultureSelection selection, DateTime now) async {
    final current = await load(now);
    final dateKey = dateKeyFor(now);
    final nextEntries = [
      RecentCultureUsage(
        id: selection.id,
        region: selection.region,
        spokenAtMillis: now.millisecondsSinceEpoch,
      ),
      ...current.recentEntries,
    ];
    final spokenObservances = <String>{...current.spokenObservanceIdsToday};
    if (selection.observance) {
      spokenObservances.add(selection.id);
    }
    final next = current.copyWith(
      dateKey: dateKey,
      countToday: current.countToday + 1,
      recentEntries: nextEntries.take(_maxRecentEntries).toList(growable: false),
      spokenObservanceIdsToday: spokenObservances.toList(growable: false),
    );
    await _store.put(_usageStateKey, _normalize(next, now).toJson());
  }

  String dateKeyFor(DateTime now) {
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  CultureUsageState _normalize(CultureUsageState state, DateTime now) {
    final todayKey = dateKeyFor(now);
    final recent = state.recentEntries.take(_maxRecentEntries).toList(growable: false);
    if (state.dateKey == todayKey) {
      return state.copyWith(recentEntries: recent);
    }
    return CultureUsageState(
      dateKey: todayKey,
      countToday: 0,
      recentEntries: recent,
      spokenObservanceIdsToday: const <String>[],
    );
  }
}
