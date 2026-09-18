import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'grid_geometry.dart';

class TableGroupBounds {
  final int topRow;
  final int leftColumn;
  final int bottomRowExclusive;
  final int rightColumnExclusive;

  const TableGroupBounds({
    required this.topRow,
    required this.leftColumn,
    required this.bottomRowExclusive,
    required this.rightColumnExclusive,
  });

  int get widthCells => rightColumnExclusive - leftColumn;
  int get heightCells => bottomRowExclusive - topRow;

  TableGroupBounds translated({
    required int rowDelta,
    required int columnDelta,
  }) {
    return TableGroupBounds(
      topRow: topRow + rowDelta,
      leftColumn: leftColumn + columnDelta,
      bottomRowExclusive: bottomRowExclusive + rowDelta,
      rightColumnExclusive: rightColumnExclusive + columnDelta,
    );
  }
}

/// Pure position calculations shared by group move, duplicate, and preview.
class TableGroupGeometry {
  const TableGroupGeometry._();

  static TableGroupBounds boundsFor(Iterable<LayoutTable> tables) {
    final tableList = tables.toList();
    if (tableList.isEmpty) {
      throw ArgumentError('At least one table is required.');
    }

    var top = tableList.first.topRow;
    var left = tableList.first.leftColumn;
    var bottom = tableList.first.bottomRowExclusive;
    var right = tableList.first.rightColumnExclusive;

    for (final table in tableList.skip(1)) {
      if (table.topRow < top) {
        top = table.topRow;
      }
      if (table.leftColumn < left) {
        left = table.leftColumn;
      }
      if (table.bottomRowExclusive > bottom) {
        bottom = table.bottomRowExclusive;
      }
      if (table.rightColumnExclusive > right) {
        right = table.rightColumnExclusive;
      }
    }

    return TableGroupBounds(
      topRow: top,
      leftColumn: left,
      bottomRowExclusive: bottom,
      rightColumnExclusive: right,
    );
  }

  static List<LayoutTable> translate(
    Iterable<LayoutTable> tables, {
    required int rowDelta,
    required int columnDelta,
  }) {
    return [
      for (final table in tables)
        table.copyWith(
          topRow: table.topRow + rowDelta,
          leftColumn: table.leftColumn + columnDelta,
        ),
    ];
  }

  /// Tries the four nearby sides first, then every allowed position.
  ///
  /// The one-cell gap in the preferred offsets makes duplicated groups easy
  /// to distinguish from their originals.
  static Iterable<GridCoordinate> duplicateOffsets({
    required Iterable<LayoutTable> tables,
    required RoomBounds placementBounds,
  }) sync* {
    final bounds = boundsFor(tables);
    final seen = <GridCoordinate>{};
    final preferredOffsets = [
      GridCoordinate(row: 0, column: bounds.widthCells + 1),
      GridCoordinate(row: bounds.heightCells + 1, column: 0),
      GridCoordinate(row: 0, column: -(bounds.widthCells + 1)),
      GridCoordinate(row: -(bounds.heightCells + 1), column: 0),
      GridCoordinate(
        row: bounds.heightCells + 1,
        column: bounds.widthCells + 1,
      ),
    ];

    for (final offset in preferredOffsets) {
      final shifted = bounds.translated(
        rowDelta: offset.row,
        columnDelta: offset.column,
      );
      if (_fitsInsideBounds(shifted, placementBounds) && seen.add(offset)) {
        yield offset;
      }
    }

    final lastTop = placementBounds.bottomRowExclusive - bounds.heightCells;
    final lastLeft = placementBounds.rightColumnExclusive - bounds.widthCells;

    for (var row = placementBounds.topRow; row <= lastTop; row += 1) {
      for (
        var column = placementBounds.leftColumn;
        column <= lastLeft;
        column += 1
      ) {
        final offset = GridCoordinate(
          row: row - bounds.topRow,
          column: column - bounds.leftColumn,
        );
        if ((offset.row != 0 || offset.column != 0) && seen.add(offset)) {
          yield offset;
        }
      }
    }
  }

  static bool _fitsInsideBounds(
    TableGroupBounds bounds,
    RoomBounds placementBounds,
  ) {
    return bounds.topRow >= placementBounds.topRow &&
        bounds.leftColumn >= placementBounds.leftColumn &&
        bounds.bottomRowExclusive <= placementBounds.bottomRowExclusive &&
        bounds.rightColumnExclusive <= placementBounds.rightColumnExclusive;
  }
}
