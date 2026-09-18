import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';
import '../utils/layout_resize_geometry.dart';

typedef LayoutResizeCallback =
    void Function(
      LayoutResizeTarget target,
      LayoutResizeSide side,
      int deltaCells,
    );

/// Controls which boundary moves and by how many grid cells.
class ResizeToolbar extends StatefulWidget {
  final MapEditorController controller;
  final LayoutResizeCallback onResize;
  final VoidCallback onEditSelectedEntrance;
  final VoidCallback onDeleteSelectedEntrance;

  const ResizeToolbar({
    super.key,
    required this.controller,
    required this.onResize,
    required this.onEditSelectedEntrance,
    required this.onDeleteSelectedEntrance,
  });

  @override
  State<ResizeToolbar> createState() => _ResizeToolbarState();
}

class _ResizeToolbarState extends State<ResizeToolbar> {
  LayoutResizeTarget _target = LayoutResizeTarget.room;
  int _stepCells = 5;

  @override
  Widget build(BuildContext context) {
    final layout = widget.controller.layout;
    final dimensionLabel = _target == LayoutResizeTarget.canvas
        ? '${layout.canvasRows} rows × ${layout.canvasColumns} columns'
        : '${layout.roomBounds.heightCells} rows × '
              '${layout.roomBounds.widthCells} columns';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _TargetChoice(
                label: 'Canvas',
                icon: Icons.crop_free,
                selected: _target == LayoutResizeTarget.canvas,
                onSelected: () {
                  widget.controller.setEntrancePlacementEnabled(false);
                  setState(() {
                    _target = LayoutResizeTarget.canvas;
                  });
                },
              ),
              const SizedBox(width: 7),
              _TargetChoice(
                label: 'Room',
                icon: Icons.storefront,
                selected: _target == LayoutResizeTarget.room,
                onSelected: () {
                  setState(() {
                    _target = LayoutResizeTarget.room;
                  });
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dimensionLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_target == LayoutResizeTarget.room) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                FilterChip(
                  key: const ValueKey('entrance-placement-toggle'),
                  avatar: const Icon(Icons.door_front_door, size: 17),
                  label: Text(
                    widget.controller.isEntrancePlacementEnabled
                        ? 'Entrances on'
                        : 'Place entrances',
                  ),
                  selected: widget.controller.isEntrancePlacementEnabled,
                  selectedColor: const Color(0xFFCFFAFE),
                  checkmarkColor: const Color(0xFF0E7490),
                  side: BorderSide(
                    color: widget.controller.isEntrancePlacementEnabled
                        ? const Color(0xFF0891B2)
                        : const Color(0xFFCBD5E1),
                  ),
                  onSelected:
                      widget.controller.setEntrancePlacementEnabled,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _entranceInstructions,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (widget.controller.selectedEntrance != null) ...[
                  IconButton(
                    key: const ValueKey('edit-selected-entrance-button'),
                    tooltip: 'Edit entrance properties',
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFF0891B2),
                    onPressed: widget.onEditSelectedEntrance,
                    icon: const Icon(Icons.tune, size: 21),
                  ),
                  IconButton(
                    key: const ValueKey('delete-selected-entrance-button'),
                    tooltip: 'Delete selected entrance',
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFFDC2626),
                    onPressed: widget.onDeleteSelectedEntrance,
                    icon: const Icon(Icons.delete_outline, size: 21),
                  ),
                  IconButton(
                    tooltip: 'Clear entrance selection',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.controller.clearEntranceSelection,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Cells per tap',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              for (final step in const [1, 5, 10]) ...[
                _StepChoice(
                  value: step,
                  selected: _stepCells == step,
                  onSelected: () {
                    setState(() {
                      _stepCells = step;
                    });
                  },
                ),
                if (step != 10) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final itemWidth = (constraints.maxWidth - spacing * 3) / 4;

              return Wrap(
                spacing: spacing,
                children: [
                  for (final side in LayoutResizeSide.values)
                    SizedBox(
                      width: itemWidth,
                      child: _SideResizeControl(
                        side: side,
                        stepCells: _stepCells,
                        onShrink: () =>
                            widget.onResize(_target, side, -_stepCells),
                        onExpand: () =>
                            widget.onResize(_target, side, _stepCells),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 5),
          const Text(
            '− shrinks that edge  •  + expands that edge',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _entranceInstructions {
    final entranceCount = widget.controller.entranceCount;
    final countLabel = '$entranceCount placed.';
    if (widget.controller.selectedEntrance != null) {
      return 'Selected. Long-press and drag it to any room wall. $countLabel';
    }
    if (widget.controller.isEntrancePlacementEnabled) {
      return 'Double-tap a wall to add; tap an entrance to select it. '
          '$countLabel';
    }
    return 'Turn on to add, select, move, or delete entrances. $countLabel';
  }
}

class _TargetChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _TargetChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF0891B2).withOpacity(0.14)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0891B2)
                  : const Color(0xFFCBD5E1),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? const Color(0xFF0E7490)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF0E7490)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepChoice extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onSelected;

  const _StepChoice({
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 31,
        height: 31,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0891B2) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SideResizeControl extends StatelessWidget {
  final LayoutResizeSide side;
  final int stepCells;
  final VoidCallback onShrink;
  final VoidCallback onExpand;

  const _SideResizeControl({
    required this.side,
    required this.stepCells,
    required this.onShrink,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (side) {
      LayoutResizeSide.top => 'Top',
      LayoutResizeSide.right => 'Right',
      LayoutResizeSide.bottom => 'Bottom',
      LayoutResizeSide.left => 'Left',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(3, 5, 3, 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Shrink $label by $stepCells cells',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 30),
                onPressed: onShrink,
                icon: const Icon(Icons.remove, size: 19),
              ),
              IconButton(
                tooltip: 'Expand $label by $stepCells cells',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 30),
                color: const Color(0xFF0E7490),
                onPressed: onExpand,
                icon: const Icon(Icons.add, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
