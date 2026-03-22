import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/core/speech/speech_talkativeness.dart';
import 'package:glocal/features/culture/application/culture_history_service.dart';
import 'package:glocal/features/culture/application/culture_selector.dart';
import 'package:glocal/features/culture/domain/culture_models.dart';

void main() {
  test('CultureSelector returns null in minimal mode', () {
    final selector = CultureSelector();
    final selection = selector.select(
      regionMode: CultureRegionMode.globalMix,
      timeSlot: CultureTimeSlot.morning,
      talkMode: SpeechTalkativenessMode.minimal,
      usageState: CultureUsageState.empty('2026-03-22'),
      now: DateTime(2026, 3, 22, 9),
      observancesEnabled: true,
    );

    expect(selection, isNull);
  });

  test('CultureSelector skips recent snippet ids', () {
    final selector = CultureSelector(
      snippets: const [
        CulturalSnippet(
          id: 'recent_one',
          region: 'West Africa',
          timeSlot: CultureTimeSlot.morning,
          locale: 'Nigeria',
          type: CultureSnippetType.dailyLife,
          message: 'Recent message',
          weight: 4,
        ),
        CulturalSnippet(
          id: 'fresh_one',
          region: 'West Africa',
          timeSlot: CultureTimeSlot.morning,
          locale: 'Ghana',
          type: CultureSnippetType.dailyLife,
          message: 'Fresh message',
          weight: 1,
        ),
      ],
    );
    final state = CultureUsageState(
      dateKey: '2026-03-22',
      countToday: 0,
      recentEntries: const [
        RecentCultureUsage(
          id: 'recent_one',
          region: 'West Africa',
          spokenAtMillis: 1774179600000,
        ),
      ],
      spokenObservanceIdsToday: const <String>[],
    );

    final selection = selector.select(
      regionMode: CultureRegionMode.westAfrica,
      timeSlot: CultureTimeSlot.morning,
      talkMode: SpeechTalkativenessMode.balanced,
      usageState: state,
      now: DateTime(2026, 3, 22, 9),
      observancesEnabled: false,
    );

    expect(selection, isNotNull);
    expect(selection!.id, 'fresh_one');
  });

  test('CultureSelector prefers observances on matching morning', () {
    final selector = CultureSelector(
      snippets: const [
        CulturalSnippet(
          id: 'plain_snippet',
          region: 'Europe',
          timeSlot: CultureTimeSlot.morning,
          locale: 'France',
          type: CultureSnippetType.dailyLife,
          message: 'Plain snippet',
          weight: 1,
        ),
      ],
      observances: const [
        CultureObservance(
          id: 'special_day',
          region: 'Global',
          dateKey: '03-22',
          message: 'Today is a special observance.',
          weight: 4,
        ),
      ],
    );

    final selection = selector.select(
      regionMode: CultureRegionMode.globalMix,
      timeSlot: CultureTimeSlot.morning,
      talkMode: SpeechTalkativenessMode.balanced,
      usageState: CultureUsageState.empty('2026-03-22'),
      now: DateTime(2026, 3, 22, 8),
      observancesEnabled: true,
    );

    expect(selection, isNotNull);
    expect(selection!.observance, isTrue);
    expect(selection.id, 'special_day');
  });

  test('CultureHistoryService resets daily count but keeps recent history', () async {
    final history = CultureHistoryService(MemoryCultureHistoryStore());
    await history.recordSelection(
      const CultureSelection(
        id: 'wa_ng_evening_01',
        region: 'West Africa',
        message: 'In many Nigerian homes, evening is a time for dinner.',
        type: CultureSnippetType.dailyLife,
      ),
      DateTime(2026, 3, 21, 19),
    );

    final nextDay = await history.load(DateTime(2026, 3, 22, 8));
    expect(nextDay.countToday, 0);
    expect(
      nextDay.recentIdsAt(DateTime(2026, 3, 22, 8)),
      contains('wa_ng_evening_01'),
    );
  });
}
