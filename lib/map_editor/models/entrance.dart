import 'survey_enums.dart';

class Entrance {
  final String entranceId;
  final WallSide wallSide;

  /// Distance, in cells, from the wall's top/left starting corner.
  final int offsetCells;

  final int widthCells;

  /// Number of cells that must remain empty in front of the entrance.
  final int clearanceDepthCells;

  Entrance({
    required this.entranceId,
    required this.wallSide,
    required this.offsetCells,
    required this.widthCells,
    required this.clearanceDepthCells,
  }) {
    if (entranceId.trim().isEmpty) {
      throw ArgumentError('entranceId cannot be empty.');
    }
    if (offsetCells < 0) {
      throw ArgumentError('offsetCells cannot be negative.');
    }
    if (widthCells <= 0) {
      throw ArgumentError('widthCells must be greater than zero.');
    }
    if (clearanceDepthCells < 0) {
      throw ArgumentError('clearanceDepthCells cannot be negative.');
    }
  }

  Map<String, dynamic> toJson() => {
        'entranceId': entranceId,
        'wallSide': wallSide.jsonValue,
        'offsetCells': offsetCells,
        'widthCells': widthCells,
        'clearanceDepthCells': clearanceDepthCells,
      };

  factory Entrance.fromJson(Map<String, dynamic> json) => Entrance(
        entranceId: json['entranceId'] as String,
        wallSide: WallSide.fromJson(json['wallSide'] as String),
        offsetCells: json['offsetCells'] as int,
        widthCells: json['widthCells'] as int,
        clearanceDepthCells: json['clearanceDepthCells'] as int,
      );
}

