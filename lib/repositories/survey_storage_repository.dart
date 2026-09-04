// survey_storage_repository.dart
//
// Responsibility:
// Isolates all Supabase Storage access. The UI never needs to know how JSON
// objects are listed, grouped into stores, downloaded, or versioned on save.

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_record.dart';
import '../models/survey_document.dart';

class SurveyStorageRepository {
  final SupabaseClient client;
  final String bucketName;
  final int pageSize;

  const SurveyStorageRepository({
    required this.client,
    required this.bucketName,
    this.pageSize = 500,
  });

  StorageFileApi get _storage => client.storage.from(bucketName);

  /// Builds a temporary store index directly from Storage.
  ///
  /// This is intentionally acceptable for the test phase. For ~1000 stores in
  /// production, replace this method with a small Postgres metadata/index table
  /// so the browser does not need to download every store's newest JSON simply
  /// to learn its city/state.
  Future<List<StoreRecord>> loadStoreIndex() async {
    final objects = <StorageSurveyVersion>[];
    await _walkFolder('', objects);

    final byFolder = <String, List<StorageSurveyVersion>>{};
    for (final object in objects) {
      final slash = object.objectPath.lastIndexOf('/');
      final folder = slash < 0 ? '' : object.objectPath.substring(0, slash);
      byFolder.putIfAbsent(folder, () => []).add(object);
    }

    final stores = <StoreRecord>[];
    for (final entry in byFolder.entries) {
      final versions = [...entry.value]..sort(_newestFirst);
      if (versions.isEmpty) {
        continue;
      }

      String storeNumber = _lastFolderSegment(entry.key);
      String stateCode = '';
      String city = '';

      try {
        final latest = await loadSurvey(versions.first.objectPath);
        storeNumber = latest.storeNumber == 'Unknown'
            ? storeNumber
            : latest.storeNumber;
        stateCode = latest.stateCode;
        city = latest.city;
      } catch (_) {
        // Keep the path-derived record visible even when one JSON is malformed.
        // Opening it later will surface the actual parsing/download error.
      }

      stores.add(
        StoreRecord(
          storageFolder: entry.key,
          storeNumber: storeNumber,
          stateCode: stateCode,
          city: city,
          versions: List.unmodifiable(versions),
        ),
      );
    }

    stores.sort((a, b) {
      final aNumber = int.tryParse(a.storeNumber);
      final bNumber = int.tryParse(b.storeNumber);
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      return a.storeNumber.compareTo(b.storeNumber);
    });

    return stores;
  }

  Future<SurveyDocument> loadSurvey(String objectPath) async {
    final bytes = await _storage.download(objectPath);
    return SurveyDocument.fromBytes(bytes);
  }

  /// Saves edits as a NEW immutable version rather than overwriting history.
  /// The filename intentionally contains store number + upload timestamp + id.
  Future<String> saveNewVersion({
    required SurveyDocument survey,
    required String currentObjectPath,
  }) async {
    final folder = _parentFolder(currentObjectPath);
    final now = DateTime.now().toUtc();
    final timestamp = now.toIso8601String().replaceAll(':', '-');
    final safeStore = _safeFilePart(survey.storeNumber);
    final safeSurveyId = _safeFilePart(
      survey.surveyId.isEmpty ? 'edited' : survey.surveyId,
    );
    final fileName = '$safeStore-$timestamp-$safeSurveyId.json';
    final nextPath = folder.isEmpty ? fileName : '$folder/$fileName';

    final bytes = Uint8List.fromList(
      utf8.encode(survey.toJsonString(pretty: true)),
    );

    await _storage.uploadBinary(
      nextPath,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '0',
        upsert: false,
        contentType: 'application/json',
      ),
    );

    return nextPath;
  }

  Future<void> _walkFolder(
    String prefix,
    List<StorageSurveyVersion> output,
  ) async {
    var offset = 0;

    while (true) {
      final objects = await _storage.list(
        path: prefix,
        searchOptions: SearchOptions(limit: pageSize, offset: offset),
      );

      for (final object in objects) {
        final path = prefix.isEmpty ? object.name : '$prefix/${object.name}';
        if (_looksLikeFolder(object)) {
          await _walkFolder(path, output);
          continue;
        }

        if (!object.name.toLowerCase().endsWith('.json')) {
          continue;
        }

        output.add(
          StorageSurveyVersion(
            objectPath: path,
            updatedAt: DateTime.tryParse(object.updatedAt ?? ''),
          ),
        );
      }

      if (objects.length < pageSize) {
        break;
      }
      offset += pageSize;
    }
  }

  bool _looksLikeFolder(FileObject object) {
    return object.id == null && object.metadata == null;
  }

  int _newestFirst(StorageSurveyVersion a, StorageSurveyVersion b) {
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

  String _lastFolderSegment(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? 'Unknown' : parts.last;
  }

  String _parentFolder(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  String _safeFilePart(String value) {
    final normalized = value.trim().isEmpty ? 'unknown' : value.trim();
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  }
}
