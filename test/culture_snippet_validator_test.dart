import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validator.dart';

void main() {
  final validator = CultureSnippetValidator();

  test('accepts a good daily life snippet', () {
    final result = validator.validate(
      const CulturalSnippetDraft(
        id: 'wa_evening_01',
        region: 'West Africa',
        timeSlot: 'evening',
        locale: 'Nigeria',
        type: 'daily_life',
        message:
            'In many Nigerian homes, evening is a time for dinner and conversation.',
      ),
    );

    expect(result.isValid, true);
  });

  test('flags overly absolute language', () {
    final result = validator.validate(
      const CulturalSnippetDraft(
        id: 'bad_01',
        region: 'Europe',
        timeSlot: 'evening',
        locale: 'Spain',
        type: 'daily_life',
        message: 'Spaniards always eat very late every night.',
      ),
    );

    expect(
      result.warnings.any((warning) => warning.code == 'absolute_language'),
      true,
    );
  });

  test('rejects overly long non-observance snippet', () {
    final result = validator.validate(
      const CulturalSnippetDraft(
        id: 'bad_02',
        region: 'North America',
        timeSlot: 'morning',
        locale: 'USA',
        type: 'daily_life',
        message:
            'In many parts of the United States, the morning period is frequently associated with highly structured commuting patterns, beverage rituals, and complex scheduling demands before the official workday begins.',
      ),
    );

    expect(result.isValid, false);
    expect(result.errors.any((error) => error.code == 'too_long'), true);
  });
}
