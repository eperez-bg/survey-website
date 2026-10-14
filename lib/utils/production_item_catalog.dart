// production_item_catalog.dart
//
// Responsibility:
// Owns the ordered production-item catalog used by Excel exports. The order,
// item numbers, and descriptions mirror the supplied comparison workbook.

import '../models/production_item_definition.dart';

class ProductionItemCatalog {
  const ProductionItemCatalog._();

  static const items = <ProductionItemDefinition>[
    ProductionItemDefinition(
      itemNumber: '89225-200',
      description: '(New) Reverse Sprinkler System (Red Sprinkler)',
      sourceFormula: '1 per single table under Canopy',
      quantityRule: ProductionItemQuantityRule.singleTablesUnderCanopy,
    ),
    ProductionItemDefinition(
      itemNumber: '89225-700',
      description: '(NEW) Folding Tower Concept w/Adjustable Towers',
      sourceFormula: '1 per Single table outside of Canopy',
      quantityRule: ProductionItemQuantityRule.singleTablesOutsideCanopy,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-015-20',
      description: '20" Towers + Post mount trough (sprinkler bridge)',
      sourceFormula: '1 per Hanging basket (both in and outside of canopy)',
      quantityRule: ProductionItemQuantityRule.allHangingBaskets,
    ),
    // The source workbook merges this description across 88177-015-20 and
    // 88177-015P. Repeat it so each exported item column has both header rows.
    ProductionItemDefinition(
      itemNumber: '88177-015P',
      description: '20" Towers + Post mount trough (sprinkler bridge)',
      sourceFormula: '1 per Hanging basket (both in and outside of canopy)',
      quantityRule: ProductionItemQuantityRule.allHangingBaskets,
    ),
    ProductionItemDefinition(
      itemNumber: 'Poly Tube (700FT ROLL)',
      description: 'Poly Tube (700FT ROLL)',
      sourceFormula: '15ft per table',
      quantityRule: ProductionItemQuantityRule.polyTubeRolls,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-010-200',
      description: '3/4 Garden Hose (200FT Roll)',
      sourceFormula: '37ft per zone, plus 74ft (two additional zones)',
      quantityRule: ProductionItemQuantityRule.gardenHoseRolls,
    ),
    ProductionItemDefinition(
      itemNumber: '2706N8, 2706N24, 5388K24',
      description: 'Garden Hose End Fittings',
      sourceFormula: 'Counted 1 per zone',
      quantityRule: ProductionItemQuantityRule.zoneCount,
    ),
    ProductionItemDefinition(
      itemNumber: '7459T21',
      description: 'Brass Wye-Shaped On-Off Valve',
      sourceFormula: 'Counted 1 per spigot',
      quantityRule: ProductionItemQuantityRule.spigotCount,
    ),
    ProductionItemDefinition(
      itemNumber: 'Pressure Regulator',
      description: 'Pressure Regulator',
      sourceFormula: 'Counted 1 per zone under canopy?',
      quantityRule: ProductionItemQuantityRule.zonesUnderCanopy,
    ),
    ProductionItemDefinition(
      itemNumber: '1-Port Timer Assembly (with timer)',
      description: '1-Port Zone Control Assembly (With Timer)',
      sourceFormula: 'Counted 1 per Zone',
      quantityRule: ProductionItemQuantityRule.zoneCount,
    ),
    ProductionItemDefinition(
      itemNumber: 'brass nozzle for poly',
      description: 'Brass fitting for Poly Tube',
      sourceFormula: 'Counted 1 per Timer or 1 per zone',
      quantityRule: ProductionItemQuantityRule.zoneCount,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-SHUT-OFFVALVE',
      description: 'Shut-off Valve',
      sourceFormula: 'Counted 2 per Grouped table',
      quantityRule: ProductionItemQuantityRule.twiceTableGroupCount,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-S-CONNECTOR',
      description: 'Straight connector',
      sourceFormula: 'Counted 1 per folding tower bridge (89225-700)',
      quantityRule: ProductionItemQuantityRule.singleTablesOutsideCanopy,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-L-CONNECTOR',
      description: 'L-connector for Poly',
      sourceFormula: '4 per Grouped table',
      quantityRule: ProductionItemQuantityRule.fourTimesTableGroupCount,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-T-CONNECTOR',
      description: 'T-connector for Poly',
      sourceFormula: '1 per Grouped table AND 1 per hanging basket',
      quantityRule:
          ProductionItemQuantityRule.tableGroupsPlusHangingBaskets,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-GRAYPOLY',
      description: 'GRAY POLY TUBE PLUG WITH DRAIN',
      sourceFormula: '1 per Grouped table AND 1 per hanging basket',
      quantityRule:
          ProductionItemQuantityRule.tableGroupsPlusHangingBaskets,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-CUTTER',
      description: 'Cutter',
      sourceFormula: null,
      quantityRule: ProductionItemQuantityRule.noFormula,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-ZIPTIE',
      description: 'Zip Ties (Bag of 100)',
      sourceFormula: '7 per table',
      quantityRule: ProductionItemQuantityRule.zipTieBags,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-610',
      description: 'Ramp',
      sourceFormula: 'From Data',
      quantityRule: ProductionItemQuantityRule.rampCount,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-CBALETIE',
      description: 'Color Zip Ties',
      sourceFormula: '1 Set per store',
      quantityRule: ProductionItemQuantityRule.onePerStore,
    ),
    // The supplied comparison workbook does not provide an item number.
    ProductionItemDefinition(
      itemNumber: '',
      description: 'Cautious Flag Pole',
      sourceFormula: '1 per group of ramps (counts of distances)',
      quantityRule: ProductionItemQuantityRule.rampSectionsCount,
    ),
    ProductionItemDefinition(
      itemNumber: '88177-REPLCAMENTKIT',
      description: '88177 REPLACEMENT KIT',
      sourceFormula: '1 per Store',
      quantityRule: ProductionItemQuantityRule.onePerStore,
    ),
  ];
}
