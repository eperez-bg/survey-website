// survey_map_model.dart
//
// Responsibility:
// Represents the persisted map contract used by survey-app schema 9. Parsing is
// intentionally tolerant enough to display older ramp-based survey versions,
// while all new edits continue to use the current distance-based field names.
//
// Main types:
// - SurveyMapModel: complete gardenCenterLayout data.
// - LayoutTableModel: one physical 2x3/3x2 table rectangle.
// - DistanceModel/DistanceEndpointModel: saved measured-distance geometry.
// - EntranceModel, SpigotModel, CanopyCellModel, ZoneModel, RoomBoundsModel.

import '../utils/json_utils.dart';

enum TableKind { normal, hangingBasket, custom }

enum TableOrientation { horizontal, vertical }

enum WallSide { top, right, bottom, left }

enum EdgeSide { top, right, bottom, left }

extension TableKindJson on TableKind {
  String get jsonValue => switch (this) {
        TableKind.normal => 'normal',
        TableKind.hangingBasket => 'hanging_basket',
        TableKind.custom => 'custom',
      };
}

extension TableOrientationJson on TableOrientation {
  String get jsonValue => name;
}

extension WallSideJson on WallSide {
  String get jsonValue => name;
}

extension EdgeSideJson on EdgeSide {
  String get jsonValue => name;
}

class GridCoordinate {
  final int row;
  final int column;

  const GridCoordinate({required this.row, required this.column});

  @override
  bool operator ==(Object other) =>
      other is GridCoordinate && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}

class RoomBoundsModel {
  final int topRow;
  final int leftColumn;
  final int widthCells;
  final int heightCells;

  const RoomBoundsModel({
    required this.topRow,
    required this.leftColumn,
    required this.widthCells,
    required this.heightCells,
  });

  int get bottomRowExclusive => topRow + heightCells;
  int get rightColumnExclusive => leftColumn + widthCells;

  bool containsCell(GridCoordinate cell) =>
      cell.row >= topRow &&
      cell.row < bottomRowExclusive &&
      cell.column >= leftColumn &&
      cell.column < rightColumnExclusive;

  factory RoomBoundsModel.fromJson(Map<String, dynamic> json) {
    return RoomBoundsModel(
      topRow: _requiredInt(json, 'topRow'),
      leftColumn: _requiredInt(json, 'leftColumn'),
      widthCells: _requiredInt(json, 'widthCells'),
      heightCells: _requiredInt(json, 'heightCells'),
    );
  }
}

class LayoutTableModel {
  final String tableId;
  final String? zoneId;
  final String? pairId;
  final int topRow;
  final int leftColumn;
  final TableKind tableKind;
  final TableOrientation orientation;
  final String? customName;

  const LayoutTableModel({
    required this.tableId,
    required this.zoneId,
    required this.pairId,
    required this.topRow,
    required this.leftColumn,
    required this.tableKind,
    required this.orientation,
    required this.customName,
  });

  int get widthCells => orientation == TableOrientation.horizontal ? 3 : 2;
  int get heightCells => orientation == TableOrientation.horizontal ? 2 : 3;
  int get bottomRowExclusive => topRow + heightCells;
  int get rightColumnExclusive => leftColumn + widthCells;
  String get logicalKey =>
      pairId == null ? 'legacy-table:$tableId' : 'table-pair:$pairId';

  LayoutTableModel translated({required int rowDelta, required int columnDelta}) {
    return LayoutTableModel(
      tableId: tableId,
      zoneId: zoneId,
      pairId: pairId,
      topRow: topRow + rowDelta,
      leftColumn: leftColumn + columnDelta,
      tableKind: tableKind,
      orientation: orientation,
      customName: customName,
    );
  }

  factory LayoutTableModel.fromJson(Map<String, dynamic> json) {
    final tableId = nullableString(json['tableId']);
    if (tableId == null) {
      throw const FormatException('A map table is missing tableId.');
    }

    return LayoutTableModel(
      tableId: tableId,
      zoneId: nullableString(json['zoneId']),
      pairId: nullableString(json['pairId']),
      topRow: _requiredInt(json, 'topRow'),
      leftColumn: _requiredInt(json, 'leftColumn'),
      tableKind: _tableKind(json['tableKind']),
      orientation: _tableOrientation(json['orientation']),
      customName: nullableString(json['customName']),
    );
  }
}

class ZoneModel {
  final String zoneId;
  final String label;
  final String colorHex;

  const ZoneModel({
    required this.zoneId,
    required this.label,
    required this.colorHex,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    final id = nullableString(json['zoneId']);
    if (id == null) {
      throw const FormatException('A zone is missing zoneId.');
    }
    return ZoneModel(
      zoneId: id,
      label: nullableString(json['label']) ?? id,
      colorHex: nullableString(json['colorHex']) ?? '#94A3B8',
    );
  }
}

class CanopyCellModel {
  final int row;
  final int column;
  final double? heightInches;
  final double? lengthInches;
  final double? widthInches;

  const CanopyCellModel({
    required this.row,
    required this.column,
    required this.heightInches,
    required this.lengthInches,
    required this.widthInches,
  });

  bool get hasCompleteMeasurements =>
      heightInches != null && lengthInches != null && widthInches != null;

  String get measurementKey =>
      '${heightInches ?? 'null'}|${lengthInches ?? 'null'}|${widthInches ?? 'null'}';

  factory CanopyCellModel.fromJson(Map<String, dynamic> json) {
    return CanopyCellModel(
      row: _requiredInt(json, 'row'),
      column: _requiredInt(json, 'column'),
      heightInches: nullableDouble(json['heightInches']),
      lengthInches: nullableDouble(json['lengthInches']),
      widthInches: nullableDouble(json['widthInches']),
    );
  }
}

class SpigotModel {
  final int rowLine;
  final int columnLine;
  final double? pressurePsi;

  const SpigotModel({
    required this.rowLine,
    required this.columnLine,
    required this.pressurePsi,
  });

  String get key => '$rowLine:$columnLine';

  factory SpigotModel.fromJson(Map<String, dynamic> json) {
    return SpigotModel(
      rowLine: _requiredInt(json, 'rowLine'),
      columnLine: _requiredInt(json, 'columnLine'),
      pressurePsi: nullableDouble(json['pressurePsi']),
    );
  }
}

sealed class DistanceEndpointModel {
  const DistanceEndpointModel();

  factory DistanceEndpointModel.fromJson(Map<String, dynamic> json) {
    final type = nullableString(json['type'] ?? json['targetKind'])?.toLowerCase();
    if (type == 'table' || json.containsKey('tableId')) {
      final tableId = nullableString(json['tableId']);
      if (tableId == null) {
        throw const FormatException('A table distance endpoint is missing tableId.');
      }
      return TableDistanceEndpointModel(
        tableId: tableId,
        edgeSide: _edgeSide(json['edgeSide']),
        offsetCells: _requiredInt(json, 'offsetCells'),
      );
    }
    if (type == 'wall' || json.containsKey('wallSide')) {
      return WallDistanceEndpointModel(
        wallSide: _wallSide(json['wallSide']),
        offsetCells: _requiredInt(json, 'offsetCells'),
      );
    }
    throw FormatException('Unknown distance endpoint type: ${json['type']}');
  }
}

final class TableDistanceEndpointModel extends DistanceEndpointModel {
  final String tableId;
  final EdgeSide edgeSide;
  final int offsetCells;

  const TableDistanceEndpointModel({
    required this.tableId,
    required this.edgeSide,
    required this.offsetCells,
  });

  @override
  bool operator ==(Object other) =>
      other is TableDistanceEndpointModel &&
      tableId == other.tableId &&
      edgeSide == other.edgeSide &&
      offsetCells == other.offsetCells;

  @override
  int get hashCode => Object.hash(tableId, edgeSide, offsetCells);
}

final class WallDistanceEndpointModel extends DistanceEndpointModel {
  final WallSide wallSide;
  final int offsetCells;

  const WallDistanceEndpointModel({
    required this.wallSide,
    required this.offsetCells,
  });

  @override
  bool operator ==(Object other) =>
      other is WallDistanceEndpointModel &&
      wallSide == other.wallSide &&
      offsetCells == other.offsetCells;

  @override
  int get hashCode => Object.hash(wallSide, offsetCells);
}

class DistanceModel {
  final String distanceId;
  final double measuredDistance;
  final DistanceEndpointModel start;
  final DistanceEndpointModel end;
  final bool isLegacyRamp;

  const DistanceModel({
    required this.distanceId,
    required this.measuredDistance,
    required this.start,
    required this.end,
    this.isLegacyRamp = false,
  });

  factory DistanceModel.fromJson(
    Map<String, dynamic> json, {
    bool legacyRamp = false,
  }) {
    final id = nullableString(
      legacyRamp ? json['rampId'] : json['distanceId'],
    );
    if (id == null) {
      throw FormatException(
        legacyRamp ? 'A legacy ramp is missing rampId.' : 'A distance is missing distanceId.',
      );
    }

    final rawMeasurement = nullableDouble(
      legacyRamp ? json['measuredGap'] : json['measuredDistance'],
    );
    if (rawMeasurement == null) {
      throw FormatException('$id is missing its measured distance.');
    }
    final unit = nullableString(json['measurementUnit'])?.toLowerCase() ?? 'inches';
    final inches = switch (unit) {
      'feet' || 'foot' || 'ft' => rawMeasurement * 12,
      _ => rawMeasurement,
    };

    return DistanceModel(
      distanceId: id,
      measuredDistance: inches,
      start: DistanceEndpointModel.fromJson(mapValue(json['start'])),
      end: DistanceEndpointModel.fromJson(mapValue(json['end'])),
      isLegacyRamp: legacyRamp,
    );
  }
}

class EntranceModel {
  final String entranceId;
  final WallSide wallSide;
  final int offsetCells;
  final int widthCells;
  final int clearanceDepthCells;

  const EntranceModel({
    required this.entranceId,
    required this.wallSide,
    required this.offsetCells,
    required this.widthCells,
    required this.clearanceDepthCells,
  });

  factory EntranceModel.fromJson(Map<String, dynamic> json) {
    final id = nullableString(json['entranceId']);
    if (id == null) {
      throw const FormatException('An entrance is missing entranceId.');
    }
    return EntranceModel(
      entranceId: id,
      wallSide: _wallSide(json['wallSide']),
      offsetCells: _requiredInt(json, 'offsetCells'),
      widthCells: _requiredInt(json, 'widthCells'),
      clearanceDepthCells: nullableInt(json['clearanceDepthCells']) ?? 4,
    );
  }
}

class SurveyMapModel {
  final int canvasRows;
  final int canvasColumns;
  final RoomBoundsModel roomBounds;
  final List<LayoutTableModel> tables;
  final List<ZoneModel> zones;
  final List<CanopyCellModel> canopyCells;
  final List<SpigotModel> spigots;
  final List<DistanceModel> distances;
  final List<EntranceModel> entrances;

  const SurveyMapModel({
    required this.canvasRows,
    required this.canvasColumns,
    required this.roomBounds,
    required this.tables,
    required this.zones,
    required this.canopyCells,
    required this.spigots,
    required this.distances,
    required this.entrances,
  });

  LayoutTableModel? tableById(String tableId) {
    for (final table in tables) {
      if (table.tableId == tableId) {
        return table;
      }
    }
    return null;
  }

  ZoneModel? zoneById(String? zoneId) {
    if (zoneId == null) {
      return null;
    }
    for (final zone in zones) {
      if (zone.zoneId == zoneId) {
        return zone;
      }
    }
    return null;
  }

  factory SurveyMapModel.fromJson(Map<String, dynamic> json) {
    final currentDistances = mapListValue(json['distanceList']);
    final legacyRamps = currentDistances.isEmpty
        ? mapListValue(json['rampList'])
        : const <Map<String, dynamic>>[];

    return SurveyMapModel(
      canvasRows: _requiredInt(json, 'canvasRows'),
      canvasColumns: _requiredInt(json, 'canvasColumns'),
      roomBounds: RoomBoundsModel.fromJson(mapValue(json['roomBounds'])),
      tables: mapListValue(json['layoutTableList'])
          .map(LayoutTableModel.fromJson)
          .toList(growable: false),
      zones: mapListValue(json['zoneList'])
          .map(ZoneModel.fromJson)
          .toList(growable: false),
      canopyCells: mapListValue(json['canopyCellList'])
          .map(CanopyCellModel.fromJson)
          .toList(growable: false),
      spigots: mapListValue(json['spigotList'])
          .map(SpigotModel.fromJson)
          .toList(growable: false),
      distances: [
        for (final item in currentDistances) DistanceModel.fromJson(item),
        for (final item in legacyRamps)
          DistanceModel.fromJson(item, legacyRamp: true),
      ],
      entrances: mapListValue(json['entranceList'])
          .map(EntranceModel.fromJson)
          .toList(growable: false),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = nullableInt(json[key]);
  if (value == null) {
    throw FormatException('Map field $key must be an integer.');
  }
  return value;
}

TableKind _tableKind(Object? value) {
  final normalized = nullableString(value)?.toLowerCase() ?? 'normal';
  return switch (normalized) {
    'hanging_basket' || 'hangingbasket' || 'hanging' => TableKind.hangingBasket,
    'custom' => TableKind.custom,
    _ => TableKind.normal,
  };
}

TableOrientation _tableOrientation(Object? value) {
  final normalized = nullableString(value)?.toLowerCase() ?? 'horizontal';
  return normalized == 'vertical' || normalized == 'v'
      ? TableOrientation.vertical
      : TableOrientation.horizontal;
}

WallSide _wallSide(Object? value) {
  return switch (nullableString(value)?.toLowerCase()) {
    'top' => WallSide.top,
    'right' => WallSide.right,
    'bottom' => WallSide.bottom,
    'left' => WallSide.left,
    final other => throw FormatException('Unknown wall side: $other'),
  };
}

EdgeSide _edgeSide(Object? value) {
  return switch (nullableString(value)?.toLowerCase()) {
    'top' => EdgeSide.top,
    'right' => EdgeSide.right,
    'bottom' => EdgeSide.bottom,
    'left' => EdgeSide.left,
    final other => throw FormatException('Unknown table edge side: $other'),
  };
}
