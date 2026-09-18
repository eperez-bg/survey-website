// no_install_zone_cell.dart
//
// Responsibility:
// Represents one persisted grid cell where fixtures and distance paths cannot
// be installed. Coordinates define identity so rectangular areas can be added,
// merged, removed, shifted during resize, and rebuilt from uploaded JSON.

class NoInstallZoneCell {
  final int row;
  final int column;

  NoInstallZoneCell({required this.row, required this.column}) {
    if (row < 0 || column < 0) {
      throw ArgumentError(
        'No Install Zone cell coordinates cannot be negative.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'row': row,
    'column': column,
  };

  factory NoInstallZoneCell.fromJson(Map<String, dynamic> json) =>
      NoInstallZoneCell(
        row: json['row'] as int,
        column: json['column'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is NoInstallZoneCell &&
      row == other.row &&
      column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}
