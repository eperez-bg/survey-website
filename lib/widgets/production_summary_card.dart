// production_summary_card.dart
//
// Responsibility:
// Displays derived counts without embedding any production formulas in UI.

import 'package:flutter/material.dart';

import '../models/production_calculation.dart';

class ProductionSummaryCard extends StatelessWidget {
  final ProductionCalculation calculation;

  const ProductionSummaryCard({super.key, required this.calculation});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      (
        'Irrigation systems',
        calculation.irrigationSystems.toString(),
        'zone count',
      ),
      (
        'Weighted tables',
        calculation.weightedTableCount.toString(),
        '${calculation.logicalTableFixtures} logical fixtures',
      ),
      (
        'Table mix',
        '${calculation.normalTableCount} / ${calculation.hangingBasketCount}',
        'normal / hanging',
      ),
      (
        'Distances',
        calculation.distanceCount.toString(),
        '${_number(calculation.totalDistanceInches)} total inches',
      ),
      (
        '3-foot sections',
        _number(calculation.threeFootSections),
        'temporary distance ÷ 36 rule',
      ),
      (
        'Water + access',
        '${calculation.spigotCount} / ${calculation.entranceCount}',
        'spigots / entrances',
      ),
      (
        'Canopy areas',
        calculation.canopyAreaCount.toString(),
        '${calculation.canopyCellCount} occupied cells',
      ),
      (
        'Custom tables',
        calculation.customTableCount.toString(),
        '${calculation.physicalTableObjects} physical table objects',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Production summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                for (final item in items)
                  SizedBox(
                    width: 155,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          item.$3,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
