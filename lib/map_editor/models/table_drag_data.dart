import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

/// Temporary UI data carried while a table is being dragged.
///
/// Palette drags have no existing IDs. Existing-table drags carry every table
/// moving together plus the table used as the drag anchor.
class TableDragData {
  final TableKind tableKind;
  final TableOrientation orientation;

  /// Retained so older single-table callers continue to work.
  final String? existingTableId;
  final List<String> existingTableIds;
  final String? anchorTableId;

  const TableDragData({
    required this.tableKind,
    required this.orientation,
    this.existingTableId,
    this.existingTableIds = const [],
    this.anchorTableId,
  });

  List<String> get movingTableIds {
    if (existingTableIds.isNotEmpty) {
      return existingTableIds;
    }
    final legacyId = existingTableId;
    return legacyId == null ? const [] : [legacyId];
  }

  String? get effectiveAnchorTableId {
    if (anchorTableId != null) {
      return anchorTableId;
    }
    if (existingTableId != null) {
      return existingTableId;
    }
    return existingTableIds.length == 1 ? existingTableIds.single : null;
  }

  bool get isMovingExistingTable => movingTableIds.isNotEmpty;
}
