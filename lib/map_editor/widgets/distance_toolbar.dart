import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';

/// Context-sensitive controls for drawing or editing distances.
class DistanceToolbar extends StatelessWidget {
  final MapEditorController controller;
  final VoidCallback onMoveSelectedDistance;
  final VoidCallback onEditSelectedDistance;
  final VoidCallback onDeleteSelectedDistance;

  const DistanceToolbar({
    super.key,
    required this.controller,
    required this.onMoveSelectedDistance,
    required this.onEditSelectedDistance,
    required this.onDeleteSelectedDistance,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDistance = controller.selectedDistance;

    if (selectedDistance != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.linear_scale, color: Color(0xFF0F766E)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected distance',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _formatMeasurement(selectedDistance.measuredDistance),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onMoveSelectedDistance,
              icon: const Icon(Icons.open_with),
              label: const Text('Move'),
            ),
            TextButton.icon(
              onPressed: onEditSelectedDistance,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            IconButton(
              tooltip: 'Delete selected distance',
              onPressed: onDeleteSelectedDistance,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            ),
            IconButton(
              tooltip: 'Deselect distance',
              onPressed: controller.deselectDistance,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }

    if (controller.hasDistanceDraft || controller.isMovingDistance) {
      final cellCount = controller.draftDistanceCells.length;

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.edit_road, color: Color(0xFF0F766E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.isMovingDistance && cellCount == 0
                    ? 'Moving selected distance. Tap the first cell of its new path.'
                    : '$cellCount distance ${cellCount == 1 ? 'cell' : 'cells'} '
                        'selected. Tap the last cell to finish the path.',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: controller.cancelDistanceDraft,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Tap the first and last cell between a table and another '
              'table, wall, or canopy edge. You can pan and zoom between '
              'taps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMeasurement(double distance) {
    final number = distance == distance.roundToDouble()
        ? distance.toInt().toString()
        : distance.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$number in';
  }
}
