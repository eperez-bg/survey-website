import 'survey_enums.dart';

sealed class DistanceEndpoint {
  const DistanceEndpoint();

  Map<String, dynamic> toJson();

  factory DistanceEndpoint.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'table':
        return TableDistanceEndpoint.fromJson(json);
      case 'canopy':
        return CanopyDistanceEndpoint.fromJson(json);
      case 'wall':
        return WallDistanceEndpoint.fromJson(json);
      default:
        throw FormatException(
          'Unknown DistanceEndpoint type: ${json['type']}',
        );
    }
  }
}

final class TableDistanceEndpoint extends DistanceEndpoint {
  final String tableId;
  final EdgeSide edgeSide;

  /// Offset along the selected table edge.
  final int offsetCells;

  TableDistanceEndpoint({
    required this.tableId,
    required this.edgeSide,
    required this.offsetCells,
  }) {
    if (tableId.trim().isEmpty) {
      throw ArgumentError('tableId cannot be empty.');
    }
    if (offsetCells < 0) {
      throw ArgumentError('offsetCells cannot be negative.');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'table',
        'tableId': tableId,
        'edgeSide': edgeSide.jsonValue,
        'offsetCells': offsetCells,
      };

  factory TableDistanceEndpoint.fromJson(Map<String, dynamic> json) =>
      TableDistanceEndpoint(
        tableId: json['tableId'] as String,
        edgeSide: EdgeSide.fromJson(json['edgeSide'] as String),
        offsetCells: json['offsetCells'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is TableDistanceEndpoint &&
      tableId == other.tableId &&
      edgeSide == other.edgeSide &&
      offsetCells == other.offsetCells;

  @override
  int get hashCode => Object.hash(tableId, edgeSide, offsetCells);
}

/// One grid-cell segment on the outside perimeter of a canopy.
///
/// Canopies remain cell-based in the layout model. Saving the referenced cell
/// and one of its four sides identifies the exact edge segment without adding
/// a second canopy identity system.
final class CanopyDistanceEndpoint extends DistanceEndpoint {
  final int row;
  final int column;
  final EdgeSide edgeSide;

  CanopyDistanceEndpoint({
    required this.row,
    required this.column,
    required this.edgeSide,
  }) {
    if (row < 0 || column < 0) {
      throw ArgumentError('Canopy endpoint coordinates cannot be negative.');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'canopy',
        'row': row,
        'column': column,
        'edgeSide': edgeSide.jsonValue,
      };

  factory CanopyDistanceEndpoint.fromJson(Map<String, dynamic> json) =>
      CanopyDistanceEndpoint(
        row: json['row'] as int,
        column: json['column'] as int,
        edgeSide: EdgeSide.fromJson(json['edgeSide'] as String),
      );

  CanopyDistanceEndpoint translated({
    required int rowDelta,
    required int columnDelta,
  }) =>
      CanopyDistanceEndpoint(
        row: row + rowDelta,
        column: column + columnDelta,
        edgeSide: edgeSide,
      );

  @override
  bool operator ==(Object other) =>
      other is CanopyDistanceEndpoint &&
      row == other.row &&
      column == other.column &&
      edgeSide == other.edgeSide;

  @override
  int get hashCode => Object.hash(row, column, edgeSide);
}

final class WallDistanceEndpoint extends DistanceEndpoint {
  final WallSide wallSide;

  /// Offset along the wall's top/left starting corner.
  final int offsetCells;

  WallDistanceEndpoint({
    required this.wallSide,
    required this.offsetCells,
  }) {
    if (offsetCells < 0) {
      throw ArgumentError('offsetCells cannot be negative.');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'wall',
        'wallSide': wallSide.jsonValue,
        'offsetCells': offsetCells,
      };

  factory WallDistanceEndpoint.fromJson(Map<String, dynamic> json) =>
      WallDistanceEndpoint(
        wallSide: WallSide.fromJson(json['wallSide'] as String),
        offsetCells: json['offsetCells'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is WallDistanceEndpoint &&
      wallSide == other.wallSide &&
      offsetCells == other.offsetCells;

  @override
  int get hashCode => Object.hash(wallSide, offsetCells);
}
