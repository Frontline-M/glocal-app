class HourlyAnnouncementScheduler {
  DateTime? _lastRunHour;

  bool shouldRun(DateTime now) {
    final thisHour = DateTime(now.year, now.month, now.day, now.hour);

    if (_lastRunHour == null) {
      _lastRunHour = thisHour;
      return true;
    }

    final hourChanged = _lastRunHour!.year != thisHour.year ||
        _lastRunHour!.month != thisHour.month ||
        _lastRunHour!.day != thisHour.day ||
        _lastRunHour!.hour != thisHour.hour;

    if (!hourChanged) {
      return false;
    }

    _lastRunHour = thisHour;
    return true;
  }
}



