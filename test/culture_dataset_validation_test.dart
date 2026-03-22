import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/features/culture/data/cultural_snippets.dart';
import 'package:glocal/features/culture/data/observances.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validation_adapter.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validator.dart';

void main() {
  test('cultural snippet dataset has no validation errors', () {
    final validator = CultureSnippetValidator();
    final drafts = validationDraftsFromSnippets(culturalSnippets);

    for (final draft in drafts) {
      final siblings = drafts.where((entry) => entry.id != draft.id);
      final result = validator.validate(draft, existing: siblings);
      expect(
        result.errors,
        isEmpty,
        reason: 'Snippet ${draft.id} has validation errors: ${result.errors.join('; ')}',
      );
    }
  });

  test('observance dataset has no validation errors', () {
    final validator = CultureSnippetValidator();
    final drafts = validationDraftsFromObservances(culturalObservances);

    for (final draft in drafts) {
      final siblings = drafts.where((entry) => entry.id != draft.id);
      final result = validator.validate(draft, existing: siblings);
      expect(
        result.errors,
        isEmpty,
        reason: 'Observance ${draft.id} has validation errors: ${result.errors.join('; ')}',
      );
    }
  });
}
