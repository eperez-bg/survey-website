import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/widgets/survey_map_painter.dart';

void main() {
  testWidgets('schema-9 representative map paints without an exception', (
    tester,
  ) async {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    const cellSize = 16.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CustomPaint(
            size: Size(
              survey.canvasColumns * cellSize,
              survey.canvasRows * cellSize,
            ),
            painter: SurveyMapPainter(
              survey: survey,
              cellSize: cellSize,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
