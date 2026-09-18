part of '../map_editor_controller.dart';

/// Entrance placement, selection, movement, and deletion use cases.
extension MapEditorEntranceActions on MapEditorController {
  /// Enables entrance gestures only while the Room editor is active.
  void setEntrancePlacementEnabled(bool enabled) {
    if (enabled && _activeTool != MapEditorTool.resize) {
      return;
    }
    if (_isEntrancePlacementEnabled == enabled) {
      return;
    }

    _isEntrancePlacementEnabled = enabled;
    if (!enabled) {
      _selectedEntranceId = null;
      _clearEntranceDrag();
    }
    notifyListeners();
  }

  /// Saves a new entrance centered at an already-snapped wall position.
  EditorActionResult addEntrance(EntranceWallPlacement placement) {
    final editingResult = _validateEntranceEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }

    final entrance = Entrance(
      entranceId: _nextEntranceId(),
      wallSide: placement.wallSide,
      offsetCells: placement.offsetCells,
      widthCells: EntrancePlacementRules.defaultWidthCells,
      clearanceDepthCells:
          EntrancePlacementRules.defaultClearanceDepthCells,
    );
    final placementError = EntrancePlacementRules.placementError(
      candidate: entrance,
      layout: _layout,
    );
    if (placementError != null) {
      return EditorActionResult.failure(placementError);
    }

    _layout = _layout.copyWith(
      entranceList: [..._layout.entranceList, entrance],
    );
    _selectedTableIds.clear();
    _selectedDistanceId = null;
    _selectedEntranceId = entrance.entranceId;
    _clearEntranceDrag();
    notifyListeners();

    return const EditorActionResult.success(message: 'Entrance added.');
  }

  /// Selects an entrance so the Room toolbar can offer deletion.
  void selectEntrance(String entranceId) {
    final exists = _layout.entranceList.any(
      (entrance) => entrance.entranceId == entranceId,
    );
    if (!exists ||
        !_isEntrancePlacementEnabled ||
        _activeTool != MapEditorTool.resize) {
      return;
    }
    if (_selectedEntranceId == entranceId && !isDraggingEntrance) {
      return;
    }

    _selectedTableIds.clear();
    _selectedDistanceId = null;
    _selectedEntranceId = entranceId;
    _clearEntranceDrag();
    notifyListeners();
  }

  void clearEntranceSelection() {
    if (_selectedEntranceId == null && !isDraggingEntrance) {
      return;
    }

    _selectedEntranceId = null;
    _clearEntranceDrag();
    notifyListeners();
  }

  /// Starts a long-press move and keeps the original as the first preview.
  EditorActionResult beginEntranceDrag(String entranceId) {
    final editingResult = _validateEntranceEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }

    Entrance? entrance;
    for (final candidate in _layout.entranceList) {
      if (candidate.entranceId == entranceId) {
        entrance = candidate;
        break;
      }
    }
    if (entrance == null) {
      return const EditorActionResult.failure(
        'That entrance no longer exists.',
      );
    }

    _selectedTableIds.clear();
    _selectedDistanceId = null;
    _selectedEntranceId = entranceId;
    _draggingEntranceId = entranceId;
    _entranceDragPreview = entrance;
    _entranceDragPreviewError = null;
    notifyListeners();

    return const EditorActionResult.success();
  }

  /// Updates the visual candidate without mutating persisted layout data.
  void updateEntranceDragPreview(EntranceWallPlacement? placement) {
    final original = _draggedEntrance;
    if (original == null) {
      return;
    }

    if (placement == null) {
      _entranceDragPreview = null;
      _entranceDragPreviewError =
          'Entrances can only be placed on room walls.';
      notifyListeners();
      return;
    }

    final candidate = Entrance(
      entranceId: original.entranceId,
      wallSide: placement.wallSide,
      offsetCells: placement.offsetCells,
      widthCells: original.widthCells,
      clearanceDepthCells: original.clearanceDepthCells,
    );
    _entranceDragPreview = candidate;
    _entranceDragPreviewError = EntrancePlacementRules.placementError(
      candidate: candidate,
      layout: _layout,
      ignoredEntranceId: original.entranceId,
    );
    notifyListeners();
  }

  /// Commits a valid preview or restores the original entrance on failure.
  EditorActionResult finishEntranceDrag() {
    final original = _draggedEntrance;
    if (original == null) {
      return const EditorActionResult.failure(
        'Long-press an entrance before moving it.',
      );
    }

    final preview = _entranceDragPreview;
    final placementError = _entranceDragPreviewError;
    _clearEntranceDrag();

    if (preview == null || placementError != null) {
      notifyListeners();
      return EditorActionResult.failure(
        placementError ?? 'Entrances can only be placed on room walls.',
      );
    }

    final didMove = preview.wallSide != original.wallSide ||
        preview.offsetCells != original.offsetCells;
    if (!didMove) {
      notifyListeners();
      return const EditorActionResult.success();
    }

    _layout = _layout.copyWith(
      entranceList: [
        for (final entrance in _layout.entranceList)
          entrance.entranceId == preview.entranceId ? preview : entrance,
      ],
    );
    _selectedEntranceId = preview.entranceId;
    notifyListeners();

    return const EditorActionResult.success(message: 'Entrance moved.');
  }

  void cancelEntranceDrag() {
    if (!isDraggingEntrance && _entranceDragPreview == null) {
      return;
    }

    _clearEntranceDrag();
    notifyListeners();
  }

  /// Updates every persisted entrance property from the admin properties
  /// dialog while still applying the field app's placement checks.
  EditorActionResult updateSelectedEntrance({
    required WallSide wallSide,
    required int offsetCells,
    required int widthCells,
    required int clearanceDepthCells,
  }) {
    final editingResult = _validateEntranceEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }

    final original = selectedEntrance;
    if (original == null) {
      return const EditorActionResult.failure(
        'Tap an entrance before editing it.',
      );
    }

    Entrance candidate;
    try {
      candidate = Entrance(
        entranceId: original.entranceId,
        wallSide: wallSide,
        offsetCells: offsetCells,
        widthCells: widthCells,
        clearanceDepthCells: clearanceDepthCells,
      );
    } on ArgumentError catch (error) {
      return EditorActionResult.failure(error.message?.toString() ?? '$error');
    }

    final placementError = EntrancePlacementRules.placementError(
      candidate: candidate,
      layout: _layout,
      ignoredEntranceId: original.entranceId,
    );
    if (placementError != null) {
      return EditorActionResult.failure(placementError);
    }

    _layout = _layout.copyWith(
      entranceList: [
        for (final entrance in _layout.entranceList)
          entrance.entranceId == candidate.entranceId ? candidate : entrance,
      ],
    );
    _selectedEntranceId = candidate.entranceId;
    _clearEntranceDrag();
    notifyListeners();

    return const EditorActionResult.success(
      message: 'Entrance properties updated.',
    );
  }

  EditorActionResult removeSelectedEntrance() {
    final editingResult = _validateEntranceEditingIsEnabled();
    if (!editingResult.succeeded) {
      return editingResult;
    }
    final entranceId = _selectedEntranceId;
    if (entranceId == null) {
      return const EditorActionResult.failure(
        'Tap an entrance before deleting it.',
      );
    }
    final exists = _layout.entranceList.any(
      (entrance) => entrance.entranceId == entranceId,
    );
    if (!exists) {
      _selectedEntranceId = null;
      _clearEntranceDrag();
      notifyListeners();
      return const EditorActionResult.failure(
        'That entrance no longer exists.',
      );
    }

    _layout = _layout.copyWith(
      entranceList: _layout.entranceList
          .where((entrance) => entrance.entranceId != entranceId)
          .toList(),
    );
    _selectedEntranceId = null;
    _clearEntranceDrag();
    notifyListeners();

    return const EditorActionResult.success(message: 'Entrance deleted.');
  }

  Entrance? get _draggedEntrance {
    final entranceId = _draggingEntranceId;
    if (entranceId == null) {
      return null;
    }

    for (final entrance in _layout.entranceList) {
      if (entrance.entranceId == entranceId) {
        return entrance;
      }
    }

    return null;
  }

  EditorActionResult _validateEntranceEditingIsEnabled() {
    if (_activeTool != MapEditorTool.resize) {
      return const EditorActionResult.failure(
        'Entrances can only be changed while Size is selected.',
      );
    }
    if (!_isEntrancePlacementEnabled) {
      return const EditorActionResult.failure(
        'Choose Room and turn on entrance placement first.',
      );
    }

    return const EditorActionResult.success();
  }
}
