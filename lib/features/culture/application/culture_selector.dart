import 'dart:math';

import '../../../core/speech/speech_talkativeness.dart';
import '../data/cultural_snippets.dart';
import '../data/observances.dart';
import '../domain/culture_models.dart';
import 'culture_policy.dart';

class CultureSelector {
  CultureSelector({
    List<CulturalSnippet>? snippets,
    List<CultureObservance>? observances,
    Random? random,
  })  : _snippets = snippets ?? culturalSnippets,
        _observances = observances ?? culturalObservances,
        _random = random;

  final List<CulturalSnippet> _snippets;
  final List<CultureObservance> _observances;
  final Random? _random;

  CultureSelection? select({
    required CultureRegionMode regionMode,
    required CultureTimeSlot timeSlot,
    required SpeechTalkativenessMode talkMode,
    required CultureUsageState usageState,
    required DateTime now,
    required bool observancesEnabled,
    CultureSnippetType? type,
  }) {
    if (!CulturePolicy.supportsCulture(talkMode)) {
      return null;
    }

    final dailyCap = CulturePolicy.dailyCap(talkMode);
    if (usageState.countToday >= dailyCap) {
      return null;
    }

    final observance = _selectObservance(
      regionMode: regionMode,
      timeSlot: timeSlot,
      talkMode: talkMode,
      usageState: usageState,
      now: now,
      observancesEnabled: observancesEnabled,
    );
    if (observance != null) {
      return observance;
    }

    final recentIds = usageState.recentIdsAt(now).toSet();
    final eligible = _snippets.where((snippet) {
      final regionOk = _matchesRegion(snippet.region, regionMode);
      final timeOk = snippet.timeSlot == timeSlot;
      final typeOk = type == null || snippet.type == type;
      final recentOk = !recentIds.contains(snippet.id);
      final modeOk = !snippet.expressiveOnly ||
          CulturePolicy.allowsExpressiveOnly(talkMode);
      return regionOk && timeOk && typeOk && recentOk && modeOk;
    }).toList(growable: false);

    if (eligible.isEmpty) {
      return null;
    }

    final random = _random ?? Random(_seedFor(now, usageState));
    final chosen = _pickWeighted(
      eligible,
      random: random,
      weightOf: (snippet) => _adjustedWeight(
        snippet.weight,
        snippet.region,
        usageState.lastRegion,
        regionMode,
      ),
    );

    return CultureSelection(
      id: chosen.id,
      region: chosen.region,
      message: chosen.message,
      type: chosen.type,
    );
  }

  CultureSelection? _selectObservance({
    required CultureRegionMode regionMode,
    required CultureTimeSlot timeSlot,
    required SpeechTalkativenessMode talkMode,
    required CultureUsageState usageState,
    required DateTime now,
    required bool observancesEnabled,
  }) {
    if (!observancesEnabled || !CulturePolicy.supportsCulture(talkMode)) {
      return null;
    }
    if (timeSlot != CultureTimeSlot.morning &&
        timeSlot != CultureTimeSlot.evening) {
      return null;
    }

    final dateKey = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final eligible = _observances.where((observance) {
      final regionOk = regionMode == CultureRegionMode.globalMix ||
          observance.region == 'Global' ||
          observance.region == regionMode.label;
      final dateOk = observance.dateKey == dateKey;
      final notSpokenToday =
          !usageState.spokenObservanceIdsToday.contains(observance.id);
      return regionOk && dateOk && notSpokenToday;
    }).toList(growable: false);

    if (eligible.isEmpty) {
      return null;
    }

    final random = _random ?? Random(_seedFor(now, usageState) + 31);
    final chosen = _pickWeighted(
      eligible,
      random: random,
      weightOf: (observance) => observance.weight,
    );

    return CultureSelection(
      id: chosen.id,
      region: chosen.region,
      message: chosen.message,
      type: CultureSnippetType.observance,
      observance: true,
    );
  }

  bool _matchesRegion(String snippetRegion, CultureRegionMode regionMode) {
    if (regionMode == CultureRegionMode.globalMix) {
      return true;
    }
    return snippetRegion == regionMode.label || snippetRegion == 'Global';
  }

  int _adjustedWeight(
    int baseWeight,
    String region,
    String? lastRegion,
    CultureRegionMode regionMode,
  ) {
    if (regionMode == CultureRegionMode.globalMix &&
        lastRegion != null &&
        region == lastRegion) {
      return baseWeight > 1 ? baseWeight - 1 : 1;
    }
    return baseWeight;
  }

  int _seedFor(DateTime now, CultureUsageState usageState) {
    return (now.year * 1000000) +
        (now.month * 10000) +
        (now.day * 100) +
        now.hour +
        (usageState.countToday * 17);
  }

  T _pickWeighted<T>(
    List<T> items, {
    required Random random,
    required int Function(T item) weightOf,
  }) {
    final totalWeight = items.fold<int>(0, (sum, item) => sum + weightOf(item));
    if (totalWeight <= 0) {
      return items.last;
    }

    final roll = random.nextInt(totalWeight);
    var cumulative = 0;
    for (final item in items) {
      cumulative += weightOf(item);
      if (roll < cumulative) {
        return item;
      }
    }
    return items.last;
  }
}
