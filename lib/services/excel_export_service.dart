// excel_export_service.dart
//
// Responsibility:
// Formats schema-9 survey data and already-derived production values as XLSX.
// It deliberately does not own geometry or manufacturing rules.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';

import '../models/production_calculation.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../utils/json_utils.dart';
import '../utils/map_geometry.dart';
import '../utils/table_pair_rules.dart';

class ExcelExportService {
  const ExcelExportService();

  Uint8List buildSurveyWorkbook({
    required SurveyDocument survey,
    required ProductionCalculation calculation,
    required String objectPath,
  }) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Summary');
    workbook.setDefaultSheet('Summary');
    final layout = survey.mapData;

    final summary = workbook['Summary'];
    _append(summary, ['Field', 'Value']);
    _append(summary, ['Store Number', survey.storeNumber]);
    _append(summary, ['City', survey.city]);
    _append(summary, ['State', survey.stateCode]);
    _append(summary, ['PIC', survey.picName]);
    _append(summary, ['Surveyor', survey.surveyorName]);
    _append(summary, ['Survey ID', survey.surveyId]);
    _append(summary, ['Schema Version', survey.schemaVersion]);
    _append(summary, ['Status', survey.status]);
    _append(summary, ['Visit Date', survey.visitDate?.toIso8601String()]);
    _append(summary, ['Object Path', objectPath]);
    _append(summary, ['Irrigation Systems', calculation.irrigationSystems]);
    _append(summary, [
      'Logical Table Fixtures',
      calculation.logicalTableFixtures,
    ]);
    _append(summary, ['Weighted Table Count', calculation.weightedTableCount]);
    _append(summary, ['Normal Table Count', calculation.normalTableCount]);
    _append(summary, ['Hanging Basket Count', calculation.hangingBasketCount]);
    _append(summary, ['Custom Table Count', calculation.customTableCount]);
    _append(summary, [
      'Physical Table Objects',
      calculation.physicalTableObjects,
    ]);
    _append(summary, ['Distance Count', calculation.distanceCount]);
    _append(summary, [
      'Total Distance (inches)',
      calculation.totalDistanceInches,
    ]);
    _append(summary, [
      'Three-foot Sections (temporary)',
      calculation.threeFootSections,
    ]);
    _append(summary, ['Spigots', calculation.spigotCount]);
    _append(summary, ['Entrances', calculation.entranceCount]);
    _append(summary, ['Canopy Areas', calculation.canopyAreaCount]);
    _append(summary, ['Canopy Cells', calculation.canopyCellCount]);

    final tables = workbook['Tables'];
    _append(tables, [
      'tableId',
      'pairId',
      'zoneId',
      'topRow',
      'leftColumn',
      'tableKind',
      'orientation',
      'customName',
      'widthCells',
      'heightCells',
    ]);
    for (final table in layout.tables) {
      _append(tables, [
        table.tableId,
        table.pairId,
        table.zoneId,
        table.topRow,
        table.leftColumn,
        table.tableKind.jsonValue,
        table.orientation.jsonValue,
        table.customName,
        table.widthCells,
        table.heightCells,
      ]);
    }

    final zones = workbook['Zones'];
    _append(zones, ['zoneId', 'label', 'colorHex', 'weightedTableCount']);
    for (final zone in layout.zones) {
      _append(zones, [
        zone.zoneId,
        zone.label,
        zone.colorHex,
        TablePairRules.weightedCountForZone(layout.tables, zone.zoneId),
      ]);
    }

    final distances = workbook['Distances'];
    _append(distances, [
      'distanceId',
      'measuredDistance',
      'measurementUnit',
      'mappedCellCount',
      'startType',
      'startReference',
      'endType',
      'endReference',
    ]);
    for (final distance in layout.distances) {
      _append(distances, [
        distance.distanceId,
        distance.measuredDistance,
        'inches',
        MapGeometry.cellsForDistance(distance, layout).length,
        _endpointType(distance.start),
        _endpointReference(distance.start),
        _endpointType(distance.end),
        _endpointReference(distance.end),
      ]);
    }

    final canopies = workbook['Canopy Cells'];
    _append(canopies, [
      'row',
      'column',
      'heightInches',
      'lengthInches',
      'widthInches',
    ]);
    for (final canopy in layout.canopyCells) {
      _append(canopies, [
        canopy.row,
        canopy.column,
        canopy.heightInches,
        canopy.lengthInches,
        canopy.widthInches,
      ]);
    }

    final spigots = workbook['Spigots'];
    _append(spigots, ['rowLine', 'columnLine', 'pressurePsi']);
    for (final spigot in layout.spigots) {
      _append(spigots, [spigot.rowLine, spigot.columnLine, spigot.pressurePsi]);
    }

    final entrances = workbook['Entrances'];
    _append(entrances, [
      'entranceId',
      'wallSide',
      'offsetCells',
      'widthCells',
      'clearanceDepthCells',
    ]);
    for (final entrance in layout.entrances) {
      _append(entrances, [
        entrance.entranceId,
        entrance.wallSide.jsonValue,
        entrance.offsetCells,
        entrance.widthCells,
        entrance.clearanceDepthCells,
      ]);
    }

    final raw = workbook['Raw JSON'];
    _append(raw, ['JSON Path', 'Value']);
    for (final entry in flattenJson(survey.raw).entries) {
      _append(raw, [entry.key, entry.value]);
    }

    return _encode(workbook);
  }

  /// Consolidates selected stores into one download instead of opening many
  /// browser downloads. Each store still gets its own compact detail sheet.
  Uint8List buildStoresWorkbook(List<SurveyExportBundle> bundles) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Stores');
    workbook.setDefaultSheet('Stores');
    final stores = workbook['Stores'];

    _append(stores, [
      'Store Number',
      'City',
      'State',
      'Survey ID',
      'Schema',
      'Object Path',
      'Irrigation Systems',
      'Logical Fixtures',
      'Weighted Tables',
      'Normal Tables',
      'Hanging Baskets',
      'Custom Tables',
      'Distances',
      'Total Distance (in)',
      'Three-foot Sections',
      'Spigots',
      'Entrances',
      'Canopy Areas',
    ]);

    for (var index = 0; index < bundles.length; index += 1) {
      final bundle = bundles[index];
      final survey = bundle.survey;
      final calculation = bundle.calculation;
      _append(stores, [
        survey.storeNumber,
        survey.city,
        survey.stateCode,
        survey.surveyId,
        survey.schemaVersion,
        bundle.objectPath,
        calculation.irrigationSystems,
        calculation.logicalTableFixtures,
        calculation.weightedTableCount,
        calculation.normalTableCount,
        calculation.hangingBasketCount,
        calculation.customTableCount,
        calculation.distanceCount,
        calculation.totalDistanceInches,
        calculation.threeFootSections,
        calculation.spigotCount,
        calculation.entranceCount,
        calculation.canopyAreaCount,
      ]);

      final detail = workbook[_safeSheetName(survey.storeNumber, index)];
      _append(detail, ['Field', 'Value']);
      _append(detail, ['Store Number', survey.storeNumber]);
      _append(detail, ['Location', '${survey.city}, ${survey.stateCode}']);
      _append(detail, ['Survey ID', survey.surveyId]);
      _append(detail, ['Object Path', bundle.objectPath]);
      for (final entry in calculation.toJson().entries) {
        _append(detail, [entry.key, entry.value]);
      }
    }
    return _encode(workbook);
  }

  String _endpointType(DistanceEndpointModel endpoint) =>
      endpoint is TableDistanceEndpointModel ? 'table' : 'wall';

  String _endpointReference(DistanceEndpointModel endpoint) {
    if (endpoint is TableDistanceEndpointModel) {
      return '${endpoint.tableId}:${endpoint.edgeSide.jsonValue}:${endpoint.offsetCells}';
    }
    final wall = endpoint as WallDistanceEndpointModel;
    return '${wall.wallSide.jsonValue}:${wall.offsetCells}';
  }

  void _append(Sheet sheet, List<Object?> values) {
    sheet.appendRow(
      values.map((value) => TextCellValue(_display(value))).toList(),
    );
  }

  String _display(Object? value) {
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    if (value is double) {
      return value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  String _safeSheetName(String storeNumber, int index) {
    final clean = storeNumber.replaceAll(RegExp(r'[\\/*?:\[\]]'), '-');
    final candidate = 'Store-$clean-$index';
    return candidate.length <= 31 ? candidate : candidate.substring(0, 31);
  }

  Uint8List _encode(Excel workbook) {
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Excel package returned no encoded workbook bytes.');
    }
    return Uint8List.fromList(bytes);
  }
}
