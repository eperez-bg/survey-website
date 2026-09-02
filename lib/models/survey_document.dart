// survey_document.dart
// Compatibility wrapper around a survey JSON document. The complete raw map is
// retained and edited in-place so unmodeled fields survive round-trips.

import 'dart:convert';
import 'dart:typed_data';

import '../utils/json_helpers.dart';

class SurveyDocument {
  SurveyDocument({required this.raw, required this.objectPath});

  final Map<String, dynamic> raw;
  String objectPath;

  factory SurveyDocument.fromBytes(List<int> bytes, {required String objectPath}) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Survey JSON root must be an object.');
    }
    return SurveyDocument(raw: JsonHelpers.map(decoded), objectPath: objectPath);
  }

  Map<String, dynamic> get storeInfo => JsonHelpers.map(raw['storeInfo']);
  Map<String, dynamic> get surveyorInfo => JsonHelpers.map(raw['surveyorInfo']);
  Map<String, dynamic> get layout => JsonHelpers.map(raw['gardenCenterLayout']);

  String get surveyId => JsonHelpers.string(raw['surveyId'], 'survey');
  String get storeNumber => JsonHelpers.string(
        JsonHelpers.first(storeInfo, ['storeNumber', 'storeNo', 'number']),
        objectPath.split('/').length > 1
            ? objectPath.split('/')[objectPath.split('/').length - 2]
            : '',
      );
  String get state => JsonHelpers.string(storeInfo['state']);
  String get city => JsonHelpers.string(storeInfo['city']);
  String get status => JsonHelpers.string(raw['status']);

  int get canvasRows => JsonHelpers.integer(
        JsonHelpers.first(layout, ['canvasRows', 'rows']),
        30,
      );
  int get canvasColumns => JsonHelpers.integer(
        JsonHelpers.first(layout, ['canvasColumns', 'columns', 'cols']),
        30,
      );

  List<Map<String, dynamic>> get tables =>
      JsonHelpers.list(JsonHelpers.first(layout, ['layoutTableList', 'tables']))
          .map(JsonHelpers.map)
          .toList();

  List<Map<String, dynamic>> get zones =>
      JsonHelpers.list(JsonHelpers.first(layout, ['zoneList', 'zones']))
          .map(JsonHelpers.map)
          .toList();

  List<Map<String, dynamic>> get canopies =>
      JsonHelpers.list(JsonHelpers.first(layout, ['canopyCellList', 'canopies']))
          .map(JsonHelpers.map)
          .toList();

  List<Map<String, dynamic>> get spigots =>
      JsonHelpers.list(JsonHelpers.first(layout, ['spigotList', 'spigots']))
          .map(JsonHelpers.map)
          .toList();

  List<Map<String, dynamic>> get ramps =>
      JsonHelpers.list(JsonHelpers.first(layout, ['rampList', 'ramps']))
          .map(JsonHelpers.map)
          .toList();

  List<Map<String, dynamic>> get entrances =>
      JsonHelpers.list(JsonHelpers.first(layout, ['entranceList', 'entrances']))
          .map(JsonHelpers.map)
          .toList();

  Map<String, dynamic> get roomBounds =>
      JsonHelpers.map(JsonHelpers.first(layout, ['roomBounds', 'room']));

  Uint8List toPrettyJsonBytes() => Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(raw)),
    );

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(raw);

  void replaceRawFromJsonText(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Survey JSON root must be an object.');
    }
    raw
      ..clear()
      ..addAll(JsonHelpers.map(decoded));
  }

  void moveTable(String tableId, int topRow, int leftColumn) {
    for (final table in tables) {
      final id = JsonHelpers.string(
        JsonHelpers.first(table, ['tableId', 'id', 'layoutTableId']),
      );
      if (id == tableId) {
        table['topRow'] = topRow;
        table['leftColumn'] = leftColumn;
        return;
      }
    }
  }

  void assignTableZone(String tableId, String? zoneId) {
    for (final table in tables) {
      final id = JsonHelpers.string(
        JsonHelpers.first(table, ['tableId', 'id', 'layoutTableId']),
      );
      if (id == tableId) {
        table['zoneId'] = zoneId;
        return;
      }
    }
  }

  void setRampMeasurement(String rampId, double value) {
    for (final ramp in ramps) {
      final id = JsonHelpers.string(JsonHelpers.first(ramp, ['rampId', 'id']));
      if (id == rampId) {
        ramp['measuredGap'] = value;
        return;
      }
    }
  }
}
