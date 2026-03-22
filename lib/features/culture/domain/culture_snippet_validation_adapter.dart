import 'culture_models.dart';
import 'culture_snippet_validator.dart';

extension CulturalSnippetValidationDraftX on CulturalSnippet {
  CulturalSnippetDraft toValidationDraft() {
    return CulturalSnippetDraft(
      id: id,
      region: region,
      timeSlot: timeSlot.storageValue,
      locale: locale,
      type: type.storageValue,
      message: message,
      weight: weight,
      expressiveOnly: expressiveOnly,
    );
  }
}

extension CultureObservanceValidationDraftX on CultureObservance {
  CulturalSnippetDraft toValidationDraft({
    CultureTimeSlot defaultTimeSlot = CultureTimeSlot.morning,
  }) {
    return CulturalSnippetDraft(
      id: id,
      region: region,
      timeSlot: defaultTimeSlot.storageValue,
      locale: region,
      type: CultureSnippetType.observance.storageValue,
      message: message,
      weight: weight,
    );
  }
}

List<CulturalSnippetDraft> validationDraftsFromSnippets(
  Iterable<CulturalSnippet> snippets,
) {
  return snippets
      .map((snippet) => snippet.toValidationDraft())
      .toList(growable: false);
}

List<CulturalSnippetDraft> validationDraftsFromObservances(
  Iterable<CultureObservance> observances, {
  CultureTimeSlot defaultTimeSlot = CultureTimeSlot.morning,
}) {
  return observances
      .map(
        (observance) =>
            observance.toValidationDraft(defaultTimeSlot: defaultTimeSlot),
      )
      .toList(growable: false);
}
