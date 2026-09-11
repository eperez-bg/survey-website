// map_geometry.dart
//
// Responsibility:
// Rebuilds saved schema 9-11 distance cells and applies the same collision
// rules used by the Flutter field app. It has no UI or storage dependencies.

import 'dart:math' as math;

import '../models/survey_map_model.dart';

enum DistanceAxis { horizontal, vertical }

class GridArea {
  final int topRow;
  final int leftColumn;
  final int bottomRowExclusive;
  final int rightColumnExclusive;

  const GridArea({
    required this.topRow,
    required this.leftColumn,
    required this.bottomRowExclusive,
    required this.rightColumnExclusive,
  });

  bool contains(GridCoordinate cell) =>
      cell.row >= topRow &&
      cell.row < bottomRowExclusive &&
      cell.column >= leftColumn &&
      cell.column < rightColumnExclusive;

  bool overlapsTable(LayoutTableModel table) => MapGeometry.areasOverlap(
        firstTop: topRow,
        firstLeft: leftColumn,
        firstBottom: bottomRowExclusive,
        firstRight: rightColumnExclusive,
        secondTop: table.topRow,
        secondLeft: table.leftColumn,
        secondBottom: table.bottomRowExclusive,
        secondRight: table.rightColumnExclusive,
      );
}

class MapGeometry {
  const MapGeometry._();

  static List<GridCoordinate> cellsForDistance(
    DistanceModel distance,
    SurveyMapModel layout,
  ) {
    final startCandidates = _adjacentCells(distance.start, layout);
    final endCandidates = _adjacentCells(distance.end, layout);

    for (final startCell in startCandidates) {
      for (final endCell in endCandidates) {
        final axes = <DistanceAxis>[
          if (startCell.row == endCell.row) DistanceAxis.horizontal,
          if (startCell.column == endCell.column) DistanceAxis.vertical,
        ];
        for (final axis in axes) {
          final cells = _line(startCell, endCell, axis);
          if (cells.any(
            (cell) => !canvasContainsCell(layout, cell) ||
                tableAt(layout, cell.row, cell.column) != null ||
                isNoInstallZoneCell(layout, cell),
          )) {
            continue;
          }
          final resolved = _resolve(cells, axis, layout);
          if (resolved != null &&
              _sameEndpointPair(
                distance.start,
                distance.end,
                resolved.start,
                resolved.end,
              )) {
            return cells;
          }
        }
      }
    }
    return const [];
  }

  static bool distanceReferencesTable(DistanceModel distance, String tableId) {
    final start = distance.start;
    final end = distance.end;
    return (start is TableDistanceEndpointModel && start.tableId == tableId) ||
        (end is TableDistanceEndpointModel && end.tableId == tableId);
  }

  static String? tableGroupPlacementError({
    required List<LayoutTableModel> candidates,
    required SurveyMapModel layout,
    Set<String> ignoredTableIds = const {},
  }) {
    for (final candidate in candidates) {
      if (candidate.topRow < 0 ||
          candidate.leftColumn < 0 ||
          candidate.bottomRowExclusive > layout.canvasRows ||
          candidate.rightColumnExclusive > layout.canvasColumns) {
        return 'Tables must fit completely inside the canvas.';
      }
      if (tableCrossesRoomWall(candidate, layout.roomBounds)) {
        return 'Tables cannot cross a room wall.';
      }
      if (layout.entrances
          .map((item) => entranceClearance(item, layout.roomBounds))
          .any((area) => area.overlapsTable(candidate))) {
        return 'Nothing can be placed in front of an entrance.';
      }
      for (final existing in layout.tables) {
        if (!ignoredTableIds.contains(existing.tableId) &&
            tablesOverlap(candidate, existing)) {
          return 'Tables cannot overlap.';
        }
      }
      for (final distance in layout.distances) {
        if (cellsForDistance(distance, layout).any(
          (cell) =>
              cell.row >= candidate.topRow &&
              cell.row < candidate.bottomRowExclusive &&
              cell.column >= candidate.leftColumn &&
              cell.column < candidate.rightColumnExclusive,
        )) {
          return 'Tables cannot overlap distances.';
        }
      }
    }

    for (var first = 0; first < candidates.length; first += 1) {
      for (var second = first + 1; second < candidates.length; second += 1) {
        if (tablesOverlap(candidates[first], candidates[second])) {
          return 'Tables cannot overlap.';
        }
      }
    }
    return null;
  }

  static String? entrancePlacementError({
    required EntranceModel candidate,
    required SurveyMapModel layout,
    String? ignoredEntranceId,
  }) {
    final wallLength = candidate.wallSide == WallSide.top ||
            candidate.wallSide == WallSide.bottom
        ? layout.roomBounds.widthCells
        : layout.roomBounds.heightCells;
    if (candidate.widthCells <= 0 ||
        candidate.clearanceDepthCells < 0 ||
        candidate.offsetCells < 0 ||
        candidate.offsetCells + candidate.widthCells > wallLength) {
      return 'The entrance must fit completely on a room wall.';
    }

    for (final existing in layout.entrances) {
      if (existing.entranceId == ignoredEntranceId) {
        continue;
      }
      final overlaps = existing.wallSide == candidate.wallSide &&
          candidate.offsetCells < existing.offsetCells + existing.widthCells &&
          candidate.offsetCells + candidate.widthCells > existing.offsetCells;
      if (overlaps) {
        return 'Entrances cannot overlap.';
      }
    }

    final clearance = entranceClearance(candidate, layout.roomBounds);
    if (layout.tables.any(clearance.overlapsTable)) {
      return 'Move tables out of the entrance clearance first.';
    }
    for (final distance in layout.distances) {
      if (cellsForDistance(distance, layout).any(clearance.contains)) {
        return 'Move or delete the distance blocking this entrance first.';
      }
    }
    if (layout.spigots.any(
      (spigot) => spigotOccupiesEntrance(spigot, candidate, layout.roomBounds),
    )) {
      return 'A spigot cannot occupy the same wall section as an entrance.';
    }
    return null;
  }

  static GridArea entranceClearance(
    EntranceModel entrance,
    RoomBoundsModel room,
  ) {
    return switch (entrance.wallSide) {
      WallSide.top => GridArea(
          topRow: room.topRow - entrance.clearanceDepthCells,
          leftColumn: room.leftColumn + entrance.offsetCells,
          bottomRowExclusive: room.topRow + entrance.clearanceDepthCells,
          rightColumnExclusive:
              room.leftColumn + entrance.offsetCells + entrance.widthCells,
        ),
      WallSide.right => GridArea(
          topRow: room.topRow + entrance.offsetCells,
          leftColumn: room.rightColumnExclusive - entrance.clearanceDepthCells,
          bottomRowExclusive:
              room.topRow + entrance.offsetCells + entrance.widthCells,
          rightColumnExclusive:
              room.rightColumnExclusive + entrance.clearanceDepthCells,
        ),
      WallSide.bottom => GridArea(
          topRow: room.bottomRowExclusive - entrance.clearanceDepthCells,
          leftColumn: room.leftColumn + entrance.offsetCells,
          bottomRowExclusive:
              room.bottomRowExclusive + entrance.clearanceDepthCells,
          rightColumnExclusive:
              room.leftColumn + entrance.offsetCells + entrance.widthCells,
        ),
      WallSide.left => GridArea(
          topRow: room.topRow + entrance.offsetCells,
          leftColumn: room.leftColumn - entrance.clearanceDepthCells,
          bottomRowExclusive:
              room.topRow + entrance.offsetCells + entrance.widthCells,
          rightColumnExclusive: room.leftColumn + entrance.clearanceDepthCells,
        ),
    };
  }

  static bool spigotFitsLayout(SpigotModel spigot, SurveyMapModel layout) {
    final room = layout.roomBounds;
    return spigot.rowLine >= room.topRow &&
        spigot.rowLine <= room.bottomRowExclusive &&
        spigot.columnLine >= room.leftColumn &&
        spigot.columnLine <= room.rightColumnExclusive &&
        spigot.rowLine >= 0 &&
        spigot.rowLine <= layout.canvasRows &&
        spigot.columnLine >= 0 &&
        spigot.columnLine <= layout.canvasColumns;
  }

  static bool spigotOccupiesEntrance(
    SpigotModel spigot,
    EntranceModel entrance,
    RoomBoundsModel room,
  ) {
    final start = entrance.offsetCells;
    final end = entrance.offsetCells + entrance.widthCells;
    return switch (entrance.wallSide) {
      WallSide.top => spigot.rowLine == room.topRow &&
          spigot.columnLine >= room.leftColumn + start &&
          spigot.columnLine <= room.leftColumn + end,
      WallSide.right => spigot.columnLine == room.rightColumnExclusive &&
          spigot.rowLine >= room.topRow + start &&
          spigot.rowLine <= room.topRow + end,
      WallSide.bottom => spigot.rowLine == room.bottomRowExclusive &&
          spigot.columnLine >= room.leftColumn + start &&
          spigot.columnLine <= room.leftColumn + end,
      WallSide.left => spigot.columnLine == room.leftColumn &&
          spigot.rowLine >= room.topRow + start &&
          spigot.rowLine <= room.topRow + end,
    };
  }

  static bool tableCrossesRoomWall(
    LayoutTableModel table,
    RoomBoundsModel room,
  ) {
    final overlapsRoom = areasOverlap(
      firstTop: table.topRow,
      firstLeft: table.leftColumn,
      firstBottom: table.bottomRowExclusive,
      firstRight: table.rightColumnExclusive,
      secondTop: room.topRow,
      secondLeft: room.leftColumn,
      secondBottom: room.bottomRowExclusive,
      secondRight: room.rightColumnExclusive,
    );
    final fullyInside = table.topRow >= room.topRow &&
        table.leftColumn >= room.leftColumn &&
        table.bottomRowExclusive <= room.bottomRowExclusive &&
        table.rightColumnExclusive <= room.rightColumnExclusive;
    return overlapsRoom && !fullyInside;
  }

  static bool tablesOverlap(LayoutTableModel first, LayoutTableModel second) {
    return areasOverlap(
      firstTop: first.topRow,
      firstLeft: first.leftColumn,
      firstBottom: first.bottomRowExclusive,
      firstRight: first.rightColumnExclusive,
      secondTop: second.topRow,
      secondLeft: second.leftColumn,
      secondBottom: second.bottomRowExclusive,
      secondRight: second.rightColumnExclusive,
    );
  }

  static bool areasOverlap({
    required int firstTop,
    required int firstLeft,
    required int firstBottom,
    required int firstRight,
    required int secondTop,
    required int secondLeft,
    required int secondBottom,
    required int secondRight,
  }) {
    return firstLeft < secondRight &&
        firstRight > secondLeft &&
        firstTop < secondBottom &&
        firstBottom > secondTop;
  }

  static bool canvasContainsCell(SurveyMapModel layout, GridCoordinate cell) =>
      cell.row >= 0 &&
      cell.row < layout.canvasRows &&
      cell.column >= 0 &&
      cell.column < layout.canvasColumns;

  static LayoutTableModel? tableAt(
    SurveyMapModel layout,
    int row,
    int column,
  ) {
    for (final table in layout.tables) {
      if (row >= table.topRow &&
          row < table.bottomRowExclusive &&
          column >= table.leftColumn &&
          column < table.rightColumnExclusive) {
        return table;
      }
    }
    return null;
  }

  static CanopyCellModel? canopyAt(
    SurveyMapModel layout,
    int row,
    int column,
  ) {
    for (final canopy in layout.canopyCells) {
      if (canopy.row == row && canopy.column == column) {
        return canopy;
      }
    }
    return null;
  }

  static bool isNoInstallZoneCell(
    SurveyMapModel layout,
    GridCoordinate cell,
  ) {
    return layout.noInstallZoneCells.any(
      (blocked) => blocked.row == cell.row && blocked.column == cell.column,
    );
  }

  static List<GridCoordinate> _line(
    GridCoordinate start,
    GridCoordinate end,
    DistanceAxis axis,
  ) {
    if (axis == DistanceAxis.horizontal) {
      final first = math.min(start.column, end.column);
      final last = math.max(start.column, end.column);
      return [
        for (var column = first; column <= last; column += 1)
          GridCoordinate(row: start.row, column: column),
      ];
    }
    final first = math.min(start.row, end.row);
    final last = math.max(start.row, end.row);
    return [
      for (var row = first; row <= last; row += 1)
        GridCoordinate(row: row, column: start.column),
    ];
  }

  static _ResolvedDistance? _resolve(
    List<GridCoordinate> cells,
    DistanceAxis axis,
    SurveyMapModel layout,
  ) {
    final ordered = [...cells]
      ..sort((a, b) => axis == DistanceAxis.horizontal
          ? a.column.compareTo(b.column)
          : a.row.compareTo(b.row));
    final inside = [for (final cell in ordered) layout.roomBounds.containsCell(cell)];
    if (inside.any((value) => value) && inside.any((value) => !value)) {
      return null;
    }
    final start = _endpointBefore(ordered.first, axis, layout);
    final end = _endpointAfter(ordered.last, axis, layout);
    if (start == null || end == null) {
      return null;
    }
    if (start is WallDistanceEndpointModel && end is WallDistanceEndpointModel) {
      return null;
    }
    if (start is TableDistanceEndpointModel &&
        end is TableDistanceEndpointModel &&
        start.tableId == end.tableId) {
      return null;
    }
    if (start is CanopyDistanceEndpointModel &&
        end is CanopyDistanceEndpointModel &&
        start.row == end.row &&
        start.column == end.column) {
      return null;
    }
    return _ResolvedDistance(start, end);
  }

  static DistanceEndpointModel? _endpointBefore(
    GridCoordinate cell,
    DistanceAxis axis,
    SurveyMapModel layout,
  ) {
    final room = layout.roomBounds;
    if (axis == DistanceAxis.horizontal) {
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.leftColumn) {
        return WallDistanceEndpointModel(
          wallSide: WallSide.left,
          offsetCells: cell.row - room.topRow,
        );
      }
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.rightColumnExclusive) {
        return WallDistanceEndpointModel(
          wallSide: WallSide.right,
          offsetCells: cell.row - room.topRow,
        );
      }
      final table = tableAt(layout, cell.row, cell.column - 1);
      if (table != null) {
        return TableDistanceEndpointModel(
          tableId: table.tableId,
          edgeSide: EdgeSide.right,
          offsetCells: cell.row - table.topRow,
        );
      }
      final canopy = canopyAt(layout, cell.row, cell.column - 1);
      return canopy == null
          ? null
          : CanopyDistanceEndpointModel(
              row: canopy.row,
              column: canopy.column,
              edgeSide: EdgeSide.right,
            );
    }

    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.topRow) {
      return WallDistanceEndpointModel(
        wallSide: WallSide.top,
        offsetCells: cell.column - room.leftColumn,
      );
    }
    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.bottomRowExclusive) {
      return WallDistanceEndpointModel(
        wallSide: WallSide.bottom,
        offsetCells: cell.column - room.leftColumn,
      );
    }
    final table = tableAt(layout, cell.row - 1, cell.column);
    if (table != null) {
      return TableDistanceEndpointModel(
        tableId: table.tableId,
        edgeSide: EdgeSide.bottom,
        offsetCells: cell.column - table.leftColumn,
      );
    }
    final canopy = canopyAt(layout, cell.row - 1, cell.column);
    return canopy == null
        ? null
        : CanopyDistanceEndpointModel(
            row: canopy.row,
            column: canopy.column,
            edgeSide: EdgeSide.bottom,
          );
  }

  static DistanceEndpointModel? _endpointAfter(
    GridCoordinate cell,
    DistanceAxis axis,
    SurveyMapModel layout,
  ) {
    final room = layout.roomBounds;
    if (axis == DistanceAxis.horizontal) {
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.rightColumnExclusive - 1) {
        return WallDistanceEndpointModel(
          wallSide: WallSide.right,
          offsetCells: cell.row - room.topRow,
        );
      }
      if (cell.row >= room.topRow &&
          cell.row < room.bottomRowExclusive &&
          cell.column == room.leftColumn - 1) {
        return WallDistanceEndpointModel(
          wallSide: WallSide.left,
          offsetCells: cell.row - room.topRow,
        );
      }
      final table = tableAt(layout, cell.row, cell.column + 1);
      if (table != null) {
        return TableDistanceEndpointModel(
          tableId: table.tableId,
          edgeSide: EdgeSide.left,
          offsetCells: cell.row - table.topRow,
        );
      }
      final canopy = canopyAt(layout, cell.row, cell.column + 1);
      return canopy == null
          ? null
          : CanopyDistanceEndpointModel(
              row: canopy.row,
              column: canopy.column,
              edgeSide: EdgeSide.left,
            );
    }

    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.bottomRowExclusive - 1) {
      return WallDistanceEndpointModel(
        wallSide: WallSide.bottom,
        offsetCells: cell.column - room.leftColumn,
      );
    }
    if (cell.column >= room.leftColumn &&
        cell.column < room.rightColumnExclusive &&
        cell.row == room.topRow - 1) {
      return WallDistanceEndpointModel(
        wallSide: WallSide.top,
        offsetCells: cell.column - room.leftColumn,
      );
    }
    final table = tableAt(layout, cell.row + 1, cell.column);
    if (table != null) {
      return TableDistanceEndpointModel(
        tableId: table.tableId,
        edgeSide: EdgeSide.top,
        offsetCells: cell.column - table.leftColumn,
      );
    }
    final canopy = canopyAt(layout, cell.row + 1, cell.column);
    return canopy == null
        ? null
        : CanopyDistanceEndpointModel(
            row: canopy.row,
            column: canopy.column,
            edgeSide: EdgeSide.top,
          );
  }

  static List<GridCoordinate> _adjacentCells(
    DistanceEndpointModel endpoint,
    SurveyMapModel layout,
  ) {
    if (endpoint is WallDistanceEndpointModel) {
      final room = layout.roomBounds;
      switch (endpoint.wallSide) {
        case WallSide.top:
          if (endpoint.offsetCells >= room.widthCells) return const [];
          final column = room.leftColumn + endpoint.offsetCells;
          return [
            GridCoordinate(row: room.topRow, column: column),
            GridCoordinate(row: room.topRow - 1, column: column),
          ];
        case WallSide.right:
          if (endpoint.offsetCells >= room.heightCells) return const [];
          final row = room.topRow + endpoint.offsetCells;
          return [
            GridCoordinate(row: row, column: room.rightColumnExclusive - 1),
            GridCoordinate(row: row, column: room.rightColumnExclusive),
          ];
        case WallSide.bottom:
          if (endpoint.offsetCells >= room.widthCells) return const [];
          final column = room.leftColumn + endpoint.offsetCells;
          return [
            GridCoordinate(row: room.bottomRowExclusive - 1, column: column),
            GridCoordinate(row: room.bottomRowExclusive, column: column),
          ];
        case WallSide.left:
          if (endpoint.offsetCells >= room.heightCells) return const [];
          final row = room.topRow + endpoint.offsetCells;
          return [
            GridCoordinate(row: row, column: room.leftColumn),
            GridCoordinate(row: row, column: room.leftColumn - 1),
          ];
      }
    }

    if (endpoint is CanopyDistanceEndpointModel) {
      if (canopyAt(layout, endpoint.row, endpoint.column) == null) {
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

    final tableEndpoint = endpoint as TableDistanceEndpointModel;
    final table = layout.tableById(tableEndpoint.tableId);
    if (table == null) return const [];
    switch (tableEndpoint.edgeSide) {
      case EdgeSide.top:
        if (tableEndpoint.offsetCells >= table.widthCells) return const [];
        return [GridCoordinate(
          row: table.topRow - 1,
          column: table.leftColumn + tableEndpoint.offsetCells,
        )];
      case EdgeSide.right:
        if (tableEndpoint.offsetCells >= table.heightCells) return const [];
        return [GridCoordinate(
          row: table.topRow + tableEndpoint.offsetCells,
          column: table.rightColumnExclusive,
        )];
      case EdgeSide.bottom:
        if (tableEndpoint.offsetCells >= table.widthCells) return const [];
        return [GridCoordinate(
          row: table.bottomRowExclusive,
          column: table.leftColumn + tableEndpoint.offsetCells,
        )];
      case EdgeSide.left:
        if (tableEndpoint.offsetCells >= table.heightCells) return const [];
        return [GridCoordinate(
          row: table.topRow + tableEndpoint.offsetCells,
          column: table.leftColumn - 1,
        )];
    }
  }

  static bool _sameEndpointPair(
    DistanceEndpointModel firstStart,
    DistanceEndpointModel firstEnd,
    DistanceEndpointModel secondStart,
    DistanceEndpointModel secondEnd,
  ) {
    return (firstStart == secondStart && firstEnd == secondEnd) ||
        (firstStart == secondEnd && firstEnd == secondStart);
  }
}

class _ResolvedDistance {
  final DistanceEndpointModel start;
  final DistanceEndpointModel end;

  const _ResolvedDistance(this.start, this.end);
}
