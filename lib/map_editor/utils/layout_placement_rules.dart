import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'grid_geometry.dart';
import 'distance_geometry.dart';
import 'entrance_placement_rules.dart';

/// Stateless placement and resize validation shared by editor features.
///
/// The controller owns user interaction state. This utility only answers
/// geometry questions about a supplied [GardenCenterLayout].
class LayoutPlacementRules {
  const LayoutPlacementRules._();

  static String? tableGroupPlacementError({
    required List<LayoutTable> candidates,
    required GardenCenterLayout layout,
    Set<String> ignoredTableIds = const {},
  }) {
    for (final candidate in candidates) {
      if (!_tableFitsInsideCanvas(candidate, layout)) {
        return 'Tables must fit completely inside the canvas.';
      }

      if (_tableCrossesRoomWall(candidate, layout.roomBounds)) {
        return 'Tables cannot cross a room wall.';
      }

      if (_overlapsEntranceClearance(candidate, layout)) {
        return 'Nothing can be placed in front of the entrance.';
      }

      if (_overlapsNoInstallZone(candidate, layout)) {
        return 'Tables cannot be placed in a No Install Zone.';
      }

      for (final existingTable in layout.layoutTableList) {
        if (ignoredTableIds.contains(existingTable.tableId)) {
          continue;
        }

        if (_tablesOverlap(candidate, existingTable)) {
          return 'Tables cannot overlap.';
        }
      }

      for (final distance in layout.distanceList) {
        final distanceCells = DistanceGeometry.cellsForDistance(distance, layout);
        final overlapsDistance = distanceCells.any(
          (cell) =>
              cell.row >= candidate.topRow &&
              cell.row < candidate.bottomRowExclusive &&
              cell.column >= candidate.leftColumn &&
              cell.column < candidate.rightColumnExclusive,
        );
        if (overlapsDistance) {
          return 'Tables cannot overlap distances.';
        }
      }
    }

    for (var firstIndex = 0; firstIndex < candidates.length; firstIndex += 1) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < candidates.length;
        secondIndex += 1
      ) {
        if (_tablesOverlap(candidates[firstIndex], candidates[secondIndex])) {
          return 'Tables cannot overlap.';
        }
      }
    }

    return null;
  }

  static String? distanceCellsPlacementError({
    required Iterable<GridCoordinate> cells,
    required GardenCenterLayout layout,
    String? ignoredDistanceId,
  }) {
    for (final cell in cells) {
      final error = _distanceCellPlacementError(
        cell,
        layout,
        ignoredDistanceId: ignoredDistanceId,
      );
      if (error != null) {
        return error;
      }
    }

    return null;
  }

  /// Validates a new No Install Zone rectangle before it is persisted.
  ///
  /// Existing No Install Zone cells are intentionally allowed so neighboring
  /// or partially overlapping rectangles can be combined and later removed.
  static String? noInstallZonePlacementError({
    required Iterable<GridCoordinate> cells,
    required GardenCenterLayout layout,
  }) {
    final candidateCells = cells.toSet();

    for (final cell in candidateCells) {
      if (!canvasContainsCell(layout: layout, cell: cell)) {
        return 'No Install Zone cells must be inside the canvas.';
      }

      if (layout.canopyCellList.contains(
        CanopyCell(row: cell.row, column: cell.column),
      )) {
        return 'A No Install Zone cannot overlap a canopy.';
      }

      if (_tableAtCell(cell, layout) != null) {
        return 'Move tables out of the No Install Zone first.';
      }
    }

    for (final distance in layout.distanceList) {
      if (DistanceGeometry.cellsForDistance(
        distance,
        layout,
      ).any(candidateCells.contains)) {
        return 'Delete distances crossing the No Install Zone first.';
      }
    }

    return null;
  }

  static String? canopyCellsPlacementError({
    required Iterable<GridCoordinate> cells,
    required GardenCenterLayout layout,
  }) {
    for (final cell in cells) {
      if (_isNoInstallZoneCell(cell, layout)) {
        return 'A canopy cannot overlap a No Install Zone.';
      }
    }

    return null;
  }

  static bool tableHasConnectedDistance({
    required String tableId,
    required GardenCenterLayout layout,
  }) {
    return layout.distanceList.any(
      (distance) => DistanceGeometry.distanceReferencesTable(distance, tableId),
    );
  }

  static String? nonDistanceResizeValidationError(GardenCenterLayout layout) {
    if (!_entrancesFitRoom(layout)) {
      return 'An entrance would no longer fit on its wall. Increase the '
          'room or move the entrance first.';
    }

    for (final entrance in layout.entranceList) {
      final entranceError = EntrancePlacementRules.placementError(
        candidate: entrance,
        layout: layout,
        ignoredEntranceId: entrance.entranceId,
      );
      if (entranceError != null) {
        return entranceError;
      }
    }

    for (final table in layout.layoutTableList) {
      if (!_tableFitsInsideCanvas(table, layout)) {
        return 'Fixtures must be moved inside the canvas before resizing.';
      }
      if (_tableCrossesRoomWall(table, layout.roomBounds)) {
        return 'A room wall would cut through a table. Move the table '
            'before resizing.';
      }
      if (_overlapsEntranceClearance(table, layout)) {
        return 'A table would block the entrance after resizing. Move it '
            'before resizing.';
      }
      if (_overlapsNoInstallZone(table, layout)) {
        return 'A table overlaps a No Install Zone. Move it before resizing.';
      }
    }

    for (final canopyCell in layout.canopyCellList) {
      if (!canvasContainsCell(
        layout: layout,
        cell: GridCoordinate(
          row: canopyCell.row,
          column: canopyCell.column,
        ),
      )) {
        return 'Canopy cells must stay inside the resized canvas.';
      }
    }

    for (final noInstallCell in layout.noInstallZoneCellList) {
      if (!canvasContainsCell(
        layout: layout,
        cell: GridCoordinate(
          row: noInstallCell.row,
          column: noInstallCell.column,
        ),
      )) {
        return 'No Install Zone cells must stay inside the resized canvas.';
      }
      if (layout.canopyCellList.contains(
        CanopyCell(row: noInstallCell.row, column: noInstallCell.column),
      )) {
        return 'A No Install Zone cannot overlap a canopy.';
      }
    }

    for (final spigot in layout.spigotList) {
      if (!_spigotFitsLayout(spigot, layout)) {
        return 'Spigots must remain inside the room or on a wall. Move '
            'them before resizing.';
      }
    }

    return null;
  }

  static bool distanceCellsAreValidInLayout(
    Iterable<GridCoordinate> cells,
    GardenCenterLayout layout, {
    required Set<GridCoordinate> occupiedDistanceCells,
  }) {
    final entranceClearances = _entranceClearanceAreas(layout).toList();

    for (final cell in cells) {
      if (!canvasContainsCell(layout: layout, cell: cell) ||
          occupiedDistanceCells.contains(cell) ||
          _isNoInstallZoneCell(cell, layout)) {
        return false;
      }

      for (final table in layout.layoutTableList) {
        final overlapsTable =
            cell.row >= table.topRow &&
            cell.row < table.bottomRowExclusive &&
            cell.column >= table.leftColumn &&
            cell.column < table.rightColumnExclusive;
        if (overlapsTable) {
          return false;
        }
      }

      if (entranceClearances.any((clearance) => clearance.containsCell(cell))) {
        return false;
      }
    }

    return true;
  }

  static String? _distanceCellPlacementError(
    GridCoordinate cell,
    GardenCenterLayout layout, {
    String? ignoredDistanceId,
  }) {
    if (!canvasContainsCell(layout: layout, cell: cell)) {
      return 'Distance cells must stay inside the canvas.';
    }

    if (_isNoInstallZoneCell(cell, layout)) {
      return 'Distances cannot cross a No Install Zone.';
    }

    for (final table in layout.layoutTableList) {
      final overlapsTable =
          cell.row >= table.topRow &&
          cell.row < table.bottomRowExclusive &&
          cell.column >= table.leftColumn &&
          cell.column < table.rightColumnExclusive;
      if (overlapsTable) {
        return 'Distances cannot be placed on tables.';
      }
    }

    for (final distance in layout.distanceList) {
      if (distance.distanceId == ignoredDistanceId) {
        continue;
      }
      if (DistanceGeometry.cellsForDistance(distance, layout).contains(cell)) {
        return 'Distances cannot overlap another distance.';
      }
    }

    for (final clearance in _entranceClearanceAreas(layout)) {
      if (clearance.containsCell(cell)) {
        return 'Distances cannot block the entrance.';
      }
    }

    // Canopies may cover fixtures and distance cells. DistanceGeometry
    // separately verifies that a saved canopy endpoint is on its perimeter.
    return null;
  }

  static bool _tableFitsInsideCanvas(
    LayoutTable table,
    GardenCenterLayout layout,
  ) {
    return table.topRow >= 0 &&
        table.leftColumn >= 0 &&
        table.bottomRowExclusive <= layout.canvasRows &&
        table.rightColumnExclusive <= layout.canvasColumns;
  }

  static bool _tableCrossesRoomWall(LayoutTable table, RoomBounds room) {
    final overlapsRoom = _areasOverlap(
      firstTop: table.topRow,
      firstLeft: table.leftColumn,
      firstBottom: table.bottomRowExclusive,
      firstRight: table.rightColumnExclusive,
      secondTop: room.topRow,
      secondLeft: room.leftColumn,
      secondBottom: room.bottomRowExclusive,
      secondRight: room.rightColumnExclusive,
    );
    final isFullyInside =
        table.topRow >= room.topRow &&
        table.leftColumn >= room.leftColumn &&
        table.bottomRowExclusive <= room.bottomRowExclusive &&
        table.rightColumnExclusive <= room.rightColumnExclusive;

    return overlapsRoom && !isFullyInside;
  }

  static bool _tablesOverlap(LayoutTable first, LayoutTable second) {
    return _areasOverlap(
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

  static bool _overlapsEntranceClearance(
    LayoutTable table,
    GardenCenterLayout layout,
  ) {
    for (final clearance in _entranceClearanceAreas(layout)) {
      if (_areasOverlap(
        firstTop: table.topRow,
        firstLeft: table.leftColumn,
        firstBottom: table.bottomRowExclusive,
        firstRight: table.rightColumnExclusive,
        secondTop: clearance.topRow,
        secondLeft: clearance.leftColumn,
        secondBottom: clearance.bottomRowExclusive,
        secondRight: clearance.rightColumnExclusive,
      )) {
        return true;
      }
    }

    return false;
  }

  static bool _overlapsNoInstallZone(
    LayoutTable table,
    GardenCenterLayout layout,
  ) {
    return layout.noInstallZoneCellList.any(
      (cell) =>
          cell.row >= table.topRow &&
          cell.row < table.bottomRowExclusive &&
          cell.column >= table.leftColumn &&
          cell.column < table.rightColumnExclusive,
    );
  }

  static LayoutTable? _tableAtCell(
    GridCoordinate cell,
    GardenCenterLayout layout,
  ) {
    for (final table in layout.layoutTableList) {
      final containsCell =
          cell.row >= table.topRow &&
          cell.row < table.bottomRowExclusive &&
          cell.column >= table.leftColumn &&
          cell.column < table.rightColumnExclusive;
      if (containsCell) {
        return table;
      }
    }

    return null;
  }

  static bool _isNoInstallZoneCell(
    GridCoordinate cell,
    GardenCenterLayout layout,
  ) {
    return layout.noInstallZoneCellList.contains(
      NoInstallZoneCell(row: cell.row, column: cell.column),
    );
  }

  static Iterable<EntranceClearanceArea> _entranceClearanceAreas(
    GardenCenterLayout layout,
  ) sync* {
    for (final entrance in layout.entranceList) {
      yield EntrancePlacementRules.clearanceAreaFor(
        entrance: entrance,
        roomBounds: layout.roomBounds,
      );
    }
  }

  static bool _areasOverlap({
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

  static bool _entrancesFitRoom(GardenCenterLayout layout) {
    final room = layout.roomBounds;

    for (final entrance in layout.entranceList) {
      final wallLength =
          entrance.wallSide == WallSide.top ||
              entrance.wallSide == WallSide.bottom
          ? room.widthCells
          : room.heightCells;
      if (entrance.offsetCells + entrance.widthCells > wallLength) {
        return false;
      }
    }

    return true;
  }

  static bool _spigotFitsLayout(Spigot spigot, GardenCenterLayout layout) {
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

  /// True when [cell] is a drawable cell anywhere on the saved canvas.
  ///
  /// Canopies and No Install Zones intentionally use canvas bounds rather
  /// than room bounds because both areas may describe outdoor installation
  /// conditions.
  static bool canvasContainsCell({
    required GardenCenterLayout layout,
    required GridCoordinate cell,
  }) {
    return cell.row >= 0 &&
        cell.row < layout.canvasRows &&
        cell.column >= 0 &&
        cell.column < layout.canvasColumns;
  }
}
