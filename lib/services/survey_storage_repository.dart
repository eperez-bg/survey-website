// survey_storage_repository.dart
// All Supabase Storage access. The UI never talks directly to Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../utils/app_config.dart';

class SurveyStorageRepository {
  SurveyStorageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  StorageFileApi get _bucket =>
      _client.storage.from(AppConfig.surveyBucket);

  Future<SurveyDocument> loadSurvey(String objectPath) async {
    final bytes = await _bucket.download(objectPath);
    return SurveyDocument.fromBytes(bytes, objectPath: objectPath);
  }

  Future<List<String>> listVersionPaths(String storeFolderPath) async {
    final objects = await _bucket.list(
      path: storeFolderPath,
      searchOptions: const SearchOptions(limit: 1000),
    );
    final files = objects
        .where((item) => item.name.toLowerCase().endsWith('.json'))
        .map((item) => '$storeFolderPath/${item.name}')
        .toList();
    files.sort((a, b) => b.compareTo(a));
    return files;
  }

  Future<List<StoreRecord>> loadStoreIndex() async {
    final stores = <StoreRecord>[];
    final rootEntries = await _bucket.list(
      searchOptions: const SearchOptions(limit: 1000),
    );

    for (final location in rootEntries) {
      if (location.name.toLowerCase().endsWith('.json')) continue;
      final locationPath = location.name;
      final storeEntries = await _bucket.list(
        path: locationPath,
        searchOptions: const SearchOptions(limit: 1000),
      );

      for (final storeEntry in storeEntries) {
        if (storeEntry.name.toLowerCase().endsWith('.json')) continue;
        final storeFolder = '$locationPath/${storeEntry.name}';
        final versions = await listVersionPaths(storeFolder);
        if (versions.isEmpty) continue;

        final latestPath = versions.first;
        try {
          final survey = await loadSurvey(latestPath);
          stores.add(StoreRecord(
            storeNumber: survey.storeNumber.isEmpty
                ? storeEntry.name
                : survey.storeNumber,
            folderPath: storeFolder,
            latestObjectPath: latestPath,
            locationSlug: location.name,
            state: survey.state,
            city: survey.city,
            latestUploadedAt: _timestampFromPath(latestPath),
          ));
        } catch (_) {
          stores.add(StoreRecord(
            storeNumber: storeEntry.name,
            folderPath: storeFolder,
            latestObjectPath: latestPath,
            locationSlug: location.name,
            latestUploadedAt: _timestampFromPath(latestPath),
          ));
        }
      }
    }

    stores.sort((a, b) {
      final ai = int.tryParse(a.storeNumber);
      final bi = int.tryParse(b.storeNumber);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.storeNumber.compareTo(b.storeNumber);
    });
    return stores;
  }

  Future<String> uploadNewVersion(SurveyDocument survey) async {
    final oldParts = survey.objectPath.split('/');
    if (oldParts.length < 3) {
      throw StateError('Survey object path does not contain a store folder.');
    }

    final storeFolder = oldParts.sublist(0, oldParts.length - 1).join('/');
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final safeSurveyId = survey.surveyId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    final name = '${survey.storeNumber}-$timestamp-$safeSurveyId.json';
    final newPath = '$storeFolder/$name';

    await _bucket.uploadBinary(
      newPath,
      survey.toPrettyJsonBytes(),
      fileOptions: const FileOptions(
        contentType: 'application/json',
        upsert: false,
      ),
    );

    survey.objectPath = newPath;
    return newPath;
  }

  DateTime? _timestampFromPath(String path) {
    final name = path.split('/').last.replaceAll('.json', '');
    final match = RegExp(r'(20\d\d-\d\d-\d\dT\d\d[-:]\d\d[-:]\d\d(?:\.\d+)?Z)').firstMatch(name);
    if (match == null) return null;
    final normalized = match.group(1)!
        .replaceFirstMapped(RegExp(r'T(\d\d)-(\d\d)-(\d\d)'), (m) => 'T${m[1]}:${m[2]}:${m[3]}');
    return DateTime.tryParse(normalized);
  }
}
