import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'grid_geometry.dart';

enum DistanceAxis { horizontal, vertical }

/// A validated straight distance path and the endpoints represented in JSON.
class DistanceConnection {
  final DistanceEndpoint start;
  final DistanceEndpoint end;
  final List<GridCoordinate> cells;
  final DistanceAxis axis;

  DistanceConnection({
    required this.start,
    required this.end,
    required List<GridCoordinate> cells,
    required this.axis,
  }) : cells = List.unmodifiable(cells);
}

class DistanceConnectionResult {
  final DistanceConnection? connection;
  final String? error;

  const DistanceConnectionResult._({this.connection, this.error});

  const DistanceConnectionResult.success(DistanceConnection connection)
    : this._(connection: connection);

  const DistanceConnectionResult.failure(String error) : this._(error: error);

  bool get succeeded => connection != null;
}

class _DistanceEndpointPair {
  final DistanceEndpoint start;
  final DistanceEndpoint end;

  const _DistanceEndpointPair({required this.start, required this.end});

  bool get includesCanopy =>
      start is CanopyDistanceEndpoint || end is CanopyDistanceEndpoint;
}

/// Pure calculations for snapping, resolving, and rebuilding distance cells.
class DistanceGeometry {
  const DistanceGeometry._();

  /// Creates a continuous one-cell-wide line using the dominant tap axis.
  static List<GridCoordinate> snappedLine(
    GridCoordinate start,
    GridCoordinate current,
  ) {
    final rowDifference = (current.row - start.row).abs();
    final columnDifference = (current.column - start.column).abs();

    if (columnDifference >= rowDifference) {
      final firstColumn = start.column < current.column
          ? start.column
          : current.column;
      final lastColumn = start.column > current.column
          ? start.column
          : current.column;

      return [
        for (var column = firstColumn; column <= lastColumn; column += 1)
          GridCoordinate(row: start.row, column: column),
      ];
    }

    final firstRow = start.row < current.row ? start.row : current.row;
    final lastRow = start.row > current.row ? start.row : current.row;

    return [
      for (var row = firstRow; row <= lastRow; row += 1)
        GridCoordinate(row: row, column: start.column),
    ];
  }

  /// Turns selected cells into table, wall, or canopy-edge endpoints.
  ///
  /// A one-cell distance checks both axes. A longer distance uses the axis
  /// represented by its selected cells. At least one endpoint must be a table
  /// fixture, so canopy-to-wall and canopy-to-canopy paths remain invalid.
  static DistanceConnectionResult resolveConnection({
    required Iterable<GridCoordinate> selectedCells,
    required GardenCenterLayout layout,
  }) {
    final cells = selectedCells.toSet().toList();
    if (cells.isEmpty) {
      return const DistanceConnectionResult.failure(
        'Select at least one distance cell.',
      );
    }

    for (final cell in cells) {
      if (!_canvasContainsCell(layout, cell)) {
        return const DistanceConnectionResult.failure(
          'Distance cells must stay inside the canvas.',
        );
      }
      if (_isNoInstallZoneCell(layout, cell)) {
        return const DistanceConnectionResult.failure(
          'A distance cannot cross a No Install Zone.',
        );
      }
    }

    if (cells.length == 1) {
      final horizontal = _resolveForAxis(
        cells: cells,
        layout: layout,
        axis: DistanceAxis.horizontal,
      );
      final vertical = _resolveForAxis(
        cells: cells,
        layout: layout,
        axis: DistanceAxis.vertical,
      );
      final validConnections = [
        if (horizontal.succeeded) horizontal.connection!,
        if (vertical.succeeded) vertical.connection!,
      ];

      if (validConnections.length == 1) {
        return DistanceConnectionResult.success(validConnections.single);
      }
      if (validConnections.length > 1) {
        return const DistanceConnectionResult.failure(
          'This cell could connect fixtures in two directions. '
          'Use a longer path so the direction is unambiguous.',
        );
      }

      return const DistanceConnectionResult.failure(
        'The distance must bridge a table to another table, wall, or '
        'canopy edge.',
      );
    }

    final sameRow = cells.every((cell) => cell.row == cells.first.row);
    final sameColumn = cells.every((cell) => cell.column == cells.first.column);

    if (!sameRow && !sameColumn) {
      return const DistanceConnectionResult.failure(
        'The distance must be one straight horizontal or vertical line.',
      );
    }

    return _resolveForAxis(
      cells: cells,
      layout: layout,
      axis: sameRow ? DistanceAxis.horizontal : DistanceAxis.vertical,
    );
  }

  /// Rebuilds the selected cells from the persisted endpoint references.
  static List<GridCoordinate> cellsForDistance(
    Distance distance,
    GardenCenterLayout layout,
  ) {
    final startCandidates = _adjacentCellsForEndpoint(distance.start, layout);
    final endCandidates = _adjacentCellsForEndpoint(distance.end, layout);

    for (final startCell in startCandidates) {
      for (final endCell in endCandidates) {
        final axes = <DistanceAxis>[
          if (startCell.row == endCell.row) DistanceAxis.horizontal,
          if (startCell.column == endCell.column) DistanceAxis.vertical,
        ];

        for (final axis in axes) {
          final cells = snappedLine(startCell, endCell);
          if (cells.any(
            (cell) =>
                !_canvasContainsCell(layout, cell) ||
                _isNoInstallZoneCell(layout, cell) ||
                _tableAt(row: cell.row, column: cell.column, layout: layout) !=
                    null,
          )) {
            continue;
          }

          final resolution = _resolveForAxis(
            cells: cells,
            layout: layout,
            axis: axis,
            requiredStart: distance.start,
            requiredEnd: distance.end,
          );
          final connection = resolution.connection;
          if (connection != null &&
              _sameEndpointPair(
                distance.start,
                distance.end,
                connection.start,
                connection.end,
              )) {
            return cells;
          }
        }
      }
    }

    return const [];
  }

  static bool distanceReferencesTable(Distance distance, String tableId) {
    final startMatches =
        distance.start is TableDistanceEndpoint &&
        (distance.start as TableDistanceEndpoint).tableId == tableId;
    final endMatches =
        distance.end is TableDistanceEndpoint &&
        (distance.end as TableDistanceEndpoint).tableId == tableId;

    return startMatches || endMatches;
  }

  static DistanceConnectionResult _resolveForAxis({
    required List<GridCoordinate> cells,
    required GardenCenterLayout layout,
    required DistanceAxis axis,
    DistanceEndpoint? requiredStart,
    DistanceEndpoint? requiredEnd,
  }) {
    final orderedCells = [...cells]
      ..sort((first, second) {
        if (axis == DistanceAxis.horizontal) {
          return first.column.compareTo(second.column);
        }
        return first.row.compareTo(second.row);
      });

    if (!_isContinuous(orderedCells, axis)) {
      return const DistanceConnectionResult.failure(
        'Distance cells must form one continuous line with no gaps.',
      );
    }

    final room = layout.roomBounds;
    final insideStates = [
      for (final cell in orderedCells)
        room.containsCell(row: cell.row, column: cell.column),
    ];
    if (insideStates.any((isInside) => isInside) &&
        insideStates.any((isInside) => !isInside)) {
      return const DistanceConnectionResult.failure(
        'A distance cannot pass through a room wall.',
      );
    }

    final startEndpoints = _endpointsBefore(
      orderedCells.first,
      axis,
      layout,
    );
    final endEndpoints = _endpointsAfter(
      orderedCells.last,
      axis,
      layout,
    );

    if (startEndpoints.isEmpty || endEndpoints.isEmpty) {
      return const DistanceConnectionResult.failure(
        'Both ends of a distance must touch a table, wall, or canopy edge.',
      );
    }

    final endpointPairs = <_DistanceEndpointPair>[
      for (final start in startEndpoints)
        for (final end in endEndpoints)
          if (_isSupportedEndpointPair(start, end))
            _DistanceEndpointPair(start: start, end: end),
    ];

    if (endpointPairs.isEmpty &&
        startEndpoints.every((endpoint) => endpoint is WallDistanceEndpoint) &&
        endEndpoints.every((endpoint) => endpoint is WallDistanceEndpoint)) {
      return const DistanceConnectionResult.failure(
        'A distance cannot connect one wall directly to another wall.',
      );
    }

    if (endpointPairs.isEmpty &&
        _containsSameTablePair(startEndpoints, endEndpoints)) {
      return const DistanceConnectionResult.failure(
        'A distance cannot connect a table back to itself.',
      );
    }

    if (endpointPairs.isEmpty) {
      return const DistanceConnectionResult.failure(
        'A distance must connect one table fixture to another table, wall, '
        'or canopy edge.',
      );
    }

    _DistanceEndpointPair? selectedPair;
    if (requiredStart != null && requiredEnd != null) {
      for (final pair in endpointPairs) {
        if (_sameEndpointPair(
          requiredStart,
          requiredEnd,
          pair.start,
          pair.end,
        )) {
          selectedPair = pair;
          break;
        }
      }
      if (selectedPair == null) {
        return const DistanceConnectionResult.failure(
          'The distance no longer touches its saved endpoints.',
        );
      }
    } else {
      // Preserve established table-to-table and table-to-wall behavior when a
      // table happens to sit under a canopy edge. A canopy endpoint is chosen
      // whenever it is the only valid target for the selected path.
      for (final pair in endpointPairs) {
        if (!pair.includesCanopy) {
          selectedPair = pair;
          break;
        }
      }
      selectedPair ??= endpointPairs.first;
    }

    final resolvedPair = selectedPair;
    if (resolvedPair == null) {
      return const DistanceConnectionResult.failure(
        'The selected distance endpoints could not be resolved.',
      );
    }

    return DistanceConnectionResult.success(
      DistanceConnection(
        start: resolvedPair.start,
        end: resolvedPair.end,
        cells: orderedCells,
        axis: axis,
      ),
    );
  }

  static bool _isSupportedEndpointPair(
    DistanceEndpoint start,
    DistanceEndpoint end,
  ) {
    final hasTableEndpoint =
        start is TableDistanceEndpoint || end is TableDistanceEndpoint;
    if (!hasTableEndpoint) {
      return false;
    }

    return !(start is TableDistanceEndpoint &&
        end is TableDistanceEndpoint &&
        start.tableId == end.tableId);
  }

  static bool _containsSameTablePair(
    Iterable<DistanceEndpoint> starts,
    Iterable<DistanceEndpoint> ends,
  ) {
    for (final start in starts.whereType<TableDistanceEndpoint>()) {
      for (final end in ends.whereType<TableDistanceEndpoint>()) {
        if (start.tableId == end.tableId) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _isContinuous(
    List<GridCoordinate> orderedCells,
    DistanceAxis axis,
  ) {
    for (var index = 1; index < orderedCells.length; index += 1) {
      final previous = orderedCells[index - 1];
      final current = orderedCells[index];

      if (axis == DistanceAxis.horizontal) {
        if (current.row != previous.row ||
            current.column != previous.column + 1) {
          return false;
        }
      } else if (current.column != previous.column ||
          current.row != previous.row + 1) {
        return false;
      }
    }

    return true;
  }

  static List<DistanceEndpoint> _endpointsBefore(
    GridCoordinate cell,
    DistanceAxis axis,
    GardenCenterLayout layout,
  ) {
    final room = layout.roomBounds;

    if (axis == DistanceAxis.horizontal) {
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.leftColumn) {
        return [
          WallDistanceEndpoint(
            wallSide: WallSide.left,
            offsetCells: cell.row - room.topRow,
          ),
        ];
      }
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.rightColumnExclusive) {
        return [
          WallDistanceEndpoint(
            wallSide: WallSide.right,
            offsetCells: cell.row - room.topRow,
          ),
        ];
      }

      final table = _tableAt(
        row: cell.row,
        column: cell.column - 1,
        layout: layout,
      );
      final canopy = _canopyEndpointAt(
        row: cell.row,
        column: cell.column - 1,
        edgeSide: EdgeSide.right,
        layout: layout,
      );
      return [
        if (table != null)
          TableDistanceEndpoint(
            tableId: table.tableId,
            edgeSide: EdgeSide.right,
            offsetCells: cell.row - table.topRow,
          ),
        if (canopy != null) canopy,
      ];
    }

    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.topRow) {
      return [
        WallDistanceEndpoint(
          wallSide: WallSide.top,
          offsetCells: cell.column - room.leftColumn,
        ),
      ];
    }
    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.bottomRowExclusive) {
      return [
        WallDistanceEndpoint(
          wallSide: WallSide.bottom,
          offsetCells: cell.column - room.leftColumn,
        ),
      ];
    }

    final table = _tableAt(
      row: cell.row - 1,
      column: cell.column,
      layout: layout,
    );
    final canopy = _canopyEndpointAt(
      row: cell.row - 1,
      column: cell.column,
      edgeSide: EdgeSide.bottom,
      layout: layout,
    );
    return [
      if (table != null)
        TableDistanceEndpoint(
          tableId: table.tableId,
          edgeSide: EdgeSide.bottom,
          offsetCells: cell.column - table.leftColumn,
        ),
      if (canopy != null) canopy,
    ];
  }

  static List<DistanceEndpoint> _endpointsAfter(
    GridCoordinate cell,
    DistanceAxis axis,
    GardenCenterLayout layout,
  ) {
    final room = layout.roomBounds;

    if (axis == DistanceAxis.horizontal) {
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.rightColumnExclusive - 1) {
        return [
          WallDistanceEndpoint(
            wallSide: WallSide.right,
            offsetCells: cell.row - room.topRow,
          ),
        ];
      }
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.leftColumn - 1) {
        return [
          WallDistanceEndpoint(
            wallSide: WallSide.left,
            offsetCells: cell.row - room.topRow,
          ),
        ];
      }

      final table = _tableAt(
        row: cell.row,
        column: cell.column + 1,
        layout: layout,
      );
      final canopy = _canopyEndpointAt(
        row: cell.row,
        column: cell.column + 1,
        edgeSide: EdgeSide.left,
        layout: layout,
      );
      return [
        if (table != null)
          TableDistanceEndpoint(
            tableId: table.tableId,
            edgeSide: EdgeSide.left,
            offsetCells: cell.row - table.topRow,
          ),
        if (canopy != null) canopy,
      ];
    }

    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.bottomRowExclusive - 1) {
      return [
        WallDistanceEndpoint(
          wallSide: WallSide.bottom,
          offsetCells: cell.column - room.leftColumn,
        ),
      ];
    }
    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.topRow - 1) {
      return [
        WallDistanceEndpoint(
          wallSide: WallSide.top,
          offsetCells: cell.column - room.leftColumn,
        ),
      ];
    }

    final table = _tableAt(
      row: cell.row + 1,
      column: cell.column,
      layout: layout,
    );
    final canopy = _canopyEndpointAt(
      row: cell.row + 1,
      column: cell.column,
      edgeSide: EdgeSide.top,
      layout: layout,
    );
    return [
      if (table != null)
        TableDistanceEndpoint(
          tableId: table.tableId,
          edgeSide: EdgeSide.top,
          offsetCells: cell.column - table.leftColumn,
        ),
      if (canopy != null) canopy,
    ];
  }

  static CanopyDistanceEndpoint? _canopyEndpointAt({
    required int row,
    required int column,
    required EdgeSide edgeSide,
    required GardenCenterLayout layout,
  }) {
    if (!_hasCanopyCell(layout, row: row, column: column)) {
      return null;
    }

    final outsideHasCanopy = switch (edgeSide) {
      EdgeSide.top => _hasCanopyCell(
          layout,
          row: row - 1,
          column: column,
        ),
      EdgeSide.right => _hasCanopyCell(
          layout,
          row: row,
          column: column + 1,
        ),
      EdgeSide.bottom => _hasCanopyCell(
          layout,
          row: row + 1,
          column: column,
        ),
      EdgeSide.left => _hasCanopyCell(
          layout,
          row: row,
          column: column - 1,
        ),
    };
    if (outsideHasCanopy) {
      return null;
    }

    return CanopyDistanceEndpoint(
      row: row,
      column: column,
      edgeSide: edgeSide,
    );
  }

  static bool _hasCanopyCell(
    GardenCenterLayout layout, {
    required int row,
    required int column,
  }) {
    if (row < 0 || column < 0) {
      return false;
    }

    return layout.canopyCellList.contains(
      CanopyCell(row: row, column: column),
    );
  }

  static LayoutTable? _tableAt({
    required int row,
    required int column,
    required GardenCenterLayout layout,
  }) {
    for (final table in layout.layoutTableList) {
      final containsCell =
          row >= table.topRow &&
          row < table.bottomRowExclusive &&
          column >= table.leftColumn &&
          column < table.rightColumnExclusive;
      if (containsCell) {
        return table;
      }
    }

    return null;
  }

  static List<GridCoordinate> _adjacentCellsForEndpoint(
    DistanceEndpoint endpoint,
    GardenCenterLayout layout,
  ) {
    if (endpoint is WallDistanceEndpoint) {
      final room = layout.roomBounds;

      switch (endpoint.wallSide) {
        case WallSide.top:
          if (endpoint.offsetCells >= room.widthCells) {
            return const [];
          }
          final column = room.leftColumn + endpoint.offsetCells;
          return [
            GridCoordinate(row: room.topRow, column: column),
            GridCoordinate(row: room.topRow - 1, column: column),
          ];
        case WallSide.right:
          if (endpoint.offsetCells >= room.heightCells) {
            return const [];
          }
          final row = room.topRow + endpoint.offsetCells;
          return [
            GridCoordinate(row: row, column: room.rightColumnExclusive - 1),
            GridCoordinate(row: row, column: room.rightColumnExclusive),
          ];
        case WallSide.bottom:
          if (endpoint.offsetCells >= room.widthCells) {
            return const [];
          }
          final column = room.leftColumn + endpoint.offsetCells;
          return [
            GridCoordinate(row: room.bottomRowExclusive - 1, column: column),
            GridCoordinate(row: room.bottomRowExclusive, column: column),
          ];
        case WallSide.left:
          if (endpoint.offsetCells >= room.heightCells) {
            return const [];
          }
          final row = room.topRow + endpoint.offsetCells;
          return [
            GridCoordinate(row: row, column: room.leftColumn),
            GridCoordinate(row: row, column: room.leftColumn - 1),
          ];
      }
    }

    if (endpoint is CanopyDistanceEndpoint) {
      final currentEndpoint = _canopyEndpointAt(
        row: endpoint.row,
        column: endpoint.column,
        edgeSide: endpoint.edgeSide,
        layout: layout,
      );
      if (currentEndpoint != endpoint) {
        return const [];
      }

      return [
        switch (endpoint.edgeSide) {
          EdgeSide.top => GridCoordinate(
              row: endpoint.row - 1,
              column: endpoint.column,
            ),
          EdgeSide.right => GridCoordinate(
              row: endpoint.row,
              column: endpoint.column + 1,
            ),
          EdgeSide.bottom => GridCoordinate(
              row: endpoint.row + 1,
              column: endpoint.column,
            ),
          EdgeSide.left => GridCoordinate(
              row: endpoint.row,
              column: endpoint.column - 1,
            ),
        },
      ];
    }

    final tableEndpoint = endpoint as TableDistanceEndpoint;
    LayoutTable? table;
    for (final candidate in layout.layoutTableList) {
      if (candidate.tableId == tableEndpoint.tableId) {
        table = candidate;
        break;
      }
    }
    if (table == null) {
      return const [];
    }

    switch (tableEndpoint.edgeSide) {
      case EdgeSide.top:
        if (tableEndpoint.offsetCells >= table.widthCells) {
          return const [];
        }
        return [
          GridCoordinate(
            row: table.topRow - 1,
            column: table.leftColumn + tableEndpoint.offsetCells,
          ),
        ];
      case EdgeSide.right:
        if (tableEndpoint.offsetCells >= table.heightCells) {
          return const [];
        }
        return [
          GridCoordinate(
            row: table.topRow + tableEndpoint.offsetCells,
            column: table.rightColumnExclusive,
          ),
        ];
      case EdgeSide.bottom:
        if (tableEndpoint.offsetCells >= table.widthCells) {
          return const [];
        }
        return [
          GridCoordinate(
            row: table.bottomRowExclusive,
            column: table.leftColumn + tableEndpoint.offsetCells,
          ),
        ];
      case EdgeSide.left:
        if (tableEndpoint.offsetCells >= table.heightCells) {
          return const [];
        }
        return [
          GridCoordinate(
            row: table.topRow + tableEndpoint.offsetCells,
            column: table.leftColumn - 1,
          ),
        ];
    }
  }

  static bool _sameEndpointPair(
    DistanceEndpoint firstStart,
    DistanceEndpoint firstEnd,
    DistanceEndpoint secondStart,
    DistanceEndpoint secondEnd,
  ) {
    return (firstStart == secondStart && firstEnd == secondEnd) ||
        (firstStart == secondEnd && firstEnd == secondStart);
  }

  static bool _canvasContainsCell(
    GardenCenterLayout layout,
    GridCoordinate cell,
  ) {
    return cell.row >= 0 &&
        cell.row < layout.canvasRows &&
        cell.column >= 0 &&
        cell.column < layout.canvasColumns;
  }

  static bool _isNoInstallZoneCell(
    GardenCenterLayout layout,
    GridCoordinate cell,
  ) {
    return layout.noInstallZoneCellList.contains(
      NoInstallZoneCell(row: cell.row, column: cell.column),
    );
  }
}
