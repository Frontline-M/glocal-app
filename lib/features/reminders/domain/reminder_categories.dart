class ReminderCategoryOption {
  const ReminderCategoryOption({
    required this.code,
    required this.label,
    required this.spokenPrefix,
  });

  final String code;
  final String label;
  final String spokenPrefix;
}

class ReminderCategories {
  static const general = 'general';

  static const options = <ReminderCategoryOption>[
    ReminderCategoryOption(
      code: general,
      label: 'General',
      spokenPrefix: 'Reminder',
    ),
    ReminderCategoryOption(
      code: 'medication',
      label: 'Medication',
      spokenPrefix: 'Medication reminder',
    ),
    ReminderCategoryOption(
      code: 'prayer',
      label: 'Prayer',
      spokenPrefix: 'Prayer reminder',
    ),
    ReminderCategoryOption(
      code: 'pickup',
      label: 'Pickup',
      spokenPrefix: 'Pickup reminder',
    ),
    ReminderCategoryOption(
      code: 'meeting',
      label: 'Meeting',
      spokenPrefix: 'Meeting reminder',
    ),
    ReminderCategoryOption(
      code: 'plan',
      label: 'Plan',
      spokenPrefix: 'Plan reminder',
    ),
  ];

  static String normalize(String? code) {
    if (code == null || code.isEmpty) return general;
    final exists = options.any((option) => option.code == code);
    return exists ? code : general;
  }

  static String labelFor(String? code) {
    final normalized = normalize(code);
    return options.firstWhere((option) => option.code == normalized).label;
  }

  static String spokenPrefixFor(String? code) {
    final normalized = normalize(code);
    return options
        .firstWhere((option) => option.code == normalized)
        .spokenPrefix;
  }
}
