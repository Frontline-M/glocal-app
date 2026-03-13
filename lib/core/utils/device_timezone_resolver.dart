import 'package:timezone/timezone.dart' as tz;

class DeviceTimezoneResolver {
  static tz.Location resolveLocation() {
    final now = DateTime.now();
    final currentZoneName = now.timeZoneName.trim();

    for (final candidate in _directCandidates(currentZoneName)) {
      final location = _tryLocation(candidate);
      if (location != null) {
        return location;
      }
    }

    final exactNameMatch = _findMatchingLocation(
      now: now,
      requireZoneNameMatch: true,
    );
    if (exactNameMatch != null) {
      return exactNameMatch;
    }

    final offsetOnlyMatch = _findMatchingLocation(
      now: now,
      requireZoneNameMatch: false,
    );
    if (offsetOnlyMatch != null) {
      return offsetOnlyMatch;
    }

    return tz.getLocation('UTC');
  }

  static Iterable<String> _directCandidates(String timeZoneName) sync* {
    if (timeZoneName.isEmpty) {
      return;
    }

    yield timeZoneName;
    yield timeZoneName.replaceAll(' ', '_');
    yield timeZoneName.replaceAll(' ', '');
  }

  static tz.Location? _tryLocation(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  }

  static tz.Location? _findMatchingLocation({
    required DateTime now,
    required bool requireZoneNameMatch,
  }) {
    for (final location in tz.timeZoneDatabase.locations.values) {
      final localNow = tz.TZDateTime.now(location);
      if (localNow.timeZoneOffset != now.timeZoneOffset) {
        continue;
      }
      if (requireZoneNameMatch &&
          !_zoneNamesMatch(localNow.timeZoneName, now.timeZoneName)) {
        continue;
      }
      return location;
    }
    return null;
  }

  static bool _zoneNamesMatch(String a, String b) {
    final left = a.trim().toLowerCase().replaceAll(' ', '');
    final right = b.trim().toLowerCase().replaceAll(' ', '');
    return left == right;
  }
}
