class CulturalSnippetDraft {
  const CulturalSnippetDraft({
    required this.id,
    required this.region,
    required this.timeSlot,
    required this.locale,
    required this.type,
    required this.message,
    this.weight = 1,
    this.expressiveOnly = false,
  });

  final String id;
  final String region;
  final String timeSlot;
  final String locale;
  final String type;
  final String message;
  final int weight;
  final bool expressiveOnly;
}

class CultureValidationIssue {
  const CultureValidationIssue({
    required this.code,
    required this.message,
    required this.isError,
  });

  final String code;
  final String message;
  final bool isError;

  @override
  String toString() => '${isError ? "ERROR" : "WARN"} [$code] $message';
}

class CultureValidationResult {
  const CultureValidationResult(this.issues);

  final List<CultureValidationIssue> issues;

  bool get isValid => !issues.any((issue) => issue.isError);

  List<CultureValidationIssue> get errors =>
      issues.where((issue) => issue.isError).toList(growable: false);

  List<CultureValidationIssue> get warnings =>
      issues.where((issue) => !issue.isError).toList(growable: false);
}

class CultureSnippetValidator {
  static const Set<String> allowedRegions = {
    'West Africa',
    'Europe',
    'East Asia',
    'Middle East',
    'North America',
    'Global',
  };

  static const Set<String> allowedTimeSlots = {
    'morning',
    'afternoon',
    'evening',
    'night',
  };

  static const Set<String> allowedTypes = {
    'daily_life',
    'language',
    'city_life',
    'reflection',
    'observance',
  };

  static const int idealMinWords = 8;
  static const int idealMaxWords = 18;
  static const int hardMaxWords = 24;

  static const List<String> discouragedAbsolutePhrases = [
    'always',
    'everyone',
    'nobody',
    'all people',
    'everybody',
    'never',
  ];

  static const List<String> discouragedStereotypePhrases = [
    'are known for',
    'typically all',
    'people there do',
    'everyone there',
    'the culture is',
  ];

  static const List<String> discouragedSpeechCharacters = [
    '(',
    ')',
    '[',
    ']',
    '/',
    ';',
  ];

  static const List<String> preferredSofteners = [
    'often',
    'can be',
    'in many places',
    'in many homes',
    'in some places',
    'for some',
  ];

  CultureValidationResult validate(
    CulturalSnippetDraft snippet, {
    Iterable<CulturalSnippetDraft> existing = const [],
  }) {
    final issues = <CultureValidationIssue>[];
    final message = snippet.message.trim();
    final normalized = _normalize(message);
    final wordCount = _wordCount(message);

    if (snippet.id.trim().isEmpty) {
      issues.add(
        const CultureValidationIssue(
          code: 'missing_id',
          message: 'Snippet id must not be empty.',
          isError: true,
        ),
      );
    }

    if (!allowedRegions.contains(snippet.region)) {
      issues.add(
        CultureValidationIssue(
          code: 'invalid_region',
          message: 'Region "${snippet.region}" is not allowed.',
          isError: true,
        ),
      );
    }

    if (!allowedTimeSlots.contains(snippet.timeSlot)) {
      issues.add(
        CultureValidationIssue(
          code: 'invalid_time_slot',
          message: 'Time slot "${snippet.timeSlot}" is not allowed.',
          isError: true,
        ),
      );
    }

    if (!allowedTypes.contains(snippet.type)) {
      issues.add(
        CultureValidationIssue(
          code: 'invalid_type',
          message: 'Type "${snippet.type}" is not allowed.',
          isError: true,
        ),
      );
    }

    if (message.isEmpty) {
      issues.add(
        const CultureValidationIssue(
          code: 'empty_message',
          message: 'Message must not be empty.',
          isError: true,
        ),
      );
      return CultureValidationResult(issues);
    }

    if (wordCount > hardMaxWords && snippet.type != 'observance') {
      issues.add(
        CultureValidationIssue(
          code: 'too_long',
          message:
              'Message has $wordCount words. Non-observance snippets should not exceed $hardMaxWords words.',
          isError: true,
        ),
      );
    } else if (wordCount < idealMinWords) {
      issues.add(
        CultureValidationIssue(
          code: 'too_short',
          message:
              'Message has $wordCount words. Cultural snippets are usually stronger at $idealMinWords-$idealMaxWords words.',
          isError: false,
        ),
      );
    } else if (wordCount > idealMaxWords) {
      issues.add(
        CultureValidationIssue(
          code: 'long_warning',
          message:
              'Message has $wordCount words. Ideal range is $idealMinWords-$idealMaxWords words.',
          isError: false,
        ),
      );
    }

    for (final phrase in discouragedAbsolutePhrases) {
      if (normalized.contains(phrase)) {
        issues.add(
          CultureValidationIssue(
            code: 'absolute_language',
            message:
                'Message uses absolute wording ("$phrase"). Prefer softer wording such as "often" or "in many places".',
            isError: false,
          ),
        );
      }
    }

    for (final phrase in discouragedStereotypePhrases) {
      if (normalized.contains(phrase)) {
        issues.add(
          CultureValidationIssue(
            code: 'stereotype_risk',
            message:
                'Message contains phrase "$phrase", which may sound overgeneralized or stereotyped.',
            isError: false,
          ),
        );
      }
    }

    for (final character in discouragedSpeechCharacters) {
      if (message.contains(character)) {
        issues.add(
          CultureValidationIssue(
            code: 'tts_punctuation',
            message:
                'Message contains "$character", which may reduce speech naturalness.',
            isError: false,
          ),
        );
      }
    }

    if (!_startsWellForMerge(message)) {
      issues.add(
        const CultureValidationIssue(
          code: 'merge_flow',
          message:
              'Message may not merge naturally after a time announcement. Prefer openings like "In many...", "Across...", or "Today...".',
          isError: false,
        ),
      );
    }

    if (snippet.type == 'language' && !_looksLanguageFriendly(message)) {
      issues.add(
        const CultureValidationIssue(
          code: 'language_style',
          message:
              'Language snippets should usually mention the language and explain the phrase briefly.',
          isError: false,
        ),
      );
    }

    if (snippet.type == 'observance' && !_looksObservanceFriendly(message)) {
      issues.add(
        const CultureValidationIssue(
          code: 'observance_style',
          message:
              'Observance snippets should usually be date-friendly, calm, and event-specific.',
          isError: false,
        ),
      );
    }

    if (!_containsAnySoftener(normalized) &&
        snippet.type != 'language' &&
        snippet.type != 'observance' &&
        snippet.region != 'Global') {
      issues.add(
        const CultureValidationIssue(
          code: 'missing_softener',
          message:
              'Consider using softer phrasing such as "often", "can be", or "in many homes".',
          isError: false,
        ),
      );
    }

    final duplicateId = existing.any((entry) => entry.id == snippet.id);
    if (duplicateId) {
      issues.add(
        CultureValidationIssue(
          code: 'duplicate_id',
          message: 'Snippet id "${snippet.id}" already exists.',
          isError: true,
        ),
      );
    }

    final nearDuplicate = existing.where((entry) {
      final similarity = _jaccardSimilarity(
        _tokenize(_normalize(entry.message)),
        _tokenize(normalized),
      );
      return similarity >= 0.80;
    }).toList(growable: false);

    if (nearDuplicate.isNotEmpty) {
      issues.add(
        CultureValidationIssue(
          code: 'near_duplicate',
          message:
              'Message is very similar to an existing snippet (${nearDuplicate.first.id}).',
          isError: false,
        ),
      );
    }

    if (snippet.weight < 1 || snippet.weight > 5) {
      issues.add(
        CultureValidationIssue(
          code: 'weight_range',
          message:
              'Weight ${snippet.weight} is unusual. Preferred range is 1 to 5.',
          isError: false,
        ),
      );
    }

    return CultureValidationResult(issues);
  }

  bool _startsWellForMerge(String text) {
    final trimmed = text.trim();
    const preferredStarts = [
      'In ',
      'Across ',
      'Today ',
      'At this hour',
      'For some',
      'Around the world',
      'In many ',
      'In parts of ',
    ];
    return preferredStarts.any(trimmed.startsWith);
  }

  bool _looksLanguageFriendly(String text) {
    final lower = _normalize(text);
    return lower.contains('in ') &&
        (lower.contains('greeting') ||
            lower.contains('means') ||
            lower.contains('common'));
  }

  bool _looksObservanceFriendly(String text) {
    final lower = _normalize(text);
    return lower.startsWith('today ') ||
        lower.contains('today is') ||
        lower.contains('today marks');
  }

  bool _containsAnySoftener(String text) {
    return preferredSofteners.any(text.contains);
  }

  int _wordCount(String input) {
    return input
        .trim()
        .split(RegExp(r'\s+'))
        .where((entry) => entry.isNotEmpty)
        .length;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Set<String> _tokenize(String input) {
    return input
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  double _jaccardSimilarity(Set<String> left, Set<String> right) {
    if (left.isEmpty && right.isEmpty) {
      return 1.0;
    }
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}
