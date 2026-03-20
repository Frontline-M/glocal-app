import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_languages.dart';
import '../../../core/speech/speech_talkativeness.dart';
import '../../announcements/application/announcement_provider.dart';
import '../../steps/application/step_provider.dart';
import '../../steps/domain/step_announcement_mode.dart';
import '../../steps/domain/step_data_provider.dart';
import '../../weather/application/weather_provider.dart';
import '../application/settings_provider.dart';
import '../domain/user_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(settingsProvider);
    final voices = ref.watch(voicesProvider);
    final stepAvailability = ref.watch(stepAvailabilityProvider);
    final stepSnapshot = ref.watch(stepSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: asyncSettings.when(
          data: (settings) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Hourly time announcement'),
                value: settings.timeAnnouncementsEnabled,
                onChanged: (value) {
                  _update(
                      ref, settings.copyWith(timeAnnouncementsEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('Hourly weather announcement'),
                value: settings.weatherAnnouncementsEnabled,
                onChanged: (value) {
                  _update(ref,
                      settings.copyWith(weatherAnnouncementsEnabled: value));
                },
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note),
                    title: const Text('Calendar diagnostics'),
                    subtitle:
                        const Text('Debug-only: check next upcoming event'),
                    onTap: () => _runCalendarDiagnostics(context, ref),
                  ),
                ),
              ],
              SwitchListTile(
                title: const Text('Location-aware profiles'),
                subtitle: const Text('Auto-adjust for Home / Work / Travel'),
                value: settings.locationProfilesEnabled,
                onChanged: (value) {
                  _update(
                      ref, settings.copyWith(locationProfilesEnabled: value));
                },
              ),
              if (settings.locationProfilesEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  'Home: ${_coordinateLabel(settings.homeLatitude, settings.homeLongitude)}',
                ),
                Text(
                  'Work: ${_coordinateLabel(settings.workLatitude, settings.workLongitude)}',
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () =>
                          _saveHomeFromCurrent(context, ref, settings),
                      child: const Text('Set Home from current location'),
                    ),
                    FilledButton.tonal(
                      onPressed: () =>
                          _saveWorkFromCurrent(context, ref, settings),
                      child: const Text('Set Work from current location'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _clearHomeLocation(context, ref, settings),
                      child: const Text('Clear Home'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _clearWorkLocation(context, ref, settings),
                      child: const Text('Clear Work'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _clearAllLocations(context, ref, settings),
                      child: const Text('Clear All Locations'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Profile radius (${settings.profileRadiusMeters.round()} m)',
                ),
                Slider(
                  value: settings.profileRadiusMeters,
                  min: 100,
                  max: 2000,
                  divisions: 19,
                  label: settings.profileRadiusMeters.round().toString(),
                  onChanged: (value) {
                    _update(ref, settings.copyWith(profileRadiusMeters: value));
                  },
                ),
              ],
              SwitchListTile(
                title: const Text('Multi-voice scenes'),
                subtitle:
                    const Text('Use separate voices for time and weather'),
                value: settings.multiVoiceSceneEnabled,
                onChanged: (value) {
                  _update(
                      ref, settings.copyWith(multiVoiceSceneEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('Adaptive battery mode'),
                subtitle:
                    const Text('Lower speech intensity and bandwidth usage'),
                value: settings.adaptiveBatteryMode,
                onChanged: (value) {
                  _update(ref, settings.copyWith(adaptiveBatteryMode: value));
                },
              ),
              SwitchListTile(
                title: const Text('Language rotation mode (hourly)'),
                subtitle: const Text(
                    'Overrides the selected language and rotates hourly'),
                value: settings.languageRotationEnabled,
                onChanged: (value) {
                  _update(
                      ref, settings.copyWith(languageRotationEnabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('24-hour clock'),
                value: settings.use24Hour,
                onChanged: (value) {
                  _update(ref, settings.copyWith(use24Hour: value));
                },
              ),
              SwitchListTile(
                title: const Text('Screensaver mode (keep screen on)'),
                value: settings.screensaverMode,
                onChanged: (value) {
                  _update(ref, settings.copyWith(screensaverMode: value));
                },
              ),
              SwitchListTile(
                title: const Text('Low-bandwidth mode'),
                value: settings.lowBandwidthMode,
                onChanged: (value) {
                  _update(ref, settings.copyWith(lowBandwidthMode: value));
                },
              ),
              SwitchListTile(
                title: const Text('Daily step announcements'),
                subtitle: const Text(
                  'Prepare spoken step summaries and milestone callouts',
                ),
                value: settings.stepAnnouncementsEnabled,
                onChanged: (value) {
                  _update(
                    ref,
                    settings.copyWith(stepAnnouncementsEnabled: value),
                  );
                },
              ),
              if (settings.stepAnnouncementsEnabled) ...[
                const SizedBox(height: 12),
                stepAvailability.when(
                  data: (availability) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Step source status'),
                    subtitle: Text(_stepAvailabilityLabel(availability)),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final granted = await ref
                            .read(stepAccessControllerProvider)
                            .requestAccess();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              granted
                                  ? 'Health Connect access granted'
                                  : 'Health Connect access not granted',
                            ),
                          ),
                        );
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) =>
                      const Text('Unable to read step source status'),
                ),
                stepSnapshot.when(
                  data: (snapshot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Today\'s steps'),
                    subtitle: Text(
                      snapshot == null
                          ? 'No step data available yet'
                          : '${snapshot.stepsToday} steps (${snapshot.source.name})',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        ref.read(stepAccessControllerProvider).refresh();
                      },
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const Text('Unable to read today\'s steps'),
                ),
                const SizedBox(height: 12),
                const Text('Step announcement mode'),
                const SizedBox(height: 6),
                DropdownButtonFormField<StepAnnouncementMode>(
                  initialValue: settings.stepAnnouncementMode,
                  items: StepAnnouncementMode.values
                      .map(
                        (mode) => DropdownMenuItem<StepAnnouncementMode>(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _update(
                        ref,
                        settings.copyWith(stepAnnouncementMode: value),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text('Daily step goal (${settings.dailyStepGoal})'),
                Slider(
                  value: settings.dailyStepGoal.toDouble(),
                  min: 2000,
                  max: 20000,
                  divisions: 36,
                  label: settings.dailyStepGoal.toString(),
                  onChanged: (value) {
                    _update(
                      ref,
                      settings.copyWith(dailyStepGoal: value.round()),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Text('Talkativeness'),
              const SizedBox(height: 6),
              DropdownButtonFormField<SpeechTalkativenessMode>(
                initialValue: settings.talkativenessMode,
                items: SpeechTalkativenessMode.values
                    .map(
                      (mode) => DropdownMenuItem<SpeechTalkativenessMode>(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _update(ref, settings.copyWith(talkativenessMode: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Language'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _normalizedLanguage(settings.languageCode),
                items: AppLanguages.options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.code,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _update(
                      ref,
                      settings.copyWith(
                        languageCode: value,
                        languageRotationEnabled: false,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Default voice'),
              const SizedBox(height: 6),
              voices.when(
                data: (list) => _voiceDropdown(
                  list: list,
                  selectedVoice: settings.voiceName,
                  onChanged: (value) {
                    _update(ref, settings.copyWith(voiceName: value));
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Unable to load voices'),
              ),
              if (settings.multiVoiceSceneEnabled) ...[
                const SizedBox(height: 12),
                const Text('Time voice (scene)'),
                const SizedBox(height: 6),
                voices.when(
                  data: (list) => _voiceDropdown(
                    list: list,
                    selectedVoice: settings.timeVoiceName,
                    onChanged: (value) {
                      _update(ref, settings.copyWith(timeVoiceName: value));
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Unable to load voices'),
                ),
                const SizedBox(height: 12),
                const Text('Weather voice (scene)'),
                const SizedBox(height: 6),
                voices.when(
                  data: (list) => _voiceDropdown(
                    list: list,
                    selectedVoice: settings.weatherVoiceName,
                    onChanged: (value) {
                      _update(ref, settings.copyWith(weatherVoiceName: value));
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Unable to load voices'),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Announcement volume (${(settings.announcementVolume * 100).round()}%)',
              ),
              Slider(
                value: settings.announcementVolume,
                onChanged: (value) {
                  _update(ref, settings.copyWith(announcementVolume: value));
                },
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  final service = ref.read(announcementServiceProvider);
                  final testSettings = settings.copyWith(
                    timeAnnouncementsEnabled: true,
                    quietHoursStart: 0,
                    quietHoursEnd: 0,
                    languageRotationEnabled: false,
                    announcementVolume: settings.announcementVolume < 0.2
                        ? 0.8
                        : settings.announcementVolume,
                  );
                  final now = DateTime.now();
                  try {
                    await ref.read(weatherProvider.notifier).refresh();
                  } catch (_) {
                    // Keep test path usable even if live refresh fails.
                  }

                  final weather = ref.read(weatherProvider).value;
                  final preview = await service.previewHourlyBundle(
                    now: now,
                    settings: testSettings,
                    weather: weather,
                  );

                  if (preview.willSpeak) {
                    await service.speakHourlyBundle(
                      now: now,
                      settings: testSettings,
                      weather: weather,
                    );
                  }

                  if (!context.mounted) {
                    return;
                  }

                  final parts = <String>[];
                  if (preview.includesTime) {
                    parts.add('time');
                  }
                  if (preview.includesEvent) {
                    parts.add('event');
                  }
                  if (preview.includesWeather) {
                    parts.add('weather');
                  }

                  final status = preview.willSpeak
                      ? 'Test announced: ${parts.isEmpty ? 'nothing' : parts.join(' + ')}'
                      : 'Test suppressed: ${_speechReasonLabel(preview.suppressionReason)}';
                  final detail = preview.message.trim().isEmpty
                      ? null
                      : preview.message.trim();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        detail == null ? status : '$status\n$detail',
                      ),
                    ),
                  );
                },
                child: const Text('Test hourly announcement now'),
              ),
              const SizedBox(height: 12),
              _QuietHoursTile(settings: settings),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load settings: $error')),
        ),
      ),
    );
  }

  Future<void> _saveHomeFromCurrent(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final position = await _captureCurrentLocation();
    if (position == null) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to read current location');
      return;
    }

    final latest = ref.read(settingsProvider).value ?? settings;
    await _update(
      ref,
      latest.copyWith(
        homeLatitude: position.latitude,
        homeLongitude: position.longitude,
      ),
    );
    if (!context.mounted) return;
    _showSnack(
      context,
      'Home saved: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
    );
  }

  Future<void> _saveWorkFromCurrent(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final position = await _captureCurrentLocation();
    if (position == null) {
      if (!context.mounted) return;
      _showSnack(context, 'Unable to read current location');
      return;
    }

    final latest = ref.read(settingsProvider).value ?? settings;
    await _update(
      ref,
      latest.copyWith(
        workLatitude: position.latitude,
        workLongitude: position.longitude,
      ),
    );
    if (!context.mounted) return;
    _showSnack(
      context,
      'Work saved: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
    );
  }

  Future<void> _clearHomeLocation(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final latest = ref.read(settingsProvider).value ?? settings;
    await _update(
      ref,
      latest.copyWith(
        homeLatitude: null,
        homeLongitude: null,
      ),
    );
    if (!context.mounted) return;
    _showSnack(context, 'Home location cleared');
  }

  Future<void> _clearWorkLocation(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final latest = ref.read(settingsProvider).value ?? settings;
    await _update(
      ref,
      latest.copyWith(
        workLatitude: null,
        workLongitude: null,
      ),
    );
    if (!context.mounted) return;
    _showSnack(context, 'Work location cleared');
  }

  Future<void> _clearAllLocations(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final latest = ref.read(settingsProvider).value ?? settings;
    await _update(
      ref,
      latest.copyWith(
        homeLatitude: null,
        homeLongitude: null,
        workLatitude: null,
        workLongitude: null,
      ),
    );
    if (!context.mounted) return;
    _showSnack(context, 'All saved locations cleared');
  }

  void _showSnack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<Position?> _captureCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final streamPosition = await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).first.timeout(const Duration(seconds: 12));
      return streamPosition;
    } catch (_) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return null;
      }
    }
  }

  String _coordinateLabel(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'not set';
    }
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String _normalizedLanguage(String code) {
    final exists = AppLanguages.options.any((option) => option.code == code);
    return exists ? code : 'en';
  }

  Widget _voiceDropdown({
    required List<String> list,
    required String selectedVoice,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: list.contains(selectedVoice) ? selectedVoice : null,
      items: list
          .map(
            (voice) => DropdownMenuItem(value: voice, child: Text(voice)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }

  Future<void> _runCalendarDiagnostics(
      BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(calendarServiceProvider);
      final now = DateTime.now();
      final event = await service.nextUpcomingEvent(
        now: now,
        within: const Duration(hours: 6),
      );
      if (!context.mounted) return;
      if (event == null) {
        _showSnack(
            context, 'Calendar: no upcoming events (or permission denied).');
        return;
      }
      final start = event.start.toLocal();
      _showSnack(context, 'Calendar: ${event.title} at $start');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Calendar error: $error');
    }
  }

  Future<void> _update(WidgetRef ref, UserSettings next) {
    return ref.read(settingsProvider.notifier).saveSettings(next);
  }

  String _speechReasonLabel(String? reason) {
    switch (reason) {
      case 'quiet_hours':
        return 'quiet hours';
      case 'recent_announcement':
        return 'recent announcement window';
      case 'talkativeness':
        return 'talkativeness mode';
      case 'no_content':
        return 'no hourly content available';
      case null:
        return 'unknown';
      default:
        return reason.replaceAll('_', ' ');
    }
  }

  String _stepAvailabilityLabel(StepProviderAvailability availability) {
    switch (availability) {
      case StepProviderAvailability.available:
        return 'Health data access is ready';
      case StepProviderAvailability.permissionRequired:
        return 'Health Connect permission is required';
      case StepProviderAvailability.unsupported:
        return 'Health Connect is not supported on this device';
      case StepProviderAvailability.unavailable:
        return 'Health Connect is unavailable';
    }
  }
}

class _QuietHoursTile extends ConsumerWidget {
  const _QuietHoursTile({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quiet hours'),
            const SizedBox(height: 6),
            Text(
                'Start: ${settings.quietHoursStart.toString().padLeft(2, '0')}:00'),
            Slider(
              value: settings.quietHoursStart.toDouble(),
              min: 0,
              max: 23,
              divisions: 23,
              label: settings.quietHoursStart.toString(),
              onChanged: (value) async {
                await ref.read(settingsProvider.notifier).saveSettings(
                      settings.copyWith(quietHoursStart: value.round()),
                    );
              },
            ),
            Text(
                'End: ${settings.quietHoursEnd.toString().padLeft(2, '0')}:00'),
            Slider(
              value: settings.quietHoursEnd.toDouble(),
              min: 0,
              max: 23,
              divisions: 23,
              label: settings.quietHoursEnd.toString(),
              onChanged: (value) async {
                await ref.read(settingsProvider.notifier).saveSettings(
                      settings.copyWith(quietHoursEnd: value.round()),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}
