// pdf_export_service.dart
// Builds PDF bytes. Single-map PDF can include a PNG captured from the map
// RepaintBoundary; bulk PDFs are lightweight store/production summaries for now.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/survey_document.dart';
import 'production_calculation_service.dart';

class PdfExportService {
  PdfExportService({ProductionCalculationService? calculator})
      : _calculator = calculator ?? const ProductionCalculationService();

  final ProductionCalculationService _calculator;

  Future<Uint8List> buildStoreMapPdf(
    SurveyDocument survey, {
    Uint8List? mapPng,
  }) async {
    final document = pw.Document();
    final calc = _calculator.calculate(survey);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        build: (_) => [
          pw.Text('Store ${survey.storeNumber}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('${survey.city}, ${survey.state}'),
          pw.SizedBox(height: 10),
          pw.Text(
              'Irrigation systems: ${calc.irrigationSystems}    Ramps: ${calc.ramps.toStringAsFixed(2)}'),
          pw.SizedBox(height: 12),
          if (mapPng != null)
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(mapPng),
                fit: pw.BoxFit.contain,
                height: 430,
              ),
            )
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Text(
                  'Map image not supplied. Open the store editor and use Export PDF to include the rendered map.'),
            ),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> buildBulkSummaryPdf(List<SurveyDocument> surveys) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        build: (_) => [
          pw.Text('Selected Survey Stores',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Store',
              'City',
              'State',
              'Irrigation Systems',
              'Ramps',
              'Tables',
            ],
            data: surveys.map((survey) {
              final calc = _calculator.calculate(survey);
              return [
                survey.storeNumber,
                survey.city,
                survey.state,
                calc.irrigationSystems.toString(),
                calc.ramps.toStringAsFixed(2),
                survey.tables.length.toString(),
              ];
            }).toList(),
          ),
        ],
      ),
    );
    return document.save();
  }
}
