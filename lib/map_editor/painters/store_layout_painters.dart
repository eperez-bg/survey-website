import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../utils/entrance_placement_rules.dart';

class StoreGridPainter extends CustomPainter {
  final double cellSize;
  final RoomBounds roomBounds;

  const StoreGridPainter({
    required this.cellSize,
    required this.roomBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F5F9),
    );

    final roomRect = Rect.fromLTWH(
      roomBounds.leftColumn * cellSize,
      roomBounds.topRow * cellSize,
      roomBounds.widthCells * cellSize,
      roomBounds.heightCells * cellSize,
    );

    canvas.drawRect(
      roomRect,
      Paint()..color = Colors.white,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(StoreGridPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.roomBounds != roomBounds;
  }
}

/// Paints saved canopy cells beneath table widgets.
///
/// Keeping this separate from walls and spigots lets tables remain fully
/// readable without moving the store boundary behind them.
class StoreCanopyPainter extends CustomPainter {
  final GardenCenterLayout layout;
  final double cellSize;

  const StoreCanopyPainter({
    required this.layout,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0x66FACC15)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final cell in layout.canopyCellList) {
      final rect = Rect.fromLTWH(
        cell.column * cellSize,
        cell.row * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect.deflate(0.75), borderPaint);
    }
  }

  @override
  bool shouldRepaint(StoreCanopyPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.cellSize != cellSize;
  }
}

/// Paints persisted No Install Zone cells as a red map area beneath fixtures.
class StoreNoInstallZonePainter extends CustomPainter {
  final GardenCenterLayout layout;
  final double cellSize;

  const StoreNoInstallZonePainter({
    required this.layout,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0x66EF4444)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final cell in layout.noInstallZoneCellList) {
      final rect = Rect.fromLTWH(
        cell.column * cellSize,
        cell.row * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect.deflate(0.75), borderPaint);
    }
  }

  @override
  bool shouldRepaint(StoreNoInstallZonePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.cellSize != cellSize;
  }
}

/// Paints walls, entrances, and spigots above map fixtures.
class StoreOverlayPainter extends CustomPainter {
  final GardenCenterLayout layout;
  final double cellSize;
  final String? selectedEntranceId;
  final Entrance? entranceDragPreview;
  final bool entranceDragPreviewIsValid;

  const StoreOverlayPainter({
    required this.layout,
    required this.cellSize,
    this.selectedEntranceId,
    this.entranceDragPreview,
    this.entranceDragPreviewIsValid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintWallsAndEntrances(canvas);
    _paintSpigots(canvas);
  }

  void _paintWallsAndEntrances(Canvas canvas) {
    final room = layout.roomBounds;
    final roomRect = Rect.fromLTWH(
      room.leftColumn * cellSize,
      room.topRow * cellSize,
      room.widthCells * cellSize,
      room.heightCells * cellSize,
    );

    final wallPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;

    canvas.drawRect(roomRect, wallPaint);

    for (final entrance in layout.entranceList) {
      if (entrance.entranceId == entranceDragPreview?.entranceId) {
        continue;
      }
      _paintEntrance(
        canvas,
        entrance,
        isSelected: entrance.entranceId == selectedEntranceId,
      );
    }

    final preview = entranceDragPreview;
    if (preview != null) {
      _paintEntrance(
        canvas,
        preview,
        isSelected: true,
        previewColor: entranceDragPreviewIsValid
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
      );
    }
  }

  void _paintEntrance(
    Canvas canvas,
    Entrance entrance, {
    required bool isSelected,
    Color? previewColor,
  }) {
    final segment = EntrancePlacementRules.sceneSegmentFor(
      entrance: entrance,
      roomBounds: layout.roomBounds,
      cellSize: cellSize,
    );

    final eraseWallPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..strokeWidth = isSelected ? 22 : 18
      ..strokeCap = StrokeCap.square;

    final entrancePaint = Paint()
      ..color =
          previewColor ??
          (isSelected ? const Color(0xFF0891B2) : const Color(0xFF93C5FD))
      ..strokeWidth = isSelected ? 13 : 10
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(segment.start, segment.end, eraseWallPaint);
    canvas.drawLine(segment.start, segment.end, entrancePaint);

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'ENTRANCE',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final center = segment.center;

    if (segment.isVertical) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.pi / 2);
      labelPainter.paint(
        canvas,
        Offset(
          -labelPainter.width / 2,
          -labelPainter.height / 2,
        ),
      );
      canvas.restore();
    } else {
      labelPainter.paint(
        canvas,
        Offset(
          center.dx - labelPainter.width / 2,
          center.dy - labelPainter.height / 2,
        ),
      );
    }
  }

  void _paintSpigots(Canvas canvas) {
    final outlinePaint = Paint()..color = Colors.white;
    final spigotPaint = Paint()..color = const Color(0xFFDC2626);

    for (final spigot in layout.spigotList) {
      final center = Offset(
        spigot.columnLine * cellSize,
        spigot.rowLine * cellSize,
      );

      canvas.drawCircle(center, 8, outlinePaint);
      canvas.drawCircle(center, 5.5, spigotPaint);
    }
  }

  @override
  bool shouldRepaint(StoreOverlayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.selectedEntranceId != selectedEntranceId ||
        oldDelegate.entranceDragPreview != entranceDragPreview ||
        oldDelegate.entranceDragPreviewIsValid != entranceDragPreviewIsValid;
  }
}
