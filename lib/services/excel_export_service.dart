// excel_export_service.dart
// Builds single-store, selected-store, and all-store XLSX workbooks.

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

import '../models/survey_document.dart';
import 'production_calculation_service.dart';

class ExcelExportService {
  ExcelExportService({ProductionCalculationService? calculator})
    : _calculator = calculator ?? const ProductionCalculationService();

  final ProductionCalculationService _calculator;

  Uint8List buildStoreWorkbook(SurveyDocument survey) {
    final excel = Excel.createExcel();
    final overview = excel['Overview'];
    final calculation = _calculator.calculate(survey);

    overview.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
    _row(overview, 'Store Number', survey.storeNumber);
    _row(overview, 'City', survey.city);
    _row(overview, 'State', survey.state);
    _row(overview, 'Status', survey.status);
    _row(overview, 'Zones / Irrigation Systems', calculation.irrigationSystems);
    _row(overview, 'Total Ramp Distance', calculation.totalRampDistance);
    _row(overview, 'Ramp Count (temporary distance / 36)', calculation.ramps);
    _row(overview, 'Tables', survey.tables.length);
    _row(overview, 'Spigots', survey.spigots.length);
    _row(overview, 'Entrances', survey.entrances.length);

    final ramps = excel['Ramps'];
    ramps.appendRow([
      TextCellValue('Ramp ID'),
      TextCellValue('Measured Gap'),
      TextCellValue('Measurement Unit'),
    ]);
    for (final ramp in survey.ramps) {
      ramps.appendRow([
        TextCellValue((ramp['rampId'] ?? ramp['id'] ?? '').toString()),
        TextCellValue((ramp['measuredGap'] ?? '').toString()),
        TextCellValue((ramp['measurementUnit'] ?? '').toString()),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Failed to encode XLSX workbook.');
    return Uint8List.fromList(bytes);
  }

  Uint8List buildStoreSummaryWorkbook(List<SurveyDocument> surveys) {
    final excel = Excel.createExcel();
    final sheet = excel['Stores'];
    sheet.appendRow([
      TextCellValue('Store Number'),
      TextCellValue('City'),
      TextCellValue('State'),
      TextCellValue('Status'),
      TextCellValue('Irrigation Systems'),
      TextCellValue('Ramps'),
      TextCellValue('Ramp Distance'),
      TextCellValue('Tables'),
      TextCellValue('Spigots'),
    ]);

    for (final survey in surveys) {
      final calc = _calculator.calculate(survey);
      sheet.appendRow([
        TextCellValue(survey.storeNumber),
        TextCellValue(survey.city),
        TextCellValue(survey.state),
        TextCellValue(survey.status),
        IntCellValue(calc.irrigationSystems),
        DoubleCellValue(calc.ramps),
        DoubleCellValue(calc.totalRampDistance),
        IntCellValue(survey.tables.length),
        IntCellValue(survey.spigots.length),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Failed to encode XLSX workbook.');
    return Uint8List.fromList(bytes);
  }

  void _row(Sheet sheet, String label, Object value) {
    sheet.appendRow([TextCellValue(label), TextCellValue(value.toString())]);
  }
}
