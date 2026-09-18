part of '../map_editor_controller.dart';

/// Canvas and room resizing use cases for [MapEditorController].
extension MapEditorResizeActions on MapEditorController {
  /// Moves one canvas or room edge by whole grid cells.
  ///
  /// Non-removable blockers are validated before disconnected distances are
  /// deleted, so every rejected resize leaves the layout unchanged.
  EditorActionResult resizeLayout({
    required LayoutResizeTarget target,
    required LayoutResizeSide side,
    required int deltaCells,
  }) {
    final calculation = LayoutResizeGeometry.calculate(
      target: target,
      side: side,
      deltaCells: deltaCells,
      canvasRows: _layout.canvasRows,
      canvasColumns: _layout.canvasColumns,
      roomBounds: _layout.roomBounds,
    );
    if (!calculation.succeeded) {
      return EditorActionResult.failure(
        calculation.error ?? 'That resize is not possible.',
      );
    }

    return target == LayoutResizeTarget.canvas
        ? _applyCanvasResize(calculation)
        : _applyRoomResize(calculation, side: side, deltaCells: deltaCells);
  }

  EditorActionResult _applyCanvasResize(LayoutResizeCalculation calculation) {
    final removedArea = calculation.removedArea;
    if (removedArea != null &&
        (_areaContainsNonDistanceFixture(removedArea, _layout) ||
            !_spigotsFitShiftedCanvas(calculation))) {
      return const EditorActionResult.failure(
        'Fixtures must be moved away from that edge before decreasing '
        'the canvas.',
      );
    }

    final shiftedLayout = _shiftLayoutForCanvasResize(calculation);
    var candidateLayout = shiftedLayout.copyWith(distanceList: const []);
    final validationError = LayoutPlacementRules.nonDistanceResizeValidationError(
      candidateLayout,
    );
    if (validationError != null) {
      return EditorActionResult.failure(validationError);
    }

    final keptDistances = <Distance>[];
    final occupiedDistanceCells = <GridCoordinate>{};
    var removedDistanceCount = 0;

    for (final distance in shiftedLayout.distanceList) {
      final cells = DistanceGeometry.cellsForDistance(distance, candidateLayout);
      final remainsValid =
          cells.isNotEmpty &&
          LayoutPlacementRules.distanceCellsAreValidInLayout(
            cells,
            candidateLayout,
            occupiedDistanceCells: occupiedDistanceCells,
          );

      if (remainsValid) {
        keptDistances.add(distance);
        occupiedDistanceCells.addAll(cells);
      } else {
        removedDistanceCount += 1;
      }
    }

    candidateLayout = candidateLayout.copyWith(distanceList: keptDistances);
    _layout = candidateLayout;
    if (_selectedDistanceId != null &&
        !keptDistances.any((distance) => distance.distanceId == _selectedDistanceId)) {
      _selectedDistanceId = null;
    }
    notifyListeners();

    return EditorActionResult.success(
      message: _automaticDistanceDeletionMessage(removedDistanceCount),
    );
  }

  EditorActionResult _applyRoomResize(
    LayoutResizeCalculation calculation, {
    required LayoutResizeSide side,
    required int deltaCells,
  }) {
    final movedWall = _wallSideForResizeSide(side);
    final addedCanvasRows = calculation.canvasRows - _layout.canvasRows;
    final addedCanvasColumns =
        calculation.canvasColumns - _layout.canvasColumns;
    final shiftedPreviousRoomBounds = RoomBounds(
      topRow: _layout.roomBounds.topRow + calculation.rowShift,
      leftColumn: _layout.roomBounds.leftColumn + calculation.columnShift,
      widthCells: _layout.roomBounds.widthCells,
      heightCells: _layout.roomBounds.heightCells,
    );
    // When room growth inserts canvas space at the top or left, shift every
    // absolute fixture first. The requested wall movement is then applied to
    // that shifted layout as part of the same saved action.
    final shiftedLayout = _shiftLayoutForCanvasResize(
      calculation,
      roomBounds: shiftedPreviousRoomBounds,
    );

    final removedArea = calculation.removedArea;
    if (removedArea != null &&
        _areaContainsNonDistanceFixture(
          removedArea,
          _layout,
          includeCanopy: false,
        )) {
      return const EditorActionResult.failure(
        'Fixtures must be moved away from that wall before decreasing '
        'the room.',
      );
    }

    final resizedEntrances = _entrancesAfterRoomResize(
      sourceLayout: shiftedLayout,
      side: side,
      deltaCells: deltaCells,
      roomBounds: calculation.roomBounds,
    );
    if (resizedEntrances == null) {
      return const EditorActionResult.failure(
        'An entrance would be cut off by that resize. Increase the room or '
        'move the entrance first.',
      );
    }

    var candidateLayout = shiftedLayout.copyWith(
      roomBounds: calculation.roomBounds,
      entranceList: resizedEntrances,
      spigotList: _spigotsAfterRoomResize(
        sourceLayout: shiftedLayout,
        side: side,
        previousRoomBounds: shiftedPreviousRoomBounds,
        resizedRoomBounds: calculation.roomBounds,
      ),
      distanceList: const [],
    );
    final validationError = LayoutPlacementRules.nonDistanceResizeValidationError(
      candidateLayout,
    );
    if (validationError != null) {
      return EditorActionResult.failure(validationError);
    }

    final keptDistancesById = <String, Distance>{};
    final occupiedDistanceCells = <GridCoordinate>{};
    var removedDistanceCount = 0;
    final orderedDistances = [
      ...shiftedLayout.distanceList.where(
        (distance) => !_distanceHasWallEndpoint(distance),
      ),
      ...shiftedLayout.distanceList.where(_distanceHasWallEndpoint),
    ];

    for (final originalDistance in orderedDistances) {
      final isAttachedToMovedWall = _distanceReferencesWallSide(
        originalDistance,
        movedWall,
      );
      if (isAttachedToMovedWall) {
        removedDistanceCount += 1;
        continue;
      }

      final distance = _distanceAfterRoomResize(
        originalDistance,
        side: side,
        deltaCells: deltaCells,
        roomBounds: calculation.roomBounds,
      );
      if (distance == null) {
        removedDistanceCount += 1;
        continue;
      }

      final cells = DistanceGeometry.cellsForDistance(distance, candidateLayout);
      final remainsValid =
          cells.isNotEmpty &&
          LayoutPlacementRules.distanceCellsAreValidInLayout(
            cells,
            candidateLayout,
            occupiedDistanceCells: occupiedDistanceCells,
          );

      if (remainsValid) {
        keptDistancesById[distance.distanceId] = distance;
        occupiedDistanceCells.addAll(cells);
        continue;
      }

      removedDistanceCount += 1;
    }

    final keptDistances = [
      for (final originalDistance in shiftedLayout.distanceList)
        if (keptDistancesById.containsKey(originalDistance.distanceId))
          keptDistancesById[originalDistance.distanceId]!,
    ];
    candidateLayout = candidateLayout.copyWith(distanceList: keptDistances);
    _layout = candidateLayout;
    if (_selectedDistanceId != null &&
        !keptDistances.any((distance) => distance.distanceId == _selectedDistanceId)) {
      _selectedDistanceId = null;
    }
    notifyListeners();

    final resizeMessages = <String>[];
    final canvasExpansionMessage = _automaticCanvasExpansionMessage(
      side: side,
      addedRows: addedCanvasRows,
      addedColumns: addedCanvasColumns,
    );
    if (canvasExpansionMessage != null) {
      resizeMessages.add(canvasExpansionMessage);
    }
    if (removedDistanceCount > 0) {
      resizeMessages.add(_automaticDistanceDeletionMessage(removedDistanceCount)!);
    }

    if (resizeMessages.isEmpty) {
      return const EditorActionResult.success();
    }

    return EditorActionResult.success(message: resizeMessages.join(' '));
  }

  GardenCenterLayout _shiftLayoutForCanvasResize(
    LayoutResizeCalculation calculation, {
    RoomBounds? roomBounds,
  }) {
    final rowShift = calculation.rowShift;
    final columnShift = calculation.columnShift;

    return _layout.copyWith(
      canvasRows: calculation.canvasRows,
      canvasColumns: calculation.canvasColumns,
      roomBounds: roomBounds ?? calculation.roomBounds,
      layoutTableList: [
        for (final table in _layout.layoutTableList)
          table.copyWith(
            topRow: table.topRow + rowShift,
            leftColumn: table.leftColumn + columnShift,
          ),
      ],
      canopyCellList: {
        for (final cell in _layout.canopyCellList)
          CanopyCell(
            row: cell.row + rowShift,
            column: cell.column + columnShift,
            heightInches: cell.heightInches,
            lengthInches: cell.lengthInches,
            widthInches: cell.widthInches,
          ),
      },
      noInstallZoneCellList: {
        for (final cell in _layout.noInstallZoneCellList)
          NoInstallZoneCell(
            row: cell.row + rowShift,
            column: cell.column + columnShift,
          ),
      },
      spigotList: {
        for (final spigot in _layout.spigotList)
          Spigot(
            rowLine: spigot.rowLine + rowShift,
            columnLine: spigot.columnLine + columnShift,
            pressurePsi: spigot.pressurePsi,
          ),
      },
      distanceList: [
        for (final distance in _layout.distanceList)
          _distanceAfterCanvasShift(
            distance,
            rowShift: rowShift,
            columnShift: columnShift,
          ),
      ],
    );
  }

  Distance _distanceAfterCanvasShift(
    Distance distance, {
    required int rowShift,
    required int columnShift,
  }) {
    DistanceEndpoint shiftedEndpoint(DistanceEndpoint endpoint) {
      if (endpoint is CanopyDistanceEndpoint) {
        return endpoint.translated(
          rowDelta: rowShift,
          columnDelta: columnShift,
        );
      }
      return endpoint;
    }

    return Distance(
      distanceId: distance.distanceId,
      measuredDistance: distance.measuredDistance,
      start: shiftedEndpoint(distance.start),
      end: shiftedEndpoint(distance.end),
    );
  }

  bool _spigotsFitShiftedCanvas(LayoutResizeCalculation calculation) {
    for (final spigot in _layout.spigotList) {
      final nextRow = spigot.rowLine + calculation.rowShift;
      final nextColumn = spigot.columnLine + calculation.columnShift;
      if (nextRow < 0 ||
          nextRow > calculation.canvasRows ||
          nextColumn < 0 ||
          nextColumn > calculation.canvasColumns) {
        return false;
      }
    }

    return true;
  }

  /// Moves spigots attached to the resized wall while leaving every other
  /// spigot at its existing absolute grid intersection.
  Set<Spigot> _spigotsAfterRoomResize({
    required GardenCenterLayout sourceLayout,
    required LayoutResizeSide side,
    required RoomBounds previousRoomBounds,
    required RoomBounds resizedRoomBounds,
  }) {
    final resizedSpigots = <Spigot>{};

    for (final spigot in sourceLayout.spigotList) {
      var rowLine = spigot.rowLine;
      var columnLine = spigot.columnLine;

      switch (side) {
        case LayoutResizeSide.top:
          if (spigot.rowLine == previousRoomBounds.topRow) {
            rowLine = resizedRoomBounds.topRow;
          }
          break;
        case LayoutResizeSide.right:
          if (spigot.columnLine == previousRoomBounds.rightColumnExclusive) {
            columnLine = resizedRoomBounds.rightColumnExclusive;
          }
          break;
        case LayoutResizeSide.bottom:
          if (spigot.rowLine == previousRoomBounds.bottomRowExclusive) {
            rowLine = resizedRoomBounds.bottomRowExclusive;
          }
          break;
        case LayoutResizeSide.left:
          if (spigot.columnLine == previousRoomBounds.leftColumn) {
            columnLine = resizedRoomBounds.leftColumn;
          }
          break;
      }

      resizedSpigots.add(
        Spigot(
          rowLine: rowLine,
          columnLine: columnLine,
          pressurePsi: spigot.pressurePsi,
        ),
      );
    }

    return resizedSpigots;
  }

  List<Entrance>? _entrancesAfterRoomResize({
    required GardenCenterLayout sourceLayout,
    required LayoutResizeSide side,
    required int deltaCells,
    required RoomBounds roomBounds,
  }) {
    final resized = <Entrance>[];

    for (final entrance in sourceLayout.entranceList) {
      final nextOffset =
          entrance.offsetCells +
          _perpendicularWallOffsetDelta(
            side: side,
            wallSide: entrance.wallSide,
            deltaCells: deltaCells,
          );
      final wallLength =
          entrance.wallSide == WallSide.top ||
              entrance.wallSide == WallSide.bottom
          ? roomBounds.widthCells
          : roomBounds.heightCells;

      if (nextOffset < 0 || nextOffset + entrance.widthCells > wallLength) {
        return null;
      }

      resized.add(
        Entrance(
          entranceId: entrance.entranceId,
          wallSide: entrance.wallSide,
          offsetCells: nextOffset,
          widthCells: entrance.widthCells,
          clearanceDepthCells: entrance.clearanceDepthCells,
        ),
      );
    }

    return resized;
  }

  Distance? _distanceAfterRoomResize(
    Distance distance, {
    required LayoutResizeSide side,
    required int deltaCells,
    required RoomBounds roomBounds,
  }) {
    final start = _distanceEndpointAfterRoomResize(
      distance.start,
      side: side,
      deltaCells: deltaCells,
      roomBounds: roomBounds,
    );
    final end = _distanceEndpointAfterRoomResize(
      distance.end,
      side: side,
      deltaCells: deltaCells,
      roomBounds: roomBounds,
    );
    if (start == null || end == null) {
      return null;
    }

    return Distance(
      distanceId: distance.distanceId,
      measuredDistance: distance.measuredDistance,
      start: start,
      end: end,
    );
  }

  DistanceEndpoint? _distanceEndpointAfterRoomResize(
    DistanceEndpoint endpoint, {
    required LayoutResizeSide side,
    required int deltaCells,
    required RoomBounds roomBounds,
  }) {
    if (endpoint is TableDistanceEndpoint ||
        endpoint is CanopyDistanceEndpoint) {
      return endpoint;
    }

    final wallEndpoint = endpoint as WallDistanceEndpoint;
    final nextOffset =
        wallEndpoint.offsetCells +
        _perpendicularWallOffsetDelta(
          side: side,
          wallSide: wallEndpoint.wallSide,
          deltaCells: deltaCells,
        );
    final wallLength =
        wallEndpoint.wallSide == WallSide.top ||
            wallEndpoint.wallSide == WallSide.bottom
        ? roomBounds.widthCells
        : roomBounds.heightCells;
    if (nextOffset < 0 || nextOffset >= wallLength) {
      return null;
    }

    return WallDistanceEndpoint(
      wallSide: wallEndpoint.wallSide,
      offsetCells: nextOffset,
    );
  }

  int _perpendicularWallOffsetDelta({
    required LayoutResizeSide side,
    required WallSide wallSide,
    required int deltaCells,
  }) {
    final movingTopOrigin =
        side == LayoutResizeSide.top &&
        (wallSide == WallSide.left || wallSide == WallSide.right);
    final movingLeftOrigin =
        side == LayoutResizeSide.left &&
        (wallSide == WallSide.top || wallSide == WallSide.bottom);
    return movingTopOrigin || movingLeftOrigin ? deltaCells : 0;
  }

  bool _distanceReferencesWallSide(Distance distance, WallSide wallSide) {
    return _endpointReferencesWallSide(distance.start, wallSide) ||
        _endpointReferencesWallSide(distance.end, wallSide);
  }

  bool _endpointReferencesWallSide(DistanceEndpoint endpoint, WallSide wallSide) {
    return endpoint is WallDistanceEndpoint && endpoint.wallSide == wallSide;
  }

  WallSide _wallSideForResizeSide(LayoutResizeSide side) {
    return switch (side) {
      LayoutResizeSide.top => WallSide.top,
      LayoutResizeSide.right => WallSide.right,
      LayoutResizeSide.bottom => WallSide.bottom,
      LayoutResizeSide.left => WallSide.left,
    };
  }

  bool _areaContainsNonDistanceFixture(
    GridCellArea area,
    GardenCenterLayout layout, {
    bool includeCanopy = true,
  }) {
    if (layout.layoutTableList.any(area.overlapsTable)) {
      return true;
    }
    if (includeCanopy &&
        layout.canopyCellList.any(
          (cell) => area.containsCell(row: cell.row, column: cell.column),
        )) {
      return true;
    }
    if (includeCanopy &&
        layout.noInstallZoneCellList.any(
          (cell) => area.containsCell(row: cell.row, column: cell.column),
        )) {
      return true;
    }

    return false;
  }

  String? _automaticDistanceDeletionMessage(int removedDistanceCount) {
    if (removedDistanceCount == 0) {
      return null;
    }

    final distanceLabel = removedDistanceCount == 1
        ? 'distance was'
        : 'distances were';
    final reason = removedDistanceCount == 1
        ? 'it no longer fit'
        : 'they no longer fit';
    return '$removedDistanceCount $distanceLabel automatically deleted because '
        '$reason after resizing.';
  }

  String? _automaticCanvasExpansionMessage({
    required LayoutResizeSide side,
    required int addedRows,
    required int addedColumns,
  }) {
    final addedCells = addedRows > 0 ? addedRows : addedColumns;
    if (addedCells <= 0) {
      return null;
    }

    final dimensionLabel = addedRows > 0
        ? (addedCells == 1 ? 'row' : 'rows')
        : (addedCells == 1 ? 'column' : 'columns');
    final sideLabel = switch (side) {
      LayoutResizeSide.top => 'top',
      LayoutResizeSide.right => 'right',
      LayoutResizeSide.bottom => 'bottom',
      LayoutResizeSide.left => 'left',
    };
    return 'Canvas automatically added $addedCells $dimensionLabel at the '
        '$sideLabel to fit the room.';
  }

  bool _distanceHasWallEndpoint(Distance distance) {
    return distance.start is WallDistanceEndpoint ||
        distance.end is WallDistanceEndpoint;
  }
}
