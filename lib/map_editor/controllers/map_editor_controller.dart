import 'package:flutter/foundation.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../models/table_drag_data.dart';
import '../models/table_drop_preview.dart';
import '../utils/canopy_rectangle.dart';
import '../utils/entrance_placement_rules.dart';
import '../utils/grid_geometry.dart';
import '../utils/layout_placement_rules.dart';
import '../utils/layout_resize_geometry.dart';
import '../utils/distance_geometry.dart';
import '../utils/survey_completion_validator.dart';
import '../utils/table_group_geometry.dart';
import '../utils/table_pair_rules.dart';
import '../utils/zone_rules.dart';

part 'map_editor/map_editor_canopy_actions.dart';
part 'map_editor/map_editor_entrance_actions.dart';
part 'map_editor/map_editor_fixture_actions.dart';
part 'map_editor/map_editor_distance_actions.dart';
part 'map_editor/map_editor_resize_actions.dart';
part 'map_editor/map_editor_zone_actions.dart';

enum MapEditorTool { select, canopy, zones, distances, resize }

class EditorActionResult {
  final bool succeeded;
  final String? message;

  const EditorActionResult._({required this.succeeded, this.message});

  const EditorActionResult.success({String? message})
    : this._(succeeded: true, message: message);

  const EditorActionResult.failure(String message)
    : this._(succeeded: false, message: message);
}

/// Owns editor state and coordinates feature-specific actions.
///
/// Widgets send user intent here. Feature extensions in `controllers/map_editor`
/// apply the individual fixture, canopy, zone, distance, and resize use cases.
/// Stateless collision rules live in [LayoutPlacementRules].
class MapEditorController extends ChangeNotifier {
  static const int _undoHistoryLimit = 30;

  GardenCenterLayout _layout;
  final GardenCenterLayout _initialLayout;

  /// Completed layout mutations only; transient taps and selections stay out.
  final List<GardenCenterLayout> _undoHistory = <GardenCenterLayout>[];
  GardenCenterLayout _lastNotifiedLayout;

  Set<String> _selectedTableIds = <String>{};
  String? _selectedDistanceId;
  String? _selectedEntranceId;
  String? _currentZoneId;
  List<GridCoordinate> _canopyDraftCorners = const [];
  GridCoordinate? _canopyInferredCorner;
  List<GridCoordinate> _canopyPreviewCells = const [];
  GridCoordinate? _distanceDraftStartCell;
  List<GridCoordinate> _draftDistanceCells = const [];
  DistanceConnection? _pendingDistanceConnection;
  Distance? _distanceBeingMoved;
  MapEditorTool _activeTool = MapEditorTool.select;
  TableOrientation _paletteOrientation = TableOrientation.horizontal;
  bool _isSpigotPlacementEnabled = false;
  bool _isNoInstallZonePlacementEnabled = false;
  bool _isEntrancePlacementEnabled = false;
  String? _draggingEntranceId;
  Entrance? _entranceDragPreview;
  String? _entranceDragPreviewError;
  int _generatedTableCount = 0;
  int _generatedTablePairCount = 0;
  int _generatedZoneCount = 0;
  int _generatedDistanceCount = 0;
  int _generatedEntranceCount = 0;

  static const List<String> _zoneColorHexes = [
    '#EF4444',
    '#22C55E',
    '#3B82F6',
    '#A855F7',
    '#F59E0B',
    '#06B6D4',
    '#EC4899',
    '#84CC16',
  ];

  MapEditorController({required GardenCenterLayout initialLayout})
    : _layout = initialLayout,
      _initialLayout = initialLayout,
      _lastNotifiedLayout = initialLayout;

  GardenCenterLayout get layout => _layout;
  bool get canUndo => _undoHistory.isNotEmpty;
  bool get hasChanges => !identical(_layout, _initialLayout);
  Set<String> get selectedTableIds => Set.unmodifiable(_selectedTableIds);

  /// Records one history entry whenever a completed action changes the layout.
  ///
  /// Every map mutation already finishes by notifying listeners. Watching the
  /// immutable layout reference here keeps undo out of the fixture, canopy,
  /// distance, zone, and resize action files and prevents failed or in-progress
  /// gestures from entering history.
  @override
  void notifyListeners() {
    if (!identical(_layout, _lastNotifiedLayout)) {
      if (_undoHistory.length == _undoHistoryLimit) {
        _undoHistory.removeAt(0);
      }
      _undoHistory.add(_lastNotifiedLayout);
      _lastNotifiedLayout = _layout;
    }

    super.notifyListeners();
  }

  /// Restores the complete layout from before the most recent map mutation.
  ///
  /// Draft canopy corners and distance cells are intentionally cleared: undo
  /// acts on completed map state, not on a half-finished gesture or open prompt.
  bool undoLastMapAction() {
    if (_undoHistory.isEmpty) {
      return false;
    }

    _layout = _undoHistory.removeLast();
    _lastNotifiedLayout = _layout;
    _clearCanopyInteraction();
    _clearDistanceInteraction();
    _clearEntranceDrag();

    final existingTableIds = {
      for (final table in _layout.layoutTableList) table.tableId,
    };
    _selectedTableIds = _selectedTableIds.intersection(existingTableIds);

    final selectedDistanceStillExists =
        _selectedDistanceId != null &&
        _layout.distanceList.any(
          (distance) => distance.distanceId == _selectedDistanceId,
        );
    if (!selectedDistanceStillExists) {
      _selectedDistanceId = null;
    }

    final selectedEntranceStillExists =
        _selectedEntranceId != null &&
        _layout.entranceList.any(
          (entrance) => entrance.entranceId == _selectedEntranceId,
        );
    if (!selectedEntranceStillExists) {
      _selectedEntranceId = null;
    }

    final currentZoneStillExists = _currentZoneId != null &&
        _layout.zoneList.any((zone) => zone.zoneId == _currentZoneId);
    if (!currentZoneStillExists) {
      _currentZoneId =
          _activeTool == MapEditorTool.zones && _layout.zoneList.isNotEmpty
          ? _layout.zoneList.first.zoneId
          : null;
    }

    // Call the superclass directly because this restoration must not create a
    // new undo entry pointing back to the state that was just removed.
    super.notifyListeners();
    return true;
  }

  /// Counts selected logical fixtures rather than physical table rectangles.
  ///
  /// Selecting either half of a new pair selects both physical IDs, but the
  /// toolbar still reports that as one selected table pair. Each custom table
  /// is an independent logical fixture.
  int get selectedTableCount => TablePairRules.logicalFixtureCount(
    _layout.layoutTableList.where(
      (table) => _selectedTableIds.contains(table.tableId),
    ),
  );

  int get selectedCustomTableCount => _layout.layoutTableList
      .where(
        (table) =>
            _selectedTableIds.contains(table.tableId) &&
            table.tableKind == TableKind.custom,
      )
      .length;

  /// Pre-fills rename when every selected custom table currently matches.
  String? get selectedCustomTableCommonName {
    final names = {
      for (final table in _layout.layoutTableList)
        if (_selectedTableIds.contains(table.tableId) &&
            table.tableKind == TableKind.custom)
          table.customName!,
    };
    return names.length == 1 ? names.single : null;
  }

  /// Compatibility getter for code that still expects one physical table ID.
  ///
  /// New paired selections contain two physical IDs, so this is intentionally
  /// null for a pair. Legacy unpaired single selections still return their ID.
  String? get selectedTableId =>
      _selectedTableIds.length == 1 ? _selectedTableIds.single : null;

  List<String> get selectedTableIdsInLayoutOrder => [
    for (final table in _layout.layoutTableList)
      if (_selectedTableIds.contains(table.tableId)) table.tableId,
  ];

  /// Returns the physical IDs that should move when [tableId] starts a drag.
  ///
  /// If the anchor is already part of a multi-pair selection, the whole current
  /// selection moves. Otherwise only the anchor's logical pair moves.
  List<String> tableIdsForDrag(String tableId) {
    final movingIds = _selectedTableIds.contains(tableId)
        ? _selectedTableIds
        : _tableSelectionUnitIds(tableId);

    return [
      for (final table in _layout.layoutTableList)
        if (movingIds.contains(table.tableId)) table.tableId,
    ];
  }

  String? get selectedDistanceId => _selectedDistanceId;
  String? get selectedEntranceId => _selectedEntranceId;
  String? get currentZoneId => _currentZoneId;
  MapEditorTool get activeTool => _activeTool;
  TableOrientation get paletteOrientation => _paletteOrientation;
  bool get isSpigotPlacementEnabled => _isSpigotPlacementEnabled;
  bool get isNoInstallZonePlacementEnabled =>
      _isNoInstallZonePlacementEnabled;
  bool get isEntrancePlacementEnabled => _isEntrancePlacementEnabled;
  bool get isDraggingEntrance => _draggingEntranceId != null;
  Entrance? get entranceDragPreview => _entranceDragPreview;
  bool get isEntranceDragPreviewValid =>
      _entranceDragPreview != null && _entranceDragPreviewError == null;
  List<GridCoordinate> get canopyDraftCorners => _canopyDraftCorners;
  GridCoordinate? get canopyInferredCorner => _canopyInferredCorner;
  List<GridCoordinate> get canopyDisplayCorners => [
    ..._canopyDraftCorners,
    if (_canopyInferredCorner != null) _canopyInferredCorner!,
  ];
  List<GridCoordinate> get canopyPreviewCells => _canopyPreviewCells;
  bool get hasCanopyDraft => _canopyDraftCorners.isNotEmpty;
  bool get isCanopyPreviewReady => _canopyPreviewCells.isNotEmpty;
  Set<GridCoordinate> get canopyValidNextCorners {
    if (_activeTool != MapEditorTool.canopy ||
        _canopyDraftCorners.length != 2 ||
        isCanopyPreviewReady) {
      return const {};
    }

    return CanopyRectangle.validNextCorners(
      selectedCorners: _canopyDraftCorners,
      minRow: 0,
      maxRow: _layout.canvasRows - 1,
      minColumn: 0,
      maxColumn: _layout.canvasColumns - 1,
    );
  }
  List<GridCoordinate> get draftDistanceCells => _draftDistanceCells;
  bool get hasDistanceDraft => _draftDistanceCells.isNotEmpty;
  bool get isAwaitingDistanceMeasurement => _pendingDistanceConnection != null;
  Distance? get distanceBeingMoved => _distanceBeingMoved;
  bool get isMovingDistance => _distanceBeingMoved != null;

  bool get canopyDraftWillRemove =>
      _canopyPreviewCells.isNotEmpty &&
      _canopyPreviewCells.every(
        (coordinate) => _isNoInstallZonePlacementEnabled
            ? _layout.noInstallZoneCellList.contains(
                NoInstallZoneCell(
                  row: coordinate.row,
                  column: coordinate.column,
                ),
              )
            : _layout.canopyCellList.contains(
                CanopyCell(row: coordinate.row, column: coordinate.column),
              ),
      );

  /// Supplies the saved measurements when an existing canopy rectangle is
  /// selected for admin editing.
  CanopyCell? get canopyPreviewSourceCell {
    if (_isNoInstallZonePlacementEnabled || _canopyPreviewCells.isEmpty) {
      return null;
    }
    final first = _canopyPreviewCells.first;
    for (final cell in _layout.canopyCellList) {
      if (cell.row == first.row && cell.column == first.column) {
        return cell;
      }
    }
    return null;
  }

  Distance? get selectedDistance {
    final distanceId = _selectedDistanceId;
    if (distanceId == null) {
      return null;
    }

    for (final distance in _layout.distanceList) {
      if (distance.distanceId == distanceId) {
        return distance;
      }
    }

    return null;
  }

  Entrance? get selectedEntrance {
    final entranceId = _selectedEntranceId;
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

  Zone? get currentZone {
    final zoneId = _currentZoneId;
    if (zoneId == null) {
      return null;
    }

    for (final zone in _layout.zoneList) {
      if (zone.zoneId == zoneId) {
        return zone;
      }
    }

    return null;
  }

  int get currentZoneIndex {
    final zoneId = _currentZoneId;
    if (zoneId == null) {
      return -1;
    }

    return _layout.zoneList.indexWhere((zone) => zone.zoneId == zoneId);
  }

  int get zoneCount => _layout.zoneList.length;

  int get currentZoneFixtureCount {
    final zoneId = _currentZoneId;
    if (zoneId == null) {
      return 0;
    }

    return ZoneRules.fixtureCount(
      _layout.layoutTableList.where((table) => table.zoneId == zoneId),
    );
  }

  int get currentZoneWeightedTableCount {
    final zoneId = _currentZoneId;
    if (zoneId == null) {
      return 0;
    }

    return ZoneRules.weightedTableCount(
      _layout.layoutTableList.where((table) => table.zoneId == zoneId),
    );
  }

  int get unassignedTableCount => ZoneRules.fixtureCount(
    _layout.layoutTableList.where((table) => table.zoneId == null),
  );

  bool get canSelectPreviousZone => currentZoneIndex > 0;

  bool get canSelectNextZone =>
      currentZoneIndex >= 0 && currentZoneIndex < _layout.zoneList.length - 1;

  /// Production-facing normal-table count: one per normal pair.
  int get normalTableCount => TablePairRules.weightedCountForKind(
    _layout.layoutTableList,
    TableKind.normal,
  );

  /// Production-facing hanging count: two per hanging-basket pair.
  int get hangingBasketCount => TablePairRules.weightedCountForKind(
    _layout.layoutTableList,
    TableKind.hangingBasket,
  );

  /// Custom tables are independent named fixtures, not production pairs.
  int get customTableCount => _layout.layoutTableList
      .where((table) => table.tableKind == TableKind.custom)
      .length;

  int get spigotCount => _layout.spigotList.length;
  int get canopyCellCount => _layout.canopyCellList.length;
  int get noInstallZoneCellCount => _layout.noInstallZoneCellList.length;
  int get distanceCount => _layout.distanceList.length;
  int get entranceCount => _layout.entranceList.length;

  bool isTableSelected(String tableId) => _selectedTableIds.contains(tableId);

  /// Runs both persisted-layout and unfinished-interaction checks.
  SurveyCompletionValidation validateForCompletion() {
    return SurveyCompletionValidator.validate(
      layout: _layout,
      hasCanopyDraft: hasCanopyDraft || isCanopyPreviewReady,
      hasDistanceDraft:
          hasDistanceDraft || isAwaitingDistanceMeasurement || isMovingDistance,
    );
  }

  /// Selects the complete logical fixture containing [tableId].
  ///
  /// New palette tables always have two physical rectangles with the same
  /// pairId. Custom and legacy unpaired tables remain independently selectable.
  void selectTable(String tableId) {
    final unitIds = _tableSelectionUnitIds(tableId);
    if (unitIds.isEmpty) {
      return;
    }

    final wasOnlySelection =
        _selectedTableIds.length == unitIds.length &&
        _selectedTableIds.containsAll(unitIds) &&
        _activeTool == MapEditorTool.select;
    if (wasOnlySelection) {
      return;
    }

    _selectedTableIds = unitIds;
    _selectedDistanceId = null;
    _selectedEntranceId = null;
    _clearEntranceDrag();
    _clearCanopyInteraction();
    _isNoInstallZonePlacementEnabled = false;
    _activeTool = MapEditorTool.select;
    notifyListeners();
  }

  /// Adds or removes an entire logical fixture from the current selection.
  void toggleTableSelection(String tableId) {
    final unitIds = _tableSelectionUnitIds(tableId);
    if (unitIds.isEmpty) {
      return;
    }

    final updatedSelection = {..._selectedTableIds};
    final wholeUnitAlreadySelected = unitIds.every(updatedSelection.contains);
    if (wholeUnitAlreadySelected) {
      updatedSelection.removeAll(unitIds);
    } else {
      updatedSelection.addAll(unitIds);
    }

    _selectedTableIds = updatedSelection;
    _selectedDistanceId = null;
    _selectedEntranceId = null;
    _clearEntranceDrag();
    _clearCanopyInteraction();
    _isNoInstallZonePlacementEnabled = false;
    _activeTool = MapEditorTool.select;
    notifyListeners();
  }

  /// Makes an unselected pair the active drag selection.
  ///
  /// Dragging any member of an already-selected multi-pair selection keeps the
  /// whole current selection together.
  void prepareTableDrag(String tableId) {
    final unitIds = _tableSelectionUnitIds(tableId);
    if (unitIds.isEmpty || unitIds.every(_selectedTableIds.contains)) {
      return;
    }

    selectTable(tableId);
  }

  void clearSelection() {
    if (_selectedTableIds.isEmpty &&
        _selectedDistanceId == null &&
        _selectedEntranceId == null &&
        !isDraggingEntrance) {
      return;
    }

    _selectedTableIds.clear();
    _selectedDistanceId = null;
    _selectedEntranceId = null;
    _clearEntranceDrag();
    notifyListeners();
  }

  void setActiveTool(MapEditorTool tool) {
    var zoneWasCreated = false;
    var zoneWasSelected = false;

    if (tool == MapEditorTool.zones && _layout.zoneList.isEmpty) {
      _appendNewZone();
      zoneWasCreated = true;
    } else if (tool == MapEditorTool.zones && currentZone == null) {
      _currentZoneId = _layout.zoneList.first.zoneId;
      zoneWasSelected = true;
    }

    if (_activeTool == tool && !zoneWasCreated && !zoneWasSelected) {
      return;
    }

    if (tool != MapEditorTool.distances) {
      _clearDistanceInteraction();
    }
    if (tool != MapEditorTool.canopy) {
      _clearCanopyInteraction();
      _isNoInstallZonePlacementEnabled = false;
    }
    if (tool != MapEditorTool.resize) {
      _isEntrancePlacementEnabled = false;
      _selectedEntranceId = null;
      _clearEntranceDrag();
    }

    _activeTool = tool;
    if (tool != MapEditorTool.select) {
      _selectedTableIds.clear();
      _isSpigotPlacementEnabled = false;
    }
    if (tool != MapEditorTool.distances) {
      _selectedDistanceId = null;
    }
    notifyListeners();
  }

  /// Returns the zone referenced by [table], or null when it is unassigned.
  Zone? zoneForTable(LayoutTable table) {
    final zoneId = table.zoneId;
    if (zoneId == null) {
      return null;
    }

    for (final zone in _layout.zoneList) {
      if (zone.zoneId == zoneId) {
        return zone;
      }
    }

    return null;
  }

  bool isTableInCurrentZone(LayoutTable table) =>
      table.zoneId != null && table.zoneId == _currentZoneId;

  void togglePaletteOrientation() {
    _paletteOrientation = _paletteOrientation == TableOrientation.horizontal
        ? TableOrientation.vertical
        : TableOrientation.horizontal;
    notifyListeners();
  }

  /// Enables the double-tap gesture used to add and remove spigots.
  ///
  /// Spigot placement is a Fixtures-only sub-mode. Keeping it off by default
  /// prevents Flutter's double-tap recognizer from delaying rapid table taps.
  void setSpigotPlacementEnabled(bool enabled) {
    if (enabled && _activeTool != MapEditorTool.select) {
      return;
    }
    if (_isSpigotPlacementEnabled == enabled) {
      return;
    }

    _isSpigotPlacementEnabled = enabled;
    notifyListeners();
  }

  /// Switches the Canopy tool between measured canopies and red No Install
  /// Zones. Changing modes clears an unfinished rectangle so one draft can
  /// never be confirmed as a different area type.
  void setNoInstallZonePlacementEnabled(bool enabled) {
    if (enabled && _activeTool != MapEditorTool.canopy) {
      return;
    }
    if (_isNoInstallZonePlacementEnabled == enabled) {
      return;
    }

    _clearCanopyInteraction();
    _isNoInstallZonePlacementEnabled = enabled;
    notifyListeners();
  }

  /// Restores the version that was loaded when the admin editor opened.
  ///
  /// Revert is intentionally a new editing baseline rather than another undo
  /// entry. After it runs, Undo cannot resurrect the discarded changes.
  void revertToInitialLayout() {
    _layout = _initialLayout;
    _lastNotifiedLayout = _initialLayout;
    _undoHistory.clear();
    _selectedTableIds.clear();
    _selectedDistanceId = null;
    _selectedEntranceId = null;
    _currentZoneId = null;
    _clearCanopyInteraction();
    _clearDistanceInteraction();
    _activeTool = MapEditorTool.select;
    _paletteOrientation = TableOrientation.horizontal;
    _isSpigotPlacementEnabled = false;
    _isNoInstallZonePlacementEnabled = false;
    _isEntrancePlacementEnabled = false;
    _clearEntranceDrag();
    _generatedTableCount = 0;
    _generatedTablePairCount = 0;
    _generatedZoneCount = 0;
    _generatedDistanceCount = 0;
    _generatedEntranceCount = 0;
    super.notifyListeners();
  }

  /// Kept for compatibility with the field-app screen this editor originated
  /// from. Admin UI should use [revertToInitialLayout].
  void resetDemo() => revertToInitialLayout();

  void _clearDistanceInteraction() {
    _distanceDraftStartCell = null;
    _draftDistanceCells = const [];
    _pendingDistanceConnection = null;
    _distanceBeingMoved = null;
  }

  void _clearCanopyInteraction() {
    _canopyDraftCorners = const [];
    _canopyInferredCorner = null;
    _canopyPreviewCells = const [];
  }

  void _clearEntranceDrag() {
    _draggingEntranceId = null;
    _entranceDragPreview = null;
    _entranceDragPreviewError = null;
  }

  /// Resolves the physical IDs that must behave as one selection unit.
  Set<String> _tableSelectionUnitIds(String tableId) =>
      TablePairRules.memberIdsForTable(_layout.layoutTableList, tableId);

  String _nextTableId() {
    _generatedTableCount += 1;
    return 'admin-table-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$_generatedTableCount';
  }

  String _nextTablePairId() {
    _generatedTablePairCount += 1;
    return 'admin-table-pair-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$_generatedTablePairCount';
  }

  String _nextDistanceId() {
    _generatedDistanceCount += 1;
    return 'admin-distance-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$_generatedDistanceCount';
  }

  String _nextEntranceId() {
    _generatedEntranceCount += 1;
    return 'admin-entrance-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$_generatedEntranceCount';
  }

  void _appendNewZone() {
    final zoneNumber = _layout.zoneList.length + 1;
    final zone = Zone(
      zoneId: _nextZoneId(),
      label: 'Zone $zoneNumber',
      colorHex: _nextZoneColorHex(),
    );

    _layout = _layout.copyWith(zoneList: [..._layout.zoneList, zone]);
    _currentZoneId = zone.zoneId;
  }

  /// Applies an assignment and removes a former zone when it becomes empty.
  ///
  /// Surviving zones retain IDs and colors; only labels are renumbered.
  void _applyZoneMembershipChange({
    required List<LayoutTable> updatedTables,
    required String? previousZoneId,
  }) {
    var updatedZones = _layout.zoneList;

    final previousZoneBecameEmpty =
        previousZoneId != null &&
        !updatedTables.any((table) => table.zoneId == previousZoneId);

    if (previousZoneBecameEmpty) {
      final removedZoneIndex = updatedZones.indexWhere(
        (zone) => zone.zoneId == previousZoneId,
      );

      if (removedZoneIndex >= 0) {
        updatedZones = [...updatedZones]..removeAt(removedZoneIndex);
        updatedZones = _renumberZones(updatedZones);

        if (_currentZoneId == previousZoneId) {
          if (updatedZones.isEmpty) {
            _currentZoneId = null;
          } else {
            final replacementIndex = removedZoneIndex < updatedZones.length
                ? removedZoneIndex
                : updatedZones.length - 1;
            _currentZoneId = updatedZones[replacementIndex].zoneId;
          }
        }
      }
    }

    _layout = _layout.copyWith(
      layoutTableList: updatedTables,
      zoneList: updatedZones,
    );
  }

  /// Removes zones left empty by a multi-table deletion.
  List<Zone> _zonesAfterRemovingTables({
    required List<LayoutTable> removedTables,
    required List<LayoutTable> remainingTables,
  }) {
    // Capture the selected zone's original position before filtering. If that
    // zone becomes empty, its former position lets us choose the closest
    // surviving neighbor instead of leaving the zone toolbar unselected.
    final originalCurrentZoneIndex = _layout.zoneList.indexWhere(
      (zone) => zone.zoneId == _currentZoneId,
    );
    final affectedZoneIds = {
      for (final table in removedTables)
        if (table.zoneId != null) table.zoneId!,
    };
    if (affectedZoneIds.isEmpty) {
      return _layout.zoneList;
    }

    final remainingZoneIds = {
      for (final table in remainingTables)
        if (table.zoneId != null) table.zoneId!,
    };
    final survivingZones = [
      for (final zone in _layout.zoneList)
        if (!affectedZoneIds.contains(zone.zoneId) ||
            remainingZoneIds.contains(zone.zoneId))
          zone,
    ];

    if (survivingZones.length == _layout.zoneList.length) {
      return survivingZones;
    }

    final currentZoneStillExists = survivingZones.any(
      (zone) => zone.zoneId == _currentZoneId,
    );
    if (!currentZoneStillExists) {
      _currentZoneId = _nearestSurvivingZoneId(
        originalZones: _layout.zoneList,
        survivingZones: survivingZones,
        originalCurrentZoneIndex: originalCurrentZoneIndex,
      );
    }

    return _renumberZones(survivingZones);
  }

  /// Finds the closest surviving zone to the removed current zone.
  ///
  /// A following zone wins an equal-distance tie, matching the toolbar's
  /// existing behavior of keeping the same visible index when possible. When
  /// no zones survive, null intentionally makes the Create Zone button appear.
  String? _nearestSurvivingZoneId({
    required List<Zone> originalZones,
    required List<Zone> survivingZones,
    required int originalCurrentZoneIndex,
  }) {
    if (survivingZones.isEmpty) {
      return null;
    }

    // A missing/stale current ID has no meaningful neighbor. Selecting the
    // first surviving zone leaves the controller in a usable state.
    if (originalCurrentZoneIndex < 0) {
      return survivingZones.first.zoneId;
    }

    final originalIndexByZoneId = <String, int>{
      for (var index = 0; index < originalZones.length; index++)
        originalZones[index].zoneId: index,
    };

    Zone? nearestZone;
    var nearestIndex = -1;
    var nearestDistance = originalZones.length + 1;

    for (final zone in survivingZones) {
      final candidateIndex = originalIndexByZoneId[zone.zoneId];
      if (candidateIndex == null) {
        continue;
      }

      final candidateDistance =
          (candidateIndex - originalCurrentZoneIndex).abs();
      final candidateIsFollowing = candidateIndex > originalCurrentZoneIndex;
      final nearestIsFollowing = nearestIndex > originalCurrentZoneIndex;

      if (candidateDistance < nearestDistance ||
          (candidateDistance == nearestDistance &&
              candidateIsFollowing &&
              !nearestIsFollowing)) {
        nearestZone = zone;
        nearestIndex = candidateIndex;
        nearestDistance = candidateDistance;
      }
    }

    return nearestZone?.zoneId ?? survivingZones.first.zoneId;
  }

  List<Zone> _renumberZones(List<Zone> zones) {
    return [
      for (var index = 0; index < zones.length; index++)
        Zone(
          zoneId: zones[index].zoneId,
          label: 'Zone ${index + 1}',
          colorHex: zones[index].colorHex,
        ),
    ];
  }

  String _nextZoneColorHex() {
    final usedColors = _layout.zoneList
        .map((zone) => zone.colorHex.toUpperCase())
        .toSet();

    for (final colorHex in _zoneColorHexes) {
      if (!usedColors.contains(colorHex)) {
        return colorHex;
      }
    }

    final fallbackIndex = _layout.zoneList.length % _zoneColorHexes.length;
    return _zoneColorHexes[fallbackIndex];
  }

  String _nextZoneId() {
    _generatedZoneCount += 1;
    return 'admin-zone-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '$_generatedZoneCount';
  }
}
