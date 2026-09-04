// table_pair_rules.dart
//
// Responsibility:
// Mirrors the field app's logical table-pair counting and selection rules.

import '../models/survey_map_model.dart';

class TablePairRules {
  static const int maxZoneWeightedTableCount = 18;

  const TablePairRules._();

  static List<LayoutTableModel> membersForTable(
    Iterable<LayoutTableModel> tables,
    String tableId,
  ) {
    LayoutTableModel? anchor;
    for (final table in tables) {
      if (table.tableId == tableId) {
        anchor = table;
        break;
      }
    }
    if (anchor == null) {
      return const [];
    }
    final pairId = anchor.pairId;
    if (pairId == null) {
      return [anchor];
    }
    return [for (final table in tables) if (table.pairId == pairId) table];
  }

  static Set<String> memberIdsForTable(
    Iterable<LayoutTableModel> tables,
    String tableId,
  ) => {
        for (final table in membersForTable(tables, tableId)) table.tableId,
      };

  static int logicalFixtureCount(Iterable<LayoutTableModel> tables) {
    final seen = <String>{};
    var count = 0;
    for (final table in tables) {
      if (seen.add(table.logicalKey)) {
        count += 1;
      }
    }
    return count;
  }

  static int weightedFixtureCount(Iterable<LayoutTableModel> tables) {
    final seen = <String>{};
    var count = 0;
    for (final table in tables) {
      if (seen.add(table.logicalKey)) {
        count += table.tableKind == TableKind.hangingBasket ? 2 : 1;
      }
    }
    return count;
  }

  static int weightedCountForZone(
    Iterable<LayoutTableModel> tables,
    String zoneId,
  ) => weightedFixtureCount(
        tables.where(
          (table) =>
              table.zoneId == zoneId && table.tableKind != TableKind.custom,
        ),
      );
}
