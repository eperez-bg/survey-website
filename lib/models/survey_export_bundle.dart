// survey_export_bundle.dart
//
// Responsibility:
// Carries one parsed survey, its storage source, and its already-calculated
// production metrics through PDF and spreadsheet export workflows.

import 'production_metrics.dart';
import 'survey_document.dart';

class SurveyExportBundle {
  final String objectPath;
  final SurveyDocument survey;
  final ProductionMetrics metrics;

  const SurveyExportBundle({
    required this.objectPath,
    required this.survey,
    required this.metrics,
  });
}
