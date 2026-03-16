import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection(
      title: 'What Glocal does',
      body:
          'Glocal provides spoken time announcements, weather updates, reminders, and optional calendar-aware context on your device.',
    ),
    _PolicySection(
      title: 'Microphone access',
      body:
          'Glocal uses microphone access only when you choose voice reminder capture or speech input features. Audio is used to create your reminder content on the device. Glocal does not use the microphone continuously for advertising or profiling.',
    ),
    _PolicySection(
      title: 'Calendar access',
      body:
          'If you allow calendar permission, Glocal reads upcoming calendar events so hourly announcements can mention your next event. Calendar data is used only to support this feature on your device.',
    ),
    _PolicySection(
      title: 'Location and weather',
      body:
          'If you allow location access, Glocal uses your location to fetch local weather and apply your saved home, work, or travel profile settings. Weather requests are made only to support the app features you enable.',
    ),
    _PolicySection(
      title: 'Reminders and notifications',
      body:
          'Glocal stores your reminders, selected voices, and related settings locally on the device so reminders can trigger reliably, including while the screen is locked. Notifications are used to alert you when reminders are due.',
    ),
    _PolicySection(
      title: 'Data storage',
      body:
          'Your settings, reminders, and cached weather data are stored locally on your device. Glocal is designed to keep this information on-device except where an external service is needed to fetch weather.',
    ),
    _PolicySection(
      title: 'Data sharing',
      body:
          'Glocal does not sell your personal data. Data is shared only as needed to provide enabled features, such as requesting weather information from a weather service.',
    ),
    _PolicySection(
      title: 'Your choices',
      body:
          'You can disable microphone, calendar, location, or notifications in your device settings. You can also remove reminders and adjust announcement settings inside the app at any time.',
    ),
    _PolicySection(
      title: 'Contact',
      body:
          'If you publish Glocal to the Play Store, add your support email or website to the public Privacy Policy page you submit in Play Console so users can contact you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Glocal Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: March 12, 2026',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const Text(
              'This in-app summary explains how Glocal uses permissions and device data to provide reminders, spoken announcements, weather updates, and optional calendar context.',
            ),
            const SizedBox(height: 20),
            for (final section in _sections)
              _PolicySectionView(section: section),
          ],
        ),
      ),
    );
  }
}

class _PolicySectionView extends StatelessWidget {
  const _PolicySectionView({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(section.body),
        ],
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;
}

