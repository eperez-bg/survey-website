import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';
import '../models/canopy_corner_drag_data.dart';

/// Controls for building canopy and No Install Zone rectangles.
class CanopyToolbar extends StatelessWidget {
  final MapEditorController controller;
  final VoidCallback onConfirm;
  final VoidCallback onEditExistingCanopy;

  const CanopyToolbar({
    super.key,
    required this.controller,
    required this.onConfirm,
    required this.onEditExistingCanopy,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.isCanopyPreviewReady) {
      return _buildConfirmation();
    }

    return _buildCornerPlacement();
  }

  Widget _buildCornerPlacement() {
    final cornerCount = controller.canopyDraftCorners.length;
    final isNoInstallZone = controller.isNoInstallZonePlacementEnabled;
    final areaLabel = isNoInstallZone ? 'No Install Zone' : 'canopy';
    final instruction = cornerCount == 0
        ? 'Place any three $areaLabel rectangle corners. The fourth is filled '
              'automatically.'
        : cornerCount == 2
        ? 'Choose one of the grey highlighted cells for corner 3.'
        : 'Corner $cornerCount of 3 placed. Place corner ${cornerCount + 1}.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FilterChip(
                key: const ValueKey('no-install-zone-placement-toggle'),
                avatar: const _NoInstallZoneSwatch(),
                label: Text(
                  isNoInstallZone
                      ? 'No Install Zone on'
                      : 'No Install Zone',
                ),
                selected: isNoInstallZone,
                selectedColor: const Color(0xFFFEE2E2),
                checkmarkColor: const Color(0xFFB91C1C),
                side: BorderSide(
                  color: isNoInstallZone
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFCBD5E1),
                ),
                onSelected: controller.setNoInstallZonePlacementEnabled,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isNoInstallZone
                      ? 'Red cells block fixture and distance placement.'
                      : 'Turn on to mark an area where nothing is installed.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CanopyCornerDraggable(isNoInstallZone: isNoInstallZone),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  instruction,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (cornerCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: controller.undoLastCanopyCorner,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo corner'),
                ),
                TextButton.icon(
                  onPressed: controller.cancelCanopyDraft,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    final willRemove = controller.shouldRemoveCanopyDraft;
    final isNoInstallZone = controller.isNoInstallZonePlacementEnabled;
    final cellCount = controller.canopyPreviewCells.length;
    final actionColor = willRemove || isNoInstallZone
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final areaLabel = isNoInstallZone ? 'No Install Zone' : 'canopy';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                willRemove
                    ? Icons.layers_clear
                    : isNoInstallZone
                    ? Icons.block
                    : Icons.grid_on,
                color: actionColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  willRemove
                      ? 'Remove this $cellCount-cell $areaLabel rectangle?'
                      : isNoInstallZone
                      ? 'Add this $cellCount-cell No Install Zone rectangle?'
                      : 'Add this $cellCount-cell canopy rectangle? '
                            'You will enter its dimensions next.',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: controller.undoLastCanopyCorner,
                  icon: const Icon(Icons.undo),
                  label: const Text('Change corner'),
                ),
                TextButton(
                  onPressed: controller.cancelCanopyDraft,
                  child: const Text('Cancel'),
                ),
                if (willRemove && !isNoInstallZone)
                  OutlinedButton.icon(
                    onPressed: onEditExistingCanopy,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit measurements'),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: actionColor),
                  onPressed: onConfirm,
                  icon: Icon(willRemove ? Icons.delete_outline : Icons.check),
                  label: Text(
                    willRemove
                        ? 'Confirm remove'
                        : isNoInstallZone
                        ? 'Confirm zone'
                        : 'Confirm canopy',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CanopyCornerDraggable extends StatelessWidget {
  final bool isNoInstallZone;

  const _CanopyCornerDraggable({required this.isNoInstallZone});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isNoInstallZone
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final borderColor = isNoInstallZone
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    final textColor = isNoInstallZone
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);
    final paletteItem = Container(
      width: 108,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.crop_free, color: borderColor, size: 19),
          const SizedBox(width: 6),
          Text(
            isNoInstallZone ? 'Drag zone' : 'Drag corner',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    return Draggable<CanopyCornerDragData>(
      data: const CanopyCornerDragData(),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 3),
          ),
          child: Icon(Icons.crop_free, color: borderColor),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: paletteItem),
      child: paletteItem,
    );
  }
}

class _NoInstallZoneSwatch extends StatelessWidget {
  const _NoInstallZoneSwatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: const Color(0x66EF4444),
        border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}
