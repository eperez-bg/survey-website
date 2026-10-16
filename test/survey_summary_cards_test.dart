import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/widgets/survey_summary_cards.dart';

void main() {
  testWidgets('shows survey, store, and PIC details in readable cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final survey = SurveyDocument(_surveyJson());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SurveySummaryCard(survey: survey),
                StoreSummaryCard(survey: survey),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Survey Summary'), findsOneWidget);
    expect(find.text('October 16, 2026'), findsOneWidget);
    expect(find.text('2:05 PM'), findsOneWidget);
    expect(find.text('Alex Surveyor'), findsOneWidget);
    expect(find.text('Survey Operations'), findsOneWidget);

    expect(find.text('Store Summary'), findsOneWidget);
    expect(find.text('2255'), findsOneWidget);
    expect(find.text('West Jefferson'), findsOneWidget);
    expect(find.text('NC'), findsOneWidget);
    expect(find.text('123 Garden Center Way, 28202'), findsOneWidget);
    expect(find.text('Jordan Sample'), findsOneWidget);
    expect(find.text('jordan@example.com'), findsOneWidget);
    expect(find.text('(704) 555-0142'), findsOneWidget);
  });
}

Map<String, dynamic> _surveyJson() => {
      'surveyId': 'summary-card-test',
      'schemaVersion': 12,
      'status': 'completed',
      'completedAt': DateTime(2026, 10, 16, 14, 5).toIso8601String(),
      'storeInfo': {
        'storeNumber': '2255',
        'stateCode': 'NC',
        'city': 'West Jefferson',
        'shippingAddress': '123 Garden Center Way',
        'postalCode': '28202',
        'picName': 'Jordan Sample',
        'picEmail': 'jordan@example.com',
        'picPhone': '(704) 555-0142',
      },
      'surveyorInfo': {
        'surveyorName': 'Alex Surveyor',
        'surveyorCompany': 'Survey Operations',
      },
      'gardenCenterLayout': {
        'canvasRows': 12,
        'canvasColumns': 12,
        'roomBounds': {
          'topRow': 1,
          'leftColumn': 1,
          'widthCells': 10,
          'heightCells': 10,
        },
        'layoutTableList': <dynamic>[],
        'zoneList': <dynamic>[],
        'canopyCellList': <dynamic>[],
        'noInstallZoneCellList': <dynamic>[],
        'spigotList': <dynamic>[],
        'distanceList': <dynamic>[],
        'entranceList': <dynamic>[],
      },
    };
