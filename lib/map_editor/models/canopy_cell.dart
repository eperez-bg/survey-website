// canopy_cell.dart
//
// Responsibility:
// Represents one occupied grid cell within a measured canopy area. The
// measurements are repeated on every cell created by one confirmation so the
// existing cell-based map and JSON format remain backward compatible.
//
// Classes:
// - CanopyCell: Stores the cell coordinate and canopy dimensions in inches.

class CanopyCell {
  final int row;
  final int column;
  final double? heightInches;
  final double? lengthInches;
  final double? widthInches;

  CanopyCell({
    required this.row,
    required this.column,
    this.heightInches,
    this.lengthInches,
    this.widthInches,
  }) {
    if (row < 0 || column < 0) {
      throw ArgumentError('Canopy cell coordinates cannot be negative.');
    }
    if (heightInches != null &&
        (!heightInches!.isFinite || heightInches! <= 0)) {
      throw ArgumentError('Canopy height must be greater than zero.');
    }
    if (lengthInches != null &&
        (!lengthInches!.isFinite || lengthInches! <= 0)) {
      throw ArgumentError('Canopy length must be greater than zero.');
    }
    if (widthInches != null &&
        (!widthInches!.isFinite || widthInches! <= 0)) {
      throw ArgumentError('Canopy width must be greater than zero.');
    }
  }

  /// Retained for code that only needs to know whether height was measured.
  bool get hasMeasuredHeight => heightInches != null;

  /// True after the surveyor has supplied every measurement required for
  /// current uploads and backend reconstruction.
  bool get hasCompleteMeasurements =>
      heightInches != null && lengthInches != null && widthInches != null;

  Map<String, dynamic> toJson() => {
    'row': row,
    'column': column,
    'heightInches': heightInches,
    'lengthInches': lengthInches,
    'widthInches': widthInches,
  };

  /// Loads current cells and legacy cells created before all dimensions
  /// existed.
  ///
  /// Missing measurements remain null so unfinished surveys can still open.
  /// Submission validation then guides the user to remeasure the old canopy.
  factory CanopyCell.fromJson(Map<String, dynamic> json) => CanopyCell(
    row: json['row'] as int,
    column: json['column'] as int,
    heightInches: (json['heightInches'] as num?)?.toDouble(),
    lengthInches: (json['lengthInches'] as num?)?.toDouble(),
    widthInches: (json['widthInches'] as num?)?.toDouble(),
  );

  /// Grid coordinates define cell identity. Measurements are metadata, so
  /// ignoring them lets sets find, replace, and remove the same cell reliably.
  @override
  bool operator ==(Object other) =>
      other is CanopyCell && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}
