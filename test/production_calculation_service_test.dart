import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/services/production_calculation_service.dart';

void main() {
  test('production calculations understand pairs and schema-9 distances', () {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );

    final result = const ProductionCalculationService().calculate(survey);

    expect(result.irrigationSystems, 2);
    expect(result.logicalTableFixtures, 3);
    expect(result.weightedTableCount, 3);
    expect(result.normalTableCount, 1);
    expect(result.hangingBasketCount, 2);
    expect(result.customTableCount, 1);
    expect(result.physicalTableObjects, 5);
    expect(result.distanceCount, 2);
    expect(result.totalDistanceInches, 276);
    expect(result.threeFootSections, closeTo(7.6667, 0.001));
    expect(result.spigotCount, 2);
    expect(result.entranceCount, 1);
    expect(result.canopyAreaCount, 1);
    expect(result.canopyCellCount, 8);
  });
}
