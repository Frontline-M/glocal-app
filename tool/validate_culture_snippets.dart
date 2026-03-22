import 'dart:io';

import 'package:glocal/features/culture/data/cultural_snippets.dart';
import 'package:glocal/features/culture/data/observances.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validation_adapter.dart';
import 'package:glocal/features/culture/domain/culture_snippet_validator.dart';

void main() {
  final validator = CultureSnippetValidator();
  var warningCount = 0;
  var errorCount = 0;

  print('Validating cultural snippets...');
  final snippetDrafts = validationDraftsFromSnippets(culturalSnippets);
  for (final draft in snippetDrafts) {
    final siblings = snippetDrafts.where((entry) => entry.id != draft.id);
    final result = validator.validate(draft, existing: siblings);
    for (final issue in result.issues) {
      final level = issue.isError ? 'ERROR' : 'WARN';
      print('$level ${draft.id}: ${issue.message}');
      if (issue.isError) {
        errorCount++;
      } else {
        warningCount++;
      }
    }
  }

  print('Validating observances...');
  final observanceDrafts = validationDraftsFromObservances(culturalObservances);
  for (final draft in observanceDrafts) {
    final siblings = observanceDrafts.where((entry) => entry.id != draft.id);
    final result = validator.validate(draft, existing: siblings);
    for (final issue in result.issues) {
      final level = issue.isError ? 'ERROR' : 'WARN';
      print('$level ${draft.id}: ${issue.message}');
      if (issue.isError) {
        errorCount++;
      } else {
        warningCount++;
      }
    }
  }

  print('Validation finished with $errorCount errors and $warningCount warnings.');
  if (errorCount > 0) {
    exitCode = 1;
  }
}
