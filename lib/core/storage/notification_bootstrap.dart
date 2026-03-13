import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/device_timezone_resolver.dart';

class NotificationBootstrap {
  static const backgroundServiceChannelId = 'glocal_background_service';
  static const backgroundServiceNotificationId = 4401;

  static bool get isAndroidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<FlutterLocalNotificationsPlugin> init() async {
    final plugin = FlutterLocalNotificationsPlugin();

    if (kIsWeb) {
      return plugin;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(DeviceTimezoneResolver.resolveLocation());

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await plugin.initialize(settings: settings);
    await ensureBackgroundServiceChannel(plugin);
    await requestAndroidPermissions(plugin);
    return plugin;
  }

  static Future<void> ensureBackgroundServiceChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }

    const channel = AndroidNotificationChannel(
      backgroundServiceChannelId,
      'Glocal background service',
      description:
          'Keeps reminders and hourly voice callouts active while the screen is locked.',
      importance: Importance.low,
      playSound: false,
    );

    await android.createNotificationChannel(channel);
  }

  static Future<void> requestAndroidPermissions(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    if (!isAndroidRuntime) {
      return;
    }

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }

    try {
      await android.requestNotificationsPermission();
    } catch (_) {
      // Ignore permission prompt failures and keep boot stable.
    }
  }
}
