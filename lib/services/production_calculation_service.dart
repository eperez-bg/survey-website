// production_calculation_service.dart
//
// Responsibility:
// Contains derived manufacturing counts. Pair-aware table math mirrors the
// field app; the 36-inch section calculation remains an isolated placeholder.

import '../models/production_calculation.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../utils/canopy_area_rules.dart';
import '../utils/table_pair_rules.dart';

class ProductionCalculationService {
  final double distanceSectionInches;

  const ProductionCalculationService({this.distanceSectionInches = 36});

  ProductionCalculation calculate(SurveyDocument survey) {
    final map = survey.mapData;
    final normal = map.tables.where((item) => item.tableKind == TableKind.normal);
    final hanging =
        map.tables.where((item) => item.tableKind == TableKind.hangingBasket);
    final custom = map.tables.where((item) => item.tableKind == TableKind.custom);
    final totalDistance = map.distances.fold<double>(
      0,
      (total, item) => total + item.measuredDistance,
    );

    return ProductionCalculation(
      irrigationSystems: map.zones.length,
      logicalTableFixtures: TablePairRules.logicalFixtureCount(map.tables),
      weightedTableCount: TablePairRules.weightedFixtureCount(
        map.tables.where((item) => item.tableKind != TableKind.custom),
      ),
      normalTableCount: TablePairRules.weightedFixtureCount(normal),
      hangingBasketCount: TablePairRules.weightedFixtureCount(hanging),
      customTableCount: custom.length,
      physicalTableObjects: map.tables.length,
      spigotCount: map.spigots.length,
      distanceCount: map.distances.length,
      totalDistanceInches: totalDistance,
      threeFootSections: totalDistance / distanceSectionInches,
      entranceCount: map.entrances.length,
      canopyAreaCount: CanopyAreaRules.group(map.canopyCells).length,
      canopyCellCount: map.canopyCells.length,
    );
  }
}
