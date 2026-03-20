import 'package:hive/hive.dart';

import 'speech_talkativeness.dart';

enum SpeechAnnouncementKind {
  event,
  reminder,
  stepMilestone,
  weather,
  culture,
  hourlyTime,
}

extension SpeechAnnouncementKindX on SpeechAnnouncementKind {
  int get priority {
    switch (this) {
      case SpeechAnnouncementKind.event:
        return 500;
      case SpeechAnnouncementKind.reminder:
        return 400;
      case SpeechAnnouncementKind.stepMilestone:
        return 300;
      case SpeechAnnouncementKind.weather:
        return 200;
      case SpeechAnnouncementKind.culture:
        return 100;
      case SpeechAnnouncementKind.hourlyTime:
        return 150;
    }
  }

  String get storageValue {
    switch (this) {
      case SpeechAnnouncementKind.event:
        return 'event';
      case SpeechAnnouncementKind.reminder:
        return 'reminder';
      case SpeechAnnouncementKind.stepMilestone:
        return 'step_milestone';
      case SpeechAnnouncementKind.weather:
        return 'weather';
      case SpeechAnnouncementKind.culture:
        return 'culture';
      case SpeechAnnouncementKind.hourlyTime:
        return 'hourly_time';
    }
  }
}

class SpeechRequest {
  const SpeechRequest({
    required this.kind,
    required this.now,
    required this.talkativenessMode,
    this.bypassRecentSuppression = false,
  });

  final SpeechAnnouncementKind kind;
  final DateTime now;
  final SpeechTalkativenessMode talkativenessMode;
  final bool bypassRecentSuppression;
}

class SpeechDecision {
  const SpeechDecision._({
    required this.shouldSpeak,
    this.reason,
  });

  const SpeechDecision.allow() : this._(shouldSpeak: true);

  const SpeechDecision.suppress(String reason)
      : this._(shouldSpeak: false, reason: reason);

  final bool shouldSpeak;
  final String? reason;
}

abstract class SpeechGovernanceStore {
  dynamic get(String key);

  Future<void> put(String key, dynamic value);
}

class HiveSpeechGovernanceStore implements SpeechGovernanceStore {
  HiveSpeechGovernanceStore(this._box);

  final Box<dynamic> _box;

  @override
  dynamic get(String key) => _box.get(key);

  @override
  Future<void> put(String key, dynamic value) => _box.put(key, value);
}

class MemorySpeechGovernanceStore implements SpeechGovernanceStore {
  final Map<String, dynamic> _values = <String, dynamic>{};

  @override
  dynamic get(String key) => _values[key];

  @override
  Future<void> put(String key, dynamic value) async {
    _values[key] = value;
  }
}

class SpeechGovernanceService {
  SpeechGovernanceService(this._store);

  static const suppressionWindow = Duration(minutes: 20);
  static const _lastSpokenAtKey = 'speech_last_spoken_at';
  static const _lastSpokenKindKey = 'speech_last_spoken_kind';
  static const _lastSpokenPriorityKey = 'speech_last_spoken_priority';

  final SpeechGovernanceStore _store;

  Future<SpeechDecision> evaluate(SpeechRequest request) async {
    if (!_isAllowedByTalkativeness(request)) {
      return const SpeechDecision.suppress('talkativeness');
    }

    final lastSpokenAt = _lastSpokenAt();
    if (lastSpokenAt == null) {
      return const SpeechDecision.allow();
    }

    final withinWindow =
        request.now.difference(lastSpokenAt) < suppressionWindow;
    if (withinWindow && !request.bypassRecentSuppression) {
      return const SpeechDecision.suppress('recent_announcement');
    }

    return const SpeechDecision.allow();
  }

  Future<void> markSpoken(SpeechRequest request) async {
    await _store.put(_lastSpokenAtKey, request.now.millisecondsSinceEpoch);
    await _store.put(_lastSpokenKindKey, request.kind.storageValue);
    await _store.put(_lastSpokenPriorityKey, request.kind.priority);
  }

  SpeechAnnouncementKind highestPriorityKind(
    Iterable<SpeechAnnouncementKind> kinds,
  ) {
    var selected = SpeechAnnouncementKind.culture;
    for (final kind in kinds) {
      if (kind.priority > selected.priority) {
        selected = kind;
      }
    }
    return selected;
  }

  String mergeAnnouncementParts({
    required String primary,
    required List<String> secondaryParts,
    required SpeechTalkativenessMode mode,
  }) {
    final cleanedSecondary = secondaryParts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (cleanedSecondary.isEmpty) {
      return primary;
    }

    final maxSecondaryParts = switch (mode) {
      SpeechTalkativenessMode.minimal => 1,
      SpeechTalkativenessMode.balanced => 1,
      SpeechTalkativenessMode.expressive => cleanedSecondary.length,
    };

    final visibleSecondary =
        cleanedSecondary.take(maxSecondaryParts).join('. ');
    if (visibleSecondary.isEmpty) {
      return primary;
    }
    return '$primary. $visibleSecondary';
  }

  bool _isAllowedByTalkativeness(SpeechRequest request) {
    switch (request.talkativenessMode) {
      case SpeechTalkativenessMode.minimal:
        return request.kind != SpeechAnnouncementKind.culture;
      case SpeechTalkativenessMode.balanced:
        return request.kind != SpeechAnnouncementKind.culture;
      case SpeechTalkativenessMode.expressive:
        return true;
    }
  }

  DateTime? _lastSpokenAt() {
    final raw = (_store.get(_lastSpokenAtKey) as num?)?.toInt();
    if (raw == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
}
