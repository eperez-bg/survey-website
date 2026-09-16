// table_group_calculator.dart
//
// Responsibility:
// Counts connected groups of non-custom physical table footprints. Tables join
// a group when their rectangles share a positive-length edge; corner contact
// alone does not connect them, and custom tables are ignored.

import '../models/survey_map_model.dart';

class TableGroupCalculator {
  const TableGroupCalculator();

  /// Returns the number of maximal edge-connected non-custom table groups.
  int countGroups(Iterable<LayoutTableModel> tables) {
    final productionTables = [
      for (final table in tables)
        if (table.tableKind != TableKind.custom) table,
    ];
    final visited = List<bool>.filled(productionTables.length, false);
    var groupCount = 0;

    // Survey maps contain relatively few tables, so an explicit graph walk is
    // clearer here than expanding every table into its occupied grid cells.
    for (
      var startIndex = 0;
      startIndex < productionTables.length;
      startIndex += 1
    ) {
      if (visited[startIndex]) continue;

      groupCount += 1;
      visited[startIndex] = true;
      final pending = <int>[startIndex];

      while (pending.isNotEmpty) {
        final currentIndex = pending.removeLast();
        final current = productionTables[currentIndex];

        for (
          var candidateIndex = 0;
          candidateIndex < productionTables.length;
          candidateIndex += 1
        ) {
          if (visited[candidateIndex] ||
              !_sharesEdge(current, productionTables[candidateIndex])) {
            continue;
          }

          visited[candidateIndex] = true;
          pending.add(candidateIndex);
        }
      }
    }

    return groupCount;
  }

  bool _sharesEdge(LayoutTableModel first, LayoutTableModel second) {
    final rowsOverlap =
        first.topRow < second.bottomRowExclusive &&
        first.bottomRowExclusive > second.topRow;
    final columnsOverlap =
        first.leftColumn < second.rightColumnExclusive &&
        first.rightColumnExclusive > second.leftColumn;
    final verticalEdgesTouch =
        first.rightColumnExclusive == second.leftColumn ||
        second.rightColumnExclusive == first.leftColumn;
    final horizontalEdgesTouch =
        first.bottomRowExclusive == second.topRow ||
        second.bottomRowExclusive == first.topRow;

    return (verticalEdgesTouch && rowsOverlap) ||
        (horizontalEdgesTouch && columnsOverlap);
  }
}
