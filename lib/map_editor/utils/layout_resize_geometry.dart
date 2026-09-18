import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

enum LayoutResizeTarget { canvas, room }

enum LayoutResizeSide { top, right, bottom, left }

/// A rectangular strip of grid cells using exclusive bottom/right edges.
class GridCellArea {
  final int topRow;
  final int leftColumn;
  final int bottomRowExclusive;
  final int rightColumnExclusive;

  const GridCellArea({
    required this.topRow,
    required this.leftColumn,
    required this.bottomRowExclusive,
    required this.rightColumnExclusive,
  });

  bool containsCell({required int row, required int column}) {
    return row >= topRow &&
        row < bottomRowExclusive &&
        column >= leftColumn &&
        column < rightColumnExclusive;
  }

  bool overlapsTable(LayoutTable table) {
    return table.leftColumn < rightColumnExclusive &&
        table.rightColumnExclusive > leftColumn &&
        table.topRow < bottomRowExclusive &&
        table.bottomRowExclusive > topRow;
  }
}

/// Pure output from calculating one requested boundary movement.
///
/// Canvas cells inserted or removed at the top/left use [rowShift] and
/// [columnShift] because those operations change every absolute coordinate.
class LayoutResizeCalculation {
  final int canvasRows;
  final int canvasColumns;
  final RoomBounds roomBounds;
  final int rowShift;
  final int columnShift;
  final GridCellArea? removedArea;
  final String? error;

  const LayoutResizeCalculation._({
    required this.canvasRows,
    required this.canvasColumns,
    required this.roomBounds,
    this.rowShift = 0,
    this.columnShift = 0,
    this.removedArea,
    this.error,
  });

  const LayoutResizeCalculation.success({
    required int canvasRows,
    required int canvasColumns,
    required RoomBounds roomBounds,
    int rowShift = 0,
    int columnShift = 0,
    GridCellArea? removedArea,
  }) : this._(
         canvasRows: canvasRows,
         canvasColumns: canvasColumns,
         roomBounds: roomBounds,
         rowShift: rowShift,
         columnShift: columnShift,
         removedArea: removedArea,
       );

  LayoutResizeCalculation.failure({
    required int canvasRows,
    required int canvasColumns,
    required RoomBounds roomBounds,
    required String error,
  }) : this._(
         canvasRows: canvasRows,
         canvasColumns: canvasColumns,
         roomBounds: roomBounds,
         error: error,
       );

  bool get succeeded => error == null;
}

/// Calculates boundary coordinates without inspecting or mutating fixtures.
class LayoutResizeGeometry {
  const LayoutResizeGeometry._();

  static LayoutResizeCalculation calculate({
    required LayoutResizeTarget target,
    required LayoutResizeSide side,
    required int deltaCells,
    required int canvasRows,
    required int canvasColumns,
    required RoomBounds roomBounds,
  }) {
    if (deltaCells == 0) {
      return LayoutResizeCalculation.failure(
        canvasRows: canvasRows,
        canvasColumns: canvasColumns,
        roomBounds: roomBounds,
        error: 'Resize amount cannot be zero.',
      );
    }

    return target == LayoutResizeTarget.canvas
        ? _calculateCanvasResize(
            side: side,
            deltaCells: deltaCells,
            canvasRows: canvasRows,
            canvasColumns: canvasColumns,
            roomBounds: roomBounds,
          )
        : _calculateRoomResize(
            side: side,
            deltaCells: deltaCells,
            canvasRows: canvasRows,
            canvasColumns: canvasColumns,
            roomBounds: roomBounds,
          );
  }

  static LayoutResizeCalculation _calculateCanvasResize({
    required LayoutResizeSide side,
    required int deltaCells,
    required int canvasRows,
    required int canvasColumns,
    required RoomBounds roomBounds,
  }) {
    var nextRows = canvasRows;
    var nextColumns = canvasColumns;
    var rowShift = 0;
    var columnShift = 0;

    switch (side) {
      case LayoutResizeSide.top:
        nextRows += deltaCells;
        rowShift = deltaCells;
        break;
      case LayoutResizeSide.right:
        nextColumns += deltaCells;
        break;
      case LayoutResizeSide.bottom:
        nextRows += deltaCells;
        break;
      case LayoutResizeSide.left:
        nextColumns += deltaCells;
        columnShift = deltaCells;
        break;
    }

    if (nextRows <= 0 || nextColumns <= 0) {
      return LayoutResizeCalculation.failure(
        canvasRows: canvasRows,
        canvasColumns: canvasColumns,
        roomBounds: roomBounds,
        error: 'The canvas must remain at least one cell wide and tall.',
      );
    }

    final nextRoomTop = roomBounds.topRow + rowShift;
    final nextRoomLeft = roomBounds.leftColumn + columnShift;
    if (nextRoomTop < 0 || nextRoomLeft < 0) {
      return LayoutResizeCalculation.failure(
        canvasRows: canvasRows,
        canvasColumns: canvasColumns,
        roomBounds: roomBounds,
        error: 'The canvas edge cannot move past the room.',
      );
    }

    final nextRoom = RoomBounds(
      topRow: nextRoomTop,
      leftColumn: nextRoomLeft,
      widthCells: roomBounds.widthCells,
      heightCells: roomBounds.heightCells,
    );

    if (!_roomFitsCanvas(nextRoom, nextRows, nextColumns)) {
      return LayoutResizeCalculation.failure(
        canvasRows: canvasRows,
        canvasColumns: canvasColumns,
        roomBounds: roomBounds,
        error: 'The canvas edge cannot move past the room.',
      );
    }

    return LayoutResizeCalculation.success(
      canvasRows: nextRows,
      canvasColumns: nextColumns,
      roomBounds: nextRoom,
      rowShift: rowShift,
      columnShift: columnShift,
      removedArea: deltaCells < 0
          ? _removedCanvasArea(
              side: side,
              removedCells: -deltaCells,
              oldRows: canvasRows,
              oldColumns: canvasColumns,
              newRows: nextRows,
              newColumns: nextColumns,
            )
          : null,
    );
  }

  static LayoutResizeCalculation _calculateRoomResize({
    required LayoutResizeSide side,
    required int deltaCells,
    required int canvasRows,
    required int canvasColumns,
    required RoomBounds roomBounds,
  }) {
    var nextTop = roomBounds.topRow;
    var nextLeft = roomBounds.leftColumn;
    var nextWidth = roomBounds.widthCells;
    var nextHeight = roomBounds.heightCells;
    var nextCanvasRows = canvasRows;
    var nextCanvasColumns = canvasColumns;
    var rowShift = 0;
    var columnShift = 0;

    switch (side) {
      case LayoutResizeSide.top:
        nextTop -= deltaCells;
        nextHeight += deltaCells;
        break;
      case LayoutResizeSide.right:
        nextWidth += deltaCells;
        break;
      case LayoutResizeSide.bottom:
        nextHeight += deltaCells;
        break;
      case LayoutResizeSide.left:
        nextLeft -= deltaCells;
        nextWidth += deltaCells;
        break;
    }

    if (nextWidth <= 0 || nextHeight <= 0) {
      return LayoutResizeCalculation.failure(
        canvasRows: canvasRows,
        canvasColumns: canvasColumns,
        roomBounds: roomBounds,
        error: 'The room must remain at least one cell wide and tall.',
      );
    }
    // Inserting canvas cells on the top or left shifts every absolute grid
    // coordinate. The final room edge is zero, while its opposite edge and all
    // existing fixtures retain their positions relative to the inserted cells.
    if (nextTop < 0) {
      rowShift = -nextTop;
      nextCanvasRows += rowShift;
      nextTop = 0;
    }
    if (nextLeft < 0) {
      columnShift = -nextLeft;
      nextCanvasColumns += columnShift;
      nextLeft = 0;
    }

    final nextRoom = RoomBounds(
      topRow: nextTop,
      leftColumn: nextLeft,
      widthCells: nextWidth,
      heightCells: nextHeight,
    );

    // Right and bottom expansion append only the cells required to contain the
    // requested room. No existing absolute coordinates move on these sides.
    if (nextRoom.bottomRowExclusive > nextCanvasRows) {
      nextCanvasRows = nextRoom.bottomRowExclusive;
    }
    if (nextRoom.rightColumnExclusive > nextCanvasColumns) {
      nextCanvasColumns = nextRoom.rightColumnExclusive;
    }

    return LayoutResizeCalculation.success(
      canvasRows: nextCanvasRows,
      canvasColumns: nextCanvasColumns,
      roomBounds: nextRoom,
      rowShift: rowShift,
      columnShift: columnShift,
      removedArea: deltaCells < 0
          ? _removedRoomArea(side: side, oldRoom: roomBounds, newRoom: nextRoom)
          : null,
    );
  }

  static GridCellArea _removedCanvasArea({
    required LayoutResizeSide side,
    required int removedCells,
    required int oldRows,
    required int oldColumns,
    required int newRows,
    required int newColumns,
  }) {
    return switch (side) {
      LayoutResizeSide.top => GridCellArea(
        topRow: 0,
        leftColumn: 0,
        bottomRowExclusive: removedCells,
        rightColumnExclusive: oldColumns,
      ),
      LayoutResizeSide.right => GridCellArea(
        topRow: 0,
        leftColumn: newColumns,
        bottomRowExclusive: oldRows,
        rightColumnExclusive: oldColumns,
      ),
      LayoutResizeSide.bottom => GridCellArea(
        topRow: newRows,
        leftColumn: 0,
        bottomRowExclusive: oldRows,
        rightColumnExclusive: oldColumns,
      ),
      LayoutResizeSide.left => GridCellArea(
        topRow: 0,
        leftColumn: 0,
        bottomRowExclusive: oldRows,
        rightColumnExclusive: removedCells,
      ),
    };
  }

  static GridCellArea _removedRoomArea({
    required LayoutResizeSide side,
    required RoomBounds oldRoom,
    required RoomBounds newRoom,
  }) {
    return switch (side) {
      LayoutResizeSide.top => GridCellArea(
        topRow: oldRoom.topRow,
        leftColumn: oldRoom.leftColumn,
        bottomRowExclusive: newRoom.topRow,
        rightColumnExclusive: oldRoom.rightColumnExclusive,
      ),
      LayoutResizeSide.right => GridCellArea(
        topRow: oldRoom.topRow,
        leftColumn: newRoom.rightColumnExclusive,
        bottomRowExclusive: oldRoom.bottomRowExclusive,
        rightColumnExclusive: oldRoom.rightColumnExclusive,
      ),
      LayoutResizeSide.bottom => GridCellArea(
        topRow: newRoom.bottomRowExclusive,
        leftColumn: oldRoom.leftColumn,
        bottomRowExclusive: oldRoom.bottomRowExclusive,
        rightColumnExclusive: oldRoom.rightColumnExclusive,
      ),
      LayoutResizeSide.left => GridCellArea(
        topRow: oldRoom.topRow,
        leftColumn: oldRoom.leftColumn,
        bottomRowExclusive: oldRoom.bottomRowExclusive,
        rightColumnExclusive: newRoom.leftColumn,
      ),
    };
  }

  static bool _roomFitsCanvas(
    RoomBounds room,
    int canvasRows,
    int canvasColumns,
  ) {
    return room.topRow >= 0 &&
        room.leftColumn >= 0 &&
        room.bottomRowExclusive <= canvasRows &&
        room.rightColumnExclusive <= canvasColumns;
  }
}
