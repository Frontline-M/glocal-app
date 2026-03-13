# Glocal

Glocal is a cross-platform voice clock app with hourly time and weather announcements, plus voice-driven reminders and alarms.

## Stack
- Flutter + Riverpod
- Clean architecture by feature modules
- Hive local storage
- Open-Meteo weather provider (pluggable interface)
- System TTS/STT

## Quick start
1. Install Flutter stable and platform SDKs.
2. Run `flutter pub get`.
3. Run `flutter run`.

## Project structure
- `lib/core`: shared config, storage bootstrap, routing, theme, utilities
- `lib/features/clock`: main clock screen
- `lib/features/settings`: preferences and controls
- `lib/features/weather`: API + cache + weather domain model
- `lib/features/announcements`: TTS and hourly announcement logic
- `lib/features/reminders`: STT transcription and local reminders
- `docs`: release, QA, privacy, and roadmap assets

## Status
This repository contains production-oriented scaffolding and starter implementations. Platform-specific setup (notification channels, background restrictions, store signing, entitlement tuning) is documented in `docs/`.
