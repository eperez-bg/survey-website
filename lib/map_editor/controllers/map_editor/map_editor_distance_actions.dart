part of '../map_editor_controller.dart';

/// Distance drafting, selection, persistence, and editing use cases.
extension MapEditorDistanceActions on MapEditorController {
  EditorActionResult beginDistanceDraft(GridCoordinate startCell) {
    if (_activeTool != MapEditorTool.distances) {
      return const EditorActionResult.failure(
        'Select the Distance tool first.',
      );
    }
    if (_pendingDistanceConnection != null) {
      return const EditorActionResult.failure(
        'Finish or cancel the current distance first.',
      );
    }

    final placementError = LayoutPlacementRules.distanceCellsPlacementError(
      cells: [startCell],
      layout: _layout,
      ignoredDistanceId: _distanceBeingMoved?.distanceId,
    );
    if (placementError != null) {
      return EditorActionResult.failure(placementError);
    }

    _selectedDistanceId = null;
    _distanceDraftStartCell = startCell;
    _draftDistanceCells = [startCell];
    notifyListeners();

    return const EditorActionResult.success();
  }

  EditorActionResult updateDistanceDraft(GridCoordinate currentCell) {
    final startCell = _distanceDraftStartCell;
    if (startCell == null) {
      return const EditorActionResult.failure(
        'Select the first distance cell.',
      );
    }
    if (_pendingDistanceConnection != null) {
      return const EditorActionResult.failure(
        'Finish or cancel the current distance first.',
      );
    }

    final candidateCells = DistanceGeometry.snappedLine(startCell, currentCell);
    final placementError = LayoutPlacementRules.distanceCellsPlacementError(
      cells: candidateCells,
      layout: _layout,
      ignoredDistanceId: _distanceBeingMoved?.distanceId,
    );
    if (placementError != null) {
      return EditorActionResult.failure(placementError);
    }

    _draftDistanceCells = candidateCells;
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Treats the second distance tap as one complete placement attempt.
  ///
  /// If either the selected path or its fixture connections are invalid, the
  /// failed draft is cleared immediately so the next tap starts a new distance.
  EditorActionResult finishDistancePath(GridCoordinate endCell) {
    final updateResult = updateDistanceDraft(endCell);
    if (!updateResult.succeeded) {
      cancelDistanceDraft();
      return updateResult;
    }

    final prepareResult = prepareDistanceDraft();
    if (!prepareResult.succeeded) {
      cancelDistanceDraft();
    }
    return prepareResult;
  }

  /// Resolves the selected cells into persisted endpoints before asking for
  /// the physical measurement.
  EditorActionResult prepareDistanceDraft() {
    if (_pendingDistanceConnection != null) {
      return const EditorActionResult.success();
    }

    final resolution = DistanceGeometry.resolveConnection(
      selectedCells: _draftDistanceCells,
      layout: _layout,
    );
    if (!resolution.succeeded) {
      return EditorActionResult.failure(
        resolution.error ?? 'The selected distance is invalid.',
      );
    }

    final connection = resolution.connection!;
    final placementError = LayoutPlacementRules.distanceCellsPlacementError(
      cells: connection.cells,
      layout: _layout,
      ignoredDistanceId: _distanceBeingMoved?.distanceId,
    );
    if (placementError != null) {
      return EditorActionResult.failure(placementError);
    }

    _pendingDistanceConnection = connection;
    notifyListeners();

    return const EditorActionResult.success();
  }

  EditorActionResult completePendingDistance({
    required double measuredDistance,
  }) {
    final connection = _pendingDistanceConnection;
    if (connection == null) {
      return const EditorActionResult.failure(
        'There is no completed distance path to save.',
      );
    }
    if (!measuredDistance.isFinite || measuredDistance <= 0) {
      return const EditorActionResult.failure(
        'Distance must be greater than zero.',
      );
    }
    final distanceBeingMoved = _distanceBeingMoved;
    final distance = Distance(
      distanceId: distanceBeingMoved?.distanceId ?? _nextDistanceId(),
      measuredDistance: measuredDistance,
      start: connection.start,
      end: connection.end,
    );

    _layout = _layout.copyWith(
      distanceList: distanceBeingMoved == null
          ? [..._layout.distanceList, distance]
          : [
              for (final existing in _layout.distanceList)
                existing.distanceId == distanceBeingMoved.distanceId
                    ? distance
                    : existing,
            ],
    );
    _clearDistanceInteraction();
    _selectedDistanceId = distance.distanceId;
    notifyListeners();

    return const EditorActionResult.success();
  }

  void cancelDistanceDraft() {
    if (_distanceDraftStartCell == null &&
        _draftDistanceCells.isEmpty &&
        _pendingDistanceConnection == null &&
        _distanceBeingMoved == null) {
      return;
    }

    final movedDistanceId = _distanceBeingMoved?.distanceId;
    _clearDistanceInteraction();
    _selectedDistanceId = movedDistanceId;
    notifyListeners();
  }

  bool selectDistanceAtCell(GridCoordinate coordinate) {
    if (_distanceBeingMoved != null) {
      return false;
    }
    for (final distance in _layout.distanceList.reversed) {
      final cells = DistanceGeometry.cellsForDistance(distance, _layout);
      if (cells.contains(coordinate)) {
        _clearDistanceInteraction();
        _selectedTableIds.clear();
        _selectedEntranceId = null;
        _clearEntranceDrag();
        _selectedDistanceId = distance.distanceId;
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  void deselectDistance() {
    if (_selectedDistanceId == null) {
      return;
    }

    _selectedDistanceId = null;
    notifyListeners();
  }

  /// Keeps the selected distance visible while the project manager redraws
  /// its endpoints. The old path is ignored for collision checks and remains
  /// untouched if the redraw is cancelled.
  EditorActionResult beginMovingSelectedDistance() {
    final distance = selectedDistance;
    if (distance == null) {
      return const EditorActionResult.failure(
        'Select a distance to move.',
      );
    }

    _distanceDraftStartCell = null;
    _draftDistanceCells = const [];
    _pendingDistanceConnection = null;
    _distanceBeingMoved = distance;
    _selectedDistanceId = null;
    notifyListeners();

    return const EditorActionResult.success(
      message: 'Tap the first and last cells for the new distance path.',
    );
  }

  EditorActionResult removeSelectedDistance() {
    final selectedId = _selectedDistanceId;
    if (selectedId == null) {
      return const EditorActionResult.failure(
        'Select a distance to delete.',
      );
    }

    _layout = _layout.copyWith(
      distanceList: _layout.distanceList
          .where((distance) => distance.distanceId != selectedId)
          .toList(),
    );
    _selectedDistanceId = null;
    _clearDistanceInteraction();
    notifyListeners();

    return const EditorActionResult.success();
  }

  EditorActionResult updateSelectedDistanceMeasurement({
    required double measuredDistance,
  }) {
    final distance = selectedDistance;
    if (distance == null) {
      return const EditorActionResult.failure('Select a distance to edit.');
    }
    if (!measuredDistance.isFinite || measuredDistance <= 0) {
      return const EditorActionResult.failure(
        'Distance must be greater than zero.',
      );
    }
    final distanceIndex = _layout.distanceList.indexWhere(
      (candidate) => candidate.distanceId == distance.distanceId,
    );
    final updatedDistances = [..._layout.distanceList];
    updatedDistances[distanceIndex] = Distance(
      distanceId: distance.distanceId,
      measuredDistance: measuredDistance,
      start: distance.start,
      end: distance.end,
    );

    _layout = _layout.copyWith(distanceList: updatedDistances);
    notifyListeners();

    return const EditorActionResult.success();
  }
}
