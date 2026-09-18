import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';

/// Compact fixture counts displayed above the map canvas.
class MapEditorSummary extends StatelessWidget {
  final MapEditorController controller;

  const MapEditorSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _CountChip(
              icon: Icons.table_restaurant,
              label: 'Tables',
              count: controller.normalTableCount,
              color: const Color(0xFF16A34A),
            ),
            _CountChip(
              icon: Icons.local_florist,
              label: 'Hanging',
              count: controller.hangingBasketCount,
              color: const Color(0xFF7C3AED),
            ),
            _CountChip(
              icon: Icons.label_outline,
              label: 'Custom',
              count: controller.customTableCount,
              color: const Color(0xFF0369A1),
            ),
            _CountChip(
              icon: Icons.water_drop,
              label: 'Spigots',
              count: controller.spigotCount,
              color: const Color(0xFFDC2626),
            ),
            _CountChip(
              icon: Icons.door_front_door,
              label: 'Entrances',
              count: controller.entranceCount,
              color: const Color(0xFF0891B2),
            ),
            _CountChip(
              icon: Icons.grid_on,
              label: 'Canopy cells',
              count: controller.canopyCellCount,
              color: const Color(0xFFD97706),
            ),
            _CountChip(
              icon: Icons.block,
              label: 'No-install cells',
              count: controller.noInstallZoneCellCount,
              color: const Color(0xFFDC2626),
            ),
            _CountChip(
              icon: Icons.linear_scale,
              label: 'Distances',
              count: controller.distanceCount,
              color: const Color(0xFF0F766E),
            ),
            _CountChip(
              icon: Icons.layers,
              label: 'Zones',
              count: controller.zoneCount,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Icon(icon, size: 17, color: color),
        label: Text('$label: $count'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Tool-specific guidance displayed immediately above the editor toolbar.
class MapEditorInstructionBar extends StatelessWidget {
  final MapEditorController controller;

  const MapEditorInstructionBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color iconColor;
    late final IconData icon;
    late final String instructions;

    switch (controller.activeTool) {
      case MapEditorTool.select:
        if (controller.isSpigotPlacementEnabled) {
          backgroundColor = const Color(0xFFFEF2F2);
          iconColor = const Color(0xFFDC2626);
          icon = Icons.water_drop;
          instructions =
              'Spigot placement is on: double-tap a grid intersection to '
              'add one and enter its PSI. Double-tap an existing spigot to '
              'edit its pressure or delete it.';
        } else {
          backgroundColor = const Color(0xFFEFF6FF);
          iconColor = const Color(0xFF2563EB);
          icon = Icons.touch_app;
          instructions =
              'Tap either half of a table pair to select the whole pair. '
              'Custom tables select individually. Long-press to drag; use '
              'the toolbar to duplicate, rename, or delete selections.';
        }
        break;
      case MapEditorTool.canopy:
        if (controller.isNoInstallZonePlacementEnabled) {
          backgroundColor = const Color(0xFFFEF2F2);
          iconColor = const Color(0xFFDC2626);
          icon = Icons.block;
          instructions =
              'No Install Zone mode: choose three rectangle corners. Red '
              'cells prevent fixtures and distance paths from crossing the '
              'area.';
        } else {
          backgroundColor = const Color(0xFFFFFBEB);
          iconColor = const Color(0xFFD97706);
          icon = Icons.grid_on;
          instructions =
              'Canopy mode: choose three rectangle corners. After the first '
              'two, only valid third corners are highlighted.';
        }
        break;
      case MapEditorTool.zones:
        backgroundColor = const Color(0xFFF5F3FF);
        iconColor = const Color(0xFF7C3AED);
        icon = Icons.layers;
          instructions =
              'Zone mode (optional): tap either half of a pair to assign the '
              'whole pair to the current zone. Custom tables cannot be added.';
        break;
      case MapEditorTool.distances:
        backgroundColor = const Color(0xFFF0FDFA);
        iconColor = const Color(0xFF0F766E);
        icon = Icons.linear_scale;
        instructions =
            'Distance mode: tap the first cell, pan or zoom if needed, then '
            'tap the last cell of the straight path. Measure only from one '
            'endpoint to the other. One end must be a table; the other can '
            'be another table, a wall, or a canopy edge. Paths cannot cross '
            'a No Install Zone.';
        break;
      case MapEditorTool.resize:
        backgroundColor = const Color(0xFFECFEFF);
        iconColor = const Color(0xFF0891B2);
        if (controller.isEntrancePlacementEnabled) {
          icon = Icons.door_front_door;
          instructions =
              'Entrance placement is on: double-tap a room wall to add one, '
              'tap an entrance to select it, or long-press and drag it to '
              'another wall.';
        } else {
          icon = Icons.aspect_ratio;
          instructions =
              'Size mode: choose Canvas or Room, select a step, then move '
              'one edge with − or +. Choose Room to edit entrances.';
        }
        break;
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instructions,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}
