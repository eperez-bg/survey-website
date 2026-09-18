// map_edit_screen.dart
//
// Responsibility:
// Provides a dedicated, full-screen admin editing session around the survey
// app's map controller. It owns confirmation dialogs and navigation while the
// controller owns map state and SurveyAdminController owns Supabase I/O.

import 'package:flutter/material.dart';

import '../controllers/survey_admin_controller.dart';
import '../map_editor/controllers/map_editor_controller.dart';
import '../map_editor/models/map_editor_models.dart';
import '../map_editor/utils/grid_geometry.dart';
import '../map_editor/utils/layout_resize_geometry.dart';
import '../map_editor/widgets/canopy_height_dialog.dart';
import '../map_editor/widgets/custom_table_name_dialog.dart';
import '../map_editor/widgets/distance_measurement_dialog.dart';
import '../map_editor/widgets/entrance_properties_dialog.dart';
import '../map_editor/widgets/map_editor_canvas.dart';
import '../map_editor/widgets/map_editor_status_widgets.dart';
import '../map_editor/widgets/map_editor_toolbar.dart';
import '../map_editor/widgets/spigot_pressure_dialog.dart';

class MapEditScreen extends StatefulWidget {
  final SurveyAdminController adminController;
  final String objectPath;
  final String storeNumber;
  final String locationLabel;
  final GardenCenterLayout initialLayout;

  const MapEditScreen({
    super.key,
    required this.adminController,
    required this.objectPath,
    required this.storeNumber,
    required this.locationLabel,
    required this.initialLayout,
  });

  @override
  State<MapEditScreen> createState() => _MapEditScreenState();
}

class _MapEditScreenState extends State<MapEditScreen> {
  late final MapEditorController _controller;
  bool _isSaving = false;
  bool _uploadSucceeded = false;
  bool _isHandlingPop = false;
  String? _uploadedObjectPath;

  @override
  void initState() {
    super.initState();
    _controller = MapEditorController(initialLayout: widget.initialLayout);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadSucceeded) {
      return _buildSuccessScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelAndReturn();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'Cancel editing',
                onPressed: _isSaving ? null : _cancelAndReturn,
                icon: const Icon(Icons.close),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Store ${widget.storeNumber} Map'),
                  Text(
                    widget.locationLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  key: const ValueKey('admin-map-undo-button'),
                  tooltip: 'Undo last map change',
                  onPressed: !_isSaving && _controller.canUndo
                      ? _undoLastAction
                      : null,
                  icon: const Icon(Icons.undo),
                ),
                TextButton.icon(
                  key: const ValueKey('admin-map-revert-button'),
                  onPressed: !_isSaving && _controller.hasChanges
                      ? _revertChanges
                      : null,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Revert'),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _cancelAndReturn,
                  child: const Text('Cancel'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('save-new-survey-version-button'),
                    onPressed: !_isSaving && _controller.hasChanges
                        ? _saveAsNewVersion
                        : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save new version'),
                  ),
                ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    MapEditorSummary(controller: _controller),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: MapEditorCanvas(
                          controller: _controller,
                          onActionRejected: _showMessage,
                          onCustomTableNameRequested: _requestCustomTableName,
                          onDistanceDraftReady: _handleDistanceDraftReady,
                          onSpigotIntersectionRequested:
                              _handleSpigotIntersectionRequested,
                        ),
                      ),
                    ),
                    MapEditorInstructionBar(controller: _controller),
                    MapEditorToolbar(
                      controller: _controller,
                      onDuplicateSelectedTables: _duplicateSelectedTables,
                      onRenameSelectedCustomTables:
                          _renameSelectedCustomTables,
                      onDeleteSelectedTables: _removeSelectedTables,
                      onConfirmCanopy: _confirmCanopy,
                      onEditExistingCanopy: _editExistingCanopy,
                      onMoveSelectedDistance: _moveSelectedDistance,
                      onEditSelectedDistance: _editSelectedDistance,
                      onDeleteSelectedDistance: _deleteSelectedDistance,
                      onEditSelectedEntrance: _editSelectedEntrance,
                      onDeleteSelectedEntrance: _deleteSelectedEntrance,
                      onResizeLayout: _resizeLayout,
                    ),
                  ],
                ),
                if (_isSaving) const _SavingOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Store ${widget.storeNumber} survey uploaded'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF16A34A),
                    size: 88,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'New survey uploaded successfully',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A new Supabase Storage object was created with the '
                    'validated map changes. The previously uploaded survey '
                    'was not changed.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_uploadedObjectPath != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _uploadedObjectPath!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    key: const ValueKey('continue-after-map-save-button'),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _undoLastAction() {
    if (_controller.undoLastMapAction()) {
      _showMessage('Last map change undone.');
    }
  }

  Future<void> _revertChanges() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revert all map changes?'),
        content: const Text(
          'The map will return to the exact version that was loaded when this '
          'editor opened. The discarded changes cannot be restored with Undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revert changes'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    _controller.revertToInitialLayout();
    _showMessage('Map restored to the version loaded from Supabase.');
  }

  Future<void> _cancelAndReturn() async {
    if (_isHandlingPop || _isSaving || !mounted) {
      return;
    }
    _isHandlingPop = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel map editing?'),
        content: const Text(
          'All changes from this editing session will be discarded and the '
          'new survey version will not be uploaded. The existing Supabase '
          'survey will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard and return'),
          ),
        ],
      ),
    );
    _isHandlingPop = false;
    if (!mounted || confirmed != true) {
      return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _saveAsNewVersion() async {
    if (_isSaving) {
      return;
    }

    final validation = _controller.validateForCompletion();
    if (!validation.isValid) {
      await _showValidationIssues(validation.issues);
      return;
    }

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upload a new survey version?'),
        content: Text(
          'This will create a new JSON object in the same Supabase folder as\n\n'
          '${widget.objectPath}\n\n'
          'The new filename will use the store number, the new updatedAt '
          'timestamp, and the survey ID. The existing object above will remain '
          'unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Upload new survey'),
          ),
        ],
      ),
    );
    if (!mounted || shouldUpload != true) {
      return;
    }

    setState(() => _isSaving = true);
    final result =
        await widget.adminController.saveCurrentSurveyLayoutAsNewVersion(
      expectedSourceObjectPath: widget.objectPath,
      layout: _controller.layout,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _uploadSucceeded = result.succeeded;
      if (result.succeeded) {
        _uploadedObjectPath = widget.adminController.currentObjectPath;
      }
    });
    if (!result.succeeded) {
      await _showSaveFailure(
        result.message ?? 'The new survey upload failed.',
      );
    }
  }

  Future<void> _showValidationIssues(List<String> issues) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Map is not ready to save'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fix the following validity checks first:'),
                const SizedBox(height: 12),
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text('• $issue'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Return to editor'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveFailure(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upload failed'),
        icon: const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
        content: SelectableText(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Return to editor'),
          ),
        ],
      ),
    );
  }

  void _duplicateSelectedTables() {
    _reportResult(_controller.duplicateSelectedTables());
  }

  Future<String?> _requestCustomTableName() =>
      showCustomTableNameDialog(context);

  Future<void> _renameSelectedCustomTables() async {
    final count = _controller.selectedCustomTableCount;
    if (count == 0) {
      _showMessage('Select at least one custom table to rename.');
      return;
    }
    final name = await showCustomTableNameDialog(
      context,
      initialName: _controller.selectedCustomTableCommonName,
      tableCount: count,
      isRenaming: true,
    );
    if (!mounted || name == null) {
      return;
    }
    _reportResult(_controller.renameSelectedCustomTables(name));
  }

  void _removeSelectedTables() {
    _reportResult(_controller.removeSelectedTables());
  }

  Future<void> _confirmCanopy() async {
    if (_controller.isNoInstallZonePlacementEnabled ||
        _controller.shouldRemoveCanopyDraft) {
      _reportResult(_controller.confirmCanopyDraft());
      return;
    }

    final input = await showCanopyHeightDialog(context);
    if (!mounted || input == null) {
      return;
    }
    _reportResult(
      _controller.confirmCanopyDraft(
        heightInches: input.heightInches,
        lengthInches: input.lengthInches,
        widthInches: input.widthInches,
      ),
    );
  }

  Future<void> _editExistingCanopy() async {
    final source = _controller.canopyPreviewSourceCell;
    final height = source?.heightInches;
    final length = source?.lengthInches;
    final width = source?.widthInches;
    if (height == null || length == null || width == null) {
      _showMessage('The selected canopy does not have complete measurements.');
      return;
    }

    final input = await showCanopyHeightDialog(
      context,
      initialInput: CanopyHeightInput(
        heightInches: height,
        lengthInches: length,
        widthInches: width,
      ),
    );
    if (!mounted || input == null) {
      return;
    }
    _reportResult(
      _controller.confirmCanopyDraft(
        heightInches: input.heightInches,
        lengthInches: input.lengthInches,
        widthInches: input.widthInches,
        replaceExistingMeasurements: true,
      ),
    );
  }

  void _resizeLayout(
    LayoutResizeTarget target,
    LayoutResizeSide side,
    int deltaCells,
  ) {
    _reportResult(
      _controller.resizeLayout(
        target: target,
        side: side,
        deltaCells: deltaCells,
      ),
    );
  }

  Future<void> _handleSpigotIntersectionRequested(
    GridIntersection intersection,
  ) async {
    final existing = _controller.spigotAt(intersection);
    if (existing == null) {
      final validation = _controller.validateNewSpigotPlacement(intersection);
      if (!validation.succeeded) {
        _reportResult(validation);
        return;
      }
    }

    final input = await showSpigotPressureDialog(
      context,
      initialPressurePsi: existing?.pressurePsi,
      allowDelete: existing != null,
    );
    if (!mounted || input == null) {
      return;
    }

    switch (input.action) {
      case SpigotPressureAction.save:
        _reportResult(
          existing == null
              ? _controller.addSpigot(
                  intersection,
                  pressurePsi: input.pressurePsi!,
                )
              : _controller.updateSpigotPressureAt(
                  intersection,
                  pressurePsi: input.pressurePsi!,
                ),
        );
        break;
      case SpigotPressureAction.delete:
        _reportResult(_controller.removeSpigotAt(intersection));
        break;
    }
  }

  Future<void> _handleDistanceDraftReady() async {
    final input = await showDistanceMeasurementDialog(
      context,
      initialDistance: _controller.distanceBeingMoved,
    );
    if (!mounted) {
      return;
    }
    if (input == null) {
      _controller.cancelDistanceDraft();
      return;
    }
    _reportResult(
      _controller.completePendingDistance(
        measuredDistance: input.measuredDistance,
      ),
    );
  }

  void _moveSelectedDistance() {
    _reportResult(_controller.beginMovingSelectedDistance());
  }

  Future<void> _editSelectedDistance() async {
    final distance = _controller.selectedDistance;
    if (distance == null) {
      _showMessage('Select a distance to edit.');
      return;
    }
    final input = await showDistanceMeasurementDialog(
      context,
      initialDistance: distance,
    );
    if (!mounted || input == null) {
      return;
    }
    _reportResult(
      _controller.updateSelectedDistanceMeasurement(
        measuredDistance: input.measuredDistance,
      ),
    );
  }

  Future<void> _deleteSelectedDistance() async {
    if (_controller.selectedDistance == null) {
      _showMessage('Select a distance to delete.');
      return;
    }
    final confirmed = await _confirmDelete(
      title: 'Delete distance?',
      message: 'This removes the path and its saved measurement.',
    );
    if (confirmed) {
      _reportResult(_controller.removeSelectedDistance());
    }
  }

  Future<void> _editSelectedEntrance() async {
    final entrance = _controller.selectedEntrance;
    if (entrance == null) {
      _showMessage('Select an entrance to edit.');
      return;
    }
    final input = await showEntrancePropertiesDialog(
      context,
      entrance: entrance,
    );
    if (!mounted || input == null) {
      return;
    }
    _reportResult(
      _controller.updateSelectedEntrance(
        wallSide: input.wallSide,
        offsetCells: input.offsetCells,
        widthCells: input.widthCells,
        clearanceDepthCells: input.clearanceDepthCells,
      ),
    );
  }

  Future<void> _deleteSelectedEntrance() async {
    if (_controller.selectedEntrance == null) {
      _showMessage('Select an entrance to delete.');
      return;
    }
    final confirmed = await _confirmDelete(
      title: 'Delete entrance?',
      message: 'This removes the selected entrance from the room wall.',
    );
    if (confirmed) {
      _reportResult(_controller.removeSelectedEntrance());
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }

  void _reportResult(EditorActionResult result) {
    final message = result.message;
    if (message != null) {
      _showMessage(message);
    }
  }
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x660F172A),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Validating and uploading a new survey version...',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
