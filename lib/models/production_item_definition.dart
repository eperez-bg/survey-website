// production_item_definition.dart
//
// Responsibility:
// Represents one produced item column in the Excel export. The item number and
// description are separate because the workbook displays them in two header
// rows. The quantity rule keeps the supplied production formula attached to
// the item without putting calculation logic in the Excel service.

enum ProductionItemQuantityRule {
  singleTablesUnderCanopy,
  singleTablesOutsideCanopy,
  allHangingBaskets,
  polyTubeRolls,
  gardenHoseRolls,
  zoneCount,
  spigotCount,
  zonesUnderCanopy,
  twiceTableGroupCount,
  fourTimesTableGroupCount,
  tableGroupsPlusHangingBaskets,
  noFormula,
  zipTieBags,
  rampCount,
  onePerStore,
  rampSectionsCount,
}

class ProductionItemDefinition {
  final String itemNumber;
  final String description;
  final String? sourceFormula;
  final ProductionItemQuantityRule quantityRule;

  const ProductionItemDefinition({
    required this.itemNumber,
    required this.description,
    required this.sourceFormula,
    required this.quantityRule,
  });
}
