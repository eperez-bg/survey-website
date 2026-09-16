import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/editor_result.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/widgets/survey_map_editor.dart';

void main() {
  testWidgets('mouse-wheel map zoom does not scroll the surrounding page', (
    tester,
  ) async {
    final pageController = ScrollController();
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );

    addTearDown(pageController.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: pageController,
            child: Column(
              children: [
                _TestMapEditor(survey: survey),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final transformationController = viewer.transformationController!;
    final scaleBefore = transformationController.value.getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(viewerFinder),
        scrollDelta: const Offset(0, 20),
      ),
    );
    await tester.pump();

    expect(
      transformationController.value.getMaxScaleOnAxis(),
      lessThan(scaleBefore),
    );
    expect(pageController.offset, 0);
  });
}

class _TestMapEditor extends StatelessWidget {
  final SurveyDocument survey;

  const _TestMapEditor({required this.survey});

  @override
  Widget build(BuildContext context) {
    return SurveyMapEditor(
      survey: survey,
      onTableMoved: (_, {required topRow, required leftColumn}) =>
          const EditorResult.success(),
      onTableZoneChanged: (_, _) => const EditorResult.success(),
      onDistanceMeasurementChanged: (_, _) => const EditorResult.success(),
      onSpigotPressureChanged: (_, _) => const EditorResult.success(),
      onEntranceChanged: (_) => const EditorResult.success(),
      onTableDeleted: (_) => const EditorResult.success(),
      onDistanceDeleted: (_) => const EditorResult.success(),
      onEntranceDeleted: (_) => const EditorResult.success(),
      onSpigotDeleted: (_) => const EditorResult.success(),
    );
  }
}
