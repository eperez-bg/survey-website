// survey_editor_screen.dart
// Store map viewer/editor with immutable version saves, production calculation,
// raw JSON fallback editing, and Excel/PDF exports.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controllers/survey_admin_controller.dart';
import '../models/store_record.dart';
import '../widgets/survey_map_canvas.dart';

class SurveyEditorScreen extends StatefulWidget {
  const SurveyEditorScreen({
    super.key,
    required this.objectPath,
    this.storeRecord,
  });

  final String objectPath;
  final StoreRecord? storeRecord;

  @override
  State<SurveyEditorScreen> createState() => _SurveyEditorScreenState();
}

class _SurveyEditorScreenState extends State<SurveyEditorScreen> {
  late final SurveyAdminController controller;
  final GlobalKey _mapCaptureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    controller = SurveyAdminController(
      initialObjectPath: widget.objectPath,
      storeRecord: widget.storeRecord,
    )..addListener(_changed);
    controller.load();
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final survey = controller.survey;
    return Scaffold(
      appBar: AppBar(
        title: Text(survey == null ? 'Store Map' : 'Store ${survey.storeNumber}'),
        actions: [
          if (controller.dirty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(child: Text('Unsaved changes')),
            ),
          IconButton(
            tooltip: 'Save as new Supabase version',
            onPressed: controller.isSaving ? null : controller.saveAsNewVersion,
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.survey == null) {
      return Center(child: SelectableText(controller.error!));
    }
    final survey = controller.survey;
    if (survey == null) return const Center(child: Text('No survey loaded.'));
    final calc = controller.calculation!;

    return Column(
      children: [
        if (controller.error != null)
          _banner(controller.error!, Colors.red.shade50),
        if (controller.message != null)
          _banner(controller.message!, Colors.green.shade50),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _versionAndExportBar(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: ClipRect(
                            child: RepaintBoundary(
                              key: _mapCaptureKey,
                              child: ColoredBox(
                                color: Colors.white,
                                child: SurveyMapCanvas(
                                  survey: survey,
                                  onMoveTable: controller.moveTable,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Production calculation',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Text('Irrigation systems: ${calc.irrigationSystems}'),
                              Text('Total ramp distance: ${calc.totalRampDistance.toStringAsFixed(2)}'),
                              Text('Ramps: ${calc.ramps.toStringAsFixed(2)}'),
                              const Divider(),
                              Text('Tables: ${survey.tables.length}'),
                              Text('Zones: ${survey.zones.length}'),
                              Text('Spigots: ${survey.spigots.length}'),
                              Text('Entrances: ${survey.entrances.length}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _editRawJson,
                        icon: const Icon(Icons.data_object),
                        label: const Text('Edit raw JSON'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'MVP map editing currently supports dragging tables. '
                        'The raw JSON editor preserves access to every existing field '
                        'until the exact mobile editor rules are ported.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _versionAndExportBar() {
    final survey = controller.survey!;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 410,
          child: DropdownButtonFormField<String>(
            initialValue: controller.versionPaths.contains(survey.objectPath)
                ? survey.objectPath
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Version',
              border: OutlineInputBorder(),
            ),
            items: controller.versionPaths
                .map((path) => DropdownMenuItem(
                      value: path,
                      child: Text(path.split('/').last,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (path) {
              if (path != null && path != survey.objectPath) {
                controller.loadVersion(path);
              }
            },
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: controller.exportExcel,
          icon: const Icon(Icons.table_view),
          label: const Text('Excel'),
        ),
        FilledButton.tonalIcon(
          onPressed: _exportMapPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Map PDF'),
        ),
        FilledButton.icon(
          onPressed: controller.isSaving ? null : controller.saveAsNewVersion,
          icon: const Icon(Icons.save),
          label: const Text('Save New Version'),
        ),
      ],
    );
  }

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.all(10),
        child: SelectableText(text),
      );

  Future<void> _editRawJson() async {
    final textController = TextEditingController(text: controller.survey!.toPrettyJson());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit raw survey JSON'),
        content: SizedBox(
          width: 850,
          height: 600,
          child: TextField(
            controller: textController,
            expands: true,
            maxLines: null,
            minLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                controller.replaceRawJson(textController.text);
                Navigator.pop(dialogContext, true);
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _exportMapPdf() async {
    Uint8List? png;
    try {
      final boundary =
          _mapCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        png = data?.buffer.asUint8List();
      }
    } catch (_) {
      // Export service still creates a useful PDF if capture fails.
    }
    await controller.exportPdf(mapPng: png);
  }
}
