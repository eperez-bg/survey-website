// survey_map_canvas.dart
// Barebones map renderer/editor. It paints the existing survey grid and supports
// dragging tables to new grid cells. More exact mobile editor rules can be ported
// into this widget/controller layer without touching storage/export code.

import 'package:flutter/material.dart';

import '../models/survey_document.dart';
import '../utils/json_helpers.dart';

class SurveyMapCanvas extends StatefulWidget {
  const SurveyMapCanvas({
    super.key,
    required this.survey,
    required this.onMoveTable,
  });

  final SurveyDocument survey;
  final void Function(String tableId, int topRow, int leftColumn) onMoveTable;

  @override
  State<SurveyMapCanvas> createState() => _SurveyMapCanvasState();
}

class _SurveyMapCanvasState extends State<SurveyMapCanvas> {
  static const double cellSize = 24;

  @override
  Widget build(BuildContext context) {
    final width = widget.survey.canvasColumns * cellSize;
    final height = widget.survey.canvasRows * cellSize;

    return InteractiveViewer(
      constrained: false,
      minScale: .35,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(120),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SurveyBasePainter(widget.survey)),
            ),
            ...widget.survey.tables.map(_buildTable),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(Map<String, dynamic> table) {
    final id = JsonHelpers.string(
      JsonHelpers.first(table, ['tableId', 'id', 'layoutTableId']),
    );
    final row = JsonHelpers.integer(JsonHelpers.first(table, ['topRow', 'row']));
    final col = JsonHelpers.integer(JsonHelpers.first(table, ['leftColumn', 'column', 'col']));
    final orientation = JsonHelpers.string(table['orientation']).toLowerCase();
    final horizontal = orientation.contains('horizontal') || orientation == '2x3';
    final rows = horizontal ? 2 : 3;
    final cols = horizontal ? 3 : 2;
    final kind = JsonHelpers.string(JsonHelpers.first(table, ['tableKind', 'kind']));
    final zone = JsonHelpers.string(table['zoneId']);

    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      child: Draggable<String>(
        data: id,
        feedback: Material(
          elevation: 6,
          child: Container(
            width: cols * cellSize,
            height: rows * cellSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: .7),
              border: Border.all(color: Colors.black87),
            ),
            child: Text(kind.isEmpty ? 'Table' : kind,
                style: const TextStyle(fontSize: 10)),
          ),
        ),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.offset);
          final nextCol = (local.dx / cellSize).round().clamp(0, widget.survey.canvasColumns - cols);
          final nextRow = (local.dy / cellSize).round().clamp(0, widget.survey.canvasRows - rows);
          widget.onMoveTable(id, nextRow, nextCol);
        },
        child: Container(
          width: cols * cellSize,
          height: rows * cellSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kind.toLowerCase().contains('hanging')
                ? Colors.orange.shade200
                : Colors.blue.shade200,
            border: Border.all(color: Colors.black87),
          ),
          child: Text(
            zone.isEmpty ? 'Table' : 'Z $zone',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _SurveyBasePainter extends CustomPainter {
  _SurveyBasePainter(this.survey);
  final SurveyDocument survey;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = .6;
    for (int r = 0; r <= survey.canvasRows; r++) {
      canvas.drawLine(Offset(0, r * _SurveyMapCanvasState.cellSize),
          Offset(size.width, r * _SurveyMapCanvasState.cellSize), grid);
    }
    for (int c = 0; c <= survey.canvasColumns; c++) {
      canvas.drawLine(Offset(c * _SurveyMapCanvasState.cellSize, 0),
          Offset(c * _SurveyMapCanvasState.cellSize, size.height), grid);
    }

    final canopyPaint = Paint()..color = Colors.yellow.withValues(alpha: .3);
    for (final canopy in survey.canopies) {
      final row = JsonHelpers.integer(canopy['row']);
      final col = JsonHelpers.integer(JsonHelpers.first(canopy, ['column', 'col']));
      canvas.drawRect(
        Rect.fromLTWH(
          col * _SurveyMapCanvasState.cellSize,
          row * _SurveyMapCanvasState.cellSize,
          _SurveyMapCanvasState.cellSize,
          _SurveyMapCanvasState.cellSize,
        ),
        canopyPaint,
      );
    }

    final spigotPaint = Paint()..color = Colors.red;
    for (final spigot in survey.spigots) {
      final row = JsonHelpers.decimal(JsonHelpers.first(spigot, ['rowLine', 'row']));
      final col = JsonHelpers.decimal(JsonHelpers.first(spigot, ['columnLine', 'column', 'col']));
      canvas.drawCircle(
        Offset(col * _SurveyMapCanvasState.cellSize, row * _SurveyMapCanvasState.cellSize),
        4,
        spigotPaint,
      );
    }

    final room = survey.roomBounds;
    if (room.isNotEmpty) {
      final top = JsonHelpers.integer(JsonHelpers.first(room, ['topRow', 'top']));
      final left = JsonHelpers.integer(JsonHelpers.first(room, ['leftColumn', 'left']));
      final bottom = JsonHelpers.integer(
          JsonHelpers.first(room, ['bottomRow', 'bottom']), survey.canvasRows);
      final right = JsonHelpers.integer(
          JsonHelpers.first(room, ['rightColumn', 'right']), survey.canvasColumns);
      final roomPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(
        Rect.fromLTRB(
          left * _SurveyMapCanvasState.cellSize,
          top * _SurveyMapCanvasState.cellSize,
          right * _SurveyMapCanvasState.cellSize,
          bottom * _SurveyMapCanvasState.cellSize,
        ),
        roomPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SurveyBasePainter oldDelegate) => true;
}
