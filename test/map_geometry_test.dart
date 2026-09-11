import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/models/survey_map_model.dart';
import 'package:survey_admin_web/services/survey_validation_service.dart';
import 'package:survey_admin_web/utils/map_geometry.dart';

void main() {
  late SurveyDocument survey;

  setUp(() {
    survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
  });

  test('reconstructs exact occupied cells from current distance endpoints', () {
    final layout = survey.mapData;
    final leftDistance = layout.distances.first;
    final rightDistance = layout.distances.last;

    expect(
      MapGeometry.cellsForDistance(leftDistance, layout),
      [
        const GridCoordinate(row: 8, column: 5),
        const GridCoordinate(row: 8, column: 6),
        const GridCoordinate(row: 8, column: 7),
        const GridCoordinate(row: 8, column: 8),
      ],
    );
    expect(MapGeometry.cellsForDistance(rightDistance, layout).length, 13);
    expect(
      MapGeometry.cellsForDistance(rightDistance, layout).first,
      const GridCoordinate(row: 15, column: 22),
    );
    expect(
      MapGeometry.cellsForDistance(rightDistance, layout).last,
      const GridCoordinate(row: 15, column: 34),
    );
  });

  test('entrance clearance straddles the wall and blocks collisions', () {
    final layout = survey.mapData;
    final clearance = MapGeometry.entranceClearance(
      layout.entrances.single,
      layout.roomBounds,
    );

    expect(clearance.topRow, 22);
    expect(clearance.bottomRowExclusive, 30);
    expect(clearance.leftColumn, 15);
    expect(clearance.rightColumnExclusive, 21);
  });

  test('representative schema-9 survey passes upload validation', () {
    expect(const SurveyValidationService().validate(survey), isEmpty);
  });

  test('schema-11 canopy endpoint reconstructs its occupied distance cells', () {
    final schema11 = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v11.json').readAsStringSync(),
    );
    final layout = schema11.mapData;
    final distance = layout.distances.single;

    expect(schema11.hasSupportedSchema, isTrue);
    expect(layout.noInstallZoneCells.length, 2);
    expect(distance.start, isA<CanopyDistanceEndpointModel>());
    expect(
      MapGeometry.cellsForDistance(distance, layout),
      [
        const GridCoordinate(row: 5, column: 6),
        const GridCoordinate(row: 6, column: 6),
        const GridCoordinate(row: 7, column: 6),
        const GridCoordinate(row: 8, column: 6),
      ],
    );
    expect(const SurveyValidationService().validate(schema11), isEmpty);
  });

  test('schema 10 remains supported without a no-install list', () {
    final source = jsonDecode(
      File('assets/sample_survey_v11.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    source['schemaVersion'] = 10;
    final layoutJson = source['gardenCenterLayout'] as Map<String, dynamic>;
    layoutJson.remove('noInstallZoneCellList');
    final schema10 = SurveyDocument(source);

    expect(schema10.hasSupportedSchema, isTrue);
    expect(schema10.mapData.noInstallZoneCells, isEmpty);
    expect(const SurveyValidationService().validate(schema10), isEmpty);
  });

  test('a no-install cell blocks a distance strip', () {
    final source = jsonDecode(
      File('assets/sample_survey_v11.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final layoutJson = source['gardenCenterLayout'] as Map<String, dynamic>;
    layoutJson['noInstallZoneCellList'] = [
      {'row': 7, 'column': 6},
    ];
    final blocked = SurveyDocument(source);

    expect(
      MapGeometry.cellsForDistance(
        blocked.mapData.distances.single,
        blocked.mapData,
      ),
      isEmpty,
    );
    expect(
      const SurveyValidationService().validate(blocked),
      contains(contains('crosses a no-install zone')),
    );
  });
}
