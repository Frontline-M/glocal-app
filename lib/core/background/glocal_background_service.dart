import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'glocal_runtime.dart';

class GlocalBackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> init() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: glocalBackgroundServiceOnStart,
        autoStart: true,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'glocal_background_service',
        initialNotificationTitle: 'Glocal background active',
        initialNotificationContent:
            'Reminders and hourly callouts stay active while the screen is locked.',
        foregroundServiceNotificationId: 4401,
        foregroundServiceTypes: const [AndroidForegroundType.mediaPlayback],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: glocalBackgroundServiceOnStart,
      ),
    );

    if (!await _service.isRunning()) {
      await _service.startService();
    }
  }
}

@pragma('vm:entry-point')
Future<void> glocalBackgroundServiceOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Glocal background active',
      content:
          'Reminders and hourly callouts stay active while the screen is locked.',
    );
  }

  final runtime = await GlocalRuntime.bootstrap();
  await runtime.recoverMissedReminders();

  Timer? timer;
  timer = Timer.periodic(const Duration(seconds: 15), (_) async {
    try {
      if (service is AndroidServiceInstance) {
        final isForeground = await service.isForegroundService();
        if (!isForeground) {
          await service.setAsForegroundService();
        }
      }
      await runtime.tick(DateTime.now());
    } catch (_) {
      // Keep the service alive even if a plugin call fails.
    }
  });

  service.on('stopService').listen((_) async {
    timer?.cancel();
    await service.stopSelf();
  });
}
