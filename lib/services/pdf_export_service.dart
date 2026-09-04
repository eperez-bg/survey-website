// pdf_export_service.dart
//
// Responsibility:
// Builds fixed-layout PDFs from the same survey map painter used by the website.
// One-store and selected-store exports share the same page builder.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/production_calculation.dart';
import '../models/survey_document.dart';
import 'map_image_service.dart';

class PdfExportService {
  final MapImageService mapImageService;

  const PdfExportService({this.mapImageService = const MapImageService()});

  Future<Uint8List> buildSurveyPdf({
    required SurveyDocument survey,
    required ProductionCalculation calculation,
    required String objectPath,
  }) async {
    return buildStoresPdf([
      SurveyExportBundle(
        objectPath: objectPath,
        survey: survey,
        calculation: calculation,
      ),
    ]);
  }

  Future<Uint8List> buildStoresPdf(List<SurveyExportBundle> bundles) async {
    final document = pw.Document();

    for (final bundle in bundles) {
      final survey = bundle.survey;
      final mapBytes = await mapImageService.renderPng(survey);
      final image = pw.MemoryImage(mapBytes);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Store ${survey.storeNumber} - ${survey.city}, ${survey.stateCode}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Survey ${survey.surveyId} | schema ${survey.schemaVersion} | ${bundle.objectPath}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    _metric('Irrigation systems', bundle.calculation.irrigationSystems),
                    _metric('Weighted tables', bundle.calculation.weightedTableCount),
                    _metric('Distances', bundle.calculation.distanceCount),
                    _metric('Distance inches', _number(bundle.calculation.totalDistanceInches)),
                    _metric('Spigots', bundle.calculation.spigotCount),
                    _metric('Entrances', bundle.calculation.entranceCount),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Container(
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return document.save();
  }

  pw.Widget _metric(String label, Object value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const pw.EdgeInsets.only(right: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
            pw.Text(
              value.toString(),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}
