// survey_index_sync_service.dart
//
// Responsibility:
// Reconciles immutable JSON objects in Supabase Storage with the lightweight
// Postgres metadata index. This slow path is explicit/first-run only and is not
// part of a normal dashboard refresh.

import 'dart:math' as math;

import '../models/store_record.dart';
import '../models/survey_version_metadata.dart';
import '../repositories/survey_metadata_repository.dart';
import '../repositories/survey_storage_repository.dart';

typedef SurveyIndexProgressCallback = void Function(
  SurveyIndexSyncProgress progress,
);

class SurveyIndexSyncProgress {
  final String message;
  final int completed;
  final int total;

  const SurveyIndexSyncProgress({
    required this.message,
    this.completed = 0,
    this.total = 0,
  });
}

class SurveyIndexSyncResult {
  final int storageObjectCount;
  final int alreadyIndexedCount;
  final int newlyIndexedCount;
  final Map<String, String> failures;

  const SurveyIndexSyncResult({
    required this.storageObjectCount,
    required this.alreadyIndexedCount,
    required this.newlyIndexedCount,
    required this.failures,
  });

  int get failureCount => failures.length;
}

class SurveyIndexSyncService {
  final SurveyStorageDataSource storageRepository;
  final SurveyMetadataDataSource metadataRepository;
  final int maxConcurrentDownloads;

  const SurveyIndexSyncService({
    required this.storageRepository,
    required this.metadataRepository,
    this.maxConcurrentDownloads = 5,
  }) : assert(maxConcurrentDownloads > 0);

  Future<SurveyIndexSyncResult> synchronize({
    SurveyIndexProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const SurveyIndexSyncProgress(
        message: 'Scanning survey JSON files in Storage...',
      ),
    );
    final listedObjects = await storageRepository.listSurveyVersions();
    final objectsByPath = <String, StorageSurveyVersion>{
      for (final object in listedObjects) object.objectPath: object,
    };
    final storageObjects = objectsByPath.values.toList(growable: false);

    onProgress?.call(
      SurveyIndexSyncProgress(
        message: 'Comparing ${storageObjects.length} Storage objects with '
            'the index...',
        total: storageObjects.length,
      ),
    );
    final indexedPaths = await metadataRepository.loadIndexedObjectPaths();
    final missing = storageObjects
        .where((object) => !indexedPaths.contains(object.objectPath))
        .toList(growable: false);

    if (missing.isEmpty) {
      return SurveyIndexSyncResult(
        storageObjectCount: storageObjects.length,
        alreadyIndexedCount: storageObjects.length,
        newlyIndexedCount: 0,
        failures: const {},
      );
    }

    var nextIndex = 0;
    var completed = 0;
    var newlyIndexed = 0;
    final failures = <String, String>{};

    Future<void> worker() async {
      while (true) {
        final itemIndex = nextIndex;
        nextIndex += 1;
        if (itemIndex >= missing.length) {
          return;
        }

        final object = missing[itemIndex];
        try {
          final survey = await storageRepository.loadSurvey(object.objectPath);
          final uploadedAt = object.updatedAt ??
              survey.updatedAt ??
              survey.completedAt ??
              survey.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final metadata = SurveyVersionMetadata.fromSurveyDocument(
            survey: survey,
            objectPath: object.objectPath,
            uploadedAt: uploadedAt,
            source: 'backfill',
          );
          await metadataRepository.registerVersion(metadata);
          newlyIndexed += 1;
        } catch (error) {
          failures[object.objectPath] = error.toString();
        }

        completed += 1;
        onProgress?.call(
          SurveyIndexSyncProgress(
            message: 'Indexing survey $completed of ${missing.length}...',
            completed: completed,
            total: missing.length,
          ),
        );
      }
    }

    final workerCount = math.min(maxConcurrentDownloads, missing.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return SurveyIndexSyncResult(
      storageObjectCount: storageObjects.length,
      alreadyIndexedCount: storageObjects.length - missing.length,
      newlyIndexedCount: newlyIndexed,
      failures: Map.unmodifiable(failures),
    );
  }
}
