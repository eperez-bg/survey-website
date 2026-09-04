// survey_admin_controller.dart
//
// Responsibility:
// Coordinates store indexing, current-survey editing, bulk selection, version
// history, calculations, and exports. Widgets report intent here instead of
// calling Supabase/export packages directly.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/editor_result.dart';
import '../models/production_calculation.dart';
import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../models/survey_map_model.dart';
import '../repositories/survey_storage_repository.dart';
import '../services/excel_export_service.dart';
import '../services/file_download_service.dart';
import '../services/pdf_export_service.dart';
import '../services/production_calculation_service.dart';
import '../services/survey_validation_service.dart';

class SurveyAdminController extends ChangeNotifier {
  final SurveyStorageRepository repository;
  final AppConfig config;
  final ProductionCalculationService calculationService;
  final SurveyValidationService validationService;
  final ExcelExportService excelExportService;
  final PdfExportService pdfExportService;
  final FileDownloadService fileDownloadService;

  SurveyAdminController({
    required this.repository,
    required this.config,
    this.calculationService = const ProductionCalculationService(),
    this.validationService = const SurveyValidationService(),
    this.excelExportService = const ExcelExportService(),
    this.pdfExportService = const PdfExportService(),
    this.fileDownloadService = const FileDownloadService(),
  });

  List<StoreRecord> _stores = const [];
  final Set<String> _selectedStoreKeys = <String>{};
  String _searchQuery = '';
  String? _stateFilter;
  bool _isBusy = false;
  String? _statusMessage;
  String? _errorMessage;

  StoreRecord? _currentStore;
  SurveyDocument? _currentSurvey;
  SurveyDocument? _savedSnapshot;
  String? _currentObjectPath;

  List<StoreRecord> get stores => List.unmodifiable(_stores);
  bool get isBusy => _isBusy;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get stateFilter => _stateFilter;
  StoreRecord? get currentStore => _currentStore;
  SurveyDocument? get currentSurvey => _currentSurvey;
  String? get currentObjectPath => _currentObjectPath;
  int get selectedStoreCount => _selectedStoreKeys.length;

  bool get hasUnsavedChanges {
    final survey = _currentSurvey;
    final snapshot = _savedSnapshot;
    if (survey == null || snapshot == null) {
      return false;
    }
    return survey.toJsonString() != snapshot.toJsonString();
  }

  ProductionCalculation? get currentCalculation {
    final survey = _currentSurvey;
    return survey == null ? null : calculationService.calculate(survey);
  }

  List<String> get availableStates {
    final states = _stores
        .map((store) => store.stateCode.trim())
        .where((state) => state.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return states;
  }

  List<StoreRecord> get filteredStores {
    final query = _searchQuery.trim().toLowerCase();
    return _stores.where((store) {
      final matchesState =
          _stateFilter == null || store.stateCode == _stateFilter;
      final matchesSearch = query.isEmpty ||
          store.storeNumber.toLowerCase().contains(query) ||
          store.city.toLowerCase().contains(query) ||
          store.stateCode.toLowerCase().contains(query);
      return matchesState && matchesSearch;
    }).toList(growable: false);
  }

  Future<void> initialize() async {
    await refreshStoreIndex(openSampleAfterRefresh: true);
  }

  Future<void> refreshStoreIndex({bool openSampleAfterRefresh = false}) async {
    await _runBusy('Loading stores from Supabase...', () async {
      final stores = await repository.loadStoreIndex();
      _stores = stores;
      _selectedStoreKeys.removeWhere(
        (key) => stores.every((store) => store.key != key),
      );

      if (openSampleAfterRefresh && _currentSurvey == null) {
        final sampleStore = _findStoreContainingPath(config.sampleObjectPath);
        if (sampleStore != null) {
          await _openStoreInternal(
            sampleStore,
            objectPath: config.sampleObjectPath,
          );
        } else {
          // The exact sample path is still useful during early testing even if
          // folder listing is restricted or the path naming changes.
          try {
            final sample = await repository.loadSurvey(config.sampleObjectPath);
            _currentSurvey = sample;
            _savedSnapshot = sample.clone();
            _currentObjectPath = config.sampleObjectPath;
          } catch (_) {
            // Keep the store list usable. The UI displays the index normally.
          }
        }
      } else if (_currentStore != null) {
        final refreshed = stores.where((store) => store.key == _currentStore!.key);
        if (refreshed.isNotEmpty) {
          _currentStore = refreshed.first;
        }
      }
    });
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setStateFilter(String? value) {
    _stateFilter = value;
    notifyListeners();
  }

  bool isStoreSelected(StoreRecord store) =>
      _selectedStoreKeys.contains(store.key);

  void setStoreSelected(StoreRecord store, bool selected) {
    if (selected) {
      _selectedStoreKeys.add(store.key);
    } else {
      _selectedStoreKeys.remove(store.key);
    }
    notifyListeners();
  }

  void selectAllFiltered(bool selected) {
    for (final store in filteredStores) {
      if (selected) {
        _selectedStoreKeys.add(store.key);
      } else {
        _selectedStoreKeys.remove(store.key);
      }
    }
    notifyListeners();
  }

  Future<void> openStore(StoreRecord store, {String? objectPath}) async {
    await _runBusy('Loading store ${store.storeNumber}...', () async {
      await _openStoreInternal(store, objectPath: objectPath);
    });
  }

  Future<void> openVersion(String objectPath) async {
    final store = _currentStore;
    if (store == null) {
      return;
    }
    await openStore(store, objectPath: objectPath);
  }

  EditorResult updateTablePosition(
    String tableId, {
    required int topRow,
    required int leftColumn,
  }) {
    return _applyEdit(
      _currentSurvey?.moveTableGroup(
            tableId,
            topRow: topRow,
            leftColumn: leftColumn,
          ) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult updateTableZone(String tableId, String? zoneId) {
    return _applyEdit(
      _currentSurvey?.setTableGroupZone(tableId, zoneId) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult updateDistanceMeasurement(String distanceId, double inches) {
    return _applyEdit(
      _currentSurvey?.setDistanceMeasurement(distanceId, inches) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult updateSpigotPressure(String spigotKey, double pressurePsi) {
    return _applyEdit(
      _currentSurvey?.setSpigotPressure(spigotKey, pressurePsi) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult updateEntrance(EntranceModel entrance) {
    return _applyEdit(
      _currentSurvey?.updateEntrance(entrance) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult deleteTable(String tableId) {
    return _applyEdit(
      _currentSurvey?.deleteTableGroup(tableId) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult deleteDistance(String distanceId) {
    return _applyEdit(
      _currentSurvey?.deleteDistance(distanceId) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult deleteEntrance(String entranceId) {
    return _applyEdit(
      _currentSurvey?.deleteEntrance(entranceId) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  EditorResult deleteSpigot(String spigotKey) {
    return _applyEdit(
      _currentSurvey?.deleteSpigot(spigotKey) ??
          const EditorResult.failure('No survey is open.'),
    );
  }

  void replaceCurrentSurveyFromJson(String source) {
    final parsed = SurveyDocument.fromJsonString(source);
    _currentSurvey = parsed;
    notifyListeners();
  }

  void revertCurrentSurvey() {
    final snapshot = _savedSnapshot;
    if (snapshot == null) {
      return;
    }
    _currentSurvey = snapshot.clone();
    _clearMessages();
    notifyListeners();
  }

  Future<void> saveCurrentSurveyAsNewVersion() async {
    final survey = _currentSurvey;
    final path = _currentObjectPath;
    if (survey == null || path == null) {
      return;
    }

    final validationErrors = validationService.validate(survey);
    if (validationErrors.isNotEmpty) {
      _errorMessage = validationErrors.join('\n');
      notifyListeners();
      return;
    }

    await _runBusy('Uploading a new survey version...', () async {
      final nextPath = await repository.saveNewVersion(
        survey: survey,
        currentObjectPath: path,
      );
      _currentObjectPath = nextPath;
      _savedSnapshot = survey.clone();
      _statusMessage = 'Saved new version: ${nextPath.split('/').last}';

      final stores = await repository.loadStoreIndex();
      _stores = stores;
      _currentStore = _findStoreContainingPath(nextPath) ?? _currentStore;
    });
  }

  Future<void> downloadCurrentExcel() async {
    final survey = _currentSurvey;
    final path = _currentObjectPath;
    if (survey == null || path == null) {
      return;
    }
    await _runBusy('Building store Excel...', () async {
      final bytes = excelExportService.buildSurveyWorkbook(
        survey: survey,
        calculation: calculationService.calculate(survey),
        objectPath: path,
      );
      await fileDownloadService.saveXlsx('store-${survey.storeNumber}', bytes);
    });
  }

  Future<void> downloadCurrentPdf() async {
    final survey = _currentSurvey;
    final path = _currentObjectPath;
    if (survey == null || path == null) {
      return;
    }
    await _runBusy('Rendering store PDF...', () async {
      final bytes = await pdfExportService.buildSurveyPdf(
        survey: survey,
        calculation: calculationService.calculate(survey),
        objectPath: path,
      );
      await fileDownloadService.savePdf('store-${survey.storeNumber}-map', bytes);
    });
  }

  Future<void> downloadSelectedExcel() async {
    final selected = _selectedStores();
    if (selected.isEmpty) {
      _setError('Select at least one store first.');
      return;
    }
    await _exportStoresExcel(selected, 'selected-stores');
  }

  Future<void> downloadAllExcel() async {
    if (_stores.isEmpty) {
      _setError('No stores are loaded.');
      return;
    }
    await _exportStoresExcel(_stores, 'all-stores');
  }

  Future<void> downloadSelectedPdf() async {
    final selected = _selectedStores();
    if (selected.isEmpty) {
      _setError('Select at least one store first.');
      return;
    }

    await _runBusy('Building selected-store PDF...', () async {
      final bundles = await _loadExportBundles(selected);
      final bytes = await pdfExportService.buildStoresPdf(bundles);
      await fileDownloadService.savePdf('selected-store-maps', bytes);
    });
  }

  void clearMessage() {
    _clearMessages();
    notifyListeners();
  }

  Future<void> _exportStoresExcel(
    List<StoreRecord> stores,
    String fileName,
  ) async {
    await _runBusy('Building $fileName Excel...', () async {
      final bundles = await _loadExportBundles(stores);
      final bytes = excelExportService.buildStoresWorkbook(bundles);
      await fileDownloadService.saveXlsx(fileName, bytes);
    });
  }

  Future<List<SurveyExportBundle>> _loadExportBundles(
    List<StoreRecord> stores,
  ) async {
    final bundles = <SurveyExportBundle>[];
    for (var index = 0; index < stores.length; index += 1) {
      final store = stores[index];
      _statusMessage =
          'Loading ${index + 1} of ${stores.length}: Store ${store.storeNumber}';
      notifyListeners();

      final path = store.latestVersion.objectPath;
      final survey = await repository.loadSurvey(path);
      bundles.add(
        SurveyExportBundle(
          objectPath: path,
          survey: survey,
          calculation: calculationService.calculate(survey),
        ),
      );
    }
    return bundles;
  }

  Future<void> _openStoreInternal(
    StoreRecord store, {
    String? objectPath,
  }) async {
    final path = objectPath ?? store.latestVersion.objectPath;
    final survey = await repository.loadSurvey(path);
    _currentStore = store;
    _currentSurvey = survey;
    _savedSnapshot = survey.clone();
    _currentObjectPath = path;
    _clearMessages();
  }

  StoreRecord? _findStoreContainingPath(String objectPath) {
    for (final store in _stores) {
      if (store.versions.any((version) => version.objectPath == objectPath)) {
        return store;
      }
    }
    return null;
  }

  List<StoreRecord> _selectedStores() {
    return _stores
        .where((store) => _selectedStoreKeys.contains(store.key))
        .toList(growable: false);
  }

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    _isBusy = true;
    _statusMessage = message;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = _humanizeError(error);
      _statusMessage = null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _statusMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _statusMessage = null;
  }

  EditorResult _applyEdit(EditorResult result) {
    if (result.succeeded) {
      _errorMessage = null;
      _statusMessage = result.message;
    } else {
      _errorMessage = result.message;
      _statusMessage = null;
    }
    notifyListeners();
    return result;
  }

  String _humanizeError(Object error) {
    if (error is FormatException) {
      return 'JSON error: ${error.message}';
    }
    if (error is JsonUnsupportedObjectError) {
      return 'JSON serialization error: $error';
    }
    return error.toString();
  }
}
