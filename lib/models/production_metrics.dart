// production_metrics.dart
//
// Responsibility:
// Represents the derived production values used by the admin summary and
// exports. Aggregate table totals intentionally exclude custom tables while
// retaining their detail counts for reporting.

class ProductionMetrics {
  final int singleTablesUnderCanopy;
  final int hangingBasketsUnderCanopy;
  final int specialTablesUnderCanopy;
  final int singleTablesOutsideCanopy;
  final int hangingBasketsOutsideCanopy;
  final int specialTablesOutsideCanopy;
  final int spigotCount;
  final double? averagePsi;
  final int rampSectionsCount;
  final int rampCountAt46Inches;
  final int tableGroupCount;
  final int zoneCount;
  final int zonesUnderCanopy;
  final double maxCanopyHeightInches;

  const ProductionMetrics({
    required this.singleTablesUnderCanopy,
    required this.hangingBasketsUnderCanopy,
    required this.specialTablesUnderCanopy,
    required this.singleTablesOutsideCanopy,
    required this.hangingBasketsOutsideCanopy,
    required this.specialTablesOutsideCanopy,
    required this.spigotCount,
    required this.averagePsi,
    required this.rampSectionsCount,
    required this.rampCountAt46Inches,
    required this.tableGroupCount,
    required this.zoneCount,
    required this.zonesUnderCanopy,
    required this.maxCanopyHeightInches,
  });

  int get tableCountUnderCanopy =>
      singleTablesUnderCanopy + hangingBasketsUnderCanopy;

  int get tableCountOutsideCanopy =>
      singleTablesOutsideCanopy + hangingBasketsOutsideCanopy;

  int get tableCount => tableCountUnderCanopy + tableCountOutsideCanopy;

  int get singleTableCount =>
      singleTablesUnderCanopy + singleTablesOutsideCanopy;

  int get hangingBasketCount =>
      hangingBasketsUnderCanopy + hangingBasketsOutsideCanopy;

  int get specialTableCount =>
      specialTablesUnderCanopy + specialTablesOutsideCanopy;

  Map<String, Object?> toJson() => {
    'tableCount': tableCount,
    'tableCountUnderCanopy': tableCountUnderCanopy,
    'singleTablesUnderCanopy': singleTablesUnderCanopy,
    'hangingBasketsUnderCanopy': hangingBasketsUnderCanopy,
    'specialTablesUnderCanopy': specialTablesUnderCanopy,
    'singleTablesOutsideCanopy': singleTablesOutsideCanopy,
    'hangingBasketsOutsideCanopy': hangingBasketsOutsideCanopy,
    'specialTablesOutsideCanopy': specialTablesOutsideCanopy,
    'spigotCount': spigotCount,
    'averagePsi': averagePsi,
    'rampSectionsCount': rampSectionsCount,
    'rampCountAt46Inches': rampCountAt46Inches,
    'tableGroupCount': tableGroupCount,
    'zoneCount': zoneCount,
    'zonesUnderCanopy': zonesUnderCanopy,
    'maxCanopyHeightInches': maxCanopyHeightInches,
  };
}
