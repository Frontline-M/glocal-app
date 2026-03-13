import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/background/glocal_runtime.dart';
import '../../../core/utils/time_formatters.dart';
import '../../announcements/application/announcement_provider.dart';
import '../../announcements/data/hourly_announcement_scheduler.dart';
import '../../reminders/application/reminder_provider.dart';
import '../../reminders/domain/reminder_categories.dart';
import '../../settings/application/settings_provider.dart';
import '../../weather/application/weather_provider.dart';

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  final _scheduler = HourlyAnnouncementScheduler();
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _lastScreensaverMode = false;
  int _lastReminderCheckSlot = -1;
  int _lastAnnouncementHourKey = -1;
  int _lastUiWeatherRefreshHourKey = -1;
  Future<GlocalRuntime>? _androidRuntime;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _androidRuntime = GlocalRuntime.bootstrap();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    Future<void>.microtask(() async {
      await ref.read(weatherProvider.notifier).refresh();
      await ref
          .read(reminderServiceProvider)
          .recoverMissedReminders(DateTime.now());
      await ref.read(remindersProvider.notifier).reload();
    });
  }

  Future<void> _onTick() async {
    if (!mounted) return;

    final current = DateTime.now();
    setState(() => _now = current);

    final hourKey = (current.year * 1000000) +
        (current.month * 10000) +
        (current.day * 100) +
        current.hour;
    final androidBackgroundDriven =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (androidBackgroundDriven) {
      final runtime = await _resolveAndroidRuntime();
      if (runtime != null) {
        try {
          await runtime.tick(current);
        } catch (_) {
          // Keep the foreground clock running if the shared runtime hits a plugin error.
        }
      }

      if (_lastUiWeatherRefreshHourKey != hourKey) {
        _lastUiWeatherRefreshHourKey = hourKey;
        try {
          await ref.read(weatherProvider.notifier).refresh();
        } catch (_) {
          // Keep the on-screen weather display stable if refresh fails.
        }
      }
    } else {
      final topOfHourWindow = current.minute == 0 && current.second <= 10;
      final shouldAnnounceHour = _scheduler.shouldRun(current) ||
          (topOfHourWindow && _lastAnnouncementHourKey != hourKey);

      if (shouldAnnounceHour) {
        _lastAnnouncementHourKey = hourKey;
        try {
          await ref.read(weatherProvider.notifier).refresh();
        } catch (_) {
          // Keep hourly flow running even if weather refresh fails.
        }
        try {
          await ref.read(hourlyAnnouncementControllerProvider).run(current);
        } catch (_) {
          // Keep timer loop alive on TTS/plugin errors.
        }
      }
    }

    final settings = ref.read(settingsProvider).value ??
        ref.read(settingsProvider).asData?.value;
    final reminderCheckEvery = (settings?.adaptiveBatteryMode ?? false)
        ? const Duration(seconds: 60)
        : const Duration(seconds: 15);
    final reminderSlot =
        current.millisecondsSinceEpoch ~/ reminderCheckEvery.inMilliseconds;
    if (reminderSlot != _lastReminderCheckSlot) {
      _lastReminderCheckSlot = reminderSlot;
      try {
        if (!androidBackgroundDriven) {
          await ref.read(reminderServiceProvider).announceDueReminders(current);
        }
      } catch (_) {
        // Ignore reminder backend errors and keep UI active.
      } finally {
        await ref.read(remindersProvider.notifier).reload();
      }
    }
  }

  Future<GlocalRuntime?> _resolveAndroidRuntime() async {
    final runtimeFuture = _androidRuntime;
    if (runtimeFuture == null) {
      return null;
    }

    try {
      return await runtimeFuture;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(settingsProvider);
    final settings = asyncSettings.value ?? asyncSettings.asData?.value;
    final muted = ref.watch(reminderMuteProvider);

    final use24Hour = settings?.use24Hour ?? true;
    final clockText = formatClockTime(_now, use24Hour: use24Hour);

    final screensaverMode = settings?.screensaverMode ?? false;
    if (screensaverMode != _lastScreensaverMode) {
      _lastScreensaverMode = screensaverMode;
      if (screensaverMode) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    }

    final weatherState = ref.watch(weatherProvider);
    final remindersState = ref.watch(remindersProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E6BA8), Color(0xFF0A4F7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Glocal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    clockText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: weatherState.when(
                    data: (weather) {
                      if (weather == null) {
                        return const _InfoText('Weather unavailable');
                      }
                      return _InfoText(
                          '${weather.temperatureC.toStringAsFixed(1)}°C');
                    },
                    loading: () => const _InfoText('Updating weather...'),
                    error: (_, __) => const _InfoText(
                        'Weather fetch failed (using cache when available)'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Upcoming reminders',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: remindersState.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const _InfoText('No reminders yet');
                      }
                      return ListView.builder(
                        itemCount: items.length.clamp(0, 4),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            color: Colors.white.withValues(alpha: 0.16),
                            child: ListTile(
                              title: Text(
                                item.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${ReminderCategories.labelFor(item.category)} - ${item.when.toLocal()}${item.repeatDaily ? ' - daily' : ''}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.snooze,
                                        color: Colors.white),
                                    tooltip: 'Snooze 10 min',
                                    onPressed: () async {
                                      await ref
                                          .read(reminderServiceProvider)
                                          .snoozeReminder(item.id,
                                              const Duration(minutes: 10));
                                      await ref
                                          .read(remindersProvider.notifier)
                                          .reload();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.white),
                                    tooltip: 'Done',
                                    onPressed: () async {
                                      await ref
                                          .read(reminderServiceProvider)
                                          .deleteReminder(item.id);
                                      await ref
                                          .read(remindersProvider.notifier)
                                          .reload();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const _InfoText('Loading reminders...'),
                    error: (_, __) =>
                        const _InfoText('Unable to load reminders'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _captureReminder(context),
                        icon: const Icon(Icons.mic),
                        label: const Text('Voice reminder'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final now = DateTime.now();
                        await ref
                            .read(reminderServiceProvider)
                            .dismissDueReminders(now);
                        await ref.read(remindersProvider.notifier).reload();
                      },
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mute reminder speech',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: muted,
                  onChanged: (value) async {
                    await ref.read(reminderServiceProvider).setMuted(value);
                    ref.read(reminderMuteProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureReminder(BuildContext context) async {
    final reminderService = ref.read(reminderServiceProvider);
    final settings = ref.read(settingsProvider).value ??
        ref.read(settingsProvider).asData?.value;
    final reminderId = DateTime.now().millisecondsSinceEpoch.toString();
    final controller = TextEditingController(text: 'New reminder');
    DateTime scheduled = DateTime.now().add(const Duration(minutes: 2));
    bool repeatDaily = false;
    String category = ReminderCategories.general;
    bool isRecording = false;
    bool isTranscribing = true;
    bool transcriptionStarted = false;
    bool dialogOpen = true;
    String transcriptionMessage = 'Listening for your reminder...';
    String? customAudioPath;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!transcriptionStarted) {
              transcriptionStarted = true;
              Future<void>.microtask(() async {
                try {
                  final transcript =
                      await reminderService.transcribeSingleUtterance(
                    languageCode: settings?.languageCode,
                  );
                  if (!dialogOpen || !context.mounted) {
                    return;
                  }
                  final currentText = controller.text.trim();
                  if (transcript.isNotEmpty &&
                      (currentText.isEmpty || currentText == 'New reminder')) {
                    controller.text = transcript;
                  }
                  transcriptionMessage = transcript.isEmpty
                      ? 'No speech detected. You can type the reminder instead.'
                      : 'Voice reminder captured.';
                } catch (_) {
                  if (!dialogOpen || !context.mounted) {
                    return;
                  }
                  transcriptionMessage =
                      'Voice capture unavailable. You can type the reminder.';
                } finally {
                  if (dialogOpen && context.mounted) {
                    setDialogState(() => isTranscribing = false);
                  }
                }
              });
            }
            return AlertDialog(
              title: const Text('Create reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isTranscribing) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            transcriptionMessage,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      decoration:
                          const InputDecoration(labelText: 'Reminder text'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDate: scheduled,
                        );
                        if (picked != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(scheduled),
                          );
                          if (time != null) {
                            scheduled = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              time.hour,
                              time.minute,
                            );
                          }
                        }
                      },
                      child: const Text('Pick date/time'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: isTranscribing
                          ? null
                          : () async {
                              if (!isRecording) {
                                final started = await reminderService
                                    .startCustomReminderRecording(reminderId);
                                if (started != null) {
                                  setDialogState(() {
                                    isRecording = true;
                                    customAudioPath = started;
                                  });
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Microphone permission is required to record.',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                final stopped = await reminderService
                                    .stopCustomReminderRecording();
                                setDialogState(() {
                                  isRecording = false;
                                  if (stopped != null && stopped.isNotEmpty) {
                                    customAudioPath = stopped;
                                  }
                                });
                              }
                            },
                      icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(
                        isRecording
                            ? 'Stop recording'
                            : 'Record in your language',
                      ),
                    ),
                    if (customAudioPath != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Custom voice recorded for this reminder',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ReminderCategories.options
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.code,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => category = value);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Daily repeat'),
                      value: repeatDaily,
                      onChanged: (value) {
                        setDialogState(() {
                          repeatDaily = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    dialogOpen = false;
                    if (isRecording) {
                      await reminderService.stopCustomReminderRecording();
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(false);
                    }
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    dialogOpen = false;
                    if (isRecording) {
                      final stopped =
                          await reminderService.stopCustomReminderRecording();
                      if (stopped != null && stopped.isNotEmpty) {
                        customAudioPath = stopped;
                      }
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogOpen = false;
    await reminderService.stopTranscription();

    if (shouldSave == true) {
      await reminderService.createReminder(
        id: reminderId,
        title: controller.text.trim(),
        when: scheduled,
        languageCode: settings?.languageCode ?? 'en',
        voiceName: settings?.voiceName ?? '',
        repeatDaily: repeatDaily,
        category: category,
        customAudioPath: customAudioPath,
      );
    }

    await ref.read(remindersProvider.notifier).reload();
    controller.dispose();
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70),
      textAlign: TextAlign.center,
    );
  }
}
