// layout_table.dart
//
// Responsibility:
// Represents one physical 2x3/3x2 table footprint on the garden-center map.
// Normal and hanging-basket fixtures use `pairId` to link their two physical
// rectangles. A custom table is one independently named rectangle. Keeping
// both relationships in this model lets JSON rebuild every fixture and keeps
// distance endpoints attached to the same stable table IDs.
//
// Main API:
// - LayoutTable: persisted physical table model.
// - widthCells / heightCells: derives the occupied grid footprint.
// - toJson / fromJson: preserves pair membership and custom names in JSON.
// - copyWith: supports movement, zoning, duplication, pairing, and renaming.

import 'survey_enums.dart';

const Object _unchangedZoneId = Object();
const Object _unchangedPairId = Object();
const Object _unchangedCustomName = Object();

class LayoutTable {
  static const int maxCustomNameLength = 40;

  final String tableId;

  /// Null while the surveyor is still assigning tables to zones.
  final String? zoneId;

  /// Shared by the two physical tables created by one palette drop.
  ///
  /// Legacy surveys may contain null because tables created before pairing was
  /// introduced are intentionally treated as independent logical fixtures.
  final String? pairId;

  final int topRow;
  final int leftColumn;
  final TableKind tableKind;
  final TableOrientation orientation;

  /// Surveyor-entered map label for a custom table.
  ///
  /// Normal and hanging-basket tables intentionally keep this null.
  final String? customName;

  LayoutTable({
    required this.tableId,
    this.zoneId,
    this.pairId,
    required this.topRow,
    required this.leftColumn,
    required this.tableKind,
    required this.orientation,
    String? customName,
  }) : customName = customName?.trim() {
    if (tableId.trim().isEmpty) {
      throw ArgumentError('tableId cannot be empty.');
    }
    if (zoneId != null && zoneId!.trim().isEmpty) {
      throw ArgumentError('zoneId must be null or non-empty.');
    }
    if (pairId != null && pairId!.trim().isEmpty) {
      throw ArgumentError('pairId must be null or non-empty.');
    }
    if (topRow < 0 || leftColumn < 0) {
      throw ArgumentError('Table position cannot be negative.');
    }
    if (tableKind == TableKind.custom) {
      if (this.customName == null || this.customName!.isEmpty) {
        throw ArgumentError('A custom table must have a name.');
      }
      if (this.customName!.length > maxCustomNameLength) {
        throw ArgumentError(
          'A custom table name cannot exceed $maxCustomNameLength characters.',
        );
      }
      if (zoneId != null) {
        throw ArgumentError('A custom table cannot belong to a zone.');
      }
      if (pairId != null) {
        throw ArgumentError('A custom table cannot belong to a table pair.');
      }
    } else if (this.customName != null) {
      throw ArgumentError('Only custom tables can have a custom name.');
    }
  }

  /// Every physical table is exactly 2x3 or 3x2 cells.
  int get widthCells => orientation == TableOrientation.horizontal ? 3 : 2;

  int get heightCells => orientation == TableOrientation.horizontal ? 2 : 3;

  int get bottomRowExclusive => topRow + heightCells;
  int get rightColumnExclusive => leftColumn + widthCells;

  /// Converts the physical table and its logical pair relationship to JSON.
  Map<String, dynamic> toJson() => {
    'tableId': tableId,
    'zoneId': zoneId,
    if (pairId != null) 'pairId': pairId,
    if (customName != null) 'customName': customName,
    'topRow': topRow,
    'leftColumn': leftColumn,
    'tableKind': tableKind.jsonValue,
    'orientation': orientation.jsonValue,
  };

  /// Recreates a table from JSON while remaining compatible with old surveys.
  ///
  /// JSON created before table pairing has no `pairId`, which naturally reads
  /// as null and keeps that old table independent instead of guessing a pair.
  factory LayoutTable.fromJson(Map<String, dynamic> json) => LayoutTable(
    tableId: json['tableId'] as String,
    zoneId: json['zoneId'] as String?,
    pairId: json['pairId'] as String?,
    customName: json['customName'] as String?,
    topRow: json['topRow'] as int,
    leftColumn: json['leftColumn'] as int,
    tableKind: TableKind.fromJson(json['tableKind'] as String),
    orientation: TableOrientation.fromJson(json['orientation'] as String),
  );

  /// Creates an updated immutable copy of this physical table.
  ///
  /// [zoneId] and [pairId] use sentinels so callers can distinguish between
  /// "leave unchanged" and explicitly setting either nullable property to null.
  LayoutTable copyWith({
    String? tableId,
    Object? zoneId = _unchangedZoneId,
    Object? pairId = _unchangedPairId,
    Object? customName = _unchangedCustomName,
    int? topRow,
    int? leftColumn,
    TableKind? tableKind,
    TableOrientation? orientation,
  }) {
    return LayoutTable(
      tableId: tableId ?? this.tableId,
      zoneId: identical(zoneId, _unchangedZoneId)
          ? this.zoneId
          : zoneId as String?,
      pairId: identical(pairId, _unchangedPairId)
          ? this.pairId
          : pairId as String?,
      customName: identical(customName, _unchangedCustomName)
          ? this.customName
          : customName as String?,
      topRow: topRow ?? this.topRow,
      leftColumn: leftColumn ?? this.leftColumn,
      tableKind: tableKind ?? this.tableKind,
      orientation: orientation ?? this.orientation,
    );
  }
}
