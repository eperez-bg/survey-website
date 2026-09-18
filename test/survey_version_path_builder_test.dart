import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/utils/survey_version_path_builder.dart';

void main() {
  test('builds a new timestamped filename in the source folder', () {
    final path = SurveyVersionPathBuilder.build(
      currentObjectPath: 'w-jefferson/2255/original.json',
      storeNumber: '2255',
      surveyId: 'survey-1',
      updatedAt: DateTime.parse('2026-09-18T14:25:30.123Z'),
    );

    expect(
      path,
      'w-jefferson/2255/2255-2026-09-18T14-25-30.123Z-survey-1.json',
    );
    expect(path, isNot('w-jefferson/2255/original.json'));
  });

  test('sanitizes filename parts and handles a bucket-root object', () {
    final path = SurveyVersionPathBuilder.build(
      currentObjectPath: 'original.json',
      storeNumber: ' 22/55 ',
      surveyId: '',
      updatedAt: DateTime.parse('2026-09-18T14:25:30Z'),
    );

    expect(path, '22-55-2026-09-18T14-25-30.000Z-edited.json');
  });

  test('cannot return the exact source object path', () {
    const existing =
        '2255-2026-09-18T14-25-30.000Z-survey-1.json';
    final path = SurveyVersionPathBuilder.build(
      currentObjectPath: existing,
      storeNumber: '2255',
      surveyId: 'survey-1',
      updatedAt: DateTime.parse('2026-09-18T14:25:30Z'),
    );

    expect(
      path,
      '2255-2026-09-18T14-25-30.000Z-survey-1-new.json',
    );
    expect(path, isNot(existing));
  });
}
