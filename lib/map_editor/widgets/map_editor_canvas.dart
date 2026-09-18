import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../controllers/map_editor_controller.dart';
import '../models/canopy_corner_drag_data.dart';
import '../models/table_drag_data.dart';
import '../models/table_drop_preview.dart';
import '../utils/entrance_placement_rules.dart';
import '../utils/grid_geometry.dart';
import '../utils/table_pair_rules.dart';
import 'map_editor_canvas_layers.dart';

class MapEditorCanvas extends StatefulWidget {
  final MapEditorController controller;
  final ValueChanged<String> onActionRejected;
  final Future<String?> Function() onCustomTableNameRequested;
  final VoidCallback onDistanceDraftReady;
  final ValueChanged<GridIntersection> onSpigotIntersectionRequested;
  final double cellSize;

  const MapEditorCanvas({
    super.key,
    required this.controller,
    required this.onActionRejected,
    required this.onCustomTableNameRequested,
    required this.onDistanceDraftReady,
    required this.onSpigotIntersectionRequested,
    this.cellSize = 30,
  });

  @override
  State<MapEditorCanvas> createState() => _MapEditorCanvasState();
}

class _MapEditorCanvasState extends State<MapEditorCanvas> {
  /// Keeps the table target visible above the surveyor's finger.
  ///
  /// This is applied in viewport logical pixels before converting through the
  /// zoom transform, so the visual distance stays useful at every zoom level.
  static const Offset _tableDropViewportOffset = Offset(0, -56);

  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  TableDropPreview? _tableDropPreview;
  Set<String> _draggedTableIds = <String>{};

  GridGeometry get _geometry => GridGeometry(cellSize: widget.cellSize);

  @override
  void initState() {
    super.initState();
    _transformationController.value = Matrix4.diagonal3Values(0.6, 0.6, 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.controller.layout;
    final isSpigotPlacementEnabled =
        widget.controller.activeTool == MapEditorTool.select &&
        widget.controller.isSpigotPlacementEnabled;
    final isEntrancePlacementEnabled =
        widget.controller.activeTool == MapEditorTool.resize &&
        widget.controller.isEntrancePlacementEnabled;
    final canvasWidth = layout.canvasColumns * widget.cellSize;
    final canvasHeight = layout.canvasRows * widget.cellSize;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: DragTarget<Object>(
          onWillAcceptWithDetails: _canAcceptDrag,
          onMove: _handleEditorDragMove,
          onLeave: _handleEditorDragLeave,
          onAcceptWithDetails: (details) {
            unawaited(_handleEditorDrop(details));
          },
          builder: (context, candidateData, rejectedData) {
            final hasCanopyCorner = candidateData.any(
              (data) => data is CanopyCornerDragData,
            );
            return Container(
              key: _viewportKey,
              decoration: BoxDecoration(
                border: candidateData.isEmpty
                    ? null
                    : Border.all(
                        color: hasCanopyCorner
                            ? widget.controller.isNoInstallZonePlacementEnabled
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706)
                            : const Color(0xFF2563EB),
                        width: 3,
                      ),
              ),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: _claimMapPointerSignal,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: 0.45,
                  maxScale: 3,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(180),
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: GestureDetector(
                      key: const ValueKey('map-editor-gesture-surface'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _handleCanvasTap,
                      onDoubleTapDown:
                          isSpigotPlacementEnabled || isEntrancePlacementEnabled
                          ? _handleCanvasDoubleTap
                          : null,
                      onLongPressStart: isEntrancePlacementEnabled
                          ? _handleEntranceLongPressStart
                          : null,
                      onLongPressMoveUpdate: isEntrancePlacementEnabled
                          ? _handleEntranceLongPressMove
                          : null,
                      onLongPressEnd: isEntrancePlacementEnabled
                          ? _handleEntranceLongPressEnd
                          : null,
                      onLongPressCancel: isEntrancePlacementEnabled
                          ? widget.controller.cancelEntranceDrag
                          : null,
                      child: MapEditorCanvasLayers(
                        controller: widget.controller,
                        cellSize: widget.cellSize,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        tableDropPreview: _tableDropPreview,
                        draggedTableIds: _draggedTableIds,
                        onTableTap: _handleTableTap,
                        onTableDragStarted: _handleTableDragStarted,
                        onTableDragFinished: _clearTableDragVisuals,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Keeps wheel zoom inside the editor from scrolling a parent page.
  void _claimMapPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
  }

  void _handleTableTap(String tableId) {
    if (widget.controller.activeTool == MapEditorTool.zones) {
      _reportFailure(widget.controller.toggleTableInCurrentZone(tableId));
      return;
    }

    widget.controller.toggleTableSelection(tableId);
  }

  bool _canAcceptDrag(DragTargetDetails<Object> details) {
    final data = details.data;
    if (data is TableDragData) {
      return widget.controller.activeTool == MapEditorTool.select;
    }
    if (data is CanopyCornerDragData) {
      return widget.controller.activeTool == MapEditorTool.canopy &&
          !widget.controller.isCanopyPreviewReady;
    }

    return false;
  }

  void _handleEditorDragMove(DragTargetDetails<Object> details) {
    final data = details.data;
    if (data is! TableDragData ||
        widget.controller.activeTool != MapEditorTool.select) {
      return;
    }

    final scenePoint = _scenePointForGlobalOffset(
      details.offset,
      reportError: false,
      viewportOffset: _tableDropViewportOffset,
    );
    if (scenePoint == null) {
      return;
    }

    final preview = widget.controller.previewTableDrop(
      dragData: data,
      topLeft: _topLeftForTableDrag(data, scenePoint),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _tableDropPreview = preview;
    });
  }

  void _handleEditorDragLeave(Object? data) {
    if (data is! TableDragData || !mounted) {
      return;
    }

    setState(() {
      _tableDropPreview = null;
    });
  }

  Future<void> _handleEditorDrop(DragTargetDetails<Object> details) async {
    final data = details.data;
    if (data is TableDragData) {
      await _handleTableDrop(data: data, globalOffset: details.offset);
      return;
    }
    if (data is CanopyCornerDragData) {
      _handleCanopyCornerDrop(details.offset);
    }
  }

  Future<void> _handleTableDrop({
    required TableDragData data,
    required Offset globalOffset,
  }) async {
    if (widget.controller.activeTool != MapEditorTool.select) {
      return;
    }

    final scenePoint = _scenePointForGlobalOffset(
      globalOffset,
      viewportOffset: _tableDropViewportOffset,
    );
    if (scenePoint == null) {
      return;
    }

    final topLeft = _topLeftForTableDrag(data, scenePoint);
    final preview = widget.controller.previewTableDrop(
      dragData: data,
      topLeft: topLeft,
    );
    if (!preview.canPlace) {
      _clearTableDragVisuals();
      widget.onActionRejected(
        preview.message ?? 'That fixture cannot be placed there.',
      );
      return;
    }

    String? customTableName;
    if (!data.isMovingExistingTable && data.tableKind == TableKind.custom) {
      _clearTableDragVisuals();
      customTableName = await widget.onCustomTableNameRequested();
      if (!mounted || customTableName == null) {
        return;
      }
    }

    final result = widget.controller.placeOrMoveTable(
      dragData: data,
      topLeft: topLeft,
      customTableName: customTableName,
    );

    _clearTableDragVisuals();
    _reportFailure(result);
  }

  GridCoordinate _topLeftForTableDrag(TableDragData data, Offset scenePoint) {
    final isHorizontal = data.orientation == TableOrientation.horizontal;

    // Standard palette drags center the complete long-side-connected pair.
    // A custom palette drag centers its one physical table. Existing drags
    // keep the anchor centered so selected groups preserve their offsets.
    final isNewPair =
        !data.isMovingExistingTable && data.tableKind != TableKind.custom;
    return _geometry.centeredTableTopLeft(
      scenePoint: scenePoint,
      widthCells: isNewPair
          ? TablePairRules.footprintWidthCells(data.orientation)
          : (isHorizontal ? 3 : 2),
      heightCells: isNewPair
          ? TablePairRules.footprintHeightCells(data.orientation)
          : (isHorizontal ? 2 : 3),
    );
  }

  void _handleTableDragStarted(
    String anchorTableId,
    List<String> movingTableIds,
  ) {
    widget.controller.prepareTableDrag(anchorTableId);
    if (!mounted) {
      return;
    }

    setState(() {
      _draggedTableIds = movingTableIds.toSet();
      _tableDropPreview = null;
    });
  }

  void _clearTableDragVisuals() {
    if (!mounted || (_draggedTableIds.isEmpty && _tableDropPreview == null)) {
      return;
    }

    setState(() {
      _draggedTableIds = <String>{};
      _tableDropPreview = null;
    });
  }

  void _handleCanopyCornerDrop(Offset globalOffset) {
    if (widget.controller.activeTool != MapEditorTool.canopy) {
      return;
    }

    final scenePoint = _scenePointForGlobalOffset(globalOffset);
    if (scenePoint == null) {
      return;
    }

    _reportFailure(
      widget.controller.addCanopyCorner(_geometry.scenePointToCell(scenePoint)),
    );
  }

  Offset? _scenePointForGlobalOffset(
    Offset globalOffset, {
    bool reportError = true,
    Offset viewportOffset = Offset.zero,
  }) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      if (reportError) {
        widget.onActionRejected('Could not locate the map canvas.');
      }
      return null;
    }

    final viewportPoint =
        renderObject.globalToLocal(globalOffset) + viewportOffset;
    return _transformationController.toScene(viewportPoint);
  }

  void _handleCanvasTap(TapUpDetails details) {
    switch (widget.controller.activeTool) {
      case MapEditorTool.canopy:
        final result = widget.controller.addCanopyCorner(
          _geometry.scenePointToCell(details.localPosition),
        );
        _reportFailure(result);
        return;
      case MapEditorTool.zones:
        return;
      case MapEditorTool.distances:
        _handleDistanceTap(details);
        return;
      case MapEditorTool.resize:
        if (widget.controller.isEntrancePlacementEnabled) {
          _handleEntranceTap(details.localPosition);
        }
        return;
      case MapEditorTool.select:
        widget.controller.clearSelection();
        return;
    }
  }

  void _handleDistanceTap(TapUpDetails details) {
    final coordinate = _geometry.scenePointToCell(details.localPosition);

    if (widget.controller.selectDistanceAtCell(coordinate)) {
      return;
    }

    if (!widget.controller.hasDistanceDraft) {
      final beginResult = widget.controller.beginDistanceDraft(coordinate);
      if (!beginResult.succeeded) {
        _reportFailure(beginResult);
        return;
      }

      // A single selected cell may already bridge two fixtures.
      final oneCellResult = widget.controller.prepareDistanceDraft();
      if (oneCellResult.succeeded) {
        widget.onDistanceDraftReady();
      }
      return;
    }

    final finishResult = widget.controller.finishDistancePath(coordinate);
    if (finishResult.succeeded) {
      widget.onDistanceDraftReady();
    } else {
      _reportFailure(finishResult);
    }
  }

  void _handleCanvasDoubleTap(TapDownDetails details) {
    if (widget.controller.activeTool == MapEditorTool.resize &&
        widget.controller.isEntrancePlacementEnabled) {
      final placement = EntrancePlacementRules.placementForScenePoint(
        scenePoint: details.localPosition,
        cellSize: widget.cellSize,
        roomBounds: widget.controller.layout.roomBounds,
        hitTolerancePixels: _entranceHitToleranceScenePixels,
      );
      if (placement == null) {
        widget.onActionRejected(
          'Entrances can only be added by double-tapping a room wall.',
        );
        return;
      }

      _reportFailure(widget.controller.addEntrance(placement));
      return;
    }

    if (widget.controller.isSpigotPlacementEnabled) {
      widget.onSpigotIntersectionRequested(
        _geometry.scenePointToNearestIntersection(details.localPosition),
      );
    }
  }

  void _handleEntranceTap(Offset scenePoint) {
    final entrance = _entranceAtScenePoint(scenePoint);
    if (entrance == null) {
      widget.controller.clearEntranceSelection();
      return;
    }

    widget.controller.selectEntrance(entrance.entranceId);
  }

  void _handleEntranceLongPressStart(LongPressStartDetails details) {
    final entrance = _entranceAtScenePoint(details.localPosition);
    if (entrance == null) {
      return;
    }

    _reportFailure(widget.controller.beginEntranceDrag(entrance.entranceId));
  }

  void _handleEntranceLongPressMove(LongPressMoveUpdateDetails details) {
    final selectedEntrance = widget.controller.selectedEntrance;
    if (!widget.controller.isDraggingEntrance || selectedEntrance == null) {
      return;
    }

    widget.controller.updateEntranceDragPreview(
      EntrancePlacementRules.placementForScenePoint(
        scenePoint: details.localPosition,
        cellSize: widget.cellSize,
        roomBounds: widget.controller.layout.roomBounds,
        widthCells: selectedEntrance.widthCells,
        hitTolerancePixels: _entranceHitToleranceScenePixels,
      ),
    );
  }

  void _handleEntranceLongPressEnd(LongPressEndDetails details) {
    if (!widget.controller.isDraggingEntrance) {
      return;
    }

    _reportFailure(widget.controller.finishEntranceDrag());
  }

  Entrance? _entranceAtScenePoint(Offset scenePoint) {
    final layout = widget.controller.layout;
    return EntrancePlacementRules.entranceAtScenePoint(
      scenePoint: scenePoint,
      cellSize: widget.cellSize,
      roomBounds: layout.roomBounds,
      entrances: layout.entranceList,
      hitTolerancePixels: _entranceHitToleranceScenePixels,
    );
  }

  double get _entranceHitToleranceScenePixels {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    return 14 / (scale <= 0 ? 1 : scale);
  }

  void _reportFailure(EditorActionResult result) {
    if (!result.succeeded && result.message != null) {
      widget.onActionRejected(result.message!);
    }
  }
}
