// survey_admin_controller.dart
//
// Responsibility:
// Coordinates store indexing, current-survey editing, bulk selection, version
// history, calculations, and exports. Widgets report intent here instead of
// calling Supabase/export packages directly.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../map_editor/models/map_editor_models.dart';
import '../models/editor_result.dart';
import '../models/production_metrics.dart';
import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../models/survey_export_bundle.dart';
import '../models/survey_map_model.dart';
import '../models/survey_version_metadata.dart';
import '../repositories/survey_metadata_repository.dart';
import '../repositories/survey_storage_repository.dart';
import '../services/excel_export_service.dart';
import '../services/file_download_service.dart';
import '../services/pdf_export_service.dart';
import '../services/survey_index_sync_service.dart';
import '../services/survey_validation_service.dart';
import '../utils/production_metrics_calculator.dart';
import '../utils/map_editor_layout_adapter.dart';

class SurveyAdminController extends ChangeNotifier {
  static const String _temporaryDeletePassword = 'a74rFnb';

  final SurveyStorageDataSource storageRepository;
  final SurveyMetadataDataSource metadataRepository;
  final SurveyIndexSyncService indexSyncService;
  final ProductionMetricsCalculator metricsCalculator;
  final SurveyValidationService validationService;
  final ExcelExportService excelExportService;
  final PdfExportService pdfExportService;
  final FileDownloadService fileDownloadService;

  SurveyAdminController({
    required SurveyStorageDataSource storageRepository,
    required SurveyMetadataDataSource metadataRepository,
    SurveyIndexSyncService? indexSyncService,
    this.metricsCalculator = const ProductionMetricsCalculator(),
    this.validationService = const SurveyValidationService(),
    this.excelExportService = const ExcelExportService(),
    this.pdfExportService = const PdfExportService(),
    this.fileDownloadService = const FileDownloadService(),
  }) : storageRepository = storageRepository,
       metadataRepository = metadataRepository,
       indexSyncService = indexSyncService ??
           SurveyIndexSyncService(
             storageRepository: storageRepository,
             metadataRepository: metadataRepository,
           );

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

  ProductionMetrics? get currentMetrics {
    final survey = _currentSurvey;
    return survey == null ? null : metricsCalculator.calculate(survey);
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
    await refreshStoreIndex();
    if (_stores.isEmpty && _errorMessage == null) {
      await synchronizeSurveyIndex();
    }
  }

  Future<void> refreshStoreIndex() async {
    await _runBusy('Loading the survey metadata index...', () async {
      final stores = await metadataRepository.loadStoreIndex();
      _replaceStoreIndex(stores);

      final current = _currentStore;
      if (current != null) {
        final refreshed = stores.where((store) => store.key == current.key);
        if (refreshed.isNotEmpty) {
          _currentStore = await _storeWithCompleteHistory(refreshed.first);
        }
      }
      _statusMessage = 'Loaded ${stores.length} store'
          '${stores.length == 1 ? '' : 's'} from the metadata index.';
    });
  }

  /// Reconciles Storage with Postgres without making recursive bucket listing
  /// part of normal startup. It runs automatically only when the new index is
  /// empty and remains available for uploads made by older mobile app builds.
  Future<void> synchronizeSurveyIndex() async {
    await _runBusy('Synchronizing the survey metadata index...', () async {
      final result = await indexSyncService.synchronize(
        onProgress: (progress) {
          _statusMessage = progress.message;
          notifyListeners();
        },
      );

      final stores = await metadataRepository.loadStoreIndex();
      _replaceStoreIndex(stores);

      final current = _currentStore;
      if (current != null) {
        final refreshed = stores.where((store) => store.key == current.key);
        if (refreshed.isNotEmpty) {
          _currentStore = await _storeWithCompleteHistory(refreshed.first);
        }
      }

      if (result.failureCount == 0) {
        _statusMessage = result.newlyIndexedCount == 0
            ? 'Survey metadata index is already synchronized.'
            : 'Indexed ${result.newlyIndexedCount} survey version'
                '${result.newlyIndexedCount == 1 ? '' : 's'} successfully.';
      } else {
        _errorMessage = 'Indexed ${result.newlyIndexedCount} survey versions, '
            'but ${result.failureCount} object'
            '${result.failureCount == 1 ? '' : 's'} could not be indexed. '
            'Run the sync again or inspect the affected JSON files.';
        _statusMessage = null;
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

  /// The temporary password is an accidental-click guard in the web client,
  /// not real authorization. Supabase RLS remains the actual access boundary.
  bool isDeletePasswordValid(String value) =>
      value == _temporaryDeletePassword;

  /// Permanently deletes the selected JSON version and its matching metadata.
  /// The latest remaining version is opened automatically. Because
  /// `survey_store_index` is a view, no replacement row is written manually.
  Future<EditorResult> deleteCurrentSurvey({
    required String password,
  }) async {
    if (!isDeletePasswordValid(password)) {
      const result = EditorResult.failure('Incorrect delete password.');
      _setError(result.message!);
      return result;
    }

    final store = _currentStore;
    final objectPath = _currentObjectPath;
    if (store == null || objectPath == null) {
      const result = EditorResult.failure('No survey is open.');
      _setError(result.message!);
      return result;
    }

    final storeNumber = store.storeNumber;
    final fileName = objectPath.split('/').last;
    _startBusy('Deleting $fileName permanently...');

    try {
      await _deleteVersionFromStorageAndIndex(objectPath);
      final replacementOpened = await _reloadAfterDeletion(storeNumber);
      final message = replacementOpened
          ? 'Deleted $fileName. The newest remaining Store $storeNumber '
              'survey is now selected.'
          : 'Deleted $fileName. Store $storeNumber had no remaining surveys '
              'and was removed from the index.';
      _statusMessage = message;
      return EditorResult.success(message);
    } catch (error) {
      final message = 'Survey deletion did not fully complete. It is safe to '
          'retry the same deletion. ${_humanizeError(error)}';
      _errorMessage = message;
      _statusMessage = null;
      return EditorResult.failure(message);
    } finally {
      _finishBusy();
    }
  }

  /// Permanently deletes every known version for the current store. Version
  /// pairs are removed Storage-first and metadata-second so a Storage failure
  /// cannot hide a JSON object that still exists.
  Future<EditorResult> deleteCurrentStore({
    required String password,
  }) async {
    if (!isDeletePasswordValid(password)) {
      const result = EditorResult.failure('Incorrect delete password.');
      _setError(result.message!);
      return result;
    }

    final store = _currentStore;
    if (store == null) {
      const result = EditorResult.failure('No store is open.');
      _setError(result.message!);
      return result;
    }

    final storeNumber = store.storeNumber;
    _startBusy('Loading all Store $storeNumber survey versions...');

    try {
      final indexedVersions = await metadataRepository.loadVersionsForStore(
        storeNumber,
      );
      final paths = <String>{
        for (final version in indexedVersions) version.objectPath,
        // Include a just-uploaded local version whose metadata registration may
        // still be pending.
        for (final version in store.versions) version.objectPath,
      }.toList(growable: false);

      if (paths.isEmpty) {
        throw StateError('No survey versions were found for Store $storeNumber.');
      }

      for (var index = 0; index < paths.length; index += 1) {
        _statusMessage = 'Deleting Store $storeNumber survey '
            '${index + 1} of ${paths.length}...';
        notifyListeners();
        await _deleteVersionFromStorageAndIndex(paths[index]);
      }

      final stores = await metadataRepository.loadStoreIndex();
      _replaceStoreIndex(stores);
      _clearCurrentSelection();
      _selectedStoreKeys.remove(storeNumber);

      final message = 'Deleted Store $storeNumber and all ${paths.length} '
          'survey version${paths.length == 1 ? '' : 's'}.';
      _statusMessage = message;
      return EditorResult.success(message);
    } catch (error) {
      final message = 'Store deletion did not fully complete. Completed '
          'versions stay deleted; it is safe to retry Delete Store to finish '
          'the remainder. ${_humanizeError(error)}';
      _errorMessage = message;
      _statusMessage = null;
      return EditorResult.failure(message);
    } finally {
      _finishBusy();
    }
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

  /// Validates the editor layout and uploads it as a new immutable object.
  ///
  /// The editor works on an isolated immutable layout. Nothing is applied to
  /// dashboard state until validation and the Storage upload both succeed.
  Future<EditorResult> saveCurrentSurveyLayoutAsNewVersion({
    required String expectedSourceObjectPath,
    required GardenCenterLayout layout,
  }) async {
    final current = _currentSurvey;
    final currentPath = _currentObjectPath;
    if (current == null || currentPath == null) {
      const result = EditorResult.failure('No survey is open.');
      _setError(result.message!);
      return result;
    }
    if (currentPath != expectedSourceObjectPath) {
      const result = EditorResult.failure(
        'The dashboard opened a different survey version. Cancel this edit '
        'session and reopen the map before saving.',
      );
      _setError(result.message!);
      return result;
    }

    late final SurveyDocument candidate;
    try {
      candidate = MapEditorLayoutAdapter.documentWithLayout(
        source: current,
        layout: layout,
      );
    } catch (error) {
      final message = _humanizeError(error);
      _setError(message);
      return EditorResult.failure(message);
    }

    final validationErrors = validationService.validate(candidate);
    if (validationErrors.isNotEmpty) {
      final message = validationErrors.join('\n');
      _setError(message);
      return EditorResult.failure(message);
    }

    _isBusy = true;
    _statusMessage =
        'Uploading a new Store ${candidate.storeNumber} survey version...';
    _errorMessage = null;
    notifyListeners();

    try {
      final storedVersion = await storageRepository.saveNewVersion(
        survey: candidate,
        currentObjectPath: currentPath,
      );
      final nextPath = storedVersion.objectPath;
      final uploadedAt = storedVersion.updatedAt ?? DateTime.now().toUtc();
      final metadata = SurveyVersionMetadata.fromSurveyDocument(
        survey: candidate,
        objectPath: nextPath,
        uploadedAt: uploadedAt,
        source: 'admin',
      );
      final registrationError = await _registerMetadataWithRetry(metadata);

      // The Storage object is already durable at this point. Update local state
      // even if the secondary index request failed so Save cannot accidentally
      // upload a duplicate revision when the user retries.
      _currentObjectPath = nextPath;
      _currentSurvey = candidate;
      _savedSnapshot = candidate.clone();
      _recordNewVersion(survey: candidate, version: storedVersion);
      final fileName = nextPath.split('/').last;

      if (registrationError != null) {
        final warning = 'New survey version uploaded: $fileName. Its metadata '
            'index entry could not be registered yet. Return to the dashboard '
            'and use Sync index; do not upload the map again.';
        _statusMessage = warning;
        return EditorResult.success(warning);
      }

      _statusMessage = 'New survey version uploaded: $fileName';
      return EditorResult.success(
        'New survey version uploaded: $fileName',
      );
    } catch (error) {
      final message = _humanizeError(error);
      _errorMessage = message;
      _statusMessage = null;
      return EditorResult.failure(message);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
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
        metrics: metricsCalculator.calculate(survey),
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
        metrics: metricsCalculator.calculate(survey),
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
      final survey = await storageRepository.loadSurvey(path);
      bundles.add(
        SurveyExportBundle(
          objectPath: path,
          survey: survey,
          metrics: metricsCalculator.calculate(survey),
        ),
      );
    }
    return bundles;
  }

  Future<void> _openStoreInternal(
    StoreRecord store, {
    String? objectPath,
  }) async {
    final storeWithHistory = await _storeWithCompleteHistory(store);
    final path = objectPath ?? storeWithHistory.latestVersion.objectPath;
    final survey = await storageRepository.loadSurvey(path);
    _currentStore = storeWithHistory;
    _currentSurvey = survey;
    _savedSnapshot = survey.clone();
    _currentObjectPath = path;
    _updateStoreInList(storeWithHistory);
    _clearMessages();
  }

  Future<StoreRecord> _storeWithCompleteHistory(StoreRecord store) async {
    final indexedVersions = await metadataRepository.loadVersionsForStore(
      store.storeNumber,
    );
    final versionsByPath = <String, StorageSurveyVersion>{
      for (final metadata in indexedVersions)
        metadata.objectPath: metadata.toStorageVersion(),
      // Keep a locally known just-uploaded path if its index registration is
      // temporarily pending.
      for (final version in store.versions) version.objectPath: version,
    };
    final versions = versionsByPath.values.toList()
      ..sort(_newestVersionFirst);
    if (versions.isEmpty) {
      return store;
    }
    final versionCount = store.versionCount > versions.length
        ? store.versionCount
        : versions.length;
    return store.copyWith(
      storageFolder: _parentFolder(versions.first.objectPath),
      versions: List.unmodifiable(versions),
      indexedVersionCount: versionCount,
    );
  }

  void _recordNewVersion({
    required SurveyDocument survey,
    required StorageSurveyVersion version,
  }) {
    final currentStore = _currentStore;
    if (currentStore == null) {
      return;
    }

    final nextStore = StoreRecord(
      storageFolder: _parentFolder(version.objectPath),
      storeNumber: survey.storeNumber,
      stateCode: survey.stateCode,
      city: survey.city,
      versions: List.unmodifiable([
        version,
        for (final existingVersion in currentStore.versions)
          if (existingVersion.objectPath != version.objectPath)
            existingVersion,
      ]),
      indexedVersionCount: currentStore.versionCount + 1,
    );
    _currentStore = nextStore;
    _updateStoreInList(nextStore);
  }

  void _replaceStoreIndex(List<StoreRecord> stores) {
    _stores = List.unmodifiable(stores);
    _selectedStoreKeys.removeWhere(
      (key) => stores.every((store) => store.key != key),
    );
  }

  void _updateStoreInList(StoreRecord updatedStore) {
    final index = _stores.indexWhere((store) => store.key == updatedStore.key);
    if (index < 0) {
      return;
    }
    final updatedStores = [..._stores];
    updatedStores[index] = updatedStore;
    _stores = List.unmodifiable(updatedStores);
  }

  Future<Object?> _registerMetadataWithRetry(
    SurveyVersionMetadata metadata,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await metadataRepository.registerVersion(metadata);
        return null;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
        }
      }
    }
    return lastError;
  }

  Future<void> _deleteVersionFromStorageAndIndex(String objectPath) async {
    await storageRepository.deleteSurvey(objectPath);

    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt += 1) {
      try {
        await metadataRepository.deleteVersion(objectPath);
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
        }
      }
    }

    throw StateError(
      'The Storage object was removed, but its metadata row could not be '
      'deleted after three attempts: $lastError',
    );
  }

  Future<bool> _reloadAfterDeletion(String storeNumber) async {
    final stores = await metadataRepository.loadStoreIndex();
    _replaceStoreIndex(stores);
    final replacements = stores.where(
      (store) => store.storeNumber == storeNumber,
    );
    if (replacements.isEmpty) {
      _clearCurrentSelection();
      _selectedStoreKeys.remove(storeNumber);
      return false;
    }

    await _openStoreInternal(replacements.first);
    return true;
  }

  void _clearCurrentSelection() {
    _currentStore = null;
    _currentSurvey = null;
    _savedSnapshot = null;
    _currentObjectPath = null;
  }

  int _newestVersionFirst(
    StorageSurveyVersion a,
    StorageSurveyVersion b,
  ) {
    final aDate = a.updatedAt;
    final bDate = b.updatedAt;
    if (aDate != null && bDate != null) {
      return bDate.compareTo(aDate);
    }
    if (aDate != null) {
      return -1;
    }
    if (bDate != null) {
      return 1;
    }
    return b.fileName.compareTo(a.fileName);
  }

  String _parentFolder(String objectPath) {
    final slash = objectPath.lastIndexOf('/');
    return slash < 0 ? '' : objectPath.substring(0, slash);
  }

  List<StoreRecord> _selectedStores() {
    return _stores
        .where((store) => _selectedStoreKeys.contains(store.key))
        .toList(growable: false);
  }

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    _startBusy(message);

    try {
      await action();
    } catch (error) {
      _errorMessage = _humanizeError(error);
      _statusMessage = null;
    } finally {
      _finishBusy();
    }
  }

  void _startBusy(String message) {
    _isBusy = true;
    _statusMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  void _finishBusy() {
    _isBusy = false;
    notifyListeners();
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
