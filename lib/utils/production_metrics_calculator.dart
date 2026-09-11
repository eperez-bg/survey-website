// production_metrics_calculator.dart
//
// Responsibility:
// Calculates production metrics from a parsed survey without depending on UI,
// Supabase, PDF, or XLSX packages.

import '../models/production_metrics.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart';

class ProductionMetricsCalculator {
  final double rampUnitInches;

  const ProductionMetricsCalculator({this.rampUnitInches = 46})
      : assert(rampUnitInches > 0);

  ProductionMetrics calculate(SurveyDocument survey) {
    final map = survey.mapData;
    final canopyCoordinates = {
      for (final cell in map.canopyCells)
        GridCoordinate(row: cell.row, column: cell.column),
    };
    final logicalTables = <String, List<LayoutTableModel>>{};

    for (final table in map.tables) {
      logicalTables
          .putIfAbsent(table.logicalKey, () => <LayoutTableModel>[])
          .add(table);
    }

    var singleUnder = 0;
    var hangingUnder = 0;
    var specialUnder = 0;
    var singleOutside = 0;
    var hangingOutside = 0;
    var specialOutside = 0;

    for (final members in logicalTables.values) {
      final kind = members.first.tableKind;
      final isUnderCanopy = members.any(
        (table) => _tableOverlapsCanopy(table, canopyCoordinates),
      );

      switch (kind) {
        case TableKind.normal:
          if (isUnderCanopy) {
            singleUnder += 1;
          } else {
            singleOutside += 1;
          }
        case TableKind.hangingBasket:
          // One hanging-basket pair contributes two production tables.
          if (isUnderCanopy) {
            hangingUnder += 2;
          } else {
            hangingOutside += 2;
          }
        case TableKind.custom:
          if (isUnderCanopy) {
            specialUnder += 1;
          } else {
            specialOutside += 1;
          }
      }
    }

    final pressureValues = <double>[
      for (final spigot in map.spigots)
        if (spigot.pressurePsi != null) spigot.pressurePsi!,
    ];
    final averagePsi = pressureValues.isEmpty
        ? null
        : pressureValues.fold<double>(0, (total, value) => total + value) /
            pressureValues.length;

    double? maxCanopyHeight;
    for (final canopyCell in map.canopyCells) {
      final height = canopyCell.heightInches;
      if (height != null &&
          (maxCanopyHeight == null || height > maxCanopyHeight)) {
        maxCanopyHeight = height;
      }
    }

    final rampCount = map.distances.fold<double>(
      0,
      (total, distance) =>
          total + (distance.measuredDistance / rampUnitInches),
    );

    return ProductionMetrics(
      singleTablesUnderCanopy: singleUnder,
      hangingBasketsUnderCanopy: hangingUnder,
      specialTablesUnderCanopy: specialUnder,
      singleTablesOutsideCanopy: singleOutside,
      hangingBasketsOutsideCanopy: hangingOutside,
      specialTablesOutsideCanopy: specialOutside,
      spigotCount: map.spigots.length,
      averagePsi: averagePsi,
      rampCountAt46Inches: rampCount,
      zoneCount: map.zones.length,
      maxCanopyHeightInches: maxCanopyHeight,
    );
  }

  bool _tableOverlapsCanopy(
    LayoutTableModel table,
    Set<GridCoordinate> canopyCoordinates,
  ) {
    for (var row = table.topRow; row < table.bottomRowExclusive; row += 1) {
      for (
        var column = table.leftColumn;
        column < table.rightColumnExclusive;
        column += 1
      ) {
        if (canopyCoordinates.contains(
          GridCoordinate(row: row, column: column),
        )) {
          return true;
        }
      }
    }
    return false;
  }
}
