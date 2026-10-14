// excel_export_service.dart
//
// Responsibility:
// Formats supported survey data and already-derived production values as XLSX.
// It deliberately does not own geometry or manufacturing rules.

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

import '../models/production_metrics.dart';
import '../models/production_item_definition.dart';
import '../models/survey_document.dart';
import '../models/survey_export_bundle.dart';
import '../utils/excel_sheet_formatter.dart';
import '../utils/production_item_catalog.dart';
import '../utils/production_item_quantity_calculator.dart';

class ExcelExportService {
  const ExcelExportService();

  static const _quantityCalculator = ProductionItemQuantityCalculator();

  static const productionHeaders = <String>[
    'Store Number',
    'State',
    'City',
    'Date Surveyed',
    'Notes',
    'Table Count',
    'Table Group Count',
    'Table Count Under Canopy',
    'Single Tables under Canopy',
    'Hanging Baskets under Canopy',
    'Special Tables under Canopy',
    'Single Tables outside Canopy',
    'Hanging Baskets outside Canopy',
    'Special Tables outside Canopy',
    'Spigot Count',
    'Average PSI',
    'Ramp Sections Count',
    'Ramp count per distance (46in)',
    'Zone Count',
    'Zones under canopy',
    'Max canopy height (in.)',
  ];

  static const List<ProductionItemDefinition> productionItems =
      ProductionItemCatalog.items;

  static int get totalColumnCount =>
      productionHeaders.length + productionItems.length;

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

  /// Writes two heading rows followed by one row for every exported store.
  ///
  /// Existing survey headings occupy the second row. Each production item
  /// adds an item-number cell in the first row and its description immediately
  /// below it. Quantities are derived from the same production metrics used by
  /// the dashboard; an item without a supplied formula remains blank.
  /// Single-store and bulk downloads intentionally use this same layout.
  Uint8List buildStoresWorkbook(List<SurveyExportBundle> bundles) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Stores');
    workbook.setDefaultSheet('Stores');
    final stores = workbook['Stores'];

    _append(stores, [
      ...List<Object?>.filled(productionHeaders.length, null),
      ...productionItems.map((item) => item.itemNumber),
    ]);
    _append(stores, [
      ...productionHeaders,
      ...productionItems.map((item) => item.description),
    ]);

    for (final bundle in bundles) {
      _append(stores, [
        ..._productionRow(bundle.survey, bundle.metrics),
        ...productionItems.map(
          (item) => _quantityCalculator.calculate(item, bundle.metrics),
        ),
      ]);
    }

    const ExcelSheetFormatter().formatPopulatedSheet(
      stores,
      headerRowCount: 2,
    );
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
      survey.visitDate,
      survey.notes,
      metrics.tableCount,
      metrics.tableGroupCount,
      metrics.tableCountUnderCanopy,
      metrics.singleTablesUnderCanopy,
      metrics.hangingBasketsUnderCanopy,
      metrics.specialTablesUnderCanopy,
      metrics.singleTablesOutsideCanopy,
      metrics.hangingBasketsOutsideCanopy,
      metrics.specialTablesOutsideCanopy,
      metrics.spigotCount,
      metrics.averagePsi,
      metrics.rampSectionsCount,
      metrics.rampCountAt46Inches,
      metrics.zoneCount,
      metrics.zonesUnderCanopy,
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
    if (value is DateTime) {
      return DateCellValue(
        year: value.year,
        month: value.month,
        day: value.day,
      );
    }
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
