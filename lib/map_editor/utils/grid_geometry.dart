import 'dart:ui';

class GridCoordinate {
  final int row;
  final int column;

  const GridCoordinate({
    required this.row,
    required this.column,
  });

  @override
  bool operator ==(Object other) =>
      other is GridCoordinate &&
      row == other.row &&
      column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}

class GridIntersection {
  final int rowLine;
  final int columnLine;

  const GridIntersection({
    required this.rowLine,
    required this.columnLine,
  });
}

/// Converts between scene pixels and integer grid coordinates.
///
/// Cell size is only a display measurement. The saved layout continues to use
/// integer rows and columns and has no dependency on physical inches.
class GridGeometry {
  final double cellSize;

  const GridGeometry({required this.cellSize});

  GridCoordinate scenePointToCell(Offset scenePoint) {
    return GridCoordinate(
      row: (scenePoint.dy / cellSize).floor(),
      column: (scenePoint.dx / cellSize).floor(),
    );
  }

  GridCoordinate centeredTableTopLeft({
    required Offset scenePoint,
    required int widthCells,
    required int heightCells,
  }) {
    return GridCoordinate(
      row: ((scenePoint.dy / cellSize) - (heightCells / 2)).round(),
      column: ((scenePoint.dx / cellSize) - (widthCells / 2)).round(),
    );
  }

  GridIntersection scenePointToNearestIntersection(Offset scenePoint) {
    return GridIntersection(
      rowLine: (scenePoint.dy / cellSize).round(),
      columnLine: (scenePoint.dx / cellSize).round(),
    );
  }

  Rect cellRect({required int row, required int column}) {
    return Rect.fromLTWH(
      column * cellSize,
      row * cellSize,
      cellSize,
      cellSize,
    );
  }
}
