// production_summary_card.dart
//
// Responsibility:
// Displays derived counts without embedding any production formulas in UI.

import 'package:flutter/material.dart';

import '../models/production_metrics.dart';

class ProductionSummaryCard extends StatelessWidget {
  final ProductionMetrics metrics;

  const ProductionSummaryCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      (
        'Table count',
        metrics.tableCount.toString(),
        'all production tables',
      ),
      (
        'Under canopy',
        metrics.tableCountUnderCanopy.toString(),
        'any table cell overlaps',
      ),
      (
        'Outside canopy',
        metrics.tableCountOutsideCanopy.toString(),
        'no table cell overlaps',
      ),
      (
        'Table mix',
        '${metrics.singleTableCount} / ${metrics.hangingBasketCount} / ${metrics.specialTableCount}',
        'single / hanging / special',
      ),
      (
        'Ramp count',
        _number(metrics.rampCountAt46Inches),
        'each distance ÷ 46 in.',
      ),
      (
        'Spigots',
        metrics.spigotCount.toString(),
        'average ${_optionalNumber(metrics.averagePsi)} PSI',
      ),
      (
        'Zones',
        metrics.zoneCount.toString(),
        'persisted map zones',
      ),
      (
        'Max canopy height',
        _number(metrics.maxCanopyHeightInches),
        'inches',
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

  static String _optionalNumber(double? value) =>
      value == null ? '—' : _number(value);
}
