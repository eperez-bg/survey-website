import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../models/table_drag_data.dart';

class LayoutTableWidget extends StatelessWidget {
  final LayoutTable table;
  final double cellSize;
  final bool isSelected;
  final bool canDrag;
  final Color? zoneColor;
  final bool isInCurrentZone;
  final bool useZoneAssignmentStyling;
  final List<String> tableIdsForDrag;
  final bool isBeingDragged;
  final VoidCallback onTap;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragFinished;

  const LayoutTableWidget({
    super.key,
    required this.table,
    required this.cellSize,
    required this.isSelected,
    required this.canDrag,
    this.zoneColor,
    this.isInCurrentZone = false,
    this.useZoneAssignmentStyling = false,
    this.tableIdsForDrag = const [],
    this.isBeingDragged = false,
    required this.onTap,
    this.onDragStarted,
    this.onDragFinished,
  });

  @override
  Widget build(BuildContext context) {
    final width = table.widthCells * cellSize;
    final height = table.heightCells * cellSize;

    final tableCard = _TableCard(
      table: table,
      isSelected: isSelected,
      zoneColor: zoneColor,
      isInCurrentZone: isInCurrentZone,
      useZoneAssignmentStyling: useZoneAssignmentStyling,
    );

    final displayedTable = AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: isBeingDragged ? 0.22 : 1,
      child: tableCard,
    );
    final tappableTable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: displayedTable,
    );

    if (!canDrag) {
      return tappableTable;
    }

    final movingTableIds = tableIdsForDrag.isEmpty
        ? [table.tableId]
        : tableIdsForDrag;

    return LongPressDraggable<TableDragData>(
      data: TableDragData(
        tableKind: table.tableKind,
        orientation: table.orientation,
        existingTableId: table.tableId,
        existingTableIds: movingTableIds,
        anchorTableId: table.tableId,
      ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragFinished?.call(),
      feedback: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: width,
              height: height,
              child: Opacity(
                opacity: 0.88,
                child: _TableCard(table: table, isSelected: true),
              ),
            ),
            if (movingTableIds.length > 1)
              Positioned(
                right: -8,
                top: -8,
                child: _SelectionCountBadge(count: movingTableIds.length),
              ),
          ],
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.22, child: tableCard),
      child: tappableTable,
    );
  }
}

class _SelectionCountBadge extends StatelessWidget {
  final int count;

  const _SelectionCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final LayoutTable table;
  final bool isSelected;
  final Color? zoneColor;
  final bool isInCurrentZone;
  final bool useZoneAssignmentStyling;

  const _TableCard({
    required this.table,
    required this.isSelected,
    this.zoneColor,
    this.isInCurrentZone = false,
    this.useZoneAssignmentStyling = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHanging = table.tableKind == TableKind.hangingBasket;
    final isCustom = table.tableKind == TableKind.custom;
    final baseBackgroundColor = isCustom
        ? const Color(0xFFE0F2FE)
        : isHanging
        ? const Color(0xFFEDE9FE)
        : const Color(0xFFDCFCE7);
    const neutralZoneColor = Color(0xFFE5E7EB);
    final showZoneStyling = useZoneAssignmentStyling && !isCustom;
    final assignedZoneColor = showZoneStyling ? zoneColor : null;
    final zoneFillColor = assignedZoneColor == null
        ? null
        : isInCurrentZone
        ? assignedZoneColor
        : Color.alphaBlend(
            assignedZoneColor.withOpacity(0.28),
            neutralZoneColor,
          );
    final foregroundColor = assignedZoneColor != null
        ? isInCurrentZone
              ? assignedZoneColor.computeLuminance() > 0.42
                    ? const Color(0xFF0F172A)
                    : Colors.white
              : const Color(0xFF334155)
        : showZoneStyling
        ? const Color(0xFF334155)
        : isCustom
        ? const Color(0xFF0369A1)
        : isHanging
        ? const Color(0xFF5B21B6)
        : const Color(0xFF166534);
    final backgroundColor =
        zoneFillColor ??
        (showZoneStyling ? neutralZoneColor : baseBackgroundColor);
    final zoneBorderColor = assignedZoneColor == null
        ? null
        : Color.alphaBlend(const Color(0x33000000), assignedZoneColor);
    final borderColor = isSelected
        ? const Color(0xFFF97316)
        : zoneBorderColor ??
              (showZoneStyling
                  ? const Color(0xFF94A3B8)
                  : foregroundColor);
    final borderWidth = isSelected
        ? 3.0
        : isInCurrentZone
        ? 4.0
        : assignedZoneColor == null
        ? 1.5
        : 2.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: isInCurrentZone && assignedZoneColor != null
                ? assignedZoneColor.withOpacity(0.45)
                : const Color(0x24000000),
            blurRadius: isInCurrentZone ? 7 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: isCustom
          ? Text(
              table.customName!,
              textAlign: TextAlign.center,
              maxLines: table.orientation == TableOrientation.horizontal
                  ? 3
                  : 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isHanging ? 'HANGING\nBASKET' : 'TABLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
    );
  }
}
