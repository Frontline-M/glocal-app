import 'reminder_categories.dart';

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.when,
    required this.createdAt,
    required this.languageCode,
    required this.voiceName,
    required this.repeatDaily,
    required this.category,
    this.customAudioPath,
    this.spokenAt,
  });

  final String id;
  final String title;
  final DateTime when;
  final DateTime createdAt;
  final String languageCode;
  final String voiceName;
  final bool repeatDaily;
  final String category;
  final String? customAudioPath;
  final DateTime? spokenAt;

  bool get isSpoken => spokenAt != null;

  ReminderItem copyWith({
    String? id,
    String? title,
    DateTime? when,
    DateTime? createdAt,
    String? languageCode,
    String? voiceName,
    bool? repeatDaily,
    String? category,
    String? customAudioPath,
    DateTime? spokenAt,
    bool clearSpokenAt = false,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      when: when ?? this.when,
      createdAt: createdAt ?? this.createdAt,
      languageCode: languageCode ?? this.languageCode,
      voiceName: voiceName ?? this.voiceName,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      category: category ?? this.category,
      customAudioPath: customAudioPath ?? this.customAudioPath,
      spokenAt: clearSpokenAt ? null : spokenAt ?? this.spokenAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'languageCode': languageCode,
        'voiceName': voiceName,
        'repeatDaily': repeatDaily,
        'category': category,
        'customAudioPath': customAudioPath,
        'spokenAt': spokenAt?.toIso8601String(),
      };

  factory ReminderItem.fromJson(Map<dynamic, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String,
      title: json['title'] as String,
      when: DateTime.parse(json['when'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      languageCode: json['languageCode'] as String? ?? 'en',
      voiceName: json['voiceName'] as String? ?? '',
      repeatDaily: json['repeatDaily'] as bool? ?? false,
      category: ReminderCategories.normalize(json['category'] as String?),
      customAudioPath: json['customAudioPath'] as String?,
      spokenAt: json['spokenAt'] == null
          ? null
          : DateTime.parse(json['spokenAt'] as String),
    );
  }
}
