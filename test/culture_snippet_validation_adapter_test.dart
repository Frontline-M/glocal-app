import 'package:flutter_test/flutter_test.dart';
import 'package:glocal/features/culture/data/cultural_snippets.dart';
import 'package:glocal/features/culture/data/observances.dart';
import 'package:glocal/features/culture/domain/culture_models.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validation_adapter.dart';

void main() {
  test('converts a cultural snippet into a validation draft', () {
    final draft = culturalSnippets.first.toValidationDraft();

    expect(draft.id, culturalSnippets.first.id);
    expect(draft.region, culturalSnippets.first.region);
    expect(draft.timeSlot, culturalSnippets.first.timeSlot.storageValue);
    expect(draft.type, culturalSnippets.first.type.storageValue);
    expect(draft.message, culturalSnippets.first.message);
  });

  test('converts observances into validation drafts with a default time slot', () {
    final drafts = validationDraftsFromObservances(
      culturalObservances,
      defaultTimeSlot: CultureTimeSlot.evening,
    );

    expect(drafts, isNotEmpty);
    expect(drafts.first.type, 'observance');
    expect(drafts.first.timeSlot, 'evening');
  });
}
