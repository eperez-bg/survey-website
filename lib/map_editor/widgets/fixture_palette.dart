import 'package:flutter/material.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import '../controllers/map_editor_controller.dart';
import '../models/table_drag_data.dart';
import '../utils/table_pair_rules.dart';

/// The fixture-specific portion of the bottom editor toolbar.
class FixturePalette extends StatelessWidget {
  final MapEditorController controller;
  final VoidCallback onDuplicateSelectedTables;
  final VoidCallback onRenameSelectedCustomTables;
  final VoidCallback onDeleteSelectedTables;

  const FixturePalette({
    super.key,
    required this.controller,
    required this.onDuplicateSelectedTables,
    required this.onRenameSelectedCustomTables,
    required this.onDeleteSelectedTables,
  });

  @override
  Widget build(BuildContext context) {
    final orientation = controller.paletteOrientation;
    final pairWidthCells = TablePairRules.footprintWidthCells(orientation);
    final pairHeightCells = TablePairRules.footprintHeightCells(orientation);
    final spigotProgress = '${controller.spigotCount} placed';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.drag_indicator,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Drag a fixture onto the grid',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                'Pair $pairWidthCells×$pairHeightCells',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
              IconButton(
                tooltip: 'Change table orientation',
                visualDensity: VisualDensity.compact,
                onPressed: controller.togglePaletteOrientation,
                icon: const Icon(Icons.rotate_90_degrees_cw),
              ),
            ],
          ),
          if (controller.selectedTableCount > 0) ...[
            const SizedBox(height: 6),
            _SelectionActions(
              selectedCount: controller.selectedTableCount,
              selectedCustomTableCount: controller.selectedCustomTableCount,
              onDuplicate: onDuplicateSelectedTables,
              onRename: onRenameSelectedCustomTables,
              onDelete: onDeleteSelectedTables,
              onClear: controller.clearSelection,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PaletteFixture(
                  label: 'Table',
                  tableKind: TableKind.normal,
                  orientation: orientation,
                  backgroundColor: const Color(0xFFDCFCE7),
                  foregroundColor: const Color(0xFF166534),
                  onDragStarted: () =>
                      controller.setActiveTool(MapEditorTool.select),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaletteFixture(
                  label: 'Hanging Basket',
                  tableKind: TableKind.hangingBasket,
                  orientation: orientation,
                  backgroundColor: const Color(0xFFEDE9FE),
                  foregroundColor: const Color(0xFF5B21B6),
                  onDragStarted: () =>
                      controller.setActiveTool(MapEditorTool.select),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaletteFixture(
                  label: 'Custom Table',
                  tableKind: TableKind.custom,
                  orientation: orientation,
                  backgroundColor: const Color(0xFFE0F2FE),
                  foregroundColor: const Color(0xFF0369A1),
                  onDragStarted: () =>
                      controller.setActiveTool(MapEditorTool.select),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                key: const ValueKey('spigot-placement-toggle'),
                avatar: const _RedDot(),
                label: Text(
                  controller.isSpigotPlacementEnabled
                      ? 'Spigot placement on'
                      : 'Place spigots',
                ),
                selected: controller.isSpigotPlacementEnabled,
                selectedColor: const Color(0xFFFEE2E2),
                checkmarkColor: const Color(0xFFB91C1C),
                side: BorderSide(
                  color: controller.isSpigotPlacementEnabled
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFCBD5E1),
                ),
                onSelected: controller.setSpigotPlacementEnabled,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.isSpigotPlacementEnabled
                      ? 'Double-tap to add or edit a spigot and its PSI. '
                            '$spigotProgress.'
                      : 'Turn on only when you need to edit spigots. '
                            '$spigotProgress.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionActions extends StatelessWidget {
  final int selectedCount;
  final int selectedCustomTableCount;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const _SelectionActions({
    required this.selectedCount,
    required this.selectedCustomTableCount,
    required this.onDuplicate,
    required this.onRename,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tableLabel = selectedCount == 1 ? 'table' : 'tables';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 19, color: Color(0xFF2563EB)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$selectedCount $tableLabel selected',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Duplicate selected tables',
            visualDensity: VisualDensity.compact,
            onPressed: onDuplicate,
            icon: const Icon(Icons.copy, size: 20),
          ),
          if (selectedCustomTableCount > 0)
            IconButton(
              key: const ValueKey('rename-selected-custom-tables-button'),
              tooltip: selectedCustomTableCount == 1
                  ? 'Rename selected custom table'
                  : 'Rename selected custom tables',
              visualDensity: VisualDensity.compact,
              onPressed: onRename,
              icon: const Icon(Icons.edit, size: 20),
            ),
          IconButton(
            tooltip: 'Delete selected tables',
            visualDensity: VisualDensity.compact,
            color: const Color(0xFFDC2626),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 21),
          ),
          IconButton(
            tooltip: 'Clear table selection',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PaletteFixture extends StatelessWidget {
  final String label;
  final TableKind tableKind;
  final TableOrientation orientation;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onDragStarted;

  const _PaletteFixture({
    required this.label,
    required this.tableKind,
    required this.orientation,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    final data = TableDragData(tableKind: tableKind, orientation: orientation);

    final paletteCard = Container(
      height: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foregroundColor, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );

    final isHorizontal = orientation == TableOrientation.horizontal;
    final isCustom = tableKind == TableKind.custom;
    final footprintWidthCells = isCustom
        ? (isHorizontal ? 3 : 2)
        : TablePairRules.footprintWidthCells(orientation);
    final footprintHeightCells = isCustom
        ? (isHorizontal ? 2 : 3)
        : TablePairRules.footprintHeightCells(orientation);

    return Draggable<TableDragData>(
      data: data,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: footprintWidthCells * 30.0,
          height: footprintHeightCells * 30.0,
          child: Flex(
            direction: isHorizontal ? Axis.vertical : Axis.horizontal,
            children: [
              for (var index = 0; index < (isCustom ? 1 : 2); index += 1)
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: foregroundColor, width: 2),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: paletteCard),
      child: paletteCard,
    );
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: const BoxDecoration(
        color: Color(0xFFDC2626),
        shape: BoxShape.circle,
      ),
    );
  }
}
