part of '../map_editor_controller.dart';

/// Zone-selection use cases for [MapEditorController].
///
/// The controller remains the single owner of layout state. Keeping these
/// actions in a focused extension makes the zone workflow easier to find
/// without changing the API used by widgets or tests.
extension MapEditorZoneActions on MapEditorController {
  void selectPreviousZone() {
    final index = currentZoneIndex;
    if (index <= 0) {
      return;
    }

    _currentZoneId = _layout.zoneList[index - 1].zoneId;
    notifyListeners();
  }

  void selectNextZone() {
    final index = currentZoneIndex;
    if (index < 0 || index >= _layout.zoneList.length - 1) {
      return;
    }

    _currentZoneId = _layout.zoneList[index + 1].zoneId;
    notifyListeners();
  }

  void createZone() {
    _clearDistanceInteraction();
    _clearCanopyInteraction();
    _isNoInstallZonePlacementEnabled = false;
    _selectedDistanceId = null;
    _appendNewZone();
    _activeTool = MapEditorTool.zones;
    _selectedTableIds.clear();
    notifyListeners();
  }

  /// Adds, moves, or removes the complete pair containing [tableId].
  ///
  /// A normal pair uses one capacity point and a hanging-basket pair uses two.
  /// Legacy tables without pairId continue to behave as one independent unit.
  /// Custom tables are rejected before any zone mutation occurs.
  EditorActionResult toggleTableInCurrentZone(String tableId) {
    final zone = currentZone;
    if (zone == null) {
      return const EditorActionResult.failure('Create or select a zone first.');
    }

    final pairTables = TablePairRules.membersForTable(
      _layout.layoutTableList,
      tableId,
    );
    if (pairTables.isEmpty) {
      return const EditorActionResult.failure('That table no longer exists.');
    }
    if (pairTables.any((table) => !ZoneRules.canAssignToZone(table))) {
      return const EditorActionResult.failure(
        'Custom tables cannot be added to zones.',
      );
    }

    final pairIds = {for (final table in pairTables) table.tableId};
    final isRemovingFromCurrentZone = pairTables.every(
      (table) => table.zoneId == zone.zoneId,
    );

    if (!isRemovingFromCurrentZone) {
      // A damaged/legacy layout could have only one physical member already in
      // this zone. Since pair-aware counting already counts that pair once, do
      // not add its weight a second time while repairing the membership.
      final pairAlreadyContributes = pairTables.any(
        (table) => table.zoneId == zone.zoneId,
      );
      final addedWeight = pairAlreadyContributes
          ? 0
          : ZoneRules.weightedTableCount(pairTables);
      final nextWeightedCount = currentZoneWeightedTableCount + addedWeight;

      if (nextWeightedCount > ZoneRules.maxWeightedTableCount) {
        return EditorActionResult.failure(
          '${zone.label} cannot contain more than '
          '${ZoneRules.maxWeightedTableCount} tables. '
          'A normal pair counts as one and a hanging-basket pair counts as two.',
        );
      }
    }

    final updatedTables = [
      for (final table in _layout.layoutTableList)
        if (pairIds.contains(table.tableId))
          table.copyWith(
            zoneId: isRemovingFromCurrentZone ? null : zone.zoneId,
          )
        else
          table,
    ];

    // Reuse the multi-table cleanup path so moving/removing a pair also removes
    // any previous zone that no longer owns a logical fixture.
    final updatedZones = _zonesAfterRemovingTables(
      removedTables: pairTables,
      remainingTables: updatedTables,
    );
    _layout = _layout.copyWith(
      layoutTableList: updatedTables,
      zoneList: updatedZones,
    );
    notifyListeners();

    return const EditorActionResult.success();
  }
}
