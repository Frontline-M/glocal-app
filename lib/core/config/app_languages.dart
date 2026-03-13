import 'package:flutter/material.dart';

class LanguageOption {
  const LanguageOption({required this.code, required this.label});

  final String code;
  final String label;
}

class AppLanguages {
  static const options = <LanguageOption>[
    LanguageOption(code: 'en', label: 'English'),
    LanguageOption(code: 'fr', label: 'French'),
    LanguageOption(code: 'es', label: 'Spanish'),
    LanguageOption(code: 'de', label: 'German'),
    LanguageOption(code: 'ar', label: 'Arabic'),
    LanguageOption(code: 'hi', label: 'Hindi'),
    LanguageOption(code: 'yo', label: 'Yoruba'),
    LanguageOption(code: 'ha', label: 'Hausa'),
    LanguageOption(code: 'tw', label: 'Twi'),
    LanguageOption(code: 'zu', label: 'Zulu'),
    LanguageOption(code: 'mas', label: 'Maasai (Massai)'),
    LanguageOption(code: 'ig', label: 'Igbo'),
    LanguageOption(code: 'bin', label: 'Edo (Bini)'),
    LanguageOption(code: 'ijc', label: 'Ijaw'),
    LanguageOption(code: 'tiv', label: 'Tiv'),
    LanguageOption(code: 'ibb', label: 'Ibibio'),
    LanguageOption(code: 'ak', label: 'Akan (Ashante)'),
    LanguageOption(code: 'fon', label: 'Fon'),
    LanguageOption(code: 'sw', label: 'Swahili'),
    LanguageOption(code: 'ki', label: 'Kikuyu'),
    LanguageOption(code: 'luo', label: 'Luo'),
    LanguageOption(code: 'am', label: 'Amharic'),
    LanguageOption(code: 'om', label: 'Oromo'),
    LanguageOption(code: 'ja', label: 'Japanese'),
    LanguageOption(code: 'zh', label: 'Chinese'),
  ];

  static final supportedLocales =
      options.map((option) => Locale(option.code)).toList(growable: false);

  static final rotationCodes =
      options.map((option) => option.code).toList(growable: false);
}
