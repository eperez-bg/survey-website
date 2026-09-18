class Spigot {
  /// Grid-line coordinates are intersections, not occupied cells.
  final int rowLine;
  final int columnLine;

  /// The pressure recorded for this physical spigot.
  ///
  /// This is nullable only so older in-progress surveys that did not store PSI
  /// on map spigots can still be restored. New placements always provide it,
  /// and survey completion rejects any spigot whose reading is missing.
  final double? pressurePsi;

  Spigot({required this.rowLine, required this.columnLine, this.pressurePsi}) {
    if (rowLine < 0 || columnLine < 0) {
      throw ArgumentError('Spigot coordinates cannot be negative.');
    }
    final pressure = pressurePsi;
    if (pressure != null && (!pressure.isFinite || pressure < 0)) {
      throw ArgumentError('pressurePsi must be a finite, non-negative value.');
    }
  }

  Map<String, dynamic> toJson() => {
    'rowLine': rowLine,
    'columnLine': columnLine,
    'pressurePsi': pressurePsi,
  };

  factory Spigot.fromJson(Map<String, dynamic> json) => Spigot(
    rowLine: json['rowLine'] as int,
    columnLine: json['columnLine'] as int,
    pressurePsi: (json['pressurePsi'] as num?)?.toDouble(),
  );

  Spigot copyWith({double? pressurePsi}) => Spigot(
    rowLine: rowLine,
    columnLine: columnLine,
    pressurePsi: pressurePsi ?? this.pressurePsi,
  );

  /// Coordinate identity keeps a grid intersection unique while PSI changes.
  @override
  bool operator ==(Object other) =>
      other is Spigot &&
      rowLine == other.rowLine &&
      columnLine == other.columnLine;

  @override
  int get hashCode => Object.hash(rowLine, columnLine);
}
