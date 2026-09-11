// excel_export_service.dart
//
// Responsibility:
// Formats supported survey data and already-derived production values as XLSX.
// It deliberately does not own geometry or manufacturing rules.

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

import '../models/production_metrics.dart';
import '../models/survey_document.dart';
import '../models/survey_export_bundle.dart';
import '../utils/excel_sheet_formatter.dart';

class ExcelExportService {
  const ExcelExportService();

  static const productionHeaders = <String>[
    'Store Number',
    'State',
    'City',
    'Table Count',
    'Table Count Under Canopy',
    'Single Tables under Canopy',
    'Hanging Baskets under Canopy',
    'Special Tables under Canopy',
    'Single Tables outside Canopy',
    'Hanging Baskets outside Canopy',
    'Special Tables outside Canopy',
    'Spigot Count',
    'Average PSI',
    'Ramp count per distance (46in)',
    'Zone Count',
    'Max canopy height (in.)',
  ];

  Uint8List buildSurveyWorkbook({
    required SurveyDocument survey,
    required ProductionMetrics metrics,
    required String objectPath,
  }) {
    return buildStoresWorkbook([
      SurveyExportBundle(
        objectPath: objectPath,
        survey: survey,
        metrics: metrics,
      ),
    ]);
  }

  /// Writes one heading row followed by one row for every exported store.
  /// Single-store and bulk downloads intentionally use this same layout.
  Uint8List buildStoresWorkbook(List<SurveyExportBundle> bundles) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Stores');
    workbook.setDefaultSheet('Stores');
    final stores = workbook['Stores'];

    _append(stores, productionHeaders);

    for (final bundle in bundles) {
      _append(stores, _productionRow(bundle.survey, bundle.metrics));
    }

    const ExcelSheetFormatter().formatPopulatedSheet(stores);
    return _encode(workbook);
  }

  List<Object?> _productionRow(
    SurveyDocument survey,
    ProductionMetrics metrics,
  ) {
    return [
      survey.storeNumber,
      survey.stateCode,
      survey.city,
      metrics.tableCount,
      metrics.tableCountUnderCanopy,
      metrics.singleTablesUnderCanopy,
      metrics.hangingBasketsUnderCanopy,
      metrics.specialTablesUnderCanopy,
      metrics.singleTablesOutsideCanopy,
      metrics.hangingBasketsOutsideCanopy,
      metrics.specialTablesOutsideCanopy,
      metrics.spigotCount,
      metrics.averagePsi,
      metrics.rampCountAt46Inches,
      metrics.zoneCount,
      metrics.maxCanopyHeightInches,
    ];
  }

  void _append(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cellValue).toList());
  }

  CellValue _cellValue(Object? value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }

  Uint8List _encode(Excel workbook) {
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Excel package returned no encoded workbook bytes.');
    }
    return Uint8List.fromList(bytes);
  }
}
