import 'package:intl/intl.dart';

String formatClockTime(DateTime dateTime, {bool use24Hour = true}) {
  return DateFormat(use24Hour ? 'HH:mm:ss' : 'hh:mm:ss a').format(dateTime);
}

String formatHourAnnouncement(DateTime dateTime, String locale) {
  try {
    return DateFormat('h:mm a', locale).format(dateTime);
  } catch (_) {
    return DateFormat('h:mm a', 'en').format(dateTime);
  }
}
