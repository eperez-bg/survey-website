// production_calculation_service.dart
// Single place for work-in-progress production formulas.

import '../models/production_calculation.dart';
import '../models/survey_document.dart';
import '../utils/json_helpers.dart';

class ProductionCalculationService {
  const ProductionCalculationService();

  ProductionCalculation calculate(SurveyDocument survey) {
    final irrigationSystems = survey.zones.length;

    double totalDistance = 0;
    for (final ramp in survey.ramps) {
      totalDistance += JsonHelpers.decimal(
        JsonHelpers.first(ramp, ['measuredGap', 'distance', 'length']),
      );
    }

    // Temporary formula requested for the MVP: divide each distance by 36
    // (equivalent to dividing the sum by 36) and add the results.
    final ramps = totalDistance / 36.0;

    return ProductionCalculation(
      irrigationSystems: irrigationSystems,
      ramps: ramps,
      totalRampDistance: totalDistance,
    );
  }
}
