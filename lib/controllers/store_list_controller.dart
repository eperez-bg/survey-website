// store_list_controller.dart
// State and user actions for store discovery, filtering, selection, and bulk export.

import 'package:flutter/foundation.dart';

import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../services/excel_export_service.dart';
import '../services/file_download_service.dart';
import '../services/pdf_export_service.dart';
import '../services/survey_storage_repository.dart';
import '../utils/app_config.dart';

class StoreListController extends ChangeNotifier {
  StoreListController({
    SurveyStorageRepository? repository,
    ExcelExportService? excel,
    PdfExportService? pdf,
    FileDownloadService? downloader,
  })  : _repository = repository ?? SurveyStorageRepository(),
        _excel = excel ?? ExcelExportService(),
        _pdf = pdf ?? PdfExportService(),
        _downloader = downloader ?? const FileDownloadService();

  final SurveyStorageRepository _repository;
  final ExcelExportService _excel;
  final PdfExportService _pdf;
  final FileDownloadService _downloader;

  List<StoreRecord> stores = [];
  final Set<String> selectedStoreNumbers = {};
  String searchText = '';
  String stateFilter = 'ALL';
  bool isLoading = false;
  String? error;

  List<String> get states {
    final values = stores
        .map((e) => e.state.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['ALL', ...values];
  }

  List<StoreRecord> get filteredStores {
    final search = searchText.trim().toLowerCase();
    return stores.where((store) {
      final matchesSearch = search.isEmpty ||
          store.storeNumber.toLowerCase().contains(search) ||
          store.city.toLowerCase().contains(search) ||
          store.locationSlug.toLowerCase().contains(search);
      final matchesState = stateFilter == 'ALL' || store.state == stateFilter;
      return matchesSearch && matchesState;
    }).toList();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      stores = await _repository.loadStoreIndex();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setSearch(String value) {
    searchText = value;
    notifyListeners();
  }

  void setState(String value) {
    stateFilter = value;
    notifyListeners();
  }

  void toggleSelection(StoreRecord store, bool selected) {
    if (selected) {
      selectedStoreNumbers.add(store.storeNumber);
    } else {
      selectedStoreNumbers.remove(store.storeNumber);
    }
    notifyListeners();
  }

  bool isSelected(StoreRecord store) =>
      selectedStoreNumbers.contains(store.storeNumber);

  Future<List<SurveyDocument>> _loadSelected({bool all = false}) async {
    final records = all
        ? stores
        : stores.where((s) => selectedStoreNumbers.contains(s.storeNumber)).toList();
    final surveys = <SurveyDocument>[];
    for (final record in records) {
      surveys.add(await _repository.loadSurvey(record.latestObjectPath));
    }
    return surveys;
  }

  Future<void> exportSelectedExcel({bool all = false}) async {
    final surveys = await _loadSelected(all: all);
    if (surveys.isEmpty) return;
    final bytes = _excel.buildStoreSummaryWorkbook(surveys);
    await _downloader.saveBytes(
      fileName: all ? 'all-stores.xlsx' : 'selected-stores.xlsx',
      bytes: bytes,
    );
  }

  Future<void> exportSelectedPdf() async {
    final surveys = await _loadSelected();
    if (surveys.isEmpty) return;
    final bytes = await _pdf.buildBulkSummaryPdf(surveys);
    await _downloader.saveBytes(fileName: 'selected-stores.pdf', bytes: bytes);
  }

  Future<SurveyDocument> loadSampleSurvey() =>
      _repository.loadSurvey(AppConfig.sampleObjectPath);
}
