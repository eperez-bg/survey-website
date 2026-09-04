// production_calculation.dart
//
// Responsibility:
// Carries derived production/index values separately from persisted survey JSON.

import 'survey_document.dart';

class ProductionCalculation {
  final int irrigationSystems;
  final int logicalTableFixtures;
  final int weightedTableCount;
  final int normalTableCount;
  final int hangingBasketCount;
  final int customTableCount;
  final int physicalTableObjects;
  final int spigotCount;
  final int distanceCount;
  final double totalDistanceInches;
  final double threeFootSections;
  final int entranceCount;
  final int canopyAreaCount;
  final int canopyCellCount;

  const ProductionCalculation({
    required this.irrigationSystems,
    required this.logicalTableFixtures,
    required this.weightedTableCount,
    required this.normalTableCount,
    required this.hangingBasketCount,
    required this.customTableCount,
    required this.physicalTableObjects,
    required this.spigotCount,
    required this.distanceCount,
    required this.totalDistanceInches,
    required this.threeFootSections,
    required this.entranceCount,
    required this.canopyAreaCount,
    required this.canopyCellCount,
  });

  Map<String, dynamic> toJson() => {
        'irrigationSystems': irrigationSystems,
        'logicalTableFixtures': logicalTableFixtures,
        'weightedTableCount': weightedTableCount,
        'normalTableCount': normalTableCount,
        'hangingBasketCount': hangingBasketCount,
        'customTableCount': customTableCount,
        'physicalTableObjects': physicalTableObjects,
        'spigotCount': spigotCount,
        'distanceCount': distanceCount,
        'totalDistanceInches': totalDistanceInches,
        'threeFootSections': threeFootSections,
        'entranceCount': entranceCount,
        'canopyAreaCount': canopyAreaCount,
        'canopyCellCount': canopyCellCount,
      };
}

class SurveyExportBundle {
  final String objectPath;
  final SurveyDocument survey;
  final ProductionCalculation calculation;

  const SurveyExportBundle({
    required this.objectPath,
    required this.survey,
    required this.calculation,
  });
}
