// survey_map_editor.dart
//
// Responsibility:
// Owns browser-only map interaction: fit/pan/zoom, fixture selection, safe
// pair-aware table dragging, and small editors for supported schema 9-11 maps.
// Geometry and mutations stay in utilities/models so this widget never guesses
// how the mobile survey format works.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/editor_result.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../utils/map_geometry.dart';
import '../utils/table_pair_rules.dart';
import 'survey_map_painter.dart';

typedef TableMoveHandler = EditorResult Function(
  String tableId, {
  required int topRow,
  required int leftColumn,
});
typedef TableZoneHandler = EditorResult Function(String tableId, String? zoneId);
typedef MeasurementHandler = EditorResult Function(String id, double value);
typedef EntranceHandler = EditorResult Function(EntranceModel entrance);
typedef DeleteHandler = EditorResult Function(String id);

class SurveyMapEditor extends StatefulWidget {
  final SurveyDocument survey;
  final TableMoveHandler onTableMoved;
  final TableZoneHandler onTableZoneChanged;
  final MeasurementHandler onDistanceMeasurementChanged;
  final MeasurementHandler onSpigotPressureChanged;
  final EntranceHandler onEntranceChanged;
  final DeleteHandler onTableDeleted;
  final DeleteHandler onDistanceDeleted;
  final DeleteHandler onEntranceDeleted;
  final DeleteHandler onSpigotDeleted;

  const SurveyMapEditor({
    super.key,
    required this.survey,
    required this.onTableMoved,
    required this.onTableZoneChanged,
    required this.onDistanceMeasurementChanged,
    required this.onSpigotPressureChanged,
    required this.onEntranceChanged,
    required this.onTableDeleted,
    required this.onDistanceDeleted,
    required this.onEntranceDeleted,
    required this.onSpigotDeleted,
  });

  @override
  State<SurveyMapEditor> createState() => _SurveyMapEditorState();
}

enum _SelectionKind { table, distance, entrance, spigot }

class _MapSelection {
  final _SelectionKind kind;
  final String id;

  const _MapSelection(this.kind, this.id);
}

class _SurveyMapEditorState extends State<SurveyMapEditor> {
  static const double _cellSize = 28;
  static const double _mapHeight = 600;

  final TransformationController _transformationController =
      TransformationController();
  _MapSelection? _selection;
  bool _editMode = false;
  String? _fitSignature;
  Size? _lastViewport;

  String? _dragTableId;
  Offset? _dragStart;
  int? _dragStartRow;
  int? _dragStartColumn;
  int _dragRowDelta = 0;
  int _dragColumnDelta = 0;

  @override
  void didUpdateWidget(covariant SurveyMapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.survey, oldWidget.survey)) {
      _selection = null;
      _fitSignature = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.survey.mapData;
    final mapSize = Size(
      math.max(1, layout.canvasColumns).toDouble() * _cellSize,
      math.max(1, layout.canvasRows).toDouble() * _cellSize,
    );
    final selectedTableIds = _selection?.kind == _SelectionKind.table
        ? TablePairRules.memberIdsForTable(layout.tables, _selection!.id)
        : const <String>{};

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  'Schema ${widget.survey.schemaVersion} store map',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.pan_tool_alt_outlined),
                      label: Text('View / pan'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.edit_location_alt_outlined),
                      label: Text('Edit fixtures'),
                    ),
                  ],
                  selected: {_editMode},
                  onSelectionChanged: (values) {
                    setState(() => _editMode = values.first);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _lastViewport == null
                      ? null
                      : () => _fitMap(_lastViewport!, mapSize),
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Fit map'),
                ),
                Text(
                  _dragTableId != null
                      ? 'Release to move ${_dragRowDelta >= 0 ? '+' : ''}$_dragRowDelta rows, '
                          '${_dragColumnDelta >= 0 ? '+' : ''}$_dragColumnDelta columns.'
                      : _editMode
                          ? 'Select any fixture. Drag tables; paired tables move together.'
                          : 'Scroll to zoom and drag to pan. Click a fixture to inspect it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: _mapHeight,
            child: ColoredBox(
              color: const Color(0xFFE2E8F0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = Size(
                    math.max(1.0, constraints.maxWidth),
                    math.max(1.0, constraints.maxHeight),
                  );
                  _scheduleInitialFit(viewport, mapSize);
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(500),
                    minScale: 0.05,
                    maxScale: 4,
                    panEnabled: !_editMode,
                    scaleEnabled: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _handleTap,
                      onPanStart: _editMode ? _handlePanStart : null,
                      onPanUpdate: _editMode ? _handlePanUpdate : null,
                      onPanEnd: _editMode ? _handlePanEnd : null,
                      onPanCancel: _editMode ? _cancelDrag : null,
                      child: CustomPaint(
                        size: mapSize,
                        painter: SurveyMapPainter(
                          survey: widget.survey,
                          cellSize: _cellSize,
                          selectedTableIds: selectedTableIds,
                          selectedDistanceId:
                              _selection?.kind == _SelectionKind.distance
                                  ? _selection!.id
                                  : null,
                          selectedEntranceId:
                              _selection?.kind == _SelectionKind.entrance
                                  ? _selection!.id
                                  : null,
                          selectedSpigotKey:
                              _selection?.kind == _SelectionKind.spigot
                                  ? _selection!.id
                                  : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _MapLegend(layout: layout),
          if (_selection != null) ...[
            const Divider(height: 1),
            _SelectionInspector(
              key: ValueKey('${_selection!.kind.name}:${_selection!.id}'),
              survey: widget.survey,
              selection: _selection!,
              onTableZoneChanged: widget.onTableZoneChanged,
              onDistanceMeasurementChanged:
                  widget.onDistanceMeasurementChanged,
              onSpigotPressureChanged: widget.onSpigotPressureChanged,
              onEntranceChanged: widget.onEntranceChanged,
              onDelete: _confirmDeleteSelection,
            ),
          ],
        ],
      ),
    );
  }

  void _scheduleInitialFit(Size viewport, Size mapSize) {
    _lastViewport = viewport;
    final signature = '${widget.survey.surveyId}|${mapSize.width}x${mapSize.height}|'
        '${viewport.width.toStringAsFixed(1)}x${viewport.height.toStringAsFixed(1)}';
    if (_fitSignature == signature) return;
    _fitSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitMap(viewport, mapSize);
    });
  }

  void _fitMap(Size viewport, Size mapSize) {
    const padding = 28.0;
    final availableWidth = math.max(1.0, viewport.width - padding * 2);
    final availableHeight = math.max(1.0, viewport.height - padding * 2);
    final scale = math.min(
      availableWidth / mapSize.width,
      availableHeight / mapSize.height,
    ).clamp(0.05, 4.0).toDouble();
    final dx = (viewport.width - mapSize.width * scale) / 2;
    final dy = (viewport.height - mapSize.height * scale) / 2;
    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _handleTap(TapUpDetails details) {
    setState(() => _selection = _selectionAt(details.localPosition));
  }

  void _handlePanStart(DragStartDetails details) {
    final hit = _selectionAt(details.localPosition);
    setState(() => _selection = hit);
    if (hit?.kind != _SelectionKind.table) return;
    final table = widget.survey.mapData.tableById(hit!.id);
    if (table == null) return;
    _dragTableId = table.tableId;
    _dragStart = details.localPosition;
    _dragStartRow = table.topRow;
    _dragStartColumn = table.leftColumn;
    _dragRowDelta = 0;
    _dragColumnDelta = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final start = _dragStart;
    if (_dragTableId == null || start == null) return;
    final delta = details.localPosition - start;
    setState(() {
      _dragRowDelta = (delta.dy / _cellSize).round();
      _dragColumnDelta = (delta.dx / _cellSize).round();
    });
  }

  void _handlePanEnd(DragEndDetails _) {
    final tableId = _dragTableId;
    final startRow = _dragStartRow;
    final startColumn = _dragStartColumn;
    final rowDelta = _dragRowDelta;
    final columnDelta = _dragColumnDelta;
    _cancelDrag();
    if (tableId == null || startRow == null || startColumn == null) return;
    if (rowDelta == 0 && columnDelta == 0) return;
    widget.onTableMoved(
      tableId,
      topRow: startRow + rowDelta,
      leftColumn: startColumn + columnDelta,
    );
  }

  void _cancelDrag() {
    if (!mounted) return;
    setState(() {
      _dragTableId = null;
      _dragStart = null;
      _dragStartRow = null;
      _dragStartColumn = null;
      _dragRowDelta = 0;
      _dragColumnDelta = 0;
    });
  }

  _MapSelection? _selectionAt(Offset point) {
    final layout = widget.survey.mapData;

    for (final spigot in layout.spigots.reversed) {
      final center = Offset(
        spigot.columnLine * _cellSize,
        spigot.rowLine * _cellSize,
      );
      if ((point - center).distance <= math.max(9.0, _cellSize * 0.4)) {
        return _MapSelection(_SelectionKind.spigot, spigot.key);
      }
    }

    for (final entrance in layout.entrances.reversed) {
      final segment = _entranceSegment(entrance, layout.roomBounds);
      if (_distanceToSegment(point, segment.$1, segment.$2) <=
          math.max(9.0, _cellSize * 0.45)) {
        return _MapSelection(_SelectionKind.entrance, entrance.entranceId);
      }
    }

    final cell = GridCoordinate(
      row: (point.dy / _cellSize).floor(),
      column: (point.dx / _cellSize).floor(),
    );
    for (final distance in layout.distances.reversed) {
      if (MapGeometry.cellsForDistance(distance, layout).contains(cell)) {
        return _MapSelection(_SelectionKind.distance, distance.distanceId);
      }
    }

    for (final table in layout.tables.reversed) {
      if (cell.row >= table.topRow &&
          cell.row < table.bottomRowExclusive &&
          cell.column >= table.leftColumn &&
          cell.column < table.rightColumnExclusive) {
        return _MapSelection(_SelectionKind.table, table.tableId);
      }
    }
    return null;
  }

  (Offset, Offset) _entranceSegment(
    EntranceModel entrance,
    RoomBoundsModel room,
  ) {
    final left = room.leftColumn * _cellSize;
    final top = room.topRow * _cellSize;
    final right = room.rightColumnExclusive * _cellSize;
    final bottom = room.bottomRowExclusive * _cellSize;
    final start = entrance.offsetCells * _cellSize;
    final end = (entrance.offsetCells + entrance.widthCells) * _cellSize;
    return switch (entrance.wallSide) {
      WallSide.top => (Offset(left + start, top), Offset(left + end, top)),
      WallSide.right => (Offset(right, top + start), Offset(right, top + end)),
      WallSide.bottom =>
        (Offset(left + start, bottom), Offset(left + end, bottom)),
      WallSide.left => (Offset(left, top + start), Offset(left, top + end)),
    };
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;
    final fromStart = point - start;
    final t = ((fromStart.dx * segment.dx + fromStart.dy * segment.dy) /
            lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    final closest = start + segment * t;
    return (point - closest).distance;
  }

  Future<void> _confirmDeleteSelection() async {
    final selection = _selection;
    if (selection == null) return;
    final noun = selection.kind.name;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete $noun?'),
            content: Text(
              selection.kind == _SelectionKind.table
                  ? 'A paired fixture deletes both physical table objects. Connected distances must be deleted first.'
                  : 'This removes the selected $noun from the edited browser copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final result = switch (selection.kind) {
      _SelectionKind.table => widget.onTableDeleted(selection.id),
      _SelectionKind.distance => widget.onDistanceDeleted(selection.id),
      _SelectionKind.entrance => widget.onEntranceDeleted(selection.id),
      _SelectionKind.spigot => widget.onSpigotDeleted(selection.id),
    };
    if (result.succeeded && mounted) {
      setState(() => _selection = null);
    }
  }
}

class _MapLegend extends StatelessWidget {
  final SurveyMapModel layout;

  const _MapLegend({required this.layout});

  @override
  Widget build(BuildContext context) {
    final labels = <(Color, String)>[
      (const Color(0xFF166534), '${layout.tables.length} physical tables'),
      (const Color(0xFFF59E0B), '${layout.canopyCells.length} canopy cells'),
      if (layout.noInstallZoneCells.isNotEmpty)
        (
          const Color(0xFFB91C1C),
          '${layout.noInstallZoneCells.length} no-install cells',
        ),
      (const Color(0xFF2563EB), '${layout.distances.length} distances'),
      (const Color(0xFF0891B2), '${layout.entrances.length} entrances'),
      (const Color(0xFFDC2626), '${layout.spigots.length} spigots'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final item in labels)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.$1,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(item.$2, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}

class _SelectionInspector extends StatelessWidget {
  final SurveyDocument survey;
  final _MapSelection selection;
  final TableZoneHandler onTableZoneChanged;
  final MeasurementHandler onDistanceMeasurementChanged;
  final MeasurementHandler onSpigotPressureChanged;
  final EntranceHandler onEntranceChanged;
  final VoidCallback onDelete;

  const _SelectionInspector({
    super.key,
    required this.survey,
    required this.selection,
    required this.onTableZoneChanged,
    required this.onDistanceMeasurementChanged,
    required this.onSpigotPressureChanged,
    required this.onEntranceChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final layout = survey.mapData;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (selection.kind) {
          _SelectionKind.table => _tableControls(layout),
          _SelectionKind.distance => _distanceControls(layout),
          _SelectionKind.entrance => _entranceControls(layout),
          _SelectionKind.spigot => _spigotControls(layout),
        },
      ),
    );
  }

  Widget _tableControls(SurveyMapModel layout) {
    final table = layout.tableById(selection.id);
    if (table == null) return const Text('The selected table was removed.');
    final members = TablePairRules.membersForTable(layout.tables, table.tableId);
    const noZone = '__NO_ZONE__';
    final uniqueZones = <String, ZoneModel>{
      for (final zone in layout.zones) zone.zoneId: zone,
    }.values.toList(growable: false);
    final validZoneIds = uniqueZones.map((item) => item.zoneId).toSet();
    final zoneValue = validZoneIds.contains(table.zoneId) ? table.zoneId! : noZone;
    final kind = switch (table.tableKind) {
      TableKind.normal => 'Normal table',
      TableKind.hangingBasket => 'Hanging basket table',
      TableKind.custom => table.customName ?? 'Custom table',
    };
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        _InspectorTitle(
          icon: Icons.table_restaurant_outlined,
          title: members.length == 2 ? '$kind pair' : kind,
          subtitle: members.map((item) => item.tableId).join(' + '),
        ),
        Text(
          'Anchor row ${table.topRow}, column ${table.leftColumn} • '
          '${table.orientation.jsonValue}',
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            value: zoneValue,
            decoration: const InputDecoration(
              labelText: 'Zone assignment',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: noZone, child: Text('No zone')),
              for (final zone in uniqueZones)
                DropdownMenuItem(
                  value: zone.zoneId,
                  child: Text(zone.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: table.tableKind == TableKind.custom
                ? null
                : (value) => onTableZoneChanged(
                      table.tableId,
                      value == noZone ? null : value,
                    ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: Text(members.length == 2 ? 'Delete pair' : 'Delete table'),
        ),
      ],
    );
  }

  Widget _distanceControls(SurveyMapModel layout) {
    DistanceModel? selected;
    for (final distance in layout.distances) {
      if (distance.distanceId == selection.id) selected = distance;
    }
    if (selected == null) return const Text('The selected distance was removed.');
    final cells = MapGeometry.cellsForDistance(selected, layout);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        _InspectorTitle(
          icon: Icons.straighten,
          title: 'Measured distance',
          subtitle: selected.distanceId,
        ),
        Text('${cells.length} mapped grid cells'),
        SizedBox(
          width: 260,
          child: _NumberEditor(
            key: ValueKey('${selected.distanceId}:${selected.measuredDistance}'),
            label: 'Measured distance',
            suffix: 'inches',
            initialValue: selected.measuredDistance,
            allowZero: false,
            onSubmit: (value) => onDistanceMeasurementChanged(
              selected!.distanceId,
              value,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete distance'),
        ),
      ],
    );
  }

  Widget _spigotControls(SurveyMapModel layout) {
    SpigotModel? selected;
    for (final spigot in layout.spigots) {
      if (spigot.key == selection.id) selected = spigot;
    }
    if (selected == null) return const Text('The selected spigot was removed.');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        _InspectorTitle(
          icon: Icons.water_drop_outlined,
          title: 'Spigot',
          subtitle: 'Grid line ${selected.rowLine}:${selected.columnLine}',
        ),
        SizedBox(
          width: 240,
          child: _NumberEditor(
            key: ValueKey('${selected.key}:${selected.pressurePsi}'),
            label: 'Pressure',
            suffix: 'PSI',
            initialValue: selected.pressurePsi,
            allowZero: true,
            onSubmit: (value) =>
                onSpigotPressureChanged(selected!.key, value),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete spigot'),
        ),
      ],
    );
  }

  Widget _entranceControls(SurveyMapModel layout) {
    EntranceModel? selected;
    for (final entrance in layout.entrances) {
      if (entrance.entranceId == selection.id) selected = entrance;
    }
    if (selected == null) return const Text('The selected entrance was removed.');
    return _EntranceEditor(
      key: ValueKey(
        '${selected.entranceId}:${selected.wallSide.name}:${selected.offsetCells}:'
        '${selected.widthCells}:${selected.clearanceDepthCells}',
      ),
      entrance: selected,
      onSubmit: onEntranceChanged,
      onDelete: onDelete,
    );
  }
}

class _InspectorTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InspectorTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberEditor extends StatefulWidget {
  final String label;
  final String suffix;
  final double? initialValue;
  final bool allowZero;
  final EditorResult Function(double value) onSubmit;

  const _NumberEditor({
    super.key,
    required this.label,
    required this.suffix,
    required this.initialValue,
    required this.allowZero,
    required this.onSubmit,
  });

  @override
  State<_NumberEditor> createState() => _NumberEditorState();
}

class _NumberEditorState extends State<_NumberEditor> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : _number(widget.initialValue!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
              errorText: _error,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null ||
        !value.isFinite ||
        (widget.allowZero ? value < 0 : value <= 0)) {
      setState(
        () => _error = widget.allowZero
            ? 'Enter zero or more.'
            : 'Enter a value above zero.',
      );
      return;
    }
    final result = widget.onSubmit(value);
    if (mounted) {
      setState(() => _error = result.succeeded ? null : result.message);
    }
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _EntranceEditor extends StatefulWidget {
  final EntranceModel entrance;
  final EntranceHandler onSubmit;
  final VoidCallback onDelete;

  const _EntranceEditor({
    super.key,
    required this.entrance,
    required this.onSubmit,
    required this.onDelete,
  });

  @override
  State<_EntranceEditor> createState() => _EntranceEditorState();
}

class _EntranceEditorState extends State<_EntranceEditor> {
  late WallSide _wallSide;
  late final TextEditingController _offset;
  late final TextEditingController _width;
  late final TextEditingController _clearance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wallSide = widget.entrance.wallSide;
    _offset = TextEditingController(text: widget.entrance.offsetCells.toString());
    _width = TextEditingController(text: widget.entrance.widthCells.toString());
    _clearance = TextEditingController(
      text: widget.entrance.clearanceDepthCells.toString(),
    );
  }

  @override
  void dispose() {
    _offset.dispose();
    _width.dispose();
    _clearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        _InspectorTitle(
          icon: Icons.door_front_door_outlined,
          title: 'Entrance',
          subtitle: widget.entrance.entranceId,
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<WallSide>(
            value: _wallSide,
            decoration: const InputDecoration(
              labelText: 'Wall',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final side in WallSide.values)
                DropdownMenuItem(value: side, child: Text(side.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _wallSide = value);
            },
          ),
        ),
        _integerField(_offset, 'Offset'),
        _integerField(_width, 'Width'),
        _integerField(_clearance, 'Clearance'),
        FilledButton(onPressed: _submit, child: const Text('Apply entrance')),
        OutlinedButton.icon(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete entrance'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _integerField(TextEditingController controller, String label) {
    return SizedBox(
      width: 112,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '$label cells',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _submit() {
    final offset = int.tryParse(_offset.text.trim());
    final width = int.tryParse(_width.text.trim());
    final clearance = int.tryParse(_clearance.text.trim());
    if (offset == null || width == null || clearance == null) {
      setState(
        () => _error =
            'Offset, width, and clearance must be whole cells.',
      );
      return;
    }
    final result = widget.onSubmit(
      EntranceModel(
        entranceId: widget.entrance.entranceId,
        wallSide: _wallSide,
        offsetCells: offset,
        widthCells: width,
        clearanceDepthCells: clearance,
      ),
    );
    if (mounted) {
      setState(() => _error = result.succeeded ? null : result.message);
    }
  }
}
