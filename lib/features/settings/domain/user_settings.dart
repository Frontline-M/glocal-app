class UserSettings {
  const UserSettings({
    required this.languageCode,
    required this.voiceName,
    required this.timeVoiceName,
    required this.weatherVoiceName,
    required this.multiVoiceSceneEnabled,
    required this.timeAnnouncementsEnabled,
    required this.weatherAnnouncementsEnabled,
    required this.announcementVolume,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.lowBandwidthMode,
    required this.adaptiveBatteryMode,
    required this.use24Hour,
    required this.screensaverMode,
    required this.languageRotationEnabled,
    required this.locationProfilesEnabled,
    required this.profileRadiusMeters,
    this.homeLatitude,
    this.homeLongitude,
    this.workLatitude,
    this.workLongitude,
  });

  static const Object _unset = Object();

  final String languageCode;
  final String voiceName;
  final String timeVoiceName;
  final String weatherVoiceName;
  final bool multiVoiceSceneEnabled;
  final bool timeAnnouncementsEnabled;
  final bool weatherAnnouncementsEnabled;
  final double announcementVolume;
  final int quietHoursStart;
  final int quietHoursEnd;
  final bool lowBandwidthMode;
  final bool adaptiveBatteryMode;
  final bool use24Hour;
  final bool screensaverMode;
  final bool languageRotationEnabled;
  final bool locationProfilesEnabled;
  final double profileRadiusMeters;
  final double? homeLatitude;
  final double? homeLongitude;
  final double? workLatitude;
  final double? workLongitude;

  factory UserSettings.defaults() => const UserSettings(
        languageCode: 'en',
        voiceName: '',
        timeVoiceName: '',
        weatherVoiceName: '',
        multiVoiceSceneEnabled: false,
        timeAnnouncementsEnabled: true,
        weatherAnnouncementsEnabled: true,
        announcementVolume: 0.8,
        quietHoursStart: 22,
        quietHoursEnd: 7,
        lowBandwidthMode: true,
        adaptiveBatteryMode: true,
        use24Hour: true,
        screensaverMode: false,
        languageRotationEnabled: false,
        locationProfilesEnabled: false,
        profileRadiusMeters: 500,
      );

  UserSettings copyWith({
    String? languageCode,
    String? voiceName,
    String? timeVoiceName,
    String? weatherVoiceName,
    bool? multiVoiceSceneEnabled,
    bool? timeAnnouncementsEnabled,
    bool? weatherAnnouncementsEnabled,
    double? announcementVolume,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? lowBandwidthMode,
    bool? adaptiveBatteryMode,
    bool? use24Hour,
    bool? screensaverMode,
    bool? languageRotationEnabled,
    bool? locationProfilesEnabled,
    double? profileRadiusMeters,
    Object? homeLatitude = _unset,
    Object? homeLongitude = _unset,
    Object? workLatitude = _unset,
    Object? workLongitude = _unset,
  }) {
    return UserSettings(
      languageCode: languageCode ?? this.languageCode,
      voiceName: voiceName ?? this.voiceName,
      timeVoiceName: timeVoiceName ?? this.timeVoiceName,
      weatherVoiceName: weatherVoiceName ?? this.weatherVoiceName,
      multiVoiceSceneEnabled:
          multiVoiceSceneEnabled ?? this.multiVoiceSceneEnabled,
      timeAnnouncementsEnabled:
          timeAnnouncementsEnabled ?? this.timeAnnouncementsEnabled,
      weatherAnnouncementsEnabled:
          weatherAnnouncementsEnabled ?? this.weatherAnnouncementsEnabled,
      announcementVolume: announcementVolume ?? this.announcementVolume,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      lowBandwidthMode: lowBandwidthMode ?? this.lowBandwidthMode,
      adaptiveBatteryMode: adaptiveBatteryMode ?? this.adaptiveBatteryMode,
      use24Hour: use24Hour ?? this.use24Hour,
      screensaverMode: screensaverMode ?? this.screensaverMode,
      languageRotationEnabled:
          languageRotationEnabled ?? this.languageRotationEnabled,
      locationProfilesEnabled:
          locationProfilesEnabled ?? this.locationProfilesEnabled,
      profileRadiusMeters: profileRadiusMeters ?? this.profileRadiusMeters,
      homeLatitude: identical(homeLatitude, _unset)
          ? this.homeLatitude
          : homeLatitude as double?,
      homeLongitude: identical(homeLongitude, _unset)
          ? this.homeLongitude
          : homeLongitude as double?,
      workLatitude: identical(workLatitude, _unset)
          ? this.workLatitude
          : workLatitude as double?,
      workLongitude: identical(workLongitude, _unset)
          ? this.workLongitude
          : workLongitude as double?,
    );
  }

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'voiceName': voiceName,
        'timeVoiceName': timeVoiceName,
        'weatherVoiceName': weatherVoiceName,
        'multiVoiceSceneEnabled': multiVoiceSceneEnabled,
        'timeAnnouncementsEnabled': timeAnnouncementsEnabled,
        'weatherAnnouncementsEnabled': weatherAnnouncementsEnabled,
        'announcementVolume': announcementVolume,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'lowBandwidthMode': lowBandwidthMode,
        'adaptiveBatteryMode': adaptiveBatteryMode,
        'use24Hour': use24Hour,
        'screensaverMode': screensaverMode,
        'languageRotationEnabled': languageRotationEnabled,
        'locationProfilesEnabled': locationProfilesEnabled,
        'profileRadiusMeters': profileRadiusMeters,
        'homeLatitude': homeLatitude,
        'homeLongitude': homeLongitude,
        'workLatitude': workLatitude,
        'workLongitude': workLongitude,
      };

  factory UserSettings.fromJson(Map<dynamic, dynamic> json) {
    return UserSettings(
      languageCode: json['languageCode'] as String? ?? 'en',
      voiceName: json['voiceName'] as String? ?? '',
      timeVoiceName: json['timeVoiceName'] as String? ?? '',
      weatherVoiceName: json['weatherVoiceName'] as String? ?? '',
      multiVoiceSceneEnabled: json['multiVoiceSceneEnabled'] as bool? ?? false,
      timeAnnouncementsEnabled:
          json['timeAnnouncementsEnabled'] as bool? ?? true,
      weatherAnnouncementsEnabled:
          json['weatherAnnouncementsEnabled'] as bool? ?? true,
      announcementVolume: (json['announcementVolume'] as num?)?.toDouble() ?? 0.8,
      quietHoursStart: (json['quietHoursStart'] as num?)?.toInt() ?? 22,
      quietHoursEnd: (json['quietHoursEnd'] as num?)?.toInt() ?? 7,
      lowBandwidthMode: json['lowBandwidthMode'] as bool? ?? true,
      adaptiveBatteryMode: json['adaptiveBatteryMode'] as bool? ?? true,
      use24Hour: json['use24Hour'] as bool? ?? true,
      screensaverMode: json['screensaverMode'] as bool? ?? false,
      languageRotationEnabled: json['languageRotationEnabled'] as bool? ?? false,
      locationProfilesEnabled: json['locationProfilesEnabled'] as bool? ?? false,
      profileRadiusMeters:
          (json['profileRadiusMeters'] as num?)?.toDouble() ?? 500,
      homeLatitude: (json['homeLatitude'] as num?)?.toDouble(),
      homeLongitude: (json['homeLongitude'] as num?)?.toDouble(),
      workLatitude: (json['workLatitude'] as num?)?.toDouble(),
      workLongitude: (json['workLongitude'] as num?)?.toDouble(),
    );
  }
}
