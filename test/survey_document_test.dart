import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';

void main() {
  test('schema-9 edits preserve unknown JSON fields', () {
    final source = jsonDecode(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    source['futureField'] = {'keepMe': true};
    final survey = SurveyDocument(source);

    final result = survey.moveTableGroup(
      'custom-checkout',
      topRow: 9,
      leftColumn: 27,
    );

    expect(result.succeeded, isTrue);
    expect(survey.raw['futureField'], {'keepMe': true});
    expect(survey.mapData.tableById('custom-checkout')?.topRow, 9);
    expect(survey.mapData.tableById('custom-checkout')?.leftColumn, 27);
  });

  test('moving one paired table moves both physical members', () {
    final survey = SurveyDocument(_pairedSurvey());

    final result = survey.moveTableGroup(
      'table-a',
      topRow: 7,
      leftColumn: 8,
    );

    expect(result.succeeded, isTrue);
    expect(survey.mapData.tableById('table-a')?.topRow, 7);
    expect(survey.mapData.tableById('table-b')?.topRow, 9);
    expect(survey.mapData.tableById('table-b')?.leftColumn, 8);
  });

  test('tables connected to a distance cannot move', () {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );

    final result = survey.moveTableGroup(
      'normal-a',
      topRow: 9,
      leftColumn: 9,
    );

    expect(result.succeeded, isFalse);
    expect(result.message, contains('connected distances'));
    expect(survey.mapData.tableById('normal-a')?.topRow, 8);
  });

  test('legacy ramp data remains measurable when distanceList is empty', () {
    final source = _pairedSurvey();
    final layout = source['gardenCenterLayout'] as Map<String, dynamic>;
    layout['distanceList'] = <dynamic>[];
    layout['rampList'] = [
      {
        'rampId': 'legacy-1',
        'measuredGap': 10,
        'measurementUnit': 'feet',
        'start': {
          'type': 'wall',
          'wallSide': 'left',
          'offsetCells': 1,
        },
        'end': {
          'type': 'table',
          'tableId': 'table-a',
          'edgeSide': 'left',
          'offsetCells': 0,
        },
      },
    ];
    final survey = SurveyDocument(source);

    expect(survey.mapData.distances.single.measuredDistance, 120);
    expect(survey.setDistanceMeasurement('legacy-1', 84).succeeded, isTrue);
    final rawRamp = survey.rawDistances.single;
    expect(rawRamp['measuredGap'], 84);
    expect(rawRamp['measurementUnit'], 'inches');
  });
}

Map<String, dynamic> _pairedSurvey() => {
      'surveyId': 'paired-test',
      'schemaVersion': 9,
      'storeInfo': {'storeNumber': '2255', 'picName': 'Jordan'},
      'surveyorInfo': {
        'surveyorName': 'Alex',
        'surveyorCompany': 'Survey Operations',
      },
      'gardenCenterLayout': {
        'canvasRows': 24,
        'canvasColumns': 24,
        'roomBounds': {
          'topRow': 2,
          'leftColumn': 2,
          'widthCells': 20,
          'heightCells': 20,
        },
        'layoutTableList': [
          {
            'tableId': 'table-a',
            'pairId': 'pair-1',
            'zoneId': 'zone-1',
            'topRow': 4,
            'leftColumn': 5,
            'tableKind': 'normal',
            'orientation': 'horizontal',
          },
          {
            'tableId': 'table-b',
            'pairId': 'pair-1',
            'zoneId': 'zone-1',
            'topRow': 6,
            'leftColumn': 5,
            'tableKind': 'normal',
            'orientation': 'horizontal',
          },
        ],
        'zoneList': [
          {'zoneId': 'zone-1', 'label': 'Zone 1', 'colorHex': '#22C55E'},
        ],
        'canopyCellList': <dynamic>[],
        'spigotList': <dynamic>[],
        'distanceList': <dynamic>[],
        'entranceList': <dynamic>[],
      },
    };
