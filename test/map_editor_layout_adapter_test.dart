import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/utils/map_editor_layout_adapter.dart';

void main() {
  test('map edit writeback preserves non-map and unknown layout fields', () {
    final source = SurveyDocument({
      'surveyId': 'survey-1',
      'schemaVersion': 11,
      'status': 'completed',
      'updatedAt': '2026-09-01T00:00:00.000Z',
      'rootExtra': {'keep': true},
      'storeInfo': {
        'storeNumber': '100',
        'stateCode': 'IL',
        'city': 'Chicago',
      },
      'surveyorInfo': <String, dynamic>{},
      'gardenCenterLayout': {
        'canvasRows': 20,
        'canvasColumns': 20,
        'roomBounds': {
          'topRow': 2,
          'leftColumn': 2,
          'widthCells': 16,
          'heightCells': 16,
        },
        'layoutTableList': <dynamic>[],
        'zoneList': <dynamic>[],
        'canopyCellList': <dynamic>[],
        'noInstallZoneCellList': <dynamic>[],
        'spigotList': <dynamic>[],
        'distanceList': <dynamic>[],
        'entranceList': <dynamic>[],
        'editorMetadata': {'keep': 'this'},
      },
    });

    final layout = MapEditorLayoutAdapter.fromDocument(source);
    final updated = MapEditorLayoutAdapter.documentWithLayout(
      source: source,
      layout: layout.copyWith(canvasColumns: 24),
    );

    expect(source.schemaVersion, 11);
    expect(source.canvasColumns, 20);
    expect(updated.schemaVersion, 12);
    expect(updated.canvasColumns, 24);
    expect(source.updatedAt, DateTime.parse('2026-09-01T00:00:00.000Z'));
    expect(updated.updatedAt, isNotNull);
    expect(
      updated.updatedAt!.isAfter(
        DateTime.parse('2026-09-01T00:00:00.000Z'),
      ),
      isTrue,
    );
    expect(updated.raw['rootExtra'], {'keep': true});
    expect(updated.layout['editorMetadata'], {'keep': 'this'});
  });

  test('legacy ramp entries migrate to schema-12 distances without loss', () {
    final source = SurveyDocument({
      'surveyId': 'legacy-survey',
      'schemaVersion': 9,
      'storeInfo': {'storeNumber': '200'},
      'surveyorInfo': <String, dynamic>{},
      'gardenCenterLayout': {
        'canvasRows': 20,
        'canvasColumns': 20,
        'roomBounds': {
          'topRow': 2,
          'leftColumn': 2,
          'widthCells': 16,
          'heightCells': 16,
        },
        'layoutTableList': [
          {
            'tableId': 'table-1',
            'topRow': 5,
            'leftColumn': 5,
            'tableKind': 'normal',
            'orientation': 'horizontal',
          },
        ],
        'zoneList': <dynamic>[],
        'canopyCellList': <dynamic>[],
        'spigotList': <dynamic>[],
        'entranceList': <dynamic>[],
        'rampList': [
          {
            'rampId': 'legacy-ramp',
            'measuredGap': 4,
            'measurementUnit': 'feet',
            'start': {
              'type': 'table',
              'tableId': 'table-1',
              'edgeSide': 'left',
              'offsetCells': 0,
            },
            'end': {
              'type': 'wall',
              'wallSide': 'left',
              'offsetCells': 4,
            },
          },
        ],
      },
    });

    final layout = MapEditorLayoutAdapter.fromDocument(source);
    final updated = MapEditorLayoutAdapter.documentWithLayout(
      source: source,
      layout: layout,
    );

    expect(layout.distanceList.single.distanceId, 'legacy-ramp');
    expect(layout.distanceList.single.measuredDistance, 48);
    expect(updated.layout.containsKey('rampList'), isFalse);
    final distances = updated.layout['distanceList'] as List<dynamic>;
    expect(distances.single['distanceId'], 'legacy-ramp');
    expect(distances.single['measuredDistance'], 48);
    expect(distances.single['measurementUnit'], 'inches');
  });
}
