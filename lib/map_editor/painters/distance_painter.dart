import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../utils/grid_geometry.dart';
import '../utils/distance_geometry.dart';

/// Draws saved distances and the temporary cells currently being selected.
class DistancePainter extends CustomPainter {
  final GardenCenterLayout layout;
  final double cellSize;
  final String? selectedDistanceId;
  final List<GridCoordinate> draftCells;

  const DistancePainter({
    required this.layout,
    required this.cellSize,
    required this.selectedDistanceId,
    required this.draftCells,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final distance in layout.distanceList) {
      final cells = DistanceGeometry.cellsForDistance(distance, layout);
      if (cells.isEmpty) {
        continue;
      }

      _paintSavedDistance(
        canvas,
        distance,
        cells,
        isSelected: distance.distanceId == selectedDistanceId,
      );
    }

    if (draftCells.isNotEmpty) {
      _paintDraft(canvas, draftCells);
    }
  }

  void _paintSavedDistance(
    Canvas canvas,
    Distance distance,
    List<GridCoordinate> cells, {
    required bool isSelected,
  }) {
    final fillPaint = Paint()
      ..color = isSelected ? const Color(0xFFBFDBFE) : const Color(0xFFDBEAFE)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFFF97316) : const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 1.5;

    final bounds = _boundsForCells(cells);
    canvas.drawRect(bounds, fillPaint);
    canvas.drawRect(bounds.deflate(0.75), borderPaint);

    _paintDistanceLabel(canvas, distance, cells);
  }

  void _paintDraft(Canvas canvas, List<GridCoordinate> cells) {
    final fillPaint = Paint()
      ..color = const Color(0x6656D5C3)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final cell in cells) {
      final rect = _cellRect(cell);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect.deflate(1), borderPaint);
    }
  }

  void _paintDistanceLabel(
    Canvas canvas,
    Distance distance,
    List<GridCoordinate> cells,
  ) {
    final bounds = _boundsForCells(cells);
    final isVertical = bounds.height > bounds.width;
    final availableWidth = math.max(
      20.0,
      (isVertical ? bounds.height : bounds.width) - 4,
    );
    final distanceText = _formatMeasurement(distance.measuredDistance);
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'DISTANCE\n',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
          TextSpan(
            text: distanceText,
            style: const TextStyle(
              color: Color(0xFF1E40AF),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: availableWidth);

    final center = bounds.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isVertical) {
      canvas.rotate(-math.pi / 2);
    }
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  Rect _cellRect(GridCoordinate cell) => Rect.fromLTWH(
    cell.column * cellSize,
    cell.row * cellSize,
    cellSize,
    cellSize,
  );

  Rect _boundsForCells(List<GridCoordinate> cells) {
    var minRow = cells.first.row;
    var maxRow = cells.first.row;
    var minColumn = cells.first.column;
    var maxColumn = cells.first.column;

    for (final cell in cells.skip(1)) {
      minRow = math.min(minRow, cell.row);
      maxRow = math.max(maxRow, cell.row);
      minColumn = math.min(minColumn, cell.column);
      maxColumn = math.max(maxColumn, cell.column);
    }

    return Rect.fromLTWH(
      minColumn * cellSize,
      minRow * cellSize,
      (maxColumn - minColumn + 1) * cellSize,
      (maxRow - minRow + 1) * cellSize,
    );
  }

  String _formatMeasurement(double distance) {
    final number = distance == distance.roundToDouble()
        ? distance.toInt().toString()
        : distance.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$number in';
  }

  @override
  bool shouldRepaint(DistancePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.selectedDistanceId != selectedDistanceId ||
        oldDelegate.draftCells != draftCells;
  }
}
