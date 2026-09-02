// survey_validation_service.dart
// Minimal admin-side validation before an edited version is uploaded.

import '../models/survey_document.dart';

class SurveyValidationService {
  const SurveyValidationService();

  List<String> validate(SurveyDocument survey) {
    final issues = <String>[];
    if (survey.storeNumber.trim().isEmpty) issues.add('Store number is missing.');
    if (survey.layout.isEmpty) issues.add('gardenCenterLayout is missing.');
    if (survey.canvasRows <= 0 || survey.canvasColumns <= 0) {
      issues.add('Canvas dimensions must be positive.');
    }
    return issues;
  }
}
