class RoomBounds {
  final int topRow;
  final int leftColumn;
  final int widthCells;
  final int heightCells;

  RoomBounds({
    required this.topRow,
    required this.leftColumn,
    required this.widthCells,
    required this.heightCells,
  }) {
    if (topRow < 0 || leftColumn < 0) {
      throw ArgumentError('Room position cannot be negative.');
    }
    if (widthCells <= 0 || heightCells <= 0) {
      throw ArgumentError('Room dimensions must be greater than zero.');
    }
  }

  int get bottomRowExclusive => topRow + heightCells;
  int get rightColumnExclusive => leftColumn + widthCells;

  bool containsCell({required int row, required int column}) {
    return row >= topRow &&
        row < bottomRowExclusive &&
        column >= leftColumn &&
        column < rightColumnExclusive;
  }

  Map<String, dynamic> toJson() => {
        'topRow': topRow,
        'leftColumn': leftColumn,
        'widthCells': widthCells,
        'heightCells': heightCells,
      };

  factory RoomBounds.fromJson(Map<String, dynamic> json) => RoomBounds(
        topRow: json['topRow'] as int,
        leftColumn: json['leftColumn'] as int,
        widthCells: json['widthCells'] as int,
        heightCells: json['heightCells'] as int,
      );
}

