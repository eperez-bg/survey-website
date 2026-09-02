// production_calculation.dart
// Work-in-progress output object. Keep calculations isolated here so changing
// the production formula later does not affect storage, screens, or exports.

class ProductionCalculation {
  const ProductionCalculation({
    required this.irrigationSystems,
    required this.ramps,
    required this.totalRampDistance,
  });

  final int irrigationSystems;
  final double ramps;
  final double totalRampDistance;
}
