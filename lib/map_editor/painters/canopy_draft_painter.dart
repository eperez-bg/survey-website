import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/grid_geometry.dart';

/// Draws transient canopy or No Install Zone rectangle selection state.
class CanopyDraftPainter extends CustomPainter {
  final double cellSize;
  final List<GridCoordinate> corners;
  final List<GridCoordinate> validNextCells;
  final List<GridCoordinate> previewCells;
  final bool willRemove;
  final bool isNoInstallZone;
  final bool showPreview;
  final bool showCorners;

  const CanopyDraftPainter({
    required this.cellSize,
    required this.corners,
    this.validNextCells = const [],
    required this.previewCells,
    required this.willRemove,
    this.isNoInstallZone = false,
    this.showPreview = true,
    this.showCorners = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showPreview && validNextCells.isNotEmpty) {
      _paintValidNextCells(canvas);
    }

    if (showPreview && previewCells.isNotEmpty) {
      _paintPreview(canvas);
    }

    if (showCorners) {
      for (var index = 0; index < corners.length; index += 1) {
        _paintCorner(canvas, corners[index], index + 1);
      }
    }
  }

  void _paintValidNextCells(Canvas canvas) {
    final fillPaint = Paint()
      ..color = const Color(0x5564748B)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final cell in validNextCells) {
      final rect = _cellRect(cell).deflate(1);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _paintPreview(Canvas canvas) {
    final previewColor = willRemove || isNoInstallZone
        ? const Color(0x44EF4444)
        : const Color(0x66FDE047);
    final borderColor = willRemove || isNoInstallZone
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final fillPaint = Paint()
      ..color = previewColor
      ..style = PaintingStyle.fill;
    final cellBorderPaint = Paint()
      ..color = borderColor.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final cell in previewCells) {
      final rect = _cellRect(cell);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect.deflate(0.5), cellBorderPaint);
    }

    final bounds = _boundsForCells(previewCells);
    canvas.drawRect(
      bounds.deflate(1.5),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _paintCorner(
    Canvas canvas,
    GridCoordinate coordinate,
    int cornerNumber,
  ) {
    final rect = _cellRect(coordinate).deflate(2);
    final color = willRemove || isNoInstallZone
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = Colors.white.withOpacity(0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$cornerNumber',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
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

  @override
  bool shouldRepaint(CanopyDraftPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.corners != corners ||
        oldDelegate.validNextCells != validNextCells ||
        oldDelegate.previewCells != previewCells ||
        oldDelegate.willRemove != willRemove ||
        oldDelegate.isNoInstallZone != isNoInstallZone ||
        oldDelegate.showPreview != showPreview ||
        oldDelegate.showCorners != showCorners;
  }
}
