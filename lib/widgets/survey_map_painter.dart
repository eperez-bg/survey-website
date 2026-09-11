// survey_map_painter.dart
//
// Responsibility:
// Draws supported schema 9-11 maps with the same coordinate meanings and visual
// layer order as the field app. Browser and PDF output reuse this painter.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../utils/canopy_area_rules.dart';
import '../utils/map_geometry.dart';

class SurveyMapPainter extends CustomPainter {
  final SurveyDocument survey;
  final double cellSize;
  final Set<String> selectedTableIds;
  final String? selectedDistanceId;
  final String? selectedEntranceId;
  final String? selectedSpigotKey;
  final bool showGrid;
  final bool showCanopyMeasurements;
  final bool showSpigotPsi;

  const SurveyMapPainter({
    required this.survey,
    required this.cellSize,
    this.selectedTableIds = const {},
    this.selectedDistanceId,
    this.selectedEntranceId,
    this.selectedSpigotKey,
    this.showGrid = true,
    this.showCanopyMeasurements = true,
    this.showSpigotPsi = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = survey.mapData;
    _paintBackgroundAndRoom(canvas, size, layout);
    if (showGrid) _paintGrid(canvas, size, layout);
    _paintCanopy(canvas, layout);
    _paintNoInstallZones(canvas, layout);
    _paintTables(canvas, layout);
    _paintDistances(canvas, layout);
    _paintWallsAndEntrances(canvas, layout);
    _paintSpigots(canvas, layout);
  }

  void _paintBackgroundAndRoom(
    Canvas canvas,
    Size size,
    SurveyMapModel layout,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F5F9),
    );
    final room = layout.roomBounds;
    canvas.drawRect(
      Rect.fromLTWH(
        room.leftColumn * cellSize,
        room.topRow * cellSize,
        room.widthCells * cellSize,
        room.heightCells * cellSize,
      ),
      Paint()..color = Colors.white,
    );
  }

  void _paintGrid(Canvas canvas, Size size, SurveyMapModel layout) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = math.max(0.55, cellSize * 0.025);
    for (var column = 0; column <= layout.canvasColumns; column += 1) {
      final x = column * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var row = 0; row <= layout.canvasRows; row += 1) {
      final y = row * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintCanopy(Canvas canvas, SurveyMapModel layout) {
    final fill = Paint()
      ..color = const Color(0x66FACC15)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, cellSize * 0.055);
    for (final cell in layout.canopyCells) {
      final rect = Rect.fromLTWH(
        cell.column * cellSize,
        cell.row * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect.deflate(border.strokeWidth / 2), border);
    }

    if (!showCanopyMeasurements || cellSize < 13) return;
    for (final area in CanopyAreaRules.group(layout.canopyCells)) {
      final dimensions = _canopyDimensions(area);
      if (dimensions == null) continue;
      final rect = Rect.fromLTRB(
        area.leftColumn * cellSize,
        area.topRow * cellSize,
        area.rightColumnExclusive * cellSize,
        area.bottomRowExclusive * cellSize,
      );
      _paintChip(
        canvas,
        rect.topCenter + Offset(0, math.min(12.0, rect.height / 2)),
        dimensions,
        background: const Color(0xD9FEF3C7),
        foreground: const Color(0xFF713F12),
        maxWidth: math.max(30.0, rect.width - 4),
      );
    }
  }

  void _paintNoInstallZones(Canvas canvas, SurveyMapModel layout) {
    final fill = Paint()
      ..color = const Color(0x66EF4444)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFB91C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, cellSize * 0.055);
    final hatch = Paint()
      ..color = const Color(0x99B91C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, cellSize * 0.035);

    for (final cell in layout.noInstallZoneCells) {
      final rect = Rect.fromLTWH(
        cell.column * cellSize,
        cell.row * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect.deflate(border.strokeWidth / 2), border);
      canvas.drawLine(rect.topLeft, rect.bottomRight, hatch);
      canvas.drawLine(rect.topRight, rect.bottomLeft, hatch);
    }
  }

  void _paintTables(Canvas canvas, SurveyMapModel layout) {
    for (final table in layout.tables) {
      final zone = layout.zoneById(table.zoneId);
      final zoneColor = _hexColor(zone?.colorHex);
      final typeColor = switch (table.tableKind) {
        TableKind.normal => const Color(0xFF166534),
        TableKind.hangingBasket => const Color(0xFF5B21B6),
        TableKind.custom => const Color(0xFF0369A1),
      };
      final fallbackFill = switch (table.tableKind) {
        TableKind.normal => const Color(0xFFDCFCE7),
        TableKind.hangingBasket => const Color(0xFFEDE9FE),
        TableKind.custom => const Color(0xFFE0F2FE),
      };
      final fillColor = zoneColor == null
          ? fallbackFill
          : Color.alphaBlend(zoneColor.withOpacity(0.62), Colors.white);
      final selected = selectedTableIds.contains(table.tableId);
      final rect = Rect.fromLTWH(
        table.leftColumn * cellSize,
        table.topRow * cellSize,
        table.widthCells * cellSize,
        table.heightCells * cellSize,
      ).deflate(math.max(1.0, cellSize * 0.055));
      final radius = Radius.circular(math.max(3.0, cellSize * 0.15));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = fillColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = selected ? const Color(0xFFF97316) : zoneColor ?? typeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected
              ? math.max(3.0, cellSize * 0.14)
              : math.max(1.5, cellSize * 0.07),
      );

      final label = switch (table.tableKind) {
        TableKind.normal => 'TABLE',
        TableKind.hangingBasket => 'HANGING\nBASKET',
        TableKind.custom => table.customName ?? 'CUSTOM',
      };
      _paintCenteredText(
        canvas,
        rect.deflate(3),
        label,
        typeColor,
        fontSize: math.max(7.0, math.min(12.0, cellSize * 0.37)),
      );
    }
  }

  void _paintDistances(Canvas canvas, SurveyMapModel layout) {
    var unresolved = 0;
    for (final distance in layout.distances) {
      final cells = MapGeometry.cellsForDistance(distance, layout);
      if (cells.isEmpty) {
        unresolved += 1;
        continue;
      }
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
      final bounds = Rect.fromLTWH(
        minColumn * cellSize,
        minRow * cellSize,
        (maxColumn - minColumn + 1) * cellSize,
        (maxRow - minRow + 1) * cellSize,
      );
      final selected = distance.distanceId == selectedDistanceId;
      canvas.drawRect(
        bounds,
        Paint()..color = selected ? const Color(0xFFBFDBFE) : const Color(0xFFDBEAFE),
      );
      canvas.drawRect(
        bounds.deflate(math.max(0.75, cellSize * 0.025)),
        Paint()
          ..color = selected ? const Color(0xFFF97316) : const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected
              ? math.max(3.0, cellSize * 0.12)
              : math.max(1.5, cellSize * 0.055),
      );
      _paintRotatedDistanceLabel(canvas, bounds, distance.measuredDistance);
    }
    if (unresolved > 0) {
      _paintChip(
        canvas,
        const Offset(8, 8),
        '$unresolved disconnected distance${unresolved == 1 ? '' : 's'}',
        background: const Color(0xE6FEE2E2),
        foreground: const Color(0xFF991B1B),
        anchorTopLeft: true,
      );
    }
  }

  void _paintWallsAndEntrances(Canvas canvas, SurveyMapModel layout) {
    final room = layout.roomBounds;
    final roomRect = Rect.fromLTWH(
      room.leftColumn * cellSize,
      room.topRow * cellSize,
      room.widthCells * cellSize,
      room.heightCells * cellSize,
    );
    canvas.drawRect(
      roomRect,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(5.0, cellSize * 0.42)
        ..strokeCap = StrokeCap.square,
    );

    for (final entrance in layout.entrances) {
      final segment = _entranceSegment(entrance, room);
      final selected = entrance.entranceId == selectedEntranceId;
      canvas.drawLine(
        segment.$1,
        segment.$2,
        Paint()
          ..color = const Color(0xFFF8FAFC)
          ..strokeWidth = selected
              ? math.max(9.0, cellSize * 0.72)
              : math.max(8.0, cellSize * 0.62)
          ..strokeCap = StrokeCap.square,
      );
      canvas.drawLine(
        segment.$1,
        segment.$2,
        Paint()
          ..color = selected ? const Color(0xFF0891B2) : const Color(0xFF93C5FD)
          ..strokeWidth = selected
              ? math.max(6.0, cellSize * 0.48)
              : math.max(5.0, cellSize * 0.36)
          ..strokeCap = StrokeCap.square,
      );
      _paintEntranceLabel(canvas, segment.$1, segment.$2);
    }
  }

  void _paintSpigots(Canvas canvas, SurveyMapModel layout) {
    for (final spigot in layout.spigots) {
      final center = Offset(
        spigot.columnLine * cellSize,
        spigot.rowLine * cellSize,
      );
      final selected = spigot.key == selectedSpigotKey;
      canvas.drawCircle(
        center,
        selected
            ? math.max(7.0, cellSize * 0.31)
            : math.max(5.0, cellSize * 0.25),
        Paint()..color = selected ? const Color(0xFFF97316) : Colors.white,
      );
      canvas.drawCircle(
        center,
        math.max(3.5, cellSize * 0.17),
        Paint()..color = const Color(0xFFDC2626),
      );
      if (showSpigotPsi && spigot.pressurePsi != null && cellSize >= 12) {
        _paintChip(
          canvas,
          center +
              Offset(
                math.max(8.0, cellSize * 0.28),
                -math.max(8.0, cellSize * 0.28),
              ),
          '${_number(spigot.pressurePsi!)} PSI',
          background: const Color(0xE6FFFFFF),
          foreground: const Color(0xFF991B1B),
          anchorTopLeft: true,
        );
      }
    }
  }

  (Offset, Offset) _entranceSegment(
    EntranceModel entrance,
    RoomBoundsModel room,
  ) {
    final left = room.leftColumn * cellSize;
    final top = room.topRow * cellSize;
    final right = room.rightColumnExclusive * cellSize;
    final bottom = room.bottomRowExclusive * cellSize;
    final start = entrance.offsetCells * cellSize;
    final end = (entrance.offsetCells + entrance.widthCells) * cellSize;
    return switch (entrance.wallSide) {
      WallSide.top => (Offset(left + start, top), Offset(left + end, top)),
      WallSide.right => (Offset(right, top + start), Offset(right, top + end)),
      WallSide.bottom => (Offset(left + start, bottom), Offset(left + end, bottom)),
      WallSide.left => (Offset(left, top + start), Offset(left, top + end)),
    };
  }

  void _paintRotatedDistanceLabel(Canvas canvas, Rect bounds, double inches) {
    final vertical = bounds.height > bounds.width;
    final painter = TextPainter(
      text: TextSpan(
        text: 'DISTANCE\n${_number(inches)} in',
        style: TextStyle(
          color: const Color(0xFF1E3A8A),
          fontSize: math.max(6.5, math.min(9.0, cellSize * 0.28)),
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(
        maxWidth: math.max(
          20.0,
          (vertical ? bounds.height : bounds.width) - 4,
        ),
      );
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    if (vertical) canvas.rotate(-math.pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintEntranceLabel(Canvas canvas, Offset start, Offset end) {
    final vertical = start.dx == end.dx;
    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final painter = TextPainter(
      text: TextSpan(
        text: 'ENTRANCE',
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: math.max(7.0, math.min(11.0, cellSize * 0.34)),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (vertical) canvas.rotate(math.pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _paintCenteredText(
    Canvas canvas,
    Rect rect,
    String text,
    Color color, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 5,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _paintChip(
    Canvas canvas,
    Offset anchor,
    String text, {
    required Color background,
    required Color foreground,
    double? maxWidth,
    bool anchorTopLeft = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: foreground,
          fontSize: math.max(6.5, math.min(9.0, cellSize * 0.28)),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final center = anchorTopLeft
        ? anchor + Offset(painter.width / 2 + 4, painter.height / 2 + 2)
        : anchor;
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 8,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = background,
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  String? _canopyDimensions(CanopyArea area) {
    if (area.heightInches == null ||
        area.lengthInches == null ||
        area.widthInches == null) {
      return null;
    }
    return '${_number(area.lengthInches!)}×${_number(area.widthInches!)}×${_number(area.heightInches!)} in';
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  Color? _hexColor(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final number = int.tryParse(cleaned, radix: 16);
    return number == null ? null : Color(0xFF000000 | number);
  }

  @override
  bool shouldRepaint(covariant SurveyMapPainter oldDelegate) => true;
}
