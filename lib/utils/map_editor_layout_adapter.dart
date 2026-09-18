// map_editor_layout_adapter.dart
//
// Responsibility:
// Bridges the admin's lossless SurveyDocument wrapper and the survey app's
// typed GardenCenterLayout editor model. Root-level survey fields remain
// untouched while map JSON is parsed, edited, and written back.

import '../map_editor/models/map_editor_models.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart' as legacy;
import 'json_utils.dart';

class MapEditorLayoutAdapter {
  const MapEditorLayoutAdapter._();

  static GardenCenterLayout fromDocument(SurveyDocument document) {
    final layoutJson = deepCopyJsonMap(document.layout);
    final currentDistances = mapListValue(layoutJson['distanceList']);
    final legacyRamps = mapListValue(layoutJson['rampList']);
    if (currentDistances.isEmpty && legacyRamps.isNotEmpty) {
      layoutJson['distanceList'] = [
        for (final distance in document.mapData.distances)
          _currentDistanceJson(distance),
      ];
    }

    return GardenCenterLayout.fromJson(
      layoutJson,
    );
  }

  static SurveyDocument documentWithLayout({
    required SurveyDocument source,
    required GardenCenterLayout layout,
  }) {
    final updated = source.clone();
    updated.replaceGardenCenterLayout(layout.toJson());
    return updated;
  }

  /// Normalizes an early `rampList` entry into the schema-12 distance shape
  /// before handing it to the current field-app model. Saving then removes the
  /// obsolete ramp list instead of silently dropping its measurements.
  static Map<String, dynamic> _currentDistanceJson(
    legacy.DistanceModel distance,
  ) {
    return {
      'distanceId': distance.distanceId,
      'measuredDistance': distance.measuredDistance,
      'measurementUnit': 'inches',
      'start': _currentEndpointJson(distance.start),
      'end': _currentEndpointJson(distance.end),
    };
  }

  static Map<String, dynamic> _currentEndpointJson(
    legacy.DistanceEndpointModel endpoint,
  ) {
    if (endpoint is legacy.TableDistanceEndpointModel) {
      return {
        'type': 'table',
        'tableId': endpoint.tableId,
        'edgeSide': endpoint.edgeSide.name,
        'offsetCells': endpoint.offsetCells,
      };
    }
    if (endpoint is legacy.WallDistanceEndpointModel) {
      return {
        'type': 'wall',
        'wallSide': endpoint.wallSide.name,
        'offsetCells': endpoint.offsetCells,
      };
    }
    if (endpoint is legacy.CanopyDistanceEndpointModel) {
      return {
        'type': 'canopy',
        'row': endpoint.row,
        'column': endpoint.column,
        'edgeSide': endpoint.edgeSide.name,
      };
    }
    throw StateError('Unsupported legacy distance endpoint: $endpoint');
  }
}
