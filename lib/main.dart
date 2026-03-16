import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/glocal_app.dart';
import 'core/storage/background_jobs.dart';
import 'core/storage/hive_bootstrap.dart';
import 'core/storage/notification_bootstrap.dart';
import 'core/storage/notification_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await HiveBootstrap.init();
  NotificationRegistry.plugin = await NotificationBootstrap.init();
  await BackgroundJobs.init();
  runApp(const ProviderScope(child: GlocalApp()));
}
