import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

/// Transient table positions shown while a drag is above the map.
///
/// These tables are never serialized. They let the canvas draw the exact
/// snapped placement in green or red before the controller commits a change.
class TableDropPreview {
  final List<LayoutTable> tables;
  final bool canPlace;
  final String? message;

  TableDropPreview({
    required Iterable<LayoutTable> tables,
    required this.canPlace,
    this.message,
  }) : tables = List.unmodifiable(tables);

  factory TableDropPreview.valid(Iterable<LayoutTable> tables) {
    return TableDropPreview(tables: tables, canPlace: true);
  }

  factory TableDropPreview.invalid(
    Iterable<LayoutTable> tables,
    String message,
  ) {
    return TableDropPreview(tables: tables, canPlace: false, message: message);
  }
}
