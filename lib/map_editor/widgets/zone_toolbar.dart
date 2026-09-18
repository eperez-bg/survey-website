import 'package:flutter/material.dart';

import '../controllers/map_editor_controller.dart';
import '../utils/zone_color.dart';
import '../utils/zone_rules.dart';

/// Bottom controls shown while the surveyor assigns tables to zones.
class ZoneToolbar extends StatelessWidget {
  final MapEditorController controller;

  const ZoneToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final zone = controller.currentZone;

    if (zone == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: controller.createZone,
          icon: const Icon(Icons.add),
          label: const Text('Create first zone'),
        ),
      );
    }

    final zoneColor = zoneColorFromHex(zone.colorHex);
    final zonePosition = controller.currentZoneIndex + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous zone',
                onPressed: controller.canSelectPreviousZone
                    ? controller.selectPreviousZone
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 66),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: zoneColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zoneColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 42,
                        decoration: BoxDecoration(
                          color: zoneColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${zone.label} • $zonePosition of '
                              '${controller.zoneCount}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${controller.currentZoneWeightedTableCount}/'
                              '${ZoneRules.maxWeightedTableCount} tables'
                              ' • ${controller.currentZoneFixtureCount} '
                              'fixtures',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Next zone',
                onPressed: controller.canSelectNextZone
                    ? controller.selectNextZone
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: 'Create new zone',
                onPressed: controller.createZone,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Zones are optional. Tap either half to assign the whole pair. '
            'Empty zones are removed automatically. '
            'Normal pairs count as 1; hanging-basket pairs count as 2. '
            '${controller.unassignedTableCount} unassigned.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
