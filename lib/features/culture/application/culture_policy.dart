import '../../../core/speech/speech_talkativeness.dart';

class CulturePolicy {
  const CulturePolicy._();

  static int dailyCap(SpeechTalkativenessMode mode) {
    switch (mode) {
      case SpeechTalkativenessMode.minimal:
        return 0;
      case SpeechTalkativenessMode.balanced:
        return 2;
      case SpeechTalkativenessMode.expressive:
        return 3;
    }
  }

  static bool supportsCulture(SpeechTalkativenessMode mode) {
    return mode != SpeechTalkativenessMode.minimal;
  }

  static bool allowsExpressiveOnly(SpeechTalkativenessMode mode) {
    return mode == SpeechTalkativenessMode.expressive;
  }

  static bool allowsStandalone(SpeechTalkativenessMode mode) {
    return mode == SpeechTalkativenessMode.expressive;
  }
}
