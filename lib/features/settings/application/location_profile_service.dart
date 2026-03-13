import 'package:geolocator/geolocator.dart';

import '../domain/location_profile.dart';
import '../domain/user_settings.dart';

class LocationProfileService {
  Future<UserSettings> apply(UserSettings settings) async {
    if (!settings.locationProfilesEnabled) {
      return settings;
    }

    final profile = await resolveProfile(settings);
    switch (profile) {
      case LocationProfile.home:
        return settings.copyWith(
          announcementVolume: settings.announcementVolume > 0.7
              ? 0.7
              : settings.announcementVolume,
          weatherAnnouncementsEnabled: true,
        );
      case LocationProfile.work:
        return settings.copyWith(
          announcementVolume: settings.announcementVolume > 0.45
              ? 0.45
              : settings.announcementVolume,
          weatherAnnouncementsEnabled: false,
        );
      case LocationProfile.travel:
      default:
        return settings.copyWith(
          announcementVolume: settings.announcementVolume > 0.6
              ? 0.6
              : settings.announcementVolume,
          weatherAnnouncementsEnabled: true,
        );
    }
  }

  Future<String> resolveProfile(UserSettings settings) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return LocationProfile.travel;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (settings.homeLatitude != null && settings.homeLongitude != null) {
        final dHome = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          settings.homeLatitude!,
          settings.homeLongitude!,
        );
        if (dHome <= settings.profileRadiusMeters) {
          return LocationProfile.home;
        }
      }

      if (settings.workLatitude != null && settings.workLongitude != null) {
        final dWork = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          settings.workLatitude!,
          settings.workLongitude!,
        );
        if (dWork <= settings.profileRadiusMeters) {
          return LocationProfile.work;
        }
      }
    } catch (_) {
      return LocationProfile.travel;
    }

    return LocationProfile.travel;
  }
}
