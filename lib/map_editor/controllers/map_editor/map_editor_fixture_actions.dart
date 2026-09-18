part of '../map_editor_controller.dart';

/// Table placement, selection mutations, and spigot editing use cases.
extension MapEditorFixtureActions on MapEditorController {
  EditorActionResult placeOrMoveTable({
    required TableDragData dragData,
    required GridCoordinate topLeft,
    String? customTableName,
  }) {
    final normalizedCustomName = customTableName?.trim();
    if (!dragData.isMovingExistingTable &&
        dragData.tableKind == TableKind.custom) {
      if (normalizedCustomName == null || normalizedCustomName.isEmpty) {
        return EditorActionResult.failure(
          'Enter a name for the custom table.',
        );
      }
      if (normalizedCustomName.length > LayoutTable.maxCustomNameLength) {
        return EditorActionResult.failure(
          'Custom table names can contain up to '
          '${LayoutTable.maxCustomNameLength} characters.',
        );
      }
    }

    final preview = previewTableDrop(
      dragData: dragData,
      topLeft: topLeft,
      customTableName: normalizedCustomName,
    );
    if (!preview.canPlace) {
      return EditorActionResult.failure(
        preview.message ?? 'That fixture cannot be placed there.',
      );
    }

    if (dragData.isMovingExistingTable) {
      final movedById = {
        for (final table in preview.tables) table.tableId: table,
      };
      _layout = _layout.copyWith(
        layoutTableList: [
          for (final table in _layout.layoutTableList)
            movedById[table.tableId] ?? table,
        ],
      );
      _selectedTableIds = movedById.keys.toSet();
    } else {
      final isCustomTable = dragData.tableKind == TableKind.custom;
      final pairId = isCustomTable ? null : _nextTablePairId();
      final tables = [
        for (final previewTable in preview.tables)
          previewTable.copyWith(
            tableId: _nextTableId(),
            pairId: pairId,
          ),
      ];
      _layout = _layout.copyWith(
        layoutTableList: [..._layout.layoutTableList, ...tables],
      );
      _selectedTableIds = {for (final table in tables) table.tableId};
    }

    _selectedDistanceId = null;
    _selectedEntranceId = null;
    _isEntrancePlacementEnabled = false;
    _clearEntranceDrag();
    _activeTool = MapEditorTool.select;
    _isNoInstallZonePlacementEnabled = false;
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Calculates snapped positions without changing the saved layout.
  TableDropPreview previewTableDrop({
    required TableDragData dragData,
    required GridCoordinate topLeft,
    String? customTableName,
  }) {
    if (!dragData.isMovingExistingTable) {
      if (topLeft.row < 0 || topLeft.column < 0) {
        return TableDropPreview.invalid(
          const [],
          'Tables must fit completely inside the canvas.',
        );
      }

      final requestedCustomName = customTableName?.trim();
      final previewCustomName = requestedCustomName != null &&
              requestedCustomName.isNotEmpty &&
              requestedCustomName.length <= LayoutTable.maxCustomNameLength
          ? requestedCustomName
          : 'Custom Table';
      final candidates = dragData.tableKind == TableKind.custom
          ? [
              LayoutTable(
                tableId: 'preview-custom-table',
                topRow: topLeft.row,
                leftColumn: topLeft.column,
                tableKind: TableKind.custom,
                orientation: dragData.orientation,
                customName: previewCustomName,
              ),
            ]
          : TablePairRules.createAdjacentPair(
              firstTableId: 'preview-table-a',
              secondTableId: 'preview-table-b',
              pairId: 'preview-table-pair',
              topRow: topLeft.row,
              leftColumn: topLeft.column,
              tableKind: dragData.tableKind,
              orientation: dragData.orientation,
            );
      final placementError = LayoutPlacementRules.tableGroupPlacementError(
        candidates: candidates,
        layout: _layout,
      );

      return placementError == null
          ? TableDropPreview.valid(candidates)
          : TableDropPreview.invalid(candidates, placementError);
    }

    final movingIds = dragData.movingTableIds.toSet();
    final movingTables = [
      for (final table in _layout.layoutTableList)
        if (movingIds.contains(table.tableId)) table,
    ];
    if (movingTables.length != movingIds.length || movingTables.isEmpty) {
      return TableDropPreview.invalid(
        const [],
        'One or more selected tables no longer exist.',
      );
    }

    final anchorId =
        dragData.effectiveAnchorTableId ?? movingTables.first.tableId;
    LayoutTable? anchorTable;
    for (final table in movingTables) {
      if (table.tableId == anchorId) {
        anchorTable = table;
        break;
      }
    }
    if (anchorTable == null) {
      return TableDropPreview.invalid(
        const [],
        'The dragged table is not part of this selection.',
      );
    }

    final rowDelta = topLeft.row - anchorTable.topRow;
    final columnDelta = topLeft.column - anchorTable.leftColumn;
    final shiftedBounds = TableGroupGeometry.boundsFor(
      movingTables,
    ).translated(rowDelta: rowDelta, columnDelta: columnDelta);
    if (shiftedBounds.topRow < 0 || shiftedBounds.leftColumn < 0) {
      return TableDropPreview.invalid(
        const [],
        'Tables must fit completely inside the canvas.',
      );
    }

    final candidates = TableGroupGeometry.translate(
      movingTables,
      rowDelta: rowDelta,
      columnDelta: columnDelta,
    );
    final hasConnectedDistance = movingIds.any(
      (tableId) => LayoutPlacementRules.tableHasConnectedDistance(
        tableId: tableId,
        layout: _layout,
      ),
    );
    if (hasConnectedDistance) {
      return TableDropPreview.invalid(
        candidates,
        'Delete connected distances before moving these tables.',
      );
    }

    final placementError = LayoutPlacementRules.tableGroupPlacementError(
      candidates: candidates,
      layout: _layout,
      ignoredTableIds: movingIds,
    );
    return placementError == null
        ? TableDropPreview.valid(candidates)
        : TableDropPreview.invalid(candidates, placementError);
  }

  /// Copies the selection to the nearest valid open area.
  ///
  /// Copies start without a zone so duplication cannot silently exceed a
  /// zone's weighted capacity.
  EditorActionResult duplicateSelectedTables() {
    final selectedTables = [
      for (final table in _layout.layoutTableList)
        if (_selectedTableIds.contains(table.tableId)) table,
    ];
    if (selectedTables.isEmpty) {
      return EditorActionResult.failure(
        'Select at least one table to duplicate.',
      );
    }

    List<LayoutTable>? placement;
    for (final offset in TableGroupGeometry.duplicateOffsets(
      tables: selectedTables,
      placementBounds: RoomBounds(
        topRow: 0,
        leftColumn: 0,
        widthCells: _layout.canvasColumns,
        heightCells: _layout.canvasRows,
      ),
    )) {
      final candidates = TableGroupGeometry.translate(
        selectedTables,
        rowDelta: offset.row,
        columnDelta: offset.column,
      );
      if (LayoutPlacementRules.tableGroupPlacementError(
            candidates: candidates,
            layout: _layout,
          ) ==
          null) {
        placement = candidates;
        break;
      }
    }

    if (placement == null) {
      return EditorActionResult.failure(
        'There is not enough open space to duplicate this selection.',
      );
    }

    final duplicatePairIds = <String, String>{};
    final duplicates = [
      for (final table in placement)
        table.copyWith(
          tableId: _nextTableId(),
          zoneId: null,
          pairId: table.pairId == null
              ? null
              : duplicatePairIds.putIfAbsent(
                  table.pairId!,
                  () => _nextTablePairId(),
                ),
        ),
    ];
    _layout = _layout.copyWith(
      layoutTableList: [..._layout.layoutTableList, ...duplicates],
    );
    _selectedTableIds = {for (final table in duplicates) table.tableId};
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Applies one label to every selected custom table.
  ///
  /// A mixed selection is supported: normal and hanging-basket tables remain
  /// unchanged, while all selected custom tables receive the new name.
  EditorActionResult renameSelectedCustomTables(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return const EditorActionResult.failure(
        'Enter a name for the selected custom tables.',
      );
    }
    if (normalizedName.length > LayoutTable.maxCustomNameLength) {
      return EditorActionResult.failure(
        'Custom table names can contain up to '
        '${LayoutTable.maxCustomNameLength} characters.',
      );
    }

    final customTableIds = {
      for (final table in _layout.layoutTableList)
        if (_selectedTableIds.contains(table.tableId) &&
            table.tableKind == TableKind.custom)
          table.tableId,
    };
    if (customTableIds.isEmpty) {
      return const EditorActionResult.failure(
        'Select at least one custom table to rename.',
      );
    }

    _layout = _layout.copyWith(
      layoutTableList: [
        for (final table in _layout.layoutTableList)
          customTableIds.contains(table.tableId)
              ? table.copyWith(customName: normalizedName)
              : table,
      ],
    );
    notifyListeners();

    return EditorActionResult.success(
      message: customTableIds.length == 1
          ? 'Custom table renamed.'
          : '${customTableIds.length} custom tables renamed.',
    );
  }

  EditorActionResult removeSelectedTables() {
    if (_selectedTableIds.isEmpty) {
      return const EditorActionResult.failure(
        'Select at least one table to delete.',
      );
    }
    if (_selectedTableIds.any(
      (tableId) => LayoutPlacementRules.tableHasConnectedDistance(
        tableId: tableId,
        layout: _layout,
      ),
    )) {
      return const EditorActionResult.failure(
        'Delete connected distances before deleting these tables.',
      );
    }

    final removedTables = _layout.layoutTableList
        .where((table) => _selectedTableIds.contains(table.tableId))
        .toList();
    final updatedTables = _layout.layoutTableList
        .where((table) => !_selectedTableIds.contains(table.tableId))
        .toList();
    _layout = _layout.copyWith(
      layoutTableList: updatedTables,
      zoneList: _zonesAfterRemovingTables(
        removedTables: removedTables,
        remainingTables: updatedTables,
      ),
    );
    _selectedTableIds.clear();
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Backward-compatible single-selection entry point.
  EditorActionResult removeSelectedTable() => removeSelectedTables();

  /// Returns the spigot at [intersection], if one already exists.
  Spigot? spigotAt(GridIntersection intersection) {
    for (final spigot in _layout.spigotList) {
      if (spigot.rowLine == intersection.rowLine &&
          spigot.columnLine == intersection.columnLine) {
        return spigot;
      }
    }

    return null;
  }

  /// Validates a new arbitrary map spigot before it is added.
  EditorActionResult validateNewSpigotPlacement(GridIntersection intersection) {
    final editingResult = _validateSpigotEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }

    if (spigotAt(intersection) != null) {
      return const EditorActionResult.failure(
        'A spigot already exists at that intersection.',
      );
    }

    final locationResult = _validateSpigotLocation(intersection);
    if (!locationResult.succeeded) {
      return locationResult;
    }

    return const EditorActionResult.success();
  }

  /// Adds a physical map spigot and its PSI reading as one operation.
  EditorActionResult addSpigot(
    GridIntersection intersection, {
    required double pressurePsi,
  }) {
    final validationResult = validateNewSpigotPlacement(intersection);
    if (!validationResult.succeeded) {
      return validationResult;
    }
    final pressureResult = _validateSpigotPressure(pressurePsi);
    if (!pressureResult.succeeded) {
      return pressureResult;
    }

    final updatedSpigots = {
      ..._layout.spigotList,
      Spigot(
        rowLine: intersection.rowLine,
        columnLine: intersection.columnLine,
        pressurePsi: pressurePsi,
      ),
    };
    _layout = _layout.copyWith(spigotList: updatedSpigots);
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Updates the PSI reading while preserving coordinate identity.
  EditorActionResult updateSpigotPressureAt(
    GridIntersection intersection, {
    required double pressurePsi,
  }) {
    final editingResult = _validateSpigotEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }
    final pressureResult = _validateSpigotPressure(pressurePsi);
    if (!pressureResult.succeeded) {
      return pressureResult;
    }

    final existingSpigot = spigotAt(intersection);
    if (existingSpigot == null) {
      return const EditorActionResult.failure(
        'There is no spigot at that intersection.',
      );
    }

    final updatedSpigots = {..._layout.spigotList}
      ..remove(existingSpigot)
      ..add(existingSpigot.copyWith(pressurePsi: pressurePsi));
    _layout = _layout.copyWith(spigotList: updatedSpigots);
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Removes the spigot and its PSI reading at [intersection].
  EditorActionResult removeSpigotAt(GridIntersection intersection) {
    final editingResult = _validateSpigotEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }

    final existingSpigot = spigotAt(intersection);
    if (existingSpigot == null) {
      return const EditorActionResult.failure(
        'There is no spigot at that intersection.',
      );
    }

    final updatedSpigots = {..._layout.spigotList}..remove(existingSpigot);
    _layout = _layout.copyWith(spigotList: updatedSpigots);
    notifyListeners();

    return const EditorActionResult.success();
  }

  EditorActionResult _validateSpigotEditingIsEnabled() {
    if (_activeTool != MapEditorTool.select) {
      return const EditorActionResult.failure(
        'Spigots can only be changed while Fixtures is selected.',
      );
    }
    if (!_isSpigotPlacementEnabled) {
      return const EditorActionResult.failure(
        'Turn on spigot placement before adding or removing a spigot.',
      );
    }

    return const EditorActionResult.success();
  }

  EditorActionResult _validateSpigotPressure(double pressurePsi) {
    if (!pressurePsi.isFinite || pressurePsi < 0) {
      return const EditorActionResult.failure(
        'Spigot pressure must be a number of zero PSI or greater.',
      );
    }

    return const EditorActionResult.success();
  }

  EditorActionResult _validateSpigotLocation(GridIntersection intersection) {
    final room = _layout.roomBounds;
    final isInsideOrOnWall =
        intersection.rowLine >= room.topRow &&
        intersection.rowLine <= room.bottomRowExclusive &&
        intersection.columnLine >= room.leftColumn &&
        intersection.columnLine <= room.rightColumnExclusive;

    if (!isInsideOrOnWall) {
      return const EditorActionResult.failure(
        'Spigots must be inside the room or on a wall.',
      );
    }

    return const EditorActionResult.success();
  }
}
