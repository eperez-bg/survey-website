// store_detail_screen.dart
//
// Responsibility:
// Presents one immutable survey version plus browser edits, schema diagnostics,
// production summaries, exports, and the interactive map. Persistence and
// mutations remain controller responsibilities.

import 'package:flutter/material.dart';

import '../controllers/survey_admin_controller.dart';
import '../models/store_record.dart';
import '../widgets/production_summary_card.dart';
import '../widgets/raw_json_editor_dialog.dart';
import '../widgets/survey_map_editor.dart';

class StoreDetailScreen extends StatelessWidget {
  final SurveyAdminController controller;

  const StoreDetailScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final survey = controller.currentSurvey;
    final objectPath = controller.currentObjectPath;
    final metrics = controller.currentMetrics;

    if (survey == null || objectPath == null || metrics == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Choose a store from the list to view its map.'),
        ),
      );
    }

    final validationIssues = controller.validationService.validate(survey);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList.list(
            children: [
              _StoreHeader(controller: controller),
              const SizedBox(height: 12),
              ProductionSummaryCard(metrics: metrics),
              const SizedBox(height: 12),
              _EditStatusCard(
                hasUnsavedChanges: controller.hasUnsavedChanges,
                validationIssues: validationIssues,
              ),
              const SizedBox(height: 12),
              SurveyMapEditor(
                survey: survey,
                onTableMoved: controller.updateTablePosition,
                onTableZoneChanged: controller.updateTableZone,
                onDistanceMeasurementChanged:
                    controller.updateDistanceMeasurement,
                onSpigotPressureChanged: controller.updateSpigotPressure,
                onEntranceChanged: controller.updateEntrance,
                onTableDeleted: controller.deleteTable,
                onDistanceDeleted: controller.deleteDistance,
                onEntranceDeleted: controller.deleteEntrance,
                onSpigotDeleted: controller.deleteSpigot,
              ),
              const SizedBox(height: 14),
              _SurveyMetadataCard(
                controller: controller,
                objectPath: objectPath,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final SurveyAdminController controller;

  const _StoreHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final survey = controller.currentSurvey!;
    final store = controller.currentStore;
    final currentPath = controller.currentObjectPath!;
    final versions = store?.versions ??
        [StorageSurveyVersion(objectPath: currentPath)];
    final versionPaths = versions.map((version) => version.objectPath).toSet();
    final selectedPath = versionPaths.contains(currentPath)
        ? currentPath
        : versions.first.objectPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store ${survey.storeNumber}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  [survey.city, survey.stateCode]
                      .where((part) => part.trim().isNotEmpty)
                      .join(', '),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Chip(
              avatar: const Icon(Icons.schema_outlined, size: 17),
              label: Text('Schema ${survey.schemaVersion}'),
            ),
            SizedBox(
              width: 360,
              child: DropdownButtonFormField<String>(
                value: selectedPath,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Immutable survey version',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final version in versions)
                    DropdownMenuItem(
                      value: version.objectPath,
                      child: Text(
                        version.fileName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (path) {
                        if (path != null && path != currentPath) {
                          controller.openVersion(path);
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : controller.saveCurrentSurveyAsNewVersion,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Save new version'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy || !controller.hasUnsavedChanges
                  ? null
                  : controller.revertCurrentSurvey,
              icon: const Icon(Icons.undo),
              label: const Text('Revert browser edits'),
            ),
            OutlinedButton.icon(
              onPressed:
                  controller.isBusy ? null : controller.downloadCurrentPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Map PDF'),
            ),
            OutlinedButton.icon(
              onPressed:
                  controller.isBusy ? null : controller.downloadCurrentExcel,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Store Excel'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => RawJsonEditorDialog(
                          initialJson: survey.toJsonString(pretty: true),
                          onApply: controller.replaceCurrentSurveyFromJson,
                        ),
                      );
                    },
              icon: const Icon(Icons.data_object),
              label: const Text('Raw JSON'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditStatusCard extends StatelessWidget {
  final bool hasUnsavedChanges;
  final List<String> validationIssues;

  const _EditStatusCard({
    required this.hasUnsavedChanges,
    required this.validationIssues,
  });

  @override
  Widget build(BuildContext context) {
    final valid = validationIssues.isEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valid ? scheme.secondaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(valid ? Icons.verified_outlined : Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valid
                      ? 'Schema-9 save checks pass${hasUnsavedChanges ? ' • browser edits pending' : ''}'
                      : '${validationIssues.length} save issue${validationIssues.length == 1 ? '' : 's'}${hasUnsavedChanges ? ' • browser edits pending' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (!valid) ...[
                  const SizedBox(height: 5),
                  for (final issue in validationIssues.take(5)) Text('• $issue'),
                  if (validationIssues.length > 5)
                    Text('• ${validationIssues.length - 5} more'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyMetadataCard extends StatelessWidget {
  final SurveyAdminController controller;
  final String objectPath;

  const _SurveyMetadataCard({
    required this.controller,
    required this.objectPath,
  });

  @override
  Widget build(BuildContext context) {
    final survey = controller.currentSurvey!;
    final layout = survey.mapData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Survey metadata',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            SelectableText('Object: $objectPath'),
            const SizedBox(height: 5),
            Wrap(
              spacing: 24,
              runSpacing: 5,
              children: [
                Text('Survey ID: ${survey.surveyId}'),
                Text('Status: ${survey.status}'),
                Text('PIC: ${survey.picName.isEmpty ? '—' : survey.picName}'),
                Text('Surveyor: ${survey.surveyorName.isEmpty ? '—' : survey.surveyorName}'),
                Text('Canvas: ${layout.canvasColumns} × ${layout.canvasRows} cells'),
                Text(
                  'Room: ${layout.roomBounds.widthCells} × ${layout.roomBounds.heightCells} cells',
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('Notes: ${survey.notes.isEmpty ? '—' : survey.notes}'),
          ],
        ),
      ),
    );
  }
}
