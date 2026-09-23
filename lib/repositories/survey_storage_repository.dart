// survey_storage_repository.dart
//
// Responsibility:
// Isolates all Supabase Storage access. Normal dashboard startup uses the
// Postgres metadata index; recursive object listing remains available only for
// explicit index synchronization and recovery.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_record.dart';
import '../models/survey_document.dart';
import '../utils/survey_version_path_builder.dart';

abstract interface class SurveyStorageDataSource {
  Future<List<StorageSurveyVersion>> listSurveyVersions();

  Future<SurveyDocument> loadSurvey(String objectPath);

  Future<StorageSurveyVersion> saveNewVersion({
    required SurveyDocument survey,
    required String currentObjectPath,
  });
}

class SurveyStorageRepository implements SurveyStorageDataSource {
  final SupabaseClient client;
  final String bucketName;
  final int pageSize;

  const SurveyStorageRepository({
    required this.client,
    required this.bucketName,
    this.pageSize = 500,
  });

  StorageFileApi get _storage => client.storage.from(bucketName);

  /// Lists every immutable survey JSON for an explicit index repair/backfill.
  /// This is deliberately not called during a normal dashboard refresh.
  @override
  Future<List<StorageSurveyVersion>> listSurveyVersions() async {
    final objects = <StorageSurveyVersion>[];
    await _walkFolder('', objects);
    objects.sort(_newestFirst);
    return List.unmodifiable(objects);
  }

  @override
  Future<SurveyDocument> loadSurvey(String objectPath) async {
    final bytes = await _storage.download(objectPath);
    return SurveyDocument.fromBytes(bytes);
  }

  /// Saves edits as a new immutable object and never targets the opened file.
  /// The filename contains store number + document updatedAt + survey id.
  @override
  Future<StorageSurveyVersion> saveNewVersion({
    required SurveyDocument survey,
    required String currentObjectPath,
  }) async {
    if (currentObjectPath.trim().isEmpty) {
      throw ArgumentError('The source survey object path cannot be empty.');
    }

    final uploadedAt = DateTime.now().toUtc();
    final nextPath = SurveyVersionPathBuilder.build(
      currentObjectPath: currentObjectPath,
      storeNumber: survey.storeNumber,
      surveyId: survey.surveyId,
      updatedAt: survey.updatedAt ?? uploadedAt,
    );

    await _storage.uploadBinary(
      nextPath,
      survey.toUtf8Bytes(pretty: true),
      fileOptions: const FileOptions(
        cacheControl: '0',
        // Insert-only: an existing object is never updated or replaced.
        upsert: false,
        contentType: 'application/json',
      ),
    );

    return StorageSurveyVersion(
      objectPath: nextPath,
      updatedAt: uploadedAt,
    );
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
}
