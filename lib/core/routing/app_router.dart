import 'package:go_router/go_router.dart';

import 'package:glocal/features/clock/presentation/clock_screen.dart';
import 'package:glocal/features/legal/presentation/privacy_policy_screen.dart';
import 'package:glocal/features/settings/presentation/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'clock',
      builder: (context, state) => const ClockScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      name: 'privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
  ],
);
