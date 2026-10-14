import 'dart:io';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/production_item_definition.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/models/survey_export_bundle.dart';
import 'package:survey_admin_web/services/excel_export_service.dart';
import 'package:survey_admin_web/utils/excel_sheet_formatter.dart';
import 'package:survey_admin_web/utils/production_item_quantity_calculator.dart';
import 'package:survey_admin_web/utils/production_metrics_calculator.dart';

void main() {
  test('store workbook starts with two-level production item headings', () {
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
    expect(stores!.maxRows, 3);
    expect(stores.maxColumns, ExcelExportService.totalColumnCount);
    expect(
      _rowText(stores.rows[0]),
      [
        ...List.filled(ExcelExportService.productionHeaders.length, ''),
        ...ExcelExportService.productionItems.map((item) => item.itemNumber),
      ],
    );
    expect(
      _rowText(stores.rows[1]),
      [
        ...ExcelExportService.productionHeaders,
        ...ExcelExportService.productionItems.map((item) => item.description),
      ],
    );
    expect(ExcelExportService.productionItems, hasLength(22));
    expect(
      ExcelExportService.productionItems.map((item) => item.itemNumber),
      orderedEquals([
        '89225-200',
        '89225-700',
        '88177-015-20',
        '88177-015P',
        'Poly Tube (700FT ROLL)',
        '88177-010-200',
        '2706N8, 2706N24, 5388K24',
        '7459T21',
        'Pressure Regulator',
        '1-Port Timer Assembly (with timer)',
        'brass nozzle for poly',
        '88177-SHUT-OFFVALVE',
        '88177-S-CONNECTOR',
        '88177-L-CONNECTOR',
        '88177-T-CONNECTOR',
        '88177-GRAYPOLY',
        '88177-CUTTER',
        '88177-ZIPTIE',
        '88177-610',
        '88177-CBALETIE',
        '',
        '88177-REPLCAMENTKIT',
      ]),
    );
    expect(
      ExcelExportService.productionItems.map((item) => item.description),
      orderedEquals([
        '(New) Reverse Sprinkler System (Red Sprinkler)',
        '(NEW) Folding Tower Concept w/Adjustable Towers',
        '20" Towers + Post mount trough (sprinkler bridge)',
        '20" Towers + Post mount trough (sprinkler bridge)',
        'Poly Tube (700FT ROLL)',
        '3/4 Garden Hose (200FT Roll)',
        'Garden Hose End Fittings',
        'Brass Wye-Shaped On-Off Valve',
        'Pressure Regulator',
        '1-Port Zone Control Assembly (With Timer)',
        'Brass fitting for Poly Tube',
        'Shut-off Valve',
        'Straight connector',
        'L-connector for Poly',
        'T-connector for Poly',
        'GRAY POLY TUBE PLUG WITH DRAIN',
        'Cutter',
        'Zip Ties (Bag of 100)',
        'Ramp',
        'Color Zip Ties',
        'Cautious Flag Pole',
        '88177 REPLACEMENT KIT',
      ]),
    );
    expect(
      ExcelExportService.productionItems[3].description,
      ExcelExportService.productionItems[2].description,
    );
    expect(ExcelExportService.productionItems[20].itemNumber, isEmpty);
    expect(
      ExcelExportService.productionItems[20].description,
      'Cautious Flag Pole',
    );
    expect(
      ExcelExportService.productionHeaders.take(5),
      orderedEquals([
        'Store Number',
        'State',
        'City',
        'Date Surveyed',
        'Notes',
      ]),
    );
    expect(ExcelExportService.productionHeaders, hasLength(21));
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
        'Average PSI',
        'Ramp Sections Count',
        'Ramp count per distance (46in)',
        'Zone Count',
        'Zones under canopy',
        'Max canopy height (in.)',
      ]),
    );
    final surveyDateColumn = ExcelExportService.productionHeaders.indexOf(
      'Date Surveyed',
    );
    final surveyDate = stores.rows[2][surveyDateColumn]?.value;
    expect(surveyDate, isA<DateCellValue>());
    final dateCell = surveyDate! as DateCellValue;
    expect(dateCell.year, 2026);
    expect(dateCell.month, 9);
    expect(dateCell.day, 2);
    final notesColumn = ExcelExportService.productionHeaders.indexOf('Notes');
    expect(stores.rows[2][notesColumn]?.value.toString(), survey.notes);
    final tableCountColumn = ExcelExportService.productionHeaders.indexOf(
      'Table Count',
    );
    expect(stores.rows[2][tableCountColumn]?.value, isA<IntCellValue>());
    expect(
      (stores.rows[2][tableCountColumn]?.value as IntCellValue).value,
      metrics.tableCount,
    );
    final tableGroupColumn = ExcelExportService.productionHeaders.indexOf(
      'Table Group Count',
    );
    final tableGroupCount = stores.rows[2][tableGroupColumn]?.value;
    expect(tableGroupCount, isA<IntCellValue>());
    expect((tableGroupCount! as IntCellValue).value, metrics.tableGroupCount);
    final rampSectionsColumn = ExcelExportService.productionHeaders.indexOf(
      'Ramp Sections Count',
    );
    final rampSectionsCount = stores.rows[2][rampSectionsColumn]?.value;
    expect(rampSectionsCount, isA<IntCellValue>());
    expect(
      (rampSectionsCount! as IntCellValue).value,
      metrics.rampSectionsCount,
    );
    final rampCountColumn = ExcelExportService.productionHeaders.indexOf(
      'Ramp count per distance (46in)',
    );
    final rampCount = stores.rows[2][rampCountColumn]?.value;
    expect(rampCount, isA<IntCellValue>());
    expect((rampCount! as IntCellValue).value, metrics.rampCountAt46Inches);
    final zonesUnderCanopyColumn = ExcelExportService.productionHeaders.indexOf(
      'Zones under canopy',
    );
    final zonesUnderCanopy = stores.rows[2][zonesUnderCanopyColumn]?.value;
    expect(zonesUnderCanopy, isA<IntCellValue>());
    expect((zonesUnderCanopy! as IntCellValue).value, metrics.zonesUnderCanopy);
    for (
      var column = tableCountColumn;
      column < ExcelExportService.productionHeaders.length;
      column += 1
    ) {
      expect(stores.rows[2][column]?.value, isNot(isA<TextCellValue>()));
    }
    const quantityCalculator = ProductionItemQuantityCalculator();
    for (
      var itemIndex = 0;
      itemIndex < ExcelExportService.productionItems.length;
      itemIndex += 1
    ) {
      final item = ExcelExportService.productionItems[itemIndex];
      final expected = quantityCalculator.calculate(item, metrics);
      final column = ExcelExportService.productionHeaders.length + itemIndex;
      final quantityCell = stores.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 2),
      );
      if (expected == null) {
        expect(quantityCell.value.toString(), isEmpty);
      } else {
        expect(quantityCell.value, isA<IntCellValue>());
        expect((quantityCell.value! as IntCellValue).value, expected);
      }
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
    expect(stores!.maxRows, 4);
    expect(stores.maxColumns, ExcelExportService.totalColumnCount);
    expect(
      _rowText(stores.rows[1]),
      [
        ...ExcelExportService.productionHeaders,
        ...ExcelExportService.productionItems.map((item) => item.description),
      ],
    );
    expect(stores.rows[2][0]?.value.toString(), survey.storeNumber);
    expect(stores.rows[3][0]?.value.toString(), survey.storeNumber);
  });

  test('Zone Count export ignores zones without production tables', () {
    final sourceSurvey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final source = sourceSurvey.raw;
    final layout = source['gardenCenterLayout'] as Map<String, dynamic>;
    final zones = layout['zoneList'] as List<dynamic>;
    zones.add({
      'zoneId': 'empty-zone',
      'label': 'Empty Zone',
      'colorHex': '#999999',
    });
    final survey = SurveyDocument(source);
    final metrics = const ProductionMetricsCalculator().calculate(survey);

    final bytes = const ExcelExportService().buildSurveyWorkbook(
      survey: survey,
      metrics: metrics,
      objectPath: 'test/store-with-empty-zone.json',
    );
    final stores = Excel.decodeBytes(bytes).tables['Stores']!;
    final zoneCountColumn = ExcelExportService.productionHeaders.indexOf(
      'Zone Count',
    );
    final zoneCount = stores.rows[2][zoneCountColumn]?.value;

    expect(zones, hasLength(3));
    expect(metrics.zoneCount, 2);
    expect(zoneCount, isA<IntCellValue>());
    expect((zoneCount! as IntCellValue).value, 2);
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

    final itemColumn = ExcelExportService.productionHeaders.length;
    final itemNumberStyle = stores.rows[0][itemColumn]!.cellStyle!;
    expect(itemNumberStyle.isBold, isTrue);
    expect(itemNumberStyle.backgroundColor.colorHex, 'FFFFF2CC');
    _expectAllThinBorders(itemNumberStyle);

    final descriptionHeaderStyle = stores.rows[1][0]!.cellStyle!;
    expect(descriptionHeaderStyle.isBold, isTrue);
    expect(descriptionHeaderStyle.backgroundColor.colorHex, 'FFFFF2CC');
    _expectAllThinBorders(descriptionHeaderStyle);

    final bodyStyle = stores.rows[2][0]!.cellStyle!;
    _expectAllThinBorders(bodyStyle);

    for (
      var columnIndex = 0;
      columnIndex < ExcelExportService.totalColumnCount;
      columnIndex += 1
    ) {
      final headerLength = columnIndex <
              ExcelExportService.productionHeaders.length
          ? ExcelExportService.productionHeaders[columnIndex].runes.length
          : _longestItemHeadingLength(
              ExcelExportService.productionItems[
                columnIndex - ExcelExportService.productionHeaders.length
              ],
            );
      expect(
        stores.getColumnWidth(columnIndex),
        greaterThan(headerLength.toDouble()),
      );
    }

    expect(stores.getRowHeight(0), ExcelSheetFormatter.headerRowHeightPoints);
    expect(stores.getRowHeight(1), ExcelSheetFormatter.bodyRowHeightPoints);
    expect(stores.getRowHeight(2), ExcelSheetFormatter.bodyRowHeightPoints);
    expect(stores.getRowHeight(3), ExcelSheetFormatter.bodyRowHeightPoints);
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
    final maxHeight = stores.rows[2][maxHeightColumn]?.value;

    expect(maxHeight, isNot(isA<TextCellValue>()));
    expect(maxHeight.toString(), '0');
  });
}

List<String> _rowText(List<dynamic> row) {
  return row.map((cell) => cell?.value.toString() ?? '').toList();
}

int _longestItemHeadingLength(ProductionItemDefinition item) {
  final itemNumberLength = item.itemNumber.runes.length;
  final descriptionLength = item.description.runes.length;
  return itemNumberLength > descriptionLength
      ? itemNumberLength
      : descriptionLength;
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
