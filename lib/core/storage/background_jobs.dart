import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../background/glocal_background_service.dart';

const weatherRefreshTask = 'glocal.weather.refresh';

class BackgroundJobs {
  static Future<void> init() async {
    if (kIsWeb) {
      return;
    }

    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android) {
      await GlocalBackgroundService.init();
      return;
    }

    if (platform != TargetPlatform.iOS) {
      return;
    }

    await Workmanager().initialize(_callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'glocal-hourly',
      weatherRefreshTask,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    return true;
  });
}
