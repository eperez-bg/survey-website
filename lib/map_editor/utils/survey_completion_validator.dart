import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'grid_geometry.dart';
import 'layout_placement_rules.dart';
import 'distance_geometry.dart';
import 'zone_rules.dart';

/// Immutable result returned before a survey can leave the map editor.
class SurveyCompletionValidation {
  final List<String> issues;

  SurveyCompletionValidation(Iterable<String> issues)
    : issues = List.unmodifiable(issues);

  bool get isValid => issues.isEmpty;
}

/// Performs a final pass over the complete map, including data loaded from JSON.
///
/// Editor actions already prevent most invalid changes. This validator repeats
/// the important invariants at submission time so restored or manually edited
/// JSON cannot bypass those protections.
class SurveyCompletionValidator {
  const SurveyCompletionValidator._();

  static SurveyCompletionValidation validate({
    required GardenCenterLayout layout,
    bool hasCanopyDraft = false,
    bool hasDistanceDraft = false,
  }) {
    final issues = <String>{};

    if (hasCanopyDraft) {
      issues.add(
        'Finish or cancel the current canopy or No Install Zone selection.',
      );
    }
    if (hasDistanceDraft) {
      issues.add('Finish or cancel the current distance.');
    }

    _validateRequiredContent(layout: layout, issues: issues);
    _validateIdentifiers(layout, issues);
    _validateZones(layout, issues);
    _validateFixtureGeometry(layout, issues);
    _validateDistances(layout, issues);

    return SurveyCompletionValidation(issues);
  }

  static void _validateRequiredContent({
    required GardenCenterLayout layout,
    required Set<String> issues,
  }) {
    if (layout.layoutTableList.isEmpty) {
      issues.add('Place at least one table before finishing.');
    }

    if (layout.entranceList.isEmpty) {
      issues.add('The garden center must have at least one entrance.');
    }

    if (layout.spigotList.isEmpty) {
      issues.add('Place at least one spigot before finishing.');
    }

    final missingPressureCount = layout.spigotList
        .where((spigot) => spigot.pressurePsi == null)
        .length;
    if (missingPressureCount > 0) {
      issues.add(
        'Enter a PSI reading for every spigot '
        '($missingPressureCount ${missingPressureCount == 1 ? 'reading is' : 'readings are'} missing).',
      );
    }

    final hasCanopyWithoutMeasurements = layout.canopyCellList.any(
      (cell) => !cell.hasCompleteMeasurements,
    );
    if (hasCanopyWithoutMeasurements) {
      issues.add(
        'Enter height, length, and width measurements in inches for every '
        'canopy before finishing. Reselect any older canopy area to add its '
        'measurements.',
      );
    }
  }

  static void _validateIdentifiers(
    GardenCenterLayout layout,
    Set<String> issues,
  ) {
    if (_containsDuplicate(
      layout.layoutTableList.map((item) => item.tableId),
    )) {
      issues.add('Two or more tables have the same ID.');
    }
    if (_containsDuplicate(layout.zoneList.map((item) => item.zoneId))) {
      issues.add('Two or more zones have the same ID.');
    }
    if (_containsDuplicate(layout.distanceList.map((item) => item.distanceId))) {
      issues.add('Two or more distances have the same ID.');
    }
    if (_containsDuplicate(
      layout.entranceList.map((item) => item.entranceId),
    )) {
      issues.add('Two or more entrances have the same ID.');
    }
  }

  static void _validateZones(GardenCenterLayout layout, Set<String> issues) {
    final zoneIds = layout.zoneList.map((zone) => zone.zoneId).toSet();
    final missingZoneReferenceCount = layout.layoutTableList
        .where(
          (table) => table.zoneId != null && !zoneIds.contains(table.zoneId),
        )
        .length;
    if (missingZoneReferenceCount > 0) {
      issues.add('One or more tables refer to a zone that no longer exists.');
    }

    for (final zone in layout.zoneList) {
      final zoneTables = layout.layoutTableList
          .where((table) => table.zoneId == zone.zoneId)
          .toList();
      if (zoneTables.isEmpty) {
        continue;
      }

      final weightedCount = ZoneRules.weightedTableCount(zoneTables);
      if (weightedCount > ZoneRules.maxWeightedTableCount) {
        issues.add(
          '${zone.label} exceeds the ${ZoneRules.maxWeightedTableCount}-table '
          'limit ($weightedCount weighted tables).',
        );
      }
    }
  }

  static void _validateFixtureGeometry(
    GardenCenterLayout layout,
    Set<String> issues,
  ) {
    final resizeError = LayoutPlacementRules.nonDistanceResizeValidationError(
      layout,
    );
    if (resizeError != null) {
      issues.add(resizeError);
    }

    for (final table in layout.layoutTableList) {
      final placementError = LayoutPlacementRules.tableGroupPlacementError(
        candidates: [table],
        layout: layout,
        ignoredTableIds: {table.tableId},
      );
      if (placementError != null) {
        issues.add(placementError);
      }
    }
  }

  static void _validateDistances(GardenCenterLayout layout, Set<String> issues) {
    final occupiedDistanceCells = <GridCoordinate>{};

    for (final distance in layout.distanceList) {
      final cells = DistanceGeometry.cellsForDistance(distance, layout);
      if (cells.isEmpty) {
        issues.add(
          'A distance is disconnected or no longer touches its saved '
          'endpoints.',
        );
        continue;
      }

      final cellsAreValid = LayoutPlacementRules.distanceCellsAreValidInLayout(
        cells,
        layout,
        occupiedDistanceCells: occupiedDistanceCells,
      );
      if (!cellsAreValid) {
        issues.add(
          'A distance overlaps a fixture, another distance, entrance '
          'clearance, or No Install Zone.',
        );
      }
      occupiedDistanceCells.addAll(cells);
    }
  }
}

bool _containsDuplicate(Iterable<String> values) {
  final uniqueValues = <String>{};
  for (final value in values) {
    if (!uniqueValues.add(value)) {
      return true;
    }
  }
  return false;
}
