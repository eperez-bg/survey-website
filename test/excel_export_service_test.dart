import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/models/survey_export_bundle.dart';
import 'package:survey_admin_web/services/excel_export_service.dart';
import 'package:survey_admin_web/utils/excel_sheet_formatter.dart';
import 'package:survey_admin_web/utils/production_metrics_calculator.dart';

void main() {
  test('store workbook starts with the required production columns', () {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final metrics = const ProductionMetricsCalculator().calculate(survey);

    final bytes = const ExcelExportService().buildSurveyWorkbook(
      survey: survey,
      metrics: metrics,
      objectPath: 'test/store.json',
    );
    final workbook = Excel.decodeBytes(bytes);
    final stores = workbook.tables['Stores'];

    expect(workbook.tables.keys, orderedEquals(['Stores']));
    expect(stores, isNotNull);
    expect(stores!.maxRows, 2);
    expect(stores.maxColumns, ExcelExportService.productionHeaders.length);
    expect(
      stores.rows.first.map((cell) => cell?.value.toString()).toList(),
      ExcelExportService.productionHeaders,
    );
    expect(
      ExcelExportService.productionHeaders,
      containsAllInOrder([
        'Table Count',
        'Table Group Count',
        'Table Count Under Canopy',
      ]),
    );
    expect(
      ExcelExportService.productionHeaders,
      containsAllInOrder([
        'Zone Count',
        'Zones under canopy',
        'Max canopy height (in.)',
      ]),
    );
    expect(stores.rows[1][3]?.value, isA<IntCellValue>());
    expect((stores.rows[1][3]?.value as IntCellValue).value, 3);
    final tableGroupColumn = ExcelExportService.productionHeaders.indexOf(
      'Table Group Count',
    );
    final tableGroupCount = stores.rows[1][tableGroupColumn]?.value;
    expect(tableGroupCount, isA<IntCellValue>());
    expect((tableGroupCount! as IntCellValue).value, metrics.tableGroupCount);
    final zonesUnderCanopyColumn = ExcelExportService.productionHeaders.indexOf(
      'Zones under canopy',
    );
    final zonesUnderCanopy = stores.rows[1][zonesUnderCanopyColumn]?.value;
    expect(zonesUnderCanopy, isA<IntCellValue>());
    expect((zonesUnderCanopy! as IntCellValue).value, metrics.zonesUnderCanopy);
    for (var column = 3; column < stores.maxColumns; column += 1) {
      expect(stores.rows[1][column]?.value, isNot(isA<TextCellValue>()));
    }
  });

  test('bulk workbook uses the same columns with one row per store', () {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final metrics = const ProductionMetricsCalculator().calculate(survey);
    final bundle = SurveyExportBundle(
      objectPath: 'test/store.json',
      survey: survey,
      metrics: metrics,
    );

    final bytes = const ExcelExportService().buildStoresWorkbook([
      bundle,
      bundle,
    ]);
    final workbook = Excel.decodeBytes(bytes);
    final stores = workbook.tables['Stores'];

    expect(workbook.tables.keys, orderedEquals(['Stores']));
    expect(stores, isNotNull);
    expect(stores!.maxRows, 3);
    expect(stores.maxColumns, ExcelExportService.productionHeaders.length);
    expect(
      stores.rows.first.map((cell) => cell?.value.toString()).toList(),
      ExcelExportService.productionHeaders,
    );
    expect(stores.rows[1][0]?.value.toString(), survey.storeNumber);
    expect(stores.rows[2][0]?.value.toString(), survey.storeNumber);
  });

  test('exported workbook applies the requested worksheet formatting', () {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final metrics = const ProductionMetricsCalculator().calculate(survey);
    final bundle = SurveyExportBundle(
      objectPath: 'test/store.json',
      survey: survey,
      metrics: metrics,
    );

    final bytes = const ExcelExportService().buildStoresWorkbook([
      bundle,
      bundle,
    ]);
    final stores = Excel.decodeBytes(bytes).tables['Stores']!;

    final headerStyle = stores.rows[0][0]!.cellStyle!;
    expect(headerStyle.isBold, isTrue);
    expect(headerStyle.backgroundColor.colorHex, 'FFFFF2CC');
    _expectAllThinBorders(headerStyle);

    final bodyStyle = stores.rows[1][0]!.cellStyle!;
    _expectAllThinBorders(bodyStyle);

    for (
      var columnIndex = 0;
      columnIndex < ExcelExportService.productionHeaders.length;
      columnIndex += 1
    ) {
      final headerLength =
          ExcelExportService.productionHeaders[columnIndex].runes.length;
      expect(
        stores.getColumnWidth(columnIndex),
        greaterThan(headerLength.toDouble()),
      );
    }

    expect(stores.getRowHeight(0), ExcelSheetFormatter.headerRowHeightPoints);
    expect(stores.getRowHeight(1), ExcelSheetFormatter.bodyRowHeightPoints);
    expect(stores.getRowHeight(2), ExcelSheetFormatter.bodyRowHeightPoints);
  });

  test('worksheet formatter leaves cells without content unbordered', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];
    sheet.appendRow([TextCellValue('Header'), TextCellValue('')]);
    sheet.appendRow([IntCellValue(1), TextCellValue('')]);

    const ExcelSheetFormatter().formatPopulatedSheet(sheet);

    expect(sheet.rows[0][0]!.cellStyle, isNotNull);
    expect(sheet.rows[1][0]!.cellStyle, isNotNull);
    _expectNoBorders(sheet.rows[0][1]!.cellStyle!);
    _expectNoBorders(sheet.rows[1][1]!.cellStyle!);
  });

  test('no canopy exports a numeric zero for max canopy height', () {
    final sourceSurvey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final source = sourceSurvey.raw;
    final layout = source['gardenCenterLayout'] as Map<String, dynamic>;
    layout['canopyCellList'] = <Map<String, dynamic>>[];
    final survey = SurveyDocument(source);
    final metrics = const ProductionMetricsCalculator().calculate(survey);

    final bytes = const ExcelExportService().buildSurveyWorkbook(
      survey: survey,
      metrics: metrics,
      objectPath: 'test/no-canopy.json',
    );
    final stores = Excel.decodeBytes(bytes).tables['Stores']!;
    final maxHeightColumn = ExcelExportService.productionHeaders.indexOf(
      'Max canopy height (in.)',
    );
    final maxHeight = stores.rows[1][maxHeightColumn]?.value;

    expect(maxHeight, isNot(isA<TextCellValue>()));
    expect(maxHeight.toString(), '0');
  });
}

void _expectAllThinBorders(CellStyle style) {
  expect(style.leftBorder.borderStyle, BorderStyle.Thin);
  expect(style.rightBorder.borderStyle, BorderStyle.Thin);
  expect(style.topBorder.borderStyle, BorderStyle.Thin);
  expect(style.bottomBorder.borderStyle, BorderStyle.Thin);
}

void _expectNoBorders(CellStyle style) {
  expect(style.leftBorder.borderStyle, isNull);
  expect(style.rightBorder.borderStyle, isNull);
  expect(style.topBorder.borderStyle, isNull);
  expect(style.bottomBorder.borderStyle, isNull);
}
