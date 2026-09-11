// survey_document.dart
//
// Responsibility:
// Owns one uploaded survey JSON document. It preserves every unknown field,
// exposes supported schema 9-11 maps as typed read models, and performs safe raw
// mutations for admin edits.
//
// Why both raw and typed data:
// - Raw JSON preservation prevents a newer mobile field from being deleted.
// - Typed map data prevents rendering bugs caused by stale names or guesses.

import 'dart:convert';
import 'dart:typed_data';

import '../utils/json_utils.dart';
import '../utils/map_geometry.dart';
import '../utils/table_pair_rules.dart';
import 'editor_result.dart';
import 'survey_map_model.dart';

class SurveyDocument {
  static const int minimumSupportedSchemaVersion = 9;
  static const int currentSupportedSchemaVersion = 11;

  Map<String, dynamic> _raw;
  SurveyMapModel? _mapCache;

  SurveyDocument(Map<String, dynamic> raw) : _raw = deepCopyJsonMap(raw) {
    _validateRoot();
  }

  factory SurveyDocument.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Survey JSON root must be an object.');
    }
    return SurveyDocument(mapValue(decoded));
  }

  factory SurveyDocument.fromBytes(Uint8List bytes) {
    return SurveyDocument.fromJsonString(utf8.decode(bytes));
  }

  Map<String, dynamic> get raw => deepCopyJsonMap(_raw);
  Map<String, dynamic> get storeInfo => mapValue(_raw['storeInfo']);
  Map<String, dynamic> get surveyorInfo => mapValue(_raw['surveyorInfo']);
  Map<String, dynamic> get layout => mapValue(_raw['gardenCenterLayout']);

  SurveyMapModel get mapData => _mapCache ??= SurveyMapModel.fromJson(layout);

  int get schemaVersion => nullableInt(_raw['schemaVersion']) ?? 1;
  bool get hasSupportedSchema =>
      schemaVersion >= minimumSupportedSchemaVersion &&
      schemaVersion <= currentSupportedSchemaVersion;
  String get storeNumber => nullableString(storeInfo['storeNumber']) ?? 'Unknown';
  String get stateCode => nullableString(storeInfo['stateCode']) ?? '';
  String get city => nullableString(storeInfo['city']) ?? '';
  String get picName => nullableString(storeInfo['picName']) ??
      nullableString(storeInfo['PICName']) ??
      '';
  String get surveyorName =>
      nullableString(surveyorInfo['surveyorName']) ?? '';
  String get surveyorCompany =>
      nullableString(surveyorInfo['surveyorCompany']) ?? '';
  String get surveyId => nullableString(_raw['surveyId']) ?? '';
  String get status => nullableString(_raw['status']) ?? '';
  String get notes =>
      nullableString(_raw['notes']) ?? nullableString(_raw['Notes']) ?? '';
  DateTime? get visitDate => nullableDateTime(_raw['visitDate']);
  DateTime? get createdAt => nullableDateTime(_raw['createdAt']);
  DateTime? get updatedAt => nullableDateTime(_raw['updatedAt']);
  DateTime? get completedAt => nullableDateTime(_raw['completedAt']);

  int get canvasRows => mapData.canvasRows;
  int get canvasColumns => mapData.canvasColumns;
  int get roomTopRow => mapData.roomBounds.topRow;
  int get roomLeftColumn => mapData.roomBounds.leftColumn;
  int get roomWidthCells => mapData.roomBounds.widthCells;
  int get roomHeightCells => mapData.roomBounds.heightCells;

  List<Map<String, dynamic>> get rawTables =>
      mapListValue(layout['layoutTableList']);
  List<Map<String, dynamic>> get rawZones => mapListValue(layout['zoneList']);
  List<Map<String, dynamic>> get rawCanopyCells =>
      mapListValue(layout['canopyCellList']);
  List<Map<String, dynamic>> get rawNoInstallZoneCells =>
      mapListValue(layout['noInstallZoneCellList']);
  List<Map<String, dynamic>> get rawSpigots =>
      mapListValue(layout['spigotList']);
  List<Map<String, dynamic>> get rawDistances =>
      mapListValue(layout['distanceList']).isNotEmpty
          ? mapListValue(layout['distanceList'])
          : mapListValue(layout['rampList']);
  List<Map<String, dynamic>> get rawEntrances =>
      mapListValue(layout['entranceList']);

  SurveyDocument clone() => SurveyDocument(_raw);

  String toJsonString({bool pretty = false}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(_raw)
        : jsonEncode(_raw);
  }

  Uint8List toUtf8Bytes({bool pretty = true}) {
    return Uint8List.fromList(utf8.encode(toJsonString(pretty: pretty)));
  }

  void replaceRaw(Map<String, dynamic> raw) {
    final replacement = deepCopyJsonMap(raw);
    final previous = _raw;
    _raw = replacement;
    _mapCache = null;
    try {
      _validateRoot();
    } catch (_) {
      _raw = previous;
      _mapCache = null;
      rethrow;
    }
  }

  Map<String, dynamic>? rawTableById(String tableId) {
    for (final table in rawTables) {
      if (nullableString(table['tableId']) == tableId) {
        return table;
      }
    }
    return null;
  }

  EditorResult moveTableGroup(
    String anchorTableId, {
    required int topRow,
    required int leftColumn,
  }) {
    final current = mapData;
    final anchor = current.tableById(anchorTableId);
    if (anchor == null) {
      return const EditorResult.failure('The selected table no longer exists.');
    }
    final members = TablePairRules.membersForTable(current.tables, anchorTableId);
    final memberIds = {for (final table in members) table.tableId};
    if (current.distances.any(
      (distance) => memberIds.any(
        (id) => MapGeometry.distanceReferencesTable(distance, id),
      ),
    )) {
      return const EditorResult.failure(
        'Delete connected distances before moving these tables.',
      );
    }

    final rowDelta = topRow - anchor.topRow;
    final columnDelta = leftColumn - anchor.leftColumn;
    final candidates = [
      for (final table in members)
        table.translated(rowDelta: rowDelta, columnDelta: columnDelta),
    ];
    final error = MapGeometry.tableGroupPlacementError(
      candidates: candidates,
      layout: current,
      ignoredTableIds: memberIds,
    );
    if (error != null) {
      return EditorResult.failure(error);
    }

    for (final table in rawTables) {
      final id = nullableString(table['tableId']);
      if (id != null && memberIds.contains(id)) {
        table['topRow'] = (nullableInt(table['topRow']) ?? 0) + rowDelta;
        table['leftColumn'] =
            (nullableInt(table['leftColumn']) ?? 0) + columnDelta;
      }
    }
    _changed();
    return EditorResult.success(
      members.length == 2 ? 'Moved the complete table pair.' : 'Moved table.',
    );
  }

  EditorResult setTableGroupZone(String tableId, String? zoneId) {
    final current = mapData;
    final members = TablePairRules.membersForTable(current.tables, tableId);
    if (members.isEmpty) {
      return const EditorResult.failure('The selected table no longer exists.');
    }
    if (members.any((table) => table.tableKind == TableKind.custom)) {
      return const EditorResult.failure('Custom tables do not belong to zones.');
    }
    if (zoneId != null && current.zoneById(zoneId) == null) {
      return const EditorResult.failure('The selected zone no longer exists.');
    }

    final memberIds = {for (final table in members) table.tableId};
    if (zoneId != null) {
      final existingTargetTables = current.tables.where(
        (table) =>
            table.zoneId == zoneId &&
            table.tableKind != TableKind.custom &&
            !memberIds.contains(table.tableId),
      );
      final nextWeight =
          TablePairRules.weightedFixtureCount(existingTargetTables) +
              TablePairRules.weightedFixtureCount(members);
      if (nextWeight > TablePairRules.maxZoneWeightedTableCount) {
        return const EditorResult.failure(
          'That would exceed the 18-table weighted limit for this zone.',
        );
      }
    }

    for (final table in rawTables) {
      if (memberIds.contains(nullableString(table['tableId']))) {
        table['zoneId'] = zoneId;
      }
    }
    _changed();
    return const EditorResult.success('Zone assignment updated.');
  }

  EditorResult setDistanceMeasurement(String distanceId, double inches) {
    if (!inches.isFinite || inches <= 0) {
      return const EditorResult.failure(
        'Distance must be a number greater than zero.',
      );
    }
    final list = _editableDistanceList;
    if (list == null) {
      return const EditorResult.failure('The distance list is missing.');
    }
    for (final item in list) {
      if (item is! Map) continue;
      final map = mapValue(item);
      final id = nullableString(map['distanceId'] ?? map['rampId']);
      if (id == distanceId) {
        if (map.containsKey('distanceId')) {
          map['measuredDistance'] = inches;
        } else {
          map['measuredGap'] = inches;
        }
        map['measurementUnit'] = 'inches';
        _changed();
        return const EditorResult.success('Distance measurement updated.');
      }
    }
    return const EditorResult.failure('The selected distance no longer exists.');
  }

  EditorResult setSpigotPressure(String spigotKey, double pressurePsi) {
    if (!pressurePsi.isFinite || pressurePsi < 0) {
      return const EditorResult.failure('PSI must be a non-negative number.');
    }
    for (final spigot in rawSpigots) {
      final key =
          '${nullableInt(spigot['rowLine'])}:${nullableInt(spigot['columnLine'])}';
      if (key == spigotKey) {
        spigot['pressurePsi'] = pressurePsi;
        _changed();
        return const EditorResult.success('Spigot PSI updated.');
      }
    }
    return const EditorResult.failure('The selected spigot no longer exists.');
  }

  EditorResult updateEntrance(EntranceModel candidate) {
    final error = MapGeometry.entrancePlacementError(
      candidate: candidate,
      layout: mapData,
      ignoredEntranceId: candidate.entranceId,
    );
    if (error != null) {
      return EditorResult.failure(error);
    }
    for (final entrance in rawEntrances) {
      if (nullableString(entrance['entranceId']) == candidate.entranceId) {
        entrance['wallSide'] = candidate.wallSide.jsonValue;
        entrance['offsetCells'] = candidate.offsetCells;
        entrance['widthCells'] = candidate.widthCells;
        entrance['clearanceDepthCells'] = candidate.clearanceDepthCells;
        _changed();
        return const EditorResult.success('Entrance updated.');
      }
    }
    return const EditorResult.failure('The selected entrance no longer exists.');
  }

  EditorResult deleteTableGroup(String tableId) {
    final current = mapData;
    final members = TablePairRules.membersForTable(current.tables, tableId);
    final ids = {for (final table in members) table.tableId};
    if (ids.isEmpty) {
      return const EditorResult.failure('The selected table no longer exists.');
    }
    if (current.distances.any(
      (distance) => ids.any(
        (id) => MapGeometry.distanceReferencesTable(distance, id),
      ),
    )) {
      return const EditorResult.failure(
        'Delete connected distances before deleting these tables.',
      );
    }
    final list = layout['layoutTableList'];
    if (list is List) {
      list.removeWhere(
        (item) => ids.contains(nullableString(mapValue(item)['tableId'])),
      );
      _changed();
      return const EditorResult.success('Table fixture deleted.');
    }
    return const EditorResult.failure('The table list is missing.');
  }

  EditorResult deleteDistance(String distanceId) {
    final list = _editableDistanceList;
    if (list == null) {
      return const EditorResult.failure('The distance list is missing.');
    }
    final before = list.length;
    list.removeWhere((item) {
      final map = mapValue(item);
      return nullableString(map['distanceId'] ?? map['rampId']) == distanceId;
    });
    if (list.length == before) {
      return const EditorResult.failure('The selected distance no longer exists.');
    }
    _changed();
    return const EditorResult.success('Distance deleted.');
  }

  EditorResult deleteEntrance(String entranceId) {
    final list = layout['entranceList'];
    if (list is! List) {
      return const EditorResult.failure('The entrance list is missing.');
    }
    final before = list.length;
    list.removeWhere(
      (item) => nullableString(mapValue(item)['entranceId']) == entranceId,
    );
    if (list.length == before) {
      return const EditorResult.failure('The selected entrance no longer exists.');
    }
    _changed();
    return const EditorResult.success('Entrance deleted.');
  }

  EditorResult deleteSpigot(String spigotKey) {
    final list = layout['spigotList'];
    if (list is! List) {
      return const EditorResult.failure('The spigot list is missing.');
    }
    final before = list.length;
    list.removeWhere((item) {
      final spigot = mapValue(item);
      return '${nullableInt(spigot['rowLine'])}:${nullableInt(spigot['columnLine'])}' ==
          spigotKey;
    });
    if (list.length == before) {
      return const EditorResult.failure('The selected spigot no longer exists.');
    }
    _changed();
    return const EditorResult.success('Spigot deleted.');
  }

  void _validateRoot() {
    if (_raw['gardenCenterLayout'] is! Map) {
      throw const FormatException('gardenCenterLayout must be a JSON object.');
    }
    mapData;
  }

  /// A few early submissions contain an empty `distanceList` alongside the
  /// still-populated legacy `rampList`. Prefer current data when it contains
  /// records, otherwise keep those older surveys editable without migration.
  List<dynamic>? get _editableDistanceList {
    final current = layout['distanceList'];
    final legacy = layout['rampList'];
    if (current is List && (current.isNotEmpty || legacy is! List)) {
      return current;
    }
    return legacy is List ? legacy : current is List ? current : null;
  }

  void _changed() {
    _raw['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    _mapCache = null;
  }
}
