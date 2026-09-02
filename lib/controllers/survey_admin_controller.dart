// survey_admin_controller.dart
// State/actions for one store version: load, edit, validate, save version, calculate,
// and export. UI widgets remain thin.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/production_calculation.dart';
import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../services/excel_export_service.dart';
import '../services/file_download_service.dart';
import '../services/pdf_export_service.dart';
import '../services/production_calculation_service.dart';
import '../services/survey_storage_repository.dart';
import '../services/survey_validation_service.dart';

class SurveyAdminController extends ChangeNotifier {
  SurveyAdminController({
    required this.initialObjectPath,
    this.storeRecord,
    SurveyStorageRepository? repository,
    ProductionCalculationService? calculator,
    SurveyValidationService? validator,
    ExcelExportService? excel,
    PdfExportService? pdf,
    FileDownloadService? downloader,
  })  : _repository = repository ?? SurveyStorageRepository(),
        _calculator = calculator ?? const ProductionCalculationService(),
        _validator = validator ?? const SurveyValidationService(),
        _excel = excel ?? ExcelExportService(),
        _pdf = pdf ?? PdfExportService(),
        _downloader = downloader ?? const FileDownloadService();

  final String initialObjectPath;
  final StoreRecord? storeRecord;
  final SurveyStorageRepository _repository;
  final ProductionCalculationService _calculator;
  final SurveyValidationService _validator;
  final ExcelExportService _excel;
  final PdfExportService _pdf;
  final FileDownloadService _downloader;

  SurveyDocument? survey;
  List<String> versionPaths = [];
  bool isLoading = false;
  bool isSaving = false;
  bool dirty = false;
  String? error;
  String? message;

  ProductionCalculation? get calculation =>
      survey == null ? null : _calculator.calculate(survey!);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      survey = await _repository.loadSurvey(initialObjectPath);
      final folder = initialObjectPath.split('/')..removeLast();
      versionPaths = await _repository.listVersionPaths(folder.join('/'));
      dirty = false;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVersion(String path) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      survey = await _repository.loadSurvey(path);
      dirty = false;
      message = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void moveTable(String tableId, int topRow, int leftColumn) {
    final current = survey;
    if (current == null) return;
    current.moveTable(tableId, topRow, leftColumn);
    dirty = true;
    notifyListeners();
  }

  void assignTableZone(String tableId, String? zoneId) {
    survey?.assignTableZone(tableId, zoneId);
    dirty = true;
    notifyListeners();
  }

  void replaceRawJson(String text) {
    survey?.replaceRawFromJsonText(text);
    dirty = true;
    notifyListeners();
  }

  Future<void> saveAsNewVersion() async {
    final current = survey;
    if (current == null) return;

    final issues = _validator.validate(current);
    if (issues.isNotEmpty) {
      error = issues.join('\n');
      notifyListeners();
      return;
    }

    isSaving = true;
    error = null;
    message = null;
    notifyListeners();
    try {
      final path = await _repository.uploadNewVersion(current);
      final folder = path.split('/')..removeLast();
      versionPaths = await _repository.listVersionPaths(folder.join('/'));
      dirty = false;
      message = 'Saved new immutable version: $path';
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> exportExcel() async {
    final current = survey;
    if (current == null) return;
    final bytes = _excel.buildStoreWorkbook(current);
    await _downloader.saveBytes(
      fileName: 'store-${current.storeNumber}.xlsx',
      bytes: bytes,
    );
  }

  Future<void> exportPdf({Uint8List? mapPng}) async {
    final current = survey;
    if (current == null) return;
    final bytes = await _pdf.buildStoreMapPdf(current, mapPng: mapPng);
    await _downloader.saveBytes(
      fileName: 'store-${current.storeNumber}-map.pdf',
      bytes: bytes,
    );
  }
}
