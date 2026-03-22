import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/speech/speech_talkativeness.dart';
import '../../settings/application/settings_provider.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/culture_models.dart';

class CultureSettingsSection extends ConsumerWidget {
  const CultureSettingsSection({
    super.key,
    required this.settings,
  });

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Cultural snippets'),
          subtitle: const Text(
            'Blend gentle regional and observance-style lines into existing announcements',
          ),
          value: settings.cultureAnnouncementsEnabled,
          onChanged: (value) {
            _update(
              ref,
              settings.copyWith(cultureAnnouncementsEnabled: value),
            );
          },
        ),
        if (settings.cultureAnnouncementsEnabled) ...[
          const SizedBox(height: 12),
          const Text('Culture region mode'),
          const SizedBox(height: 6),
          DropdownButtonFormField<CultureRegionMode>(
            initialValue: settings.cultureRegionMode,
            items: CultureRegionMode.values
                .map(
                  (mode) => DropdownMenuItem<CultureRegionMode>(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _update(ref, settings.copyWith(cultureRegionMode: value));
              }
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attach culture to announcements'),
            subtitle: const Text(
              'Prefer adding culture to time or weather messages instead of speaking it alone',
            ),
            value: settings.cultureAttachToAnnouncements,
            onChanged: (value) {
              _update(
                ref,
                settings.copyWith(cultureAttachToAnnouncements: value),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Observance messages'),
            subtitle: const Text(
              'Allow occasional date-based cultural observances in morning or evening summaries',
            ),
            value: settings.cultureObservancesEnabled,
            onChanged: (value) {
              _update(
                ref,
                settings.copyWith(cultureObservancesEnabled: value),
              );
            },
          ),
          if (settings.talkativenessMode == SpeechTalkativenessMode.minimal)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Talkativeness is set to Minimal, so culture will stay quiet until you choose Balanced or Expressive.',
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _update(WidgetRef ref, UserSettings next) {
    return ref.read(settingsProvider.notifier).saveSettings(next);
  }
}
