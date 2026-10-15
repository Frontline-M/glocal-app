# Glocal — Handoff

_Prepared 15 Oct 2026 from `main` @ `7dad98f` (last commit 22 Mar 2026). Repo: https://github.com/Frontline-M/glocal-app_

## 1. What this is

Glocal is a Flutter voice clock for Android (primary) and iOS. It speaks the time every hour, optionally bundled with weather, the next calendar event or reminder, a step-count update and a short cultural snippet. Users can also capture voice reminders, which are announced when due. 25 languages are declared, with a strong West/East African focus (Yoruba, Hausa, Igbo, Twi, Swahili, Amharic and others).

- Package / bundle id: `com.glocal.voiceclockassistant`
- Current version in `pubspec.yaml`: **1.0.6+7**
- Only git tag: `v1.0.3-4` (points at `b5f9f78`). Versions 1.0.4 → 1.0.6 were bumped in pubspec but never tagged, and only 1.0.3+4 has release notes (`docs/releases/`).
- Single branch: `main`. All commits by Frontline Media (frontlinemedia.live@gmail.com).
- `index.html` and `privacy.html` at the repo root are the GitHub Pages site (privacy policy URL for the stores).

## 2. Stack

| Area | Choice |
|---|---|
| UI / state | Flutter, Riverpod 2, go_router 17 (3 routes: `/`, `/settings`, `/privacy-policy`) |
| Storage | Hive, every box AES-encrypted; keys in `flutter_secure_storage` |
| Speech | `flutter_tts` (system voices), `speech_to_text`, `record` + `audioplayers` for voice-memo reminders |
| Background | Android: `flutter_background_service` foreground service (type `mediaPlayback`). iOS: `workmanager` |
| Notifications | `flutter_local_notifications` 21 + `timezone` |
| Weather | Open-Meteo (no API key), `lib/core/config/app_config.dart` |
| Calendar | `eventide` (Android only; iOS uses a no-op service) |
| Steps | Android Health Connect via a custom Kotlin MethodChannel |
| Android build | AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, Java 17, minSdk 26, core library desugaring |

## 3. Code map

```
lib/
  main.dart                     Boot: edge-to-edge → Hive → notifications → background jobs → app
  app/glocal_app.dart           MaterialApp.router
  core/
    background/
      glocal_background_service.dart  Android foreground service; ticks every 15 s
      glocal_runtime.dart       Composition root for the background isolate; tick() runs
                                reminder → step → hourly cycles
    config/                     Open-Meteo URL, language list (AppLanguages)
    l10n/spoken_phrases.dart    ~1,000-line catalog of spoken phrases per language
    speech/                     Speech governance (rate-limits / "talkativeness" of announcements)
    storage/                    Hive bootstrap + encryption, notification bootstrap, Workmanager setup
    utils/                      Timezone resolver, time formatting, TTS locale resolver
  features/
    announcements/              Hourly bundle builder + TTS speaking (announcement_service.dart, 659 lines)
    calendar/                   Device calendar vs no-op
    clock/                      Main screen (614 lines)
    culture/                    Snippet dataset, observances, selector, history, validator
    legal/                      In-app privacy summary
    reminders/                  Voice/text reminders, Hive repo, missed-reminder recovery (590 lines)
    settings/                   UserSettings model (~28 fields), location profiles, settings screen (749 lines)
    steps/                      Step providers (chained), announcement modes, store
    weather/                    Open-Meteo repo + cache
android/app/src/main/kotlin/…   MainActivity, HealthConnectStepChannel, PermissionsRationaleActivity
tool/validate_culture_snippets.dart  CLI validator for the culture dataset
test/                           9 files, ~23 tests (culture, speech governance, steps, scheduler, formatters)
docs/                           Release, QA checklist, roadmap, store metadata, privacy template,
                                culture content guidelines
```

Runtime flow on Android: `main()` starts the foreground service → the service isolate calls `GlocalRuntime.bootstrap()` (re-opens Hive, builds every service) → `tick()` every 15 s. Hour changes are detected via a key in the `runtime` Hive box, so the first tick after install only records the hour and speaks nothing.

## 4. Getting it running

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/validate_culture_snippets.dart   # after editing culture data
flutter run
```

Release signing: create `android/key.properties` (gitignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, then `flutter build appbundle --release`. The keystore is not in the repo — **get it and its passwords from the previous owner; without it you can't ship updates to the existing Play listing.** Full steps in `docs/release_build.md`.

> I could not run Flutter while preparing this (SDK download blocked in my environment), so build/test status below is from reading the code, not from a run.

## 5. Known problems — fix these first

1. **CI is almost certainly broken.** `.github/workflows/ci.yml` pins Flutter **3.24.1** (Dart 3.5), but `flutter_lints ^6.0.0` needs Dart ≥ 3.8, and `go_router ^17` / `flutter_local_notifications ^21` are similarly recent. `flutter pub get` should fail. Bump the CI Flutter version to whatever the team builds with locally (`.metadata` revision `ff37bef…`).
2. **Fresh clones likely won't build.** `pubspec.yaml` declares `assets/images/` but that folder isn't in git (git doesn't track empty dirs). Flutter errors on a missing asset directory. The last commit ("Fix Flutter asset packaging") removed `assets/icons/` but left this. Either remove the entry or add the folder with a `.gitkeep`.
3. **iOS will crash on permission requests.** `ios/Runner/Info.plist` only has calendar usage strings. Add `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` and `NSLocationWhenInUseUsageDescription` before any iOS testing.
4. **Health Connect steps don't reach the background isolate.** The Kotlin channel is registered on the main activity's FlutterEngine only. The foreground service runs its own engine, so `GlocalRuntime`'s step provider hits `MissingPluginException` and falls through to "unsupported". Step announcements will only work while the UI engine is alive, if at all. The plugin needs registering in the service engine too (e.g. as a proper Flutter plugin, or via the service's engine callback).
5. **Two of three step channels have no native side.** `glocal/steps/samsung_health` and `glocal/steps/local_fallback` are called from Dart but nothing implements them. Harmless (caught), but misleading.
6. **Hive is opened from two isolates.** The UI and the background service both open the same encrypted boxes. Hive isn't multi-isolate safe, so concurrent writes (settings changes, reminder edits) can be lost or corrupt a box. Consider routing writes through one isolate, or moving to a store that supports multi-process access.
7. **Silent box reset risk.** `_openEncryptedBoxWithMigration` treats *any* open failure as "legacy unencrypted box", deletes it and rewrites. If the secure-storage key is ever lost (backup restore, Keystore reset), user settings are wiped silently. The reminders box has no migration path at all.
8. **Privacy policy is out of date.** Neither `privacy.html` nor the in-app policy mentions Health Connect / step data. Google Play requires this (plus the Health Connect permissions declaration form) before a build with `READ_STEPS` is approved.
9. **iOS background is a stub.** The Workmanager task (`glocal.weather.refresh`) returns `true` and does nothing; iOS also has `autoStart: false` for the background service. There are no hourly announcements on iOS in practice.

## 6. Play Store / policy notes

The manifest requests several sensitive permissions, each of which needs a matching Play Console declaration: `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (justify as spoken announcements), `SCHEDULE_EXACT_ALARM`, `READ_CALENDAR`, `RECORD_AUDIO`, fine location, and `health.READ_STEPS`. The foreground-service type `mediaPlayback` for a service that is mostly idle is the one most likely to be challenged in review. Store copy is in `docs/store_metadata.md`; screenshots and feature graphic in `store_assets/`.

## 7. Recent work (Mar 2026, newest first)

- **Asset packaging fix** for release builds (see problem 2).
- **Culture snippets**: dataset (`culture/data/cultural_snippets.dart`, `observances.dart`), selector with history to avoid repeats, a validator enforcing the rules in `docs/culture_content_guidelines.md` (8–18 words, respectful tone, etc.), plus a dataset test and CLI tool. Settings: on/off, region mode, attach to announcements, observances.
- **Health Connect step integration** (Kotlin channel, permission rationale activity, settings UI for granting access).
- **Speech governance + step announcements**: limits how often the app speaks, with talkativeness modes; step announcement modes and a daily goal.
- **Android 15 edge-to-edge** prep.
- **Reminder audio hardening** and a shared spoken localisation layer (1.0.3+4).

## 8. Open roadmap (from `docs/roadmap.md`)

Desktop screensaver mode (scaffolded; Windows runner exists, `screensaverMode` setting exists, nothing behind it), cloud STT fallback (opt-in), richer reminder parsing ("tomorrow 8am", recurring), multi-location weather. Note: the roadmap's "encryption at rest" item is already done — Hive boxes are encrypted.

Translation quality for the less common languages (Tiv, Ijaw, Ibibio, Fon, Edo, Maasai, Luo…) in `spoken_phrases.dart` hasn't been reviewed by native speakers as far as the repo shows, and most devices have no TTS voice for them; `tts_locale_resolver.dart` decides the fallback.

## 9. Suggested first week

1. Get Flutter version, keystore, Play Console and Apple developer access from the previous owner.
2. Fix CI (1) and the asset entry (2); get `analyze` + `test` green.
3. Tag the current state (`v1.0.6-7`) and write release notes for 1.0.4–1.0.6 from the commit log.
4. Add the missing iOS usage strings (3) and update the privacy policy (8).
5. Decide on the background-isolate issues (4, 6) — they affect reliability of the app's core promise.
6. Run through `docs/qa_checklist.md` on a real Android 14/15 device, especially with battery optimisation on.
