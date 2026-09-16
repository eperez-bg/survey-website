import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/utils/production_metrics_calculator.dart';

void main() {
  test('calculates pair-level canopy and production counts', () {
    final result = const ProductionMetricsCalculator().calculate(
      SurveyDocument(_surveyJson()),
    );

    expect(result.singleTablesUnderCanopy, 1);
    expect(result.hangingBasketsUnderCanopy, 0);
    expect(result.specialTablesUnderCanopy, 1);
    expect(result.singleTablesOutsideCanopy, 0);
    expect(result.hangingBasketsOutsideCanopy, 2);
    expect(result.specialTablesOutsideCanopy, 1);
    expect(result.tableCountUnderCanopy, 1);
    expect(result.tableCountOutsideCanopy, 2);
    expect(result.tableCount, 3);
    expect(result.specialTableCount, 2);
    expect(result.tableGroupCount, 2);
    expect(result.spigotCount, 3);
    expect(result.averagePsi, 60);
    expect(result.rampCountAt46Inches, closeTo(1.5, 0.0001));
    expect(result.zoneCount, 2);
    expect(result.zonesUnderCanopy, 1);
    expect(result.maxCanopyHeightInches, 132);
  });

  test('counts each zone under canopy once across multiple tables', () {
    final json = _surveyJson();
    final layout = json['gardenCenterLayout']! as Map<String, dynamic>;
    layout['canopyCellList'] = [
      _canopyCell(row: 2, column: 2),
      _canopyCell(row: 4, column: 2),
      _canopyCell(row: 10, column: 2),
      _canopyCell(row: 19, column: 4),
    ];

    final result = const ProductionMetricsCalculator().calculate(
      SurveyDocument(json),
    );

    expect(result.zonesUnderCanopy, 2);
  });

  test('uses blank PSI and zero max height when no canopy is present', () {
    final json = _surveyJson();
    final layout = json['gardenCenterLayout']! as Map<String, dynamic>;
    layout['spigotList'] = <Map<String, dynamic>>[];
    layout['canopyCellList'] = <Map<String, dynamic>>[];

    final result = const ProductionMetricsCalculator().calculate(
      SurveyDocument(json),
    );

    expect(result.averagePsi, isNull);
    expect(result.maxCanopyHeightInches, 0);
    expect(result.tableCountUnderCanopy, 0);
    expect(result.tableCountOutsideCanopy, result.tableCount);
    expect(result.zonesUnderCanopy, 0);
  });
}

Map<String, dynamic> _canopyCell({required int row, required int column}) {
  return {
    'row': row,
    'column': column,
    'heightInches': 96.0,
    'lengthInches': 120.0,
    'widthInches': 120.0,
  };
}

Map<String, dynamic> _surveyJson() {
  return {
    'surveyId': 'production-metrics-test',
    'schemaVersion': 9,
    'storeInfo': {'storeNumber': '100', 'stateCode': 'IL', 'city': 'Chicago'},
    'surveyorInfo': <String, dynamic>{},
    'gardenCenterLayout': {
      'canvasRows': 30,
      'canvasColumns': 30,
      'roomBounds': {
        'topRow': 0,
        'leftColumn': 0,
        'widthCells': 30,
        'heightCells': 30,
      },
      'layoutTableList': [
        {
          'tableId': 'normal-a',
          'pairId': 'normal-pair',
          'zoneId': 'zone-1',
          'topRow': 2,
          'leftColumn': 2,
          'tableKind': 'normal',
          'orientation': 'horizontal',
        },
        {
          'tableId': 'normal-b',
          'pairId': 'normal-pair',
          'zoneId': 'zone-1',
          'topRow': 4,
          'leftColumn': 2,
          'tableKind': 'normal',
          'orientation': 'horizontal',
        },
        {
          'tableId': 'hanging-a',
          'pairId': 'hanging-pair',
          'zoneId': 'zone-2',
          'topRow': 10,
          'leftColumn': 2,
          'tableKind': 'hanging_basket',
          'orientation': 'vertical',
        },
        {
          'tableId': 'hanging-b',
          'pairId': 'hanging-pair',
          'zoneId': 'zone-2',
          'topRow': 10,
          'leftColumn': 4,
          'tableKind': 'hanging_basket',
          'orientation': 'vertical',
        },
        {
          'tableId': 'special-under',
          'topRow': 18,
          'leftColumn': 2,
          'tableKind': 'custom',
          'orientation': 'horizontal',
          'customName': 'Checkout',
        },
        {
          'tableId': 'special-outside',
          'topRow': 18,
          'leftColumn': 10,
          'tableKind': 'custom',
          'orientation': 'vertical',
          'customName': 'Display',
        },
      ],
      'zoneList': [
        {'zoneId': 'zone-1', 'label': 'Zone 1', 'colorHex': '#00AA00'},
        {'zoneId': 'zone-2', 'label': 'Zone 2', 'colorHex': '#0000AA'},
      ],
      'canopyCellList': [
        {
          // Only the second member overlaps, so the full normal pair is under.
          'row': 4,
          'column': 2,
          'heightInches': 96.0,
          'lengthInches': 120.0,
          'widthInches': 120.0,
        },
        {
          'row': 19,
          'column': 4,
          'heightInches': 132.0,
          'lengthInches': 120.0,
          'widthInches': 120.0,
        },
      ],
      'spigotList': [
        {'rowLine': 0, 'columnLine': 1, 'pressurePsi': 50.0},
        {'rowLine': 0, 'columnLine': 2, 'pressurePsi': 70.0},
        {'rowLine': 0, 'columnLine': 3, 'pressurePsi': null},
      ],
      'distanceList': [
        {
          'distanceId': 'distance-46',
          'measuredDistance': 46.0,
          'measurementUnit': 'inches',
          'start': {'type': 'wall', 'wallSide': 'left', 'offsetCells': 2},
          'end': {
            'type': 'table',
            'tableId': 'normal-a',
            'edgeSide': 'left',
            'offsetCells': 0,
          },
        },
        {
          'distanceId': 'distance-23',
          'measuredDistance': 23.0,
          'measurementUnit': 'inches',
          'start': {
            'type': 'table',
            'tableId': 'hanging-b',
            'edgeSide': 'right',
            'offsetCells': 0,
          },
          'end': {'type': 'wall', 'wallSide': 'right', 'offsetCells': 10},
        },
      ],
      'entranceList': <Map<String, dynamic>>[],
    },
  };
}
