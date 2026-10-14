// production_item_quantity_calculator.dart
//
// Responsibility:
// Converts already-derived production metrics into the 22 item quantities
// specified by the comparison workbook. It is pure domain logic and does not
// know how an XLSX file is laid out or downloaded.

import '../models/production_item_definition.dart';
import '../models/production_metrics.dart';

class ProductionItemQuantityCalculator {
  const ProductionItemQuantityCalculator();

  static const int _polyTubeFeetPerTable = 15;
  static const int _polyTubeFeetPerRoll = 700;
  static const int _gardenHoseFeetPerZone = 37;
  static const int _gardenHoseFeetPerRoll = 200;
  static const int _gardenHoseExtraFeet = 74;
  static const int _zipTiesPerTable = 7;
  static const int _zipTiesPerBag = 100;

  /// Returns the number of sellable items needed for one production item.
  ///
  /// Rolls and bags are whole items, so their usage is divided by the package
  /// size and rounded up. The 74-foot garden-hose allowance is added before
  /// package rounding. A null result deliberately leaves the Excel cell blank
  /// when the source workbook did not provide a formula.
  int? calculate(
    ProductionItemDefinition item,
    ProductionMetrics metrics,
  ) {
    return switch (item.quantityRule) {
      ProductionItemQuantityRule.singleTablesUnderCanopy =>
        metrics.singleTablesUnderCanopy,
      ProductionItemQuantityRule.singleTablesOutsideCanopy =>
        metrics.singleTablesOutsideCanopy,
      ProductionItemQuantityRule.allHangingBaskets =>
        metrics.hangingBasketCount,
      ProductionItemQuantityRule.polyTubeRolls => _wholePackages(
        units: metrics.tableCount,
        usagePerUnit: _polyTubeFeetPerTable,
        packageSize: _polyTubeFeetPerRoll,
      ),
      ProductionItemQuantityRule.gardenHoseRolls => _wholePackages(
        units: metrics.zoneCount,
        usagePerUnit: _gardenHoseFeetPerZone,
        packageSize: _gardenHoseFeetPerRoll,
        additionalUsage: _gardenHoseExtraFeet,
      ),
      ProductionItemQuantityRule.zoneCount => metrics.zoneCount,
      ProductionItemQuantityRule.spigotCount => metrics.spigotCount,
      ProductionItemQuantityRule.zonesUnderCanopy =>
        metrics.zonesUnderCanopy,
      ProductionItemQuantityRule.twiceTableGroupCount =>
        metrics.tableGroupCount * 2,
      ProductionItemQuantityRule.fourTimesTableGroupCount =>
        metrics.tableGroupCount * 4,
      ProductionItemQuantityRule.tableGroupsPlusHangingBaskets =>
        metrics.tableGroupCount + metrics.hangingBasketCount,
      ProductionItemQuantityRule.noFormula => null,
      ProductionItemQuantityRule.zipTieBags => _wholePackages(
        units: metrics.tableCount,
        usagePerUnit: _zipTiesPerTable,
        packageSize: _zipTiesPerBag,
      ),
      ProductionItemQuantityRule.rampCount => metrics.rampCountAt46Inches,
      ProductionItemQuantityRule.onePerStore => 1,
      ProductionItemQuantityRule.rampSectionsCount =>
        metrics.rampSectionsCount,
    };
  }

  int _wholePackages({
    required int units,
    required int usagePerUnit,
    required int packageSize,
    int additionalUsage = 0,
  }) {
    final requiredAmount = units * usagePerUnit + additionalUsage;
    if (requiredAmount == 0) return 0;
    return (requiredAmount + packageSize - 1) ~/ packageSize;
  }
}
