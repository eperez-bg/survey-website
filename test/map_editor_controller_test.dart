import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/map_editor/controllers/map_editor_controller.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';
import 'package:survey_admin_web/map_editor/utils/grid_geometry.dart';
import 'package:survey_admin_web/map_editor/utils/layout_resize_geometry.dart';

void main() {
  group('MapEditorController admin session behavior', () {
    test('revert restores the opening layout and clears undo history', () {
      final initial = _layout();
      final controller = MapEditorController(initialLayout: initial);

      final resize = controller.resizeLayout(
        target: LayoutResizeTarget.canvas,
        side: LayoutResizeSide.right,
        deltaCells: 2,
      );

      expect(resize.succeeded, isTrue);
      expect(controller.hasChanges, isTrue);
      expect(controller.canUndo, isTrue);
      expect(controller.layout.canvasColumns, initial.canvasColumns + 2);

      controller.revertToInitialLayout();

      expect(identical(controller.layout, initial), isTrue);
      expect(controller.hasChanges, isFalse);
      expect(controller.canUndo, isFalse);
      expect(controller.undoLastMapAction(), isFalse);
    });

    test('selected entrance properties can be edited with placement checks', () {
      final controller = MapEditorController(initialLayout: _layout());
      controller.setActiveTool(MapEditorTool.resize);
      controller.setEntrancePlacementEnabled(true);
      controller.selectEntrance('entrance-1');

      final result = controller.updateSelectedEntrance(
        wallSide: WallSide.bottom,
        offsetCells: 3,
        widthCells: 4,
        clearanceDepthCells: 2,
      );

      expect(result.succeeded, isTrue);
      expect(controller.selectedEntrance?.wallSide, WallSide.bottom);
      expect(controller.selectedEntrance?.offsetCells, 3);
      expect(controller.selectedEntrance?.widthCells, 4);
      expect(controller.selectedEntrance?.clearanceDepthCells, 2);
      expect(controller.canUndo, isTrue);
    });

    test('existing canopy measurements can be edited and undone', () {
      final initial = _layout(
        canopyCellList: {
          for (final row in [1, 2])
            for (final column in [1, 2])
              CanopyCell(
                row: row,
                column: column,
                heightInches: 100,
                lengthInches: 200,
                widthInches: 300,
              ),
        },
      );
      final controller = MapEditorController(initialLayout: initial);
      controller.setActiveTool(MapEditorTool.canopy);

      expect(
        controller
            .addCanopyCorner(const GridCoordinate(row: 1, column: 1))
            .succeeded,
        isTrue,
      );
      expect(
        controller
            .addCanopyCorner(const GridCoordinate(row: 1, column: 2))
            .succeeded,
        isTrue,
      );
      expect(
        controller
            .addCanopyCorner(const GridCoordinate(row: 2, column: 1))
            .succeeded,
        isTrue,
      );
      expect(controller.shouldRemoveCanopyDraft, isTrue);

      final result = controller.confirmCanopyDraft(
        heightInches: 120,
        lengthInches: 220,
        widthInches: 320,
        replaceExistingMeasurements: true,
      );

      expect(result.succeeded, isTrue);
      expect(
        controller.layout.canopyCellList.every(
          (cell) =>
              cell.heightInches == 120 &&
              cell.lengthInches == 220 &&
              cell.widthInches == 320,
        ),
        isTrue,
      );
      expect(controller.undoLastMapAction(), isTrue);
      expect(
        controller.layout.canopyCellList.every(
          (cell) => cell.heightInches == 100,
        ),
        isTrue,
      );
    });
  });
}

GardenCenterLayout _layout({
  Set<CanopyCell> canopyCellList = const <CanopyCell>{},
}) {
  return GardenCenterLayout(
    canvasRows: 20,
    canvasColumns: 20,
    roomBounds: RoomBounds(
      topRow: 3,
      leftColumn: 3,
      widthCells: 12,
      heightCells: 12,
    ),
    canopyCellList: canopyCellList,
    entranceList: [
      Entrance(
        entranceId: 'entrance-1',
        wallSide: WallSide.top,
        offsetCells: 2,
        widthCells: 3,
        clearanceDepthCells: 2,
      ),
    ],
  );
}
