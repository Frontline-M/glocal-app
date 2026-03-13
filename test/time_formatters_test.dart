import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/core/utils/time_formatters.dart';

void main() {
  test('formatClockTime returns 24h when enabled', () {
    final time = DateTime(2026, 3, 5, 17, 3, 9);
    expect(formatClockTime(time, use24Hour: true), '17:03:09');
  });

  test('formatClockTime returns 12h when disabled', () {
    final time = DateTime(2026, 3, 5, 17, 3, 9);
    expect(formatClockTime(time, use24Hour: false).contains('PM'), isTrue);
  });
}
