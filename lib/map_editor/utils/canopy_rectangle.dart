import 'grid_geometry.dart';

class CanopyRectangleResult {
  final List<GridCoordinate> cells;
  final GridCoordinate? inferredCorner;
  final String? error;

  CanopyRectangleResult._({
    List<GridCoordinate> cells = const [],
    this.inferredCorner,
    this.error,
  }) : cells = List.unmodifiable(cells);

  CanopyRectangleResult.success(
    List<GridCoordinate> cells, {
    required GridCoordinate inferredCorner,
  }) : this._(cells: cells, inferredCorner: inferredCorner);

  CanopyRectangleResult.failure(String error) : this._(error: error);

  bool get succeeded => error == null;
}

/// Pure validation and expansion for a three-corner canopy selection.
class CanopyRectangle {
  const CanopyRectangle._();

  /// Returns the cells that can legally be selected as the next corner.
  ///
  /// After two corners have been chosen this narrows the canvas to only the
  /// cells that can complete a three-corner rectangle. The method also handles
  /// the first two selections so the controller can use one rule for every
  /// canopy tap.
  static Set<GridCoordinate> validNextCorners({
    required Iterable<GridCoordinate> selectedCorners,
    required int minRow,
    required int maxRow,
    required int minColumn,
    required int maxColumn,
  }) {
    final selected = selectedCorners.toSet().toList();
    if (selected.length >= 3 ||
        minRow > maxRow ||
        minColumn > maxColumn) {
      return const {};
    }

    bool isInside(GridCoordinate coordinate) {
      return coordinate.row >= minRow &&
          coordinate.row <= maxRow &&
          coordinate.column >= minColumn &&
          coordinate.column <= maxColumn;
    }

    if (selected.length < 2) {
      return {
        for (var row = minRow; row <= maxRow; row += 1)
          for (var column = minColumn; column <= maxColumn; column += 1)
            GridCoordinate(row: row, column: column),
      }..removeAll(selected);
    }

    final first = selected[0];
    final second = selected[1];
    final candidates = <GridCoordinate>{};

    if (first.row == second.row) {
      for (var row = minRow; row <= maxRow; row += 1) {
        if (row == first.row) {
          continue;
        }
        candidates
          ..add(GridCoordinate(row: row, column: first.column))
          ..add(GridCoordinate(row: row, column: second.column));
      }
    } else if (first.column == second.column) {
      for (var column = minColumn; column <= maxColumn; column += 1) {
        if (column == first.column) {
          continue;
        }
        candidates
          ..add(GridCoordinate(row: first.row, column: column))
          ..add(GridCoordinate(row: second.row, column: column));
      }
    } else {
      candidates
        ..add(GridCoordinate(row: first.row, column: second.column))
        ..add(GridCoordinate(row: second.row, column: first.column));
    }

    return candidates.where(isInside).toSet()..removeAll(selected);
  }

  /// Returns every cell in the inclusive rectangle represented by [corners].
  ///
  /// Corner order does not matter. Three valid corners use exactly two rows
  /// and two columns; the one missing row/column combination is inferred.
  static CanopyRectangleResult fromCorners(Iterable<GridCoordinate> corners) {
    final cornerList = corners.toList();
    if (cornerList.length != 3) {
      return CanopyRectangleResult.failure(
        'Place exactly three canopy corners.',
      );
    }

    final uniqueCorners = cornerList.toSet();
    if (uniqueCorners.length != 3) {
      return CanopyRectangleResult.failure(
        'Each canopy corner must be placed on a different cell.',
      );
    }

    final rows = uniqueCorners.map((corner) => corner.row).toSet().toList()
      ..sort();
    final columns =
        uniqueCorners.map((corner) => corner.column).toSet().toList()..sort();

    if (rows.length != 2 || columns.length != 2) {
      return CanopyRectangleResult.failure(
        'The three canopy corners must form part of one rectangle.',
      );
    }

    final expectedCorners = {
      for (final row in rows)
        for (final column in columns) GridCoordinate(row: row, column: column),
    };
    final missingCorners = expectedCorners.difference(uniqueCorners);
    if (missingCorners.length != 1) {
      return CanopyRectangleResult.failure(
        'The three canopy corners must form part of one rectangle.',
      );
    }

    return CanopyRectangleResult.success([
      for (var row = rows.first; row <= rows.last; row += 1)
        for (var column = columns.first; column <= columns.last; column += 1)
          GridCoordinate(row: row, column: column),
    ], inferredCorner: missingCorners.single);
  }
}
