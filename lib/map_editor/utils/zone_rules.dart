// zone_rules.dart
//
// Responsibility:
// Defines the production-capacity rules used when assigning table pairs to
// zones. Capacity is based on logical pairs rather than physical rectangles:
// one normal pair counts as 1 table and one hanging-basket pair counts as 2.
// Custom tables are deliberately excluded from zones and zone counts.
//
// Main API:
// - maxWeightedTableCount: maximum production count allowed in one zone.
// - tableWeight: production weight of one logical fixture kind.
// - weightedTableCount: pair-aware production count for a set of tables.
// - fixtureCount: pair-aware number of logical fixtures.

import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'table_pair_rules.dart';

class ZoneRules {
  static const int maxWeightedTableCount = 18;

  const ZoneRules._();

  static bool canAssignToZone(LayoutTable table) =>
      table.tableKind != TableKind.custom;

  /// Returns the production weight for one logical fixture/pair.
  static int tableWeight(LayoutTable table) {
    if (!canAssignToZone(table)) {
      return 0;
    }
    return table.tableKind == TableKind.hangingBasket ? 2 : 1;
  }

  /// Counts normal pairs once and hanging-basket pairs twice.
  static int weightedTableCount(Iterable<LayoutTable> tables) =>
      TablePairRules.weightedFixtureCount(tables.where(canAssignToZone));

  /// Counts each logical pair once regardless of fixture kind.
  static int fixtureCount(Iterable<LayoutTable> tables) =>
      TablePairRules.logicalFixtureCount(tables.where(canAssignToZone));
}
