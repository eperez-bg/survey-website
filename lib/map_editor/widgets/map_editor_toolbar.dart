import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';
import 'canopy_toolbar.dart';
import 'fixture_palette.dart';
import 'distance_toolbar.dart';
import 'resize_toolbar.dart';
import 'zone_toolbar.dart';

/// Owns the persistent tool selector and swaps the lower toolbar content.
class MapEditorToolbar extends StatelessWidget {
  final MapEditorController controller;
  final VoidCallback onDuplicateSelectedTables;
  final VoidCallback onRenameSelectedCustomTables;
  final VoidCallback onDeleteSelectedTables;
  final VoidCallback onConfirmCanopy;
  final VoidCallback onEditExistingCanopy;
  final VoidCallback onMoveSelectedDistance;
  final VoidCallback onEditSelectedDistance;
  final VoidCallback onDeleteSelectedDistance;
  final VoidCallback onEditSelectedEntrance;
  final VoidCallback onDeleteSelectedEntrance;
  final LayoutResizeCallback onResizeLayout;

  const MapEditorToolbar({
    super.key,
    required this.controller,
    required this.onDuplicateSelectedTables,
    required this.onRenameSelectedCustomTables,
    required this.onDeleteSelectedTables,
    required this.onConfirmCanopy,
    required this.onEditExistingCanopy,
    required this.onMoveSelectedDistance,
    required this.onEditSelectedDistance,
    required this.onDeleteSelectedDistance,
    required this.onEditSelectedEntrance,
    required this.onDeleteSelectedEntrance,
    required this.onResizeLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Row(
                children: [
                  Expanded(
                    child: _ToolButton(
                      label: 'Fixtures',
                      icon: Icons.table_restaurant,
                      selected: controller.activeTool == MapEditorTool.select,
                      color: const Color(0xFF2563EB),
                      onTap: () =>
                          controller.setActiveTool(MapEditorTool.select),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToolButton(
                      label: 'Distance',
                      icon: Icons.linear_scale,
                      selected: controller.activeTool == MapEditorTool.distances,
                      color: const Color(0xFF0F766E),
                      onTap: () =>
                          controller.setActiveTool(MapEditorTool.distances),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToolButton(
                      label: 'Canopy',
                      icon: Icons.grid_on,
                      selected: controller.activeTool == MapEditorTool.canopy,
                      color: const Color(0xFFD97706),
                      onTap: () =>
                          controller.setActiveTool(MapEditorTool.canopy),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToolButton(
                      label: 'Zones',
                      icon: Icons.layers,
                      selected: controller.activeTool == MapEditorTool.zones,
                      color: const Color(0xFF7C3AED),
                      onTap: () =>
                          controller.setActiveTool(MapEditorTool.zones),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToolButton(
                      label: 'Size',
                      icon: Icons.aspect_ratio,
                      selected: controller.activeTool == MapEditorTool.resize,
                      color: const Color(0xFF0891B2),
                      onTap: () =>
                          controller.setActiveTool(MapEditorTool.resize),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (controller.activeTool) {
                MapEditorTool.select => FixturePalette(
                  key: const ValueKey('fixture-palette'),
                  controller: controller,
                  onDuplicateSelectedTables: onDuplicateSelectedTables,
                  onRenameSelectedCustomTables:
                      onRenameSelectedCustomTables,
                  onDeleteSelectedTables: onDeleteSelectedTables,
                ),
                MapEditorTool.canopy => CanopyToolbar(
                  key: const ValueKey('canopy-toolbar'),
                  controller: controller,
                  onConfirm: onConfirmCanopy,
                  onEditExistingCanopy: onEditExistingCanopy,
                ),
                MapEditorTool.zones => ZoneToolbar(
                  key: const ValueKey('zone-toolbar'),
                  controller: controller,
                ),
                MapEditorTool.distances => DistanceToolbar(
                  key: const ValueKey('distance-toolbar'),
                  controller: controller,
                  onMoveSelectedDistance: onMoveSelectedDistance,
                  onEditSelectedDistance: onEditSelectedDistance,
                  onDeleteSelectedDistance: onDeleteSelectedDistance,
                ),
                MapEditorTool.resize => ResizeToolbar(
                  key: const ValueKey('resize-toolbar'),
                  controller: controller,
                  onResize: onResizeLayout,
                  onEditSelectedEntrance: onEditSelectedEntrance,
                  onDeleteSelectedEntrance: onDeleteSelectedEntrance,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.14) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFCBD5E1),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : null),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
