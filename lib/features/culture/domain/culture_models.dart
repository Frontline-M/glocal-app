import '../../../core/speech/speech_talkativeness.dart';

enum CultureRegionMode {
  westAfrica,
  europe,
  eastAsia,
  middleEast,
  northAmerica,
  globalMix,
}

extension CultureRegionModeX on CultureRegionMode {
  String get storageValue {
    switch (this) {
      case CultureRegionMode.westAfrica:
        return 'west_africa';
      case CultureRegionMode.europe:
        return 'europe';
      case CultureRegionMode.eastAsia:
        return 'east_asia';
      case CultureRegionMode.middleEast:
        return 'middle_east';
      case CultureRegionMode.northAmerica:
        return 'north_america';
      case CultureRegionMode.globalMix:
        return 'global_mix';
    }
  }

  String get label {
    switch (this) {
      case CultureRegionMode.westAfrica:
        return 'West Africa';
      case CultureRegionMode.europe:
        return 'Europe';
      case CultureRegionMode.eastAsia:
        return 'East Asia';
      case CultureRegionMode.middleEast:
        return 'Middle East';
      case CultureRegionMode.northAmerica:
        return 'North America';
      case CultureRegionMode.globalMix:
        return 'Global Mix';
    }
  }
}

CultureRegionMode cultureRegionModeFromStorage(String? value) {
  switch (value) {
    case 'west_africa':
      return CultureRegionMode.westAfrica;
    case 'europe':
      return CultureRegionMode.europe;
    case 'east_asia':
      return CultureRegionMode.eastAsia;
    case 'middle_east':
      return CultureRegionMode.middleEast;
    case 'north_america':
      return CultureRegionMode.northAmerica;
    case 'global_mix':
    default:
      return CultureRegionMode.globalMix;
  }
}

enum CultureSnippetType {
  dailyLife,
  language,
  cityLife,
  reflection,
  observance,
}

extension CultureSnippetTypeX on CultureSnippetType {
  String get storageValue {
    switch (this) {
      case CultureSnippetType.dailyLife:
        return 'daily_life';
      case CultureSnippetType.language:
        return 'language';
      case CultureSnippetType.cityLife:
        return 'city_life';
      case CultureSnippetType.reflection:
        return 'reflection';
      case CultureSnippetType.observance:
        return 'observance';
    }
  }
}

CultureSnippetType? cultureSnippetTypeFromStorage(String? value) {
  switch (value) {
    case 'daily_life':
      return CultureSnippetType.dailyLife;
    case 'language':
      return CultureSnippetType.language;
    case 'city_life':
      return CultureSnippetType.cityLife;
    case 'reflection':
      return CultureSnippetType.reflection;
    case 'observance':
      return CultureSnippetType.observance;
    default:
      return null;
  }
}

enum CultureTimeSlot {
  morning,
  afternoon,
  evening,
  night,
}

extension CultureTimeSlotX on CultureTimeSlot {
  String get storageValue {
    switch (this) {
      case CultureTimeSlot.morning:
        return 'morning';
      case CultureTimeSlot.afternoon:
        return 'afternoon';
      case CultureTimeSlot.evening:
        return 'evening';
      case CultureTimeSlot.night:
        return 'night';
    }
  }
}

CultureTimeSlot cultureTimeSlotFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return CultureTimeSlot.morning;
  }
  if (hour >= 12 && hour < 17) {
    return CultureTimeSlot.afternoon;
  }
  if (hour >= 17 && hour < 21) {
    return CultureTimeSlot.evening;
  }
  return CultureTimeSlot.night;
}

class CulturalSnippet {
  const CulturalSnippet({
    required this.id,
    required this.region,
    required this.timeSlot,
    required this.locale,
    required this.type,
    required this.message,
    this.weight = 1,
    this.expressiveOnly = false,
  });

  final String id;
  final String region;
  final CultureTimeSlot timeSlot;
  final String locale;
  final CultureSnippetType type;
  final String message;
  final int weight;
  final bool expressiveOnly;
}

class CultureObservance {
  const CultureObservance({
    required this.id,
    required this.region,
    required this.dateKey,
    required this.message,
    this.weight = 1,
  });

  final String id;
  final String region;
  final String dateKey;
  final String message;
  final int weight;
}

class RecentCultureUsage {
  const RecentCultureUsage({
    required this.id,
    required this.region,
    required this.spokenAtMillis,
  });

  final String id;
  final String region;
  final int spokenAtMillis;

  factory RecentCultureUsage.fromJson(Map<dynamic, dynamic> json) {
    return RecentCultureUsage(
      id: json['id'] as String? ?? '',
      region: json['region'] as String? ?? 'Global',
      spokenAtMillis: (json['spokenAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'region': region,
        'spokenAtMillis': spokenAtMillis,
      };
}

class CultureUsageState {
  const CultureUsageState({
    required this.dateKey,
    required this.countToday,
    required this.recentEntries,
    required this.spokenObservanceIdsToday,
  });

  factory CultureUsageState.empty(String dateKey) => CultureUsageState(
        dateKey: dateKey,
        countToday: 0,
        recentEntries: const <RecentCultureUsage>[],
        spokenObservanceIdsToday: const <String>[],
      );

  final String dateKey;
  final int countToday;
  final List<RecentCultureUsage> recentEntries;
  final List<String> spokenObservanceIdsToday;

  String? get lastRegion =>
      recentEntries.isEmpty ? null : recentEntries.first.region;

  List<String> recentIdsAt(DateTime now) {
    final cutoff = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    final ids = <String>{};
    for (var index = 0; index < recentEntries.length; index++) {
      final entry = recentEntries[index];
      final withinThreeDays = entry.spokenAtMillis >= cutoff;
      final withinLastEight = index < 8;
      if (withinThreeDays || withinLastEight) {
        ids.add(entry.id);
      }
    }
    return ids.toList(growable: false);
  }

  CultureUsageState copyWith({
    String? dateKey,
    int? countToday,
    List<RecentCultureUsage>? recentEntries,
    List<String>? spokenObservanceIdsToday,
  }) {
    return CultureUsageState(
      dateKey: dateKey ?? this.dateKey,
      countToday: countToday ?? this.countToday,
      recentEntries: recentEntries ?? this.recentEntries,
      spokenObservanceIdsToday:
          spokenObservanceIdsToday ?? this.spokenObservanceIdsToday,
    );
  }

  factory CultureUsageState.fromJson(Map<dynamic, dynamic> json) {
    final recent = (json['recentEntries'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(RecentCultureUsage.fromJson)
        .toList(growable: false);
    final spokenObservances = (json['spokenObservanceIdsToday'] as List<dynamic>? ??
            const [])
        .whereType<String>()
        .toList(growable: false);
    return CultureUsageState(
      dateKey: json['dateKey'] as String? ?? '',
      countToday: (json['countToday'] as num?)?.toInt() ?? 0,
      recentEntries: recent,
      spokenObservanceIdsToday: spokenObservances,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'countToday': countToday,
        'recentEntries': recentEntries.map((entry) => entry.toJson()).toList(),
        'spokenObservanceIdsToday': spokenObservanceIdsToday,
      };
}

class CultureSelection {
  const CultureSelection({
    required this.id,
    required this.region,
    required this.message,
    required this.type,
    this.observance = false,
  });

  final String id;
  final String region;
  final String message;
  final CultureSnippetType type;
  final bool observance;
}

int cultureDailyCapForMode(SpeechTalkativenessMode mode) {
  switch (mode) {
    case SpeechTalkativenessMode.minimal:
      return 0;
    case SpeechTalkativenessMode.balanced:
      return 2;
    case SpeechTalkativenessMode.expressive:
      return 3;
  }
}
