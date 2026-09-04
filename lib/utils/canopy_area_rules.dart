// canopy_area_rules.dart
//
// Responsibility:
// Reassembles cell-based canopy JSON into contiguous measured canopy areas for
// summaries and labels. The persisted data remains unchanged.

import '../models/survey_map_model.dart';

class CanopyArea {
  final List<CanopyCellModel> cells;
  final int topRow;
  final int leftColumn;
  final int bottomRowExclusive;
  final int rightColumnExclusive;
  final double? heightInches;
  final double? lengthInches;
  final double? widthInches;

  const CanopyArea({
    required this.cells,
    required this.topRow,
    required this.leftColumn,
    required this.bottomRowExclusive,
    required this.rightColumnExclusive,
    required this.heightInches,
    required this.lengthInches,
    required this.widthInches,
  });
}

class CanopyAreaRules {
  const CanopyAreaRules._();

  static List<CanopyArea> group(Iterable<CanopyCellModel> source) {
    final remaining = <String, CanopyCellModel>{
      for (final cell in source) '${cell.row}:${cell.column}': cell,
    };
    final areas = <CanopyArea>[];

    while (remaining.isNotEmpty) {
      final seed = remaining.values.first;
      final queue = <CanopyCellModel>[seed];
      final cells = <CanopyCellModel>[];
      remaining.remove('${seed.row}:${seed.column}');

      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        cells.add(cell);
        for (final neighbor in <(int, int)>[
          (cell.row - 1, cell.column),
          (cell.row + 1, cell.column),
          (cell.row, cell.column - 1),
          (cell.row, cell.column + 1),
        ]) {
          final key = '${neighbor.$1}:${neighbor.$2}';
          final candidate = remaining[key];
          if (candidate != null &&
              candidate.measurementKey == seed.measurementKey) {
            remaining.remove(key);
            queue.add(candidate);
          }
        }
      }

      var minRow = cells.first.row;
      var maxRow = cells.first.row;
      var minColumn = cells.first.column;
      var maxColumn = cells.first.column;
      for (final cell in cells.skip(1)) {
        if (cell.row < minRow) minRow = cell.row;
        if (cell.row > maxRow) maxRow = cell.row;
        if (cell.column < minColumn) minColumn = cell.column;
        if (cell.column > maxColumn) maxColumn = cell.column;
      }
      areas.add(
        CanopyArea(
          cells: List.unmodifiable(cells),
          topRow: minRow,
          leftColumn: minColumn,
          bottomRowExclusive: maxRow + 1,
          rightColumnExclusive: maxColumn + 1,
          heightInches: seed.heightInches,
          lengthInches: seed.lengthInches,
          widthInches: seed.widthInches,
        ),
      );
    }

    return areas;
  }
}
