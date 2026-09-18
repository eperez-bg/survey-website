import 'canopy_cell.dart';
import 'entrance.dart';
import 'layout_table.dart';
import 'no_install_zone_cell.dart';
import 'distance.dart';
import 'room_bounds.dart';
import 'spigot.dart';
import 'zone.dart';

class GardenCenterLayout {
  final int canvasRows;
  final int canvasColumns;
  final RoomBounds roomBounds;
  final List<LayoutTable> layoutTableList;
  final List<Zone> zoneList;
  final Set<CanopyCell> canopyCellList;
  final Set<NoInstallZoneCell> noInstallZoneCellList;
  final Set<Spigot> spigotList;
  final List<Distance> distanceList;
  final List<Entrance> entranceList;

  GardenCenterLayout({
    required this.canvasRows,
    required this.canvasColumns,
    required this.roomBounds,
    List<LayoutTable> layoutTableList = const [],
    List<Zone> zoneList = const [],
    Set<CanopyCell> canopyCellList = const {},
    Set<NoInstallZoneCell> noInstallZoneCellList = const {},
    Set<Spigot> spigotList = const {},
    List<Distance> distanceList = const [],
    List<Entrance> entranceList = const [],
  })  : layoutTableList = List.unmodifiable(layoutTableList),
        zoneList = List.unmodifiable(zoneList),
        canopyCellList = Set.unmodifiable(canopyCellList),
        noInstallZoneCellList = Set.unmodifiable(noInstallZoneCellList),
        spigotList = Set.unmodifiable(spigotList),
        distanceList = List.unmodifiable(distanceList),
        entranceList = List.unmodifiable(entranceList) {
    if (canvasRows <= 0 || canvasColumns <= 0) {
      throw ArgumentError('Canvas dimensions must be greater than zero.');
    }
    if (roomBounds.bottomRowExclusive > canvasRows ||
        roomBounds.rightColumnExclusive > canvasColumns) {
      throw ArgumentError('roomBounds must fit inside the canvas.');
    }
  }

  Map<String, dynamic> toJson() {
    final sortedCanopyCells = canopyCellList.toList()
      ..sort((a, b) {
        final rowComparison = a.row.compareTo(b.row);
        return rowComparison != 0
            ? rowComparison
            : a.column.compareTo(b.column);
      });

    final sortedSpigots = spigotList.toList()
      ..sort((a, b) {
        final rowComparison = a.rowLine.compareTo(b.rowLine);
        return rowComparison != 0
            ? rowComparison
            : a.columnLine.compareTo(b.columnLine);
      });

    final sortedNoInstallZoneCells = noInstallZoneCellList.toList()
      ..sort((a, b) {
        final rowComparison = a.row.compareTo(b.row);
        return rowComparison != 0
            ? rowComparison
            : a.column.compareTo(b.column);
      });

    return {
      'canvasRows': canvasRows,
      'canvasColumns': canvasColumns,
      'roomBounds': roomBounds.toJson(),
      'layoutTableList': layoutTableList.map((item) => item.toJson()).toList(),
      'zoneList': zoneList.map((item) => item.toJson()).toList(),
      'canopyCellList': sortedCanopyCells.map((item) => item.toJson()).toList(),
      'noInstallZoneCellList': sortedNoInstallZoneCells
          .map((item) => item.toJson())
          .toList(),
      'spigotList': sortedSpigots.map((item) => item.toJson()).toList(),
      'distanceList': distanceList.map((item) => item.toJson()).toList(),
      'entranceList': entranceList.map((item) => item.toJson()).toList(),
    };
  }

  factory GardenCenterLayout.fromJson(Map<String, dynamic> json) {
    final rawTables =
        json['layoutTableList'] as List<dynamic>? ?? const <dynamic>[];
    final rawZones =
        json['zoneList'] as List<dynamic>? ?? const <dynamic>[];
    final rawCanopyCells =
        json['canopyCellList'] as List<dynamic>? ?? const <dynamic>[];
    final rawSpigots =
        json['spigotList'] as List<dynamic>? ?? const <dynamic>[];
    final rawNoInstallZoneCells =
        json['noInstallZoneCellList'] as List<dynamic>? ?? const <dynamic>[];
    final rawDistances =
        json['distanceList'] as List<dynamic>? ?? const <dynamic>[];
    final rawEntrances =
        json['entranceList'] as List<dynamic>? ?? const <dynamic>[];

    return GardenCenterLayout(
      canvasRows: json['canvasRows'] as int,
      canvasColumns: json['canvasColumns'] as int,
      roomBounds: RoomBounds.fromJson(
        Map<String, dynamic>.from(json['roomBounds'] as Map),
      ),
      layoutTableList: rawTables
          .map((item) => LayoutTable.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      zoneList: rawZones
          .map((item) => Zone.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      canopyCellList: rawCanopyCells
          .map((item) => CanopyCell.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toSet(),
      noInstallZoneCellList: rawNoInstallZoneCells
          .map((item) => NoInstallZoneCell.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toSet(),
      spigotList: rawSpigots
          .map((item) => Spigot.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toSet(),
      distanceList: rawDistances
          .map((item) => Distance.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      entranceList: rawEntrances
          .map((item) => Entrance.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }

  GardenCenterLayout copyWith({
    int? canvasRows,
    int? canvasColumns,
    RoomBounds? roomBounds,
    List<LayoutTable>? layoutTableList,
    List<Zone>? zoneList,
    Set<CanopyCell>? canopyCellList,
    Set<NoInstallZoneCell>? noInstallZoneCellList,
    Set<Spigot>? spigotList,
    List<Distance>? distanceList,
    List<Entrance>? entranceList,
  }) {
    return GardenCenterLayout(
      canvasRows: canvasRows ?? this.canvasRows,
      canvasColumns: canvasColumns ?? this.canvasColumns,
      roomBounds: roomBounds ?? this.roomBounds,
      layoutTableList: layoutTableList ?? this.layoutTableList,
      zoneList: zoneList ?? this.zoneList,
      canopyCellList: canopyCellList ?? this.canopyCellList,
      noInstallZoneCellList:
          noInstallZoneCellList ?? this.noInstallZoneCellList,
      spigotList: spigotList ?? this.spigotList,
      distanceList: distanceList ?? this.distanceList,
      entranceList: entranceList ?? this.entranceList,
    );
  }
}
