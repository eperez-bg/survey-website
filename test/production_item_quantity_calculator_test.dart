import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/production_metrics.dart';
import 'package:survey_admin_web/utils/production_item_catalog.dart';
import 'package:survey_admin_web/utils/production_item_quantity_calculator.dart';

void main() {
  const calculator = ProductionItemQuantityCalculator();

  test('calculates all item quantities in catalog order', () {
    const metrics = ProductionMetrics(
      singleTablesUnderCanopy: 24,
      hangingBasketsUnderCanopy: 2,
      specialTablesUnderCanopy: 4,
      singleTablesOutsideCanopy: 21,
      hangingBasketsOutsideCanopy: 0,
      specialTablesOutsideCanopy: 3,
      spigotCount: 6,
      averagePsi: 52,
      rampSectionsCount: 3,
      rampCountAt46Inches: 4,
      tableGroupCount: 23,
      zoneCount: 9,
      zonesUnderCanopy: 6,
      maxCanopyHeightInches: 120,
    );

    final quantities = [
      for (final item in ProductionItemCatalog.items)
        calculator.calculate(item, metrics),
    ];

    expect(
      quantities,
      orderedEquals(<int?>[
        24, // Reverse sprinkler: one per single table under canopy.
        21, // Folding tower: one per single table outside canopy.
        2, // Hanging-basket tower item 1.
        2, // Hanging-basket tower item 2.
        2, // ceil(47 tables * 15 ft / 700-ft roll).
        4, // ceil(9 zones * 37 ft / 200-ft roll) plus 2 extra.
        9, // Garden-hose fittings: one per zone.
        6, // Wye valve: one per spigot.
        6, // Pressure regulator: one per zone under canopy.
        9, // Timer: one per zone.
        9, // Brass poly fitting: one per timer/zone.
        46, // Shut-off valves: two per table group.
        21, // Straight connector: one per folding tower.
        92, // L-connectors: four per table group.
        25, // T-connectors: groups plus hanging baskets.
        25, // Gray plugs: groups plus hanging baskets.
        null, // The comparison workbook provides no cutter formula.
        4, // ceil(47 tables * 7 ties / 100-count bag).
        4, // Ramp quantity from the 46-inch ramp calculation.
        1, // One color-zip-tie set per store.
        3, // One cautious flag pole per saved distance.
        1, // One replacement kit per store.
      ]),
    );
  });

  test('package quantities round up and apply fixed per-store extras', () {
    const metrics = ProductionMetrics(
      singleTablesUnderCanopy: 0,
      hangingBasketsUnderCanopy: 0,
      specialTablesUnderCanopy: 0,
      singleTablesOutsideCanopy: 0,
      hangingBasketsOutsideCanopy: 0,
      specialTablesOutsideCanopy: 0,
      spigotCount: 0,
      averagePsi: null,
      rampSectionsCount: 0,
      rampCountAt46Inches: 0,
      tableGroupCount: 0,
      zoneCount: 0,
      zonesUnderCanopy: 0,
      maxCanopyHeightInches: 0,
    );

    expect(calculator.calculate(ProductionItemCatalog.items[4], metrics), 0);
    expect(calculator.calculate(ProductionItemCatalog.items[5], metrics), 2);
    expect(calculator.calculate(ProductionItemCatalog.items[17], metrics), 0);
    expect(calculator.calculate(ProductionItemCatalog.items[19], metrics), 1);
    expect(calculator.calculate(ProductionItemCatalog.items[21], metrics), 1);
  });
}
