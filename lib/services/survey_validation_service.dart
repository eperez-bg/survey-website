// survey_validation_service.dart
//
// Responsibility:
// Runs root-document checks plus the exact completion validator used by the
// current survey app. This keeps admin saves aligned with mobile placement,
// resize, outdoor canopy/no-install, zone, spigot, entrance, and distance rules.

import '../map_editor/utils/survey_completion_validator.dart';
import '../models/survey_document.dart';
import '../utils/map_editor_layout_adapter.dart';

class SurveyValidationService {
  const SurveyValidationService();

  List<String> validate(SurveyDocument survey) {
    final issues = <String>{};

    if (!survey.hasSupportedSchema) {
      issues.add(
        'This version uses schema ${survey.schemaVersion}; the admin supports '
        'schemas ${SurveyDocument.minimumSupportedSchemaVersion}-'
        '${SurveyDocument.currentSupportedSchemaVersion}.',
      );
    }
    if (survey.storeNumber == 'Unknown' || survey.storeNumber.trim().isEmpty) {
      issues.add('Store number is missing.');
    }

    try {
      final layout = MapEditorLayoutAdapter.fromDocument(survey);
      issues.addAll(
        SurveyCompletionValidator.validate(layout: layout).issues,
      );
    } on FormatException catch (error) {
      issues.add('Map JSON error: ${error.message}');
    } on ArgumentError catch (error) {
      issues.add('Map data error: ${error.message ?? error}');
    }

    return issues.toList(growable: false);
  }
}
