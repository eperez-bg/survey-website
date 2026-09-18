import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../controllers/map_editor_controller.dart';
import '../models/table_drop_preview.dart';
import '../painters/canopy_draft_painter.dart';
import '../painters/distance_painter.dart';
import '../painters/store_layout_painters.dart';
import '../utils/zone_color.dart';
import 'layout_table_widget.dart';

typedef TableDragStarted =
    void Function(String anchorTableId, List<String> movingTableIds);

/// Renders the ordered visual layers of the map editor.
///
/// Gesture interpretation stays in [MapEditorCanvas]. This widget receives
/// already-derived visual state and reports table-specific interactions.
class MapEditorCanvasLayers extends StatelessWidget {
  final MapEditorController controller;
  final double cellSize;
  final double canvasWidth;
  final double canvasHeight;
  final TableDropPreview? tableDropPreview;
  final Set<String> draggedTableIds;
  final ValueChanged<String> onTableTap;
  final TableDragStarted onTableDragStarted;
  final VoidCallback onTableDragFinished;

  const MapEditorCanvasLayers({
    super.key,
    required this.controller,
    required this.cellSize,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.tableDropPreview,
    required this.draggedTableIds,
    required this.onTableTap,
    required this.onTableDragStarted,
    required this.onTableDragFinished,
  });

  @override
  Widget build(BuildContext context) {
    final layout = controller.layout;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: StoreGridPainter(
            cellSize: cellSize,
            roomBounds: layout.roomBounds,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: StoreCanopyPainter(layout: layout, cellSize: cellSize),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: StoreNoInstallZonePainter(
                layout: layout,
                cellSize: cellSize,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CanopyDraftPainter(
                cellSize: cellSize,
                corners: controller.canopyDisplayCorners,
                validNextCells: controller.canopyValidNextCorners.toList(),
                previewCells: controller.canopyPreviewCells,
                willRemove: controller.canopyDraftWillRemove,
                isNoInstallZone:
                    controller.isNoInstallZonePlacementEnabled,
                showCorners: false,
              ),
            ),
          ),
        ),
        for (final table in layout.layoutTableList) _positionedTable(table),
        if (tableDropPreview != null)
          for (
            var previewIndex = 0;
            previewIndex < tableDropPreview!.tables.length;
            previewIndex += 1
          )
            _tableDropShadow(
              tableDropPreview!.tables[previewIndex],
              previewIndex,
              tableDropPreview!.canPlace,
            ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: DistancePainter(
                layout: layout,
                cellSize: cellSize,
                selectedDistanceId: controller.selectedDistanceId,
                draftCells: controller.draftDistanceCells,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: StoreOverlayPainter(
                layout: layout,
                cellSize: cellSize,
                selectedEntranceId: controller.selectedEntranceId,
                entranceDragPreview: controller.entranceDragPreview,
                entranceDragPreviewIsValid:
                    controller.isEntranceDragPreviewValid,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CanopyDraftPainter(
                cellSize: cellSize,
                corners: controller.canopyDisplayCorners,
                previewCells: controller.canopyPreviewCells,
                willRemove: controller.canopyDraftWillRemove,
                isNoInstallZone:
                    controller.isNoInstallZonePlacementEnabled,
                showPreview: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _positionedTable(LayoutTable table) {
    final isZoneMode = controller.activeTool == MapEditorTool.zones;
    final zone = isZoneMode ? controller.zoneForTable(table) : null;
    final tableIdsForDrag = controller.tableIdsForDrag(table.tableId);
    final tableWidget = LayoutTableWidget(
      table: table,
      cellSize: cellSize,
      isSelected: controller.isTableSelected(table.tableId),
      canDrag: controller.activeTool == MapEditorTool.select,
      zoneColor: zone == null ? null : zoneColorFromHex(zone.colorHex),
      isInCurrentZone: isZoneMode && controller.isTableInCurrentZone(table),
      useZoneAssignmentStyling: isZoneMode,
      tableIdsForDrag: tableIdsForDrag,
      isBeingDragged: draggedTableIds.contains(table.tableId),
      onTap: () => onTableTap(table.tableId),
      onDragStarted: () => onTableDragStarted(table.tableId, tableIdsForDrag),
      onDragFinished: onTableDragFinished,
    );

    return Positioned(
      key: ValueKey(table.tableId),
      left: table.leftColumn * cellSize,
      top: table.topRow * cellSize,
      width: table.widthCells * cellSize,
      height: table.heightCells * cellSize,
      child: IgnorePointer(
        // Cell-editing tools must receive gestures above table widgets.
        ignoring:
            controller.activeTool == MapEditorTool.canopy ||
            controller.activeTool == MapEditorTool.distances ||
            controller.activeTool == MapEditorTool.resize,
        child: tableWidget,
      ),
    );
  }

  Widget _tableDropShadow(LayoutTable table, int previewIndex, bool canPlace) {
    final color = canPlace ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Positioned(
      key: ValueKey('table-drop-shadow-${table.tableId}-$previewIndex'),
      left: table.leftColumn * cellSize,
      top: table.topRow * cellSize,
      width: table.widthCells * cellSize,
      height: table.heightCells * cellSize,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.20),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color, width: 3),
          ),
        ),
      ),
    );
  }
}
