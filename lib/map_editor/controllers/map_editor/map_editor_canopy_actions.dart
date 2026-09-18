part of '../map_editor_controller.dart';

/// Three-corner canopy and No Install Zone drafting use cases.
extension MapEditorCanopyActions on MapEditorController {
  /// True when the preview matches existing canopy cells that already have all
  /// measurements and can therefore be removed without another prompt.
  ///
  /// An older or partially measured rectangle is treated as an update instead,
  /// allowing the surveyor to add the dimensions current submissions require.
  bool get shouldRemoveCanopyDraft =>
      _canopyPreviewCells.isNotEmpty &&
      _canopyPreviewCells.every(
        (coordinate) => _isNoInstallZonePlacementEnabled
            ? _layout.noInstallZoneCellList.contains(
                NoInstallZoneCell(
                  row: coordinate.row,
                  column: coordinate.column,
                ),
              )
            : _layout.canopyCellList.any(
                (cell) =>
                    cell.row == coordinate.row &&
                    cell.column == coordinate.column &&
                    cell.hasCompleteMeasurements,
              ),
      );

  EditorActionResult addCanopyCorner(GridCoordinate coordinate) {
    if (_activeTool != MapEditorTool.canopy) {
      return const EditorActionResult.failure('Select the Canopy tool first.');
    }
    final areaName = _isNoInstallZonePlacementEnabled
        ? 'No Install Zone'
        : 'canopy';
    final areaCellName = _isNoInstallZonePlacementEnabled
        ? 'No Install Zone cells'
        : 'canopy cells';
    if (isCanopyPreviewReady) {
      return EditorActionResult.failure(
        'Confirm or cancel the current $areaName rectangle first.',
      );
    }
    if (!LayoutPlacementRules.canvasContainsCell(
      layout: _layout,
      cell: coordinate,
    )) {
      return EditorActionResult.failure(
        '$areaName cells must be inside the canvas.',
      );
    }
    if (_canopyDraftCorners.contains(coordinate)) {
      return EditorActionResult.failure(
        'Each $areaName corner must use a different cell.',
      );
    }

    final validNextCorners = CanopyRectangle.validNextCorners(
      selectedCorners: _canopyDraftCorners,
      minRow: 0,
      maxRow: _layout.canvasRows - 1,
      minColumn: 0,
      maxColumn: _layout.canvasColumns - 1,
    );
    if (!validNextCorners.contains(coordinate)) {
      return EditorActionResult.failure(
        'Choose one of the highlighted $areaCellName.',
      );
    }

    final candidateCorners = [..._canopyDraftCorners, coordinate];

    if (candidateCorners.length < 3) {
      _canopyDraftCorners = candidateCorners;
      _selectedTableIds.clear();
      _selectedDistanceId = null;
      notifyListeners();
      return const EditorActionResult.success();
    }

    final rectangle = CanopyRectangle.fromCorners(candidateCorners);
    if (!rectangle.succeeded) {
      return EditorActionResult.failure(
        rectangle.error ?? 'Those corners do not form a rectangle.',
      );
    }

    _canopyDraftCorners = candidateCorners;
    _canopyInferredCorner = rectangle.inferredCorner;
    _canopyPreviewCells = rectangle.cells;
    _selectedTableIds.clear();
    _selectedDistanceId = null;
    notifyListeners();

    return const EditorActionResult.success();
  }

  void undoLastCanopyCorner() {
    if (_canopyDraftCorners.isEmpty) {
      return;
    }

    _canopyDraftCorners = _canopyDraftCorners.sublist(
      0,
      _canopyDraftCorners.length - 1,
    );
    _canopyInferredCorner = null;
    _canopyPreviewCells = const [];
    notifyListeners();
  }

  void cancelCanopyDraft() {
    if (!hasCanopyDraft && !isCanopyPreviewReady) {
      return;
    }

    _clearCanopyInteraction();
    notifyListeners();
  }

  /// Saves or removes the previewed canopy rectangle.
  ///
  /// All three measurements are required when adding a new area or measuring a
  /// legacy area. Removal needs none because its saved data is discarded.
  EditorActionResult confirmCanopyDraft({
    double? heightInches,
    double? lengthInches,
    double? widthInches,
    bool replaceExistingMeasurements = false,
  }) {
    if (!isCanopyPreviewReady) {
      return EditorActionResult.failure(
        _isNoInstallZonePlacementEnabled
            ? 'Place three valid No Install Zone corners before confirming.'
            : 'Place three valid canopy corners before confirming.',
      );
    }

    final willRemove = shouldRemoveCanopyDraft && !replaceExistingMeasurements;
    if (_isNoInstallZonePlacementEnabled) {
      return _confirmNoInstallZoneDraft(willRemove: willRemove);
    }

    if (!willRemove) {
      final placementError = LayoutPlacementRules.canopyCellsPlacementError(
        cells: _canopyPreviewCells,
        layout: _layout,
      );
      if (placementError != null) {
        return EditorActionResult.failure(placementError);
      }
    }

    if (!willRemove &&
        (heightInches == null ||
            !heightInches.isFinite ||
            heightInches <= 0)) {
      return const EditorActionResult.failure(
        'Enter a canopy height greater than zero.',
      );
    }
    if (!willRemove &&
        (lengthInches == null ||
            !lengthInches.isFinite ||
            lengthInches <= 0)) {
      return const EditorActionResult.failure(
        'Enter a canopy length greater than zero.',
      );
    }
    if (!willRemove &&
        (widthInches == null ||
            !widthInches.isFinite ||
            widthInches <= 0)) {
      return const EditorActionResult.failure(
        'Enter a canopy width greater than zero.',
      );
    }

    final previewCells = _canopyPreviewCells
        .map(
          (coordinate) => CanopyCell(
            row: coordinate.row,
            column: coordinate.column,
            heightInches: willRemove ? null : heightInches,
            lengthInches: willRemove ? null : lengthInches,
            widthInches: willRemove ? null : widthInches,
          ),
        )
        .toSet();
    final updatedCells = {..._layout.canopyCellList};

    if (willRemove) {
      updatedCells.removeAll(previewCells);
    } else {
      // Remove coordinate-equal cells first so an overlapping or legacy cell
      // receives the newly confirmed measurement instead of keeping old data.
      updatedCells.removeAll(previewCells);
      updatedCells.addAll(previewCells);
    }

    final candidateLayout = _layout.copyWith(canopyCellList: updatedCells);
    final disconnectsCanopyDistance = _layout.distanceList.any(
      (distance) =>
          (distance.start is CanopyDistanceEndpoint ||
              distance.end is CanopyDistanceEndpoint) &&
          DistanceGeometry.cellsForDistance(distance, candidateLayout).isEmpty,
    );
    if (disconnectsCanopyDistance) {
      return const EditorActionResult.failure(
        'Delete connected distances before changing or removing this canopy.',
      );
    }

    _layout = candidateLayout;
    _clearCanopyInteraction();
    notifyListeners();

    return const EditorActionResult.success();
  }

  EditorActionResult _confirmNoInstallZoneDraft({required bool willRemove}) {
    if (!willRemove) {
      final placementError =
          LayoutPlacementRules.noInstallZonePlacementError(
            cells: _canopyPreviewCells,
            layout: _layout,
          );
      if (placementError != null) {
        return EditorActionResult.failure(placementError);
      }
    }

    final previewCells = _canopyPreviewCells
        .map(
          (coordinate) => NoInstallZoneCell(
            row: coordinate.row,
            column: coordinate.column,
          ),
        )
        .toSet();
    final updatedCells = {..._layout.noInstallZoneCellList};

    if (willRemove) {
      updatedCells.removeAll(previewCells);
    } else {
      updatedCells.addAll(previewCells);
    }

    _layout = _layout.copyWith(noInstallZoneCellList: updatedCells);
    _clearCanopyInteraction();
    notifyListeners();

    return const EditorActionResult.success();
  }
}
