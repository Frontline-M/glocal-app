enum SpeechTalkativenessMode {
  minimal,
  balanced,
  expressive,
}

extension SpeechTalkativenessModeX on SpeechTalkativenessMode {
  String get storageValue {
    switch (this) {
      case SpeechTalkativenessMode.minimal:
        return 'minimal';
      case SpeechTalkativenessMode.balanced:
        return 'balanced';
      case SpeechTalkativenessMode.expressive:
        return 'expressive';
    }
  }

  String get label {
    switch (this) {
      case SpeechTalkativenessMode.minimal:
        return 'Minimal';
      case SpeechTalkativenessMode.balanced:
        return 'Balanced';
      case SpeechTalkativenessMode.expressive:
        return 'Expressive';
    }
  }
}

SpeechTalkativenessMode speechTalkativenessModeFromStorage(String? value) {
  switch (value) {
    case 'minimal':
      return SpeechTalkativenessMode.minimal;
    case 'expressive':
      return SpeechTalkativenessMode.expressive;
    case 'balanced':
    default:
      return SpeechTalkativenessMode.balanced;
  }
}
