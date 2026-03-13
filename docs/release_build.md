# Release Build Instructions

## Prerequisites
- Flutter stable installed (`flutter doctor` passes)
- Android Studio/Xcode toolchains configured
- Store signing credentials available

## Android
1. Set `applicationId` to your final package id.
2. Configure keystore in `android/key.properties` and `app/build.gradle`.
3. Build with `flutter build appbundle --release`.
4. Upload `.aab` to Google Play Console.

## iOS
1. Set bundle id and team in Xcode.
2. Configure push/notification/background capabilities.
3. Build with `flutter build ipa --release`.
4. Upload using Xcode Organizer or Transporter.

## Mandatory checks
- Notification permissions flow tested
- Microphone and location permissions tested
- Background announcement behavior validated per platform constraints
- Privacy policy and data safety labels filled
