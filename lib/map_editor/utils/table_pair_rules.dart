// table_pair_rules.dart
//
// Responsibility:
// Centralizes the logical-pair behavior for map tables. The map still stores
// two physical LayoutTable rectangles so collision/distance geometry stays simple,
// while this utility answers which rectangles belong together and how one
// palette drop should be laid out.
//
// Main API:
// - createAdjacentPair: builds the two physical rectangles for one new pair.
// - footprintWidthCells / footprintHeightCells: reports the pair preview size.
// - membersForTable / memberIdsForTable: resolves a tapped table to its pair.
// - logicalFixtureCount: counts one logical fixture per pair.
// - weightedFixtureCount: counts normal pairs as 1 and hanging pairs as 2.
// - weightedCountForKind: powers the summary chips with pair-aware counts.

import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

class TablePairRules {
  const TablePairRules._();

  /// Creates two physical tables connected along their long sides.
  ///
  /// Horizontal tables stack vertically (3x4 total cells), while vertical
  /// tables sit side by side (4x3 total cells).
  static List<LayoutTable> createAdjacentPair({
    required String firstTableId,
    required String secondTableId,
    required String pairId,
    required int topRow,
    required int leftColumn,
    required TableKind tableKind,
    required TableOrientation orientation,
    String? zoneId,
  }) {
    if (tableKind == TableKind.custom) {
      throw ArgumentError('Custom tables are independent fixtures, not pairs.');
    }
    final first = LayoutTable(
      tableId: firstTableId,
      zoneId: zoneId,
      pairId: pairId,
      topRow: topRow,
      leftColumn: leftColumn,
      tableKind: tableKind,
      orientation: orientation,
    );

    final second = LayoutTable(
      tableId: secondTableId,
      zoneId: zoneId,
      pairId: pairId,
      topRow: orientation == TableOrientation.horizontal
          ? topRow + first.heightCells
          : topRow,
      leftColumn: orientation == TableOrientation.horizontal
          ? leftColumn
          : leftColumn + first.widthCells,
      tableKind: tableKind,
      orientation: orientation,
    );

    return [first, second];
  }

  /// Width of a newly placed pair's complete grid footprint.
  static int footprintWidthCells(TableOrientation orientation) =>
      orientation == TableOrientation.horizontal ? 3 : 4;

  /// Height of a newly placed pair's complete grid footprint.
  static int footprintHeightCells(TableOrientation orientation) =>
      orientation == TableOrientation.horizontal ? 4 : 3;

  /// Returns the complete logical selection unit containing [tableId].
  ///
  /// Legacy tables with no pairId intentionally resolve only to themselves.
  static List<LayoutTable> membersForTable(
    Iterable<LayoutTable> tables,
    String tableId,
  ) {
    LayoutTable? anchor;
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

  /// Returns only the persisted IDs for [membersForTable].
  static Set<String> memberIdsForTable(
    Iterable<LayoutTable> tables,
    String tableId,
  ) => {
    for (final table in membersForTable(tables, tableId)) table.tableId,
  };

  /// Counts physical rows as logical fixtures by de-duplicating shared pairIds.
  ///
  /// A new two-table pair counts as 1. Each legacy unpaired table also counts
  /// as 1 so old surveys retain their previous meaning.
  static int logicalFixtureCount(Iterable<LayoutTable> tables) {
    final seenKeys = <String>{};
    var count = 0;

    for (final table in tables) {
      if (seenKeys.add(_logicalKey(table))) {
        count += 1;
      }
    }

    return count;
  }

  /// Applies production counting once per logical pair.
  ///
  /// Normal pairs contribute 1. Hanging-basket pairs contribute 2.
  static int weightedFixtureCount(Iterable<LayoutTable> tables) {
    final seenKeys = <String>{};
    var total = 0;

    for (final table in tables) {
      if (seenKeys.add(_logicalKey(table))) {
        total += table.tableKind == TableKind.hangingBasket ? 2 : 1;
      }
    }

    return total;
  }

  /// Returns the pair-aware weighted count for one fixture kind.
  ///
  /// This means the normal summary displays one per normal pair, while the
  /// hanging summary displays two per hanging-basket pair.
  static int weightedCountForKind(
    Iterable<LayoutTable> tables,
    TableKind tableKind,
  ) => weightedFixtureCount(
    tables.where((table) => table.tableKind == tableKind),
  );

  /// Produces a stable de-duplication key without confusing legacy table IDs
  /// with real pair IDs that happen to contain similar text.
  static String _logicalKey(LayoutTable table) => table.pairId == null
      ? 'legacy-table:${table.tableId}'
      : 'table-pair:${table.pairId}';
}
