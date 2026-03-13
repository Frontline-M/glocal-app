import 'package:flutter_tts/flutter_tts.dart';

class TtsLocaleResolver {
  static const preferredLocaleHints = <String, String>{
    'en': 'en-US',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'de': 'de-DE',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'yo': 'yo-NG',
    'ha': 'ha-NG',
    'ig': 'ig-NG',
    'sw': 'sw-KE',
    'ak': 'ak-GH',
    'tw': 'ak-GH',
    'am': 'am-ET',
    'om': 'om-ET',
    'ja': 'ja-JP',
    'zh': 'zh-CN',
  };

  static Future<bool> isLanguageAvailable(
    FlutterTts tts,
    String languageCode,
  ) async {
    final available = await availableLocales(tts);
    if (available.isEmpty) {
      return false;
    }

    final normalized = languageCode.toLowerCase();
    if (matchLocale(available, normalized) != null) {
      return true;
    }

    final hinted = preferredLocaleHints[normalized];
    if (hinted != null &&
        matchLocale(available, hinted.toLowerCase()) != null) {
      return true;
    }

    return available.any((locale) {
      final lower = locale.toLowerCase();
      return lower.startsWith('$normalized-') ||
          lower.startsWith('${normalized}_');
    });
  }

  static Future<String> resolveLocale(FlutterTts tts, String languageCode) async {
    final available = await availableLocales(tts);
    if (available.isEmpty) {
      return languageCode;
    }

    final normalized = languageCode.toLowerCase();
    final direct = matchLocale(available, normalized);
    if (direct != null) {
      return direct;
    }

    final hinted = preferredLocaleHints[normalized];
    if (hinted != null) {
      final hintMatch = matchLocale(available, hinted.toLowerCase());
      if (hintMatch != null) {
        return hintMatch;
      }
    }

    final languageOnlyMatch = available.firstWhere(
      (locale) {
        final lower = locale.toLowerCase();
        return lower.startsWith('$normalized-') ||
            lower.startsWith('${normalized}_');
      },
      orElse: () => '',
    );
    if (languageOnlyMatch.isNotEmpty) {
      return languageOnlyMatch;
    }

    final english = matchLocale(available, 'en-us') ??
        matchLocale(available, 'en-gb') ??
        matchLocale(available, 'en');
    return english ?? available.first;
  }

  static String? matchLocale(List<String> available, String target) {
    final exact = available.where((e) => e.toLowerCase() == target).toList();
    if (exact.isNotEmpty) {
      return exact.first;
    }

    final dashNormalized = target.replaceAll('_', '-');
    final fuzzy = available.where((e) {
      final lower = e.toLowerCase().replaceAll('_', '-');
      return lower == dashNormalized;
    }).toList();
    if (fuzzy.isNotEmpty) {
      return fuzzy.first;
    }

    return null;
  }

  static Future<List<String>> availableLocales(FlutterTts tts) async {
    try {
      final raw = await tts.getLanguages;
      if (raw is List) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {
      // Ignore and fallback to defaults.
    }
    return const [];
  }
}
