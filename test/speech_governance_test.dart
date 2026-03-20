import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/core/speech/speech_governance.dart';
import 'package:glocal/core/speech/speech_talkativeness.dart';

void main() {
  group('SpeechGovernanceService', () {
    test('suppresses non-essential speech within 20 minutes', () async {
      final store = MemorySpeechGovernanceStore();
      final service = SpeechGovernanceService(store);
      final firstRequest = SpeechRequest(
        kind: SpeechAnnouncementKind.weather,
        now: DateTime(2026, 3, 19, 9, 0),
        talkativenessMode: SpeechTalkativenessMode.balanced,
      );

      await service.markSpoken(firstRequest);

      final decision = await service.evaluate(
        SpeechRequest(
          kind: SpeechAnnouncementKind.weather,
          now: DateTime(2026, 3, 19, 9, 10),
          talkativenessMode: SpeechTalkativenessMode.balanced,
        ),
      );

      expect(decision.shouldSpeak, isFalse);
      expect(decision.reason, 'recent_announcement');
    });

    test('allows urgent speech to bypass recent suppression', () async {
      final store = MemorySpeechGovernanceStore();
      final service = SpeechGovernanceService(store);
      await service.markSpoken(
        SpeechRequest(
          kind: SpeechAnnouncementKind.hourlyTime,
          now: DateTime(2026, 3, 19, 9, 0),
          talkativenessMode: SpeechTalkativenessMode.balanced,
        ),
      );

      final decision = await service.evaluate(
        SpeechRequest(
          kind: SpeechAnnouncementKind.event,
          now: DateTime(2026, 3, 19, 9, 5),
          talkativenessMode: SpeechTalkativenessMode.minimal,
          bypassRecentSuppression: true,
        ),
      );

      expect(decision.shouldSpeak, isTrue);
    });

    test('selects the highest priority announcement kind', () {
      final service = SpeechGovernanceService(MemorySpeechGovernanceStore());

      final kind = service.highestPriorityKind(
        const [
          SpeechAnnouncementKind.weather,
          SpeechAnnouncementKind.event,
          SpeechAnnouncementKind.hourlyTime,
        ],
      );

      expect(kind, SpeechAnnouncementKind.event);
    });

    test('mergeAnnouncementParts limits secondary detail by talkativeness', () {
      final service = SpeechGovernanceService(MemorySpeechGovernanceStore());

      final minimal = service.mergeAnnouncementParts(
        primary: 'It is 9 AM',
        secondaryParts: const [
          'You have a meeting in one hour',
          'Current weather is rainy',
        ],
        mode: SpeechTalkativenessMode.minimal,
      );
      final expressive = service.mergeAnnouncementParts(
        primary: 'It is 9 AM',
        secondaryParts: const [
          'You have a meeting in one hour',
          'Current weather is rainy',
        ],
        mode: SpeechTalkativenessMode.expressive,
      );

      expect(minimal, 'It is 9 AM. You have a meeting in one hour');
      expect(
        expressive,
        'It is 9 AM. You have a meeting in one hour. Current weather is rainy',
      );
    });
  });
}
