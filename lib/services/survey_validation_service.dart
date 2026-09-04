// survey_validation_service.dart
//
// Responsibility:
// Repeats the field app's important schema-9 completion and geometry checks
// before an edited survey is uploaded as a new immutable version.

import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../utils/map_geometry.dart';
import '../utils/table_pair_rules.dart';

class SurveyValidationService {
  const SurveyValidationService();

  List<String> validate(SurveyDocument survey) {
    final issues = <String>{};
    final layout = survey.mapData;

    if (survey.schemaVersion != 9) {
      issues.add(
        'This version uses schema ${survey.schemaVersion}; current uploads must use schema 9.',
      );
    }
    if (survey.storeNumber == 'Unknown' || survey.storeNumber.trim().isEmpty) {
      issues.add('Store number is missing.');
    }
    if (layout.canvasRows <= 0 || layout.canvasColumns <= 0) {
      issues.add('Canvas rows and columns must be greater than zero.');
    }
    final room = layout.roomBounds;
    if (room.topRow < 0 ||
        room.leftColumn < 0 ||
        room.widthCells <= 0 ||
        room.heightCells <= 0 ||
        room.bottomRowExclusive > layout.canvasRows ||
        room.rightColumnExclusive > layout.canvasColumns) {
      issues.add('Room bounds must fit completely inside the canvas.');
    }

    _validateRequiredContent(layout, issues);
    _validateIdentifiers(layout, issues);
    _validateZones(layout, issues);
    _validateTables(layout, issues);
    _validateCanopies(layout, issues);
    _validateSpigots(layout, issues);
    _validateEntrances(layout, issues);
    _validateDistances(layout, issues);

    return issues.toList(growable: false);
  }

  void _validateRequiredContent(
    SurveyMapModel layout,
    Set<String> issues,
  ) {
    if (layout.tables.isEmpty) {
      issues.add('Place at least one table before saving a completed survey.');
    }
    if (layout.entrances.isEmpty) {
      issues.add('The garden center must have at least one entrance.');
    }
    if (layout.spigots.isEmpty) {
      issues.add('The garden center must have at least one spigot.');
    }
    final missingPsi = layout.spigots.where((item) => item.pressurePsi == null).length;
    if (missingPsi > 0) {
      issues.add('Enter a PSI reading for every spigot ($missingPsi missing).');
    }
    if (layout.canopyCells.any((item) => !item.hasCompleteMeasurements)) {
      issues.add(
        'Every canopy cell must retain height, length, and width measurements in inches.',
      );
    }
  }

  void _validateIdentifiers(SurveyMapModel layout, Set<String> issues) {
    if (_hasDuplicates(layout.tables.map((item) => item.tableId))) {
      issues.add('Two or more tables have the same tableId.');
    }
    if (_hasDuplicates(layout.zones.map((item) => item.zoneId))) {
      issues.add('Two or more zones have the same zoneId.');
    }
    if (_hasDuplicates(layout.distances.map((item) => item.distanceId))) {
      issues.add('Two or more distances have the same distanceId.');
    }
    if (_hasDuplicates(layout.entrances.map((item) => item.entranceId))) {
      issues.add('Two or more entrances have the same entranceId.');
    }
    if (_hasDuplicates(layout.spigots.map((item) => item.key))) {
      issues.add('Two or more spigots occupy the same grid intersection.');
    }
  }

  void _validateZones(SurveyMapModel layout, Set<String> issues) {
    final zoneIds = layout.zones.map((item) => item.zoneId).toSet();
    if (layout.tables.any(
      (table) => table.zoneId != null && !zoneIds.contains(table.zoneId),
    )) {
      issues.add('One or more tables refer to a zone that no longer exists.');
    }
    for (final table in layout.tables) {
      if (table.tableKind == TableKind.custom && table.zoneId != null) {
        issues.add('Custom tables cannot belong to zones.');
      }
    }
    for (final zone in layout.zones) {
      final weighted = TablePairRules.weightedCountForZone(
        layout.tables,
        zone.zoneId,
      );
      if (weighted > TablePairRules.maxZoneWeightedTableCount) {
        issues.add('${zone.label} exceeds the 18-table weighted limit ($weighted).');
      }
    }
  }

  void _validateTables(SurveyMapModel layout, Set<String> issues) {
    final pairGroups = <String, List<LayoutTableModel>>{};
    for (final table in layout.tables) {
      final error = MapGeometry.tableGroupPlacementError(
        candidates: [table],
        layout: layout,
        ignoredTableIds: {table.tableId},
      );
      if (error != null) issues.add(error);

      if (table.tableKind == TableKind.custom) {
        final name = table.customName;
        if (name == null || name.isEmpty || name.length > 40) {
          issues.add('Every custom table needs a name of 1–40 characters.');
        }
        if (table.pairId != null) {
          issues.add('Custom tables cannot belong to table pairs.');
        }
      }
      final pairId = table.pairId;
      if (pairId != null) {
        pairGroups.putIfAbsent(pairId, () => []).add(table);
      }
    }

    for (final entry in pairGroups.entries) {
      final members = entry.value;
      if (members.length != 2) {
        issues.add('Table pair ${entry.key} must contain exactly two physical tables.');
        continue;
      }
      final first = members.first;
      final second = members.last;
      if (first.tableKind != second.tableKind ||
          first.orientation != second.orientation ||
          first.zoneId != second.zoneId) {
        issues.add('Both members of table pair ${entry.key} must share kind, orientation, and zone.');
      }
      final correctlyAdjacent = first.orientation == TableOrientation.horizontal
          ? first.leftColumn == second.leftColumn &&
              (first.topRow - second.topRow).abs() == first.heightCells
          : first.topRow == second.topRow &&
              (first.leftColumn - second.leftColumn).abs() == first.widthCells;
      if (!correctlyAdjacent) {
        issues.add('Table pair ${entry.key} is not joined along the tables’ long sides.');
      }
    }
  }

  void _validateCanopies(SurveyMapModel layout, Set<String> issues) {
    for (final cell in layout.canopyCells) {
      if (!MapGeometry.canvasContainsCell(
            layout,
            GridCoordinate(row: cell.row, column: cell.column),
          ) ||
          !layout.roomBounds.containsCell(
            GridCoordinate(row: cell.row, column: cell.column),
          )) {
        issues.add('Canopy cells must stay inside the room and canvas.');
      }
      if ((cell.heightInches ?? 0) <= 0 ||
          (cell.lengthInches ?? 0) <= 0 ||
          (cell.widthInches ?? 0) <= 0) {
        issues.add('Canopy measurements must be greater than zero.');
      }
    }
  }

  void _validateSpigots(SurveyMapModel layout, Set<String> issues) {
    for (final spigot in layout.spigots) {
      if (!MapGeometry.spigotFitsLayout(spigot, layout)) {
        issues.add('Spigots must remain inside the room or on a room wall.');
      }
      final pressure = spigot.pressurePsi;
      if (pressure != null && (!pressure.isFinite || pressure < 0)) {
        issues.add('Spigot PSI readings must be finite and non-negative.');
      }
    }
  }

  void _validateEntrances(SurveyMapModel layout, Set<String> issues) {
    for (final entrance in layout.entrances) {
      final error = MapGeometry.entrancePlacementError(
        candidate: entrance,
        layout: layout,
        ignoredEntranceId: entrance.entranceId,
      );
      if (error != null) issues.add(error);
    }
  }

  void _validateDistances(SurveyMapModel layout, Set<String> issues) {
    final occupied = <GridCoordinate>{};
    final entranceClearances = [
      for (final entrance in layout.entrances)
        MapGeometry.entranceClearance(entrance, layout.roomBounds),
    ];
    for (final distance in layout.distances) {
      if (!distance.measuredDistance.isFinite || distance.measuredDistance <= 0) {
        issues.add('Every distance measurement must be greater than zero.');
      }
      final cells = MapGeometry.cellsForDistance(distance, layout);
      if (cells.isEmpty) {
        issues.add('A distance is disconnected from its saved table/wall endpoints.');
        continue;
      }
      if (cells.any(occupied.contains)) {
        issues.add('Distances cannot overlap one another.');
      }
      if (cells.any(
        (cell) => entranceClearances.any((area) => area.contains(cell)),
      )) {
        issues.add('A distance cannot block an entrance clearance area.');
      }
      occupied.addAll(cells);
    }
  }

  bool _hasDuplicates(Iterable<String> values) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) return true;
    }
    return false;
  }
}
