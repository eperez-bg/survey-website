import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/store_record.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/models/survey_version_metadata.dart';
import 'package:survey_admin_web/repositories/survey_metadata_repository.dart';
import 'package:survey_admin_web/repositories/survey_storage_repository.dart';
import 'package:survey_admin_web/services/survey_index_sync_service.dart';

void main() {
  test('survey metadata round-trips database fields and preserves paths', () {
    final metadata = SurveyVersionMetadata.fromDatabaseRow({
      'object_path': 'surveys/IL/west-jefferson/2255/version.json',
      'survey_id': 'survey-1',
      'store_number': '2255',
      'state_code': 'IL',
      'city': 'West Jefferson',
      'schema_version': 12,
      'uploaded_at': '2026-09-18T15:30:00.000Z',
      'survey_updated_at': '2026-09-18T15:29:00.000Z',
      'source': 'admin',
    });

    expect(metadata.storeNumber, '2255');
    expect(metadata.storageFolder, 'surveys/IL/west-jefferson/2255');
    expect(metadata.toStorageVersion().objectPath, metadata.objectPath);
    expect(
      metadata.toDatabaseRow()['uploaded_at'],
      '2026-09-18T15:30:00.000Z',
    );
  });

  test('index sync skips existing paths and reports malformed JSON', () async {
    final survey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
    final storage = _FakeStorageRepository(
      survey: survey,
      versions: [
        StorageSurveyVersion(
          objectPath: 'surveys/existing.json',
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
        StorageSurveyVersion(
          objectPath: 'surveys/new.json',
          updatedAt: DateTime.utc(2026, 9, 2),
        ),
        StorageSurveyVersion(
          objectPath: 'surveys/broken.json',
          updatedAt: DateTime.utc(2026, 9, 3),
        ),
      ],
      failingPath: 'surveys/broken.json',
    );
    final metadata = _FakeMetadataRepository(
      indexedPaths: {'surveys/existing.json'},
    );
    final progress = <SurveyIndexSyncProgress>[];
    final service = SurveyIndexSyncService(
      storageRepository: storage,
      metadataRepository: metadata,
      maxConcurrentDownloads: 2,
    );

    final result = await service.synchronize(
      onProgress: (value) {
        progress.add(value);
      },
    );

    expect(result.storageObjectCount, 3);
    expect(result.alreadyIndexedCount, 1);
    expect(result.newlyIndexedCount, 1);
    expect(result.failures, contains('surveys/broken.json'));
    expect(metadata.registered.single.objectPath, 'surveys/new.json');
    expect(metadata.registered.single.source, 'backfill');
    expect(progress.last.completed, 2);
    expect(progress.last.total, 2);
  });
}

class _FakeStorageRepository implements SurveyStorageDataSource {
  final SurveyDocument survey;
  final List<StorageSurveyVersion> versions;
  final String? failingPath;

  const _FakeStorageRepository({
    required this.survey,
    required this.versions,
    this.failingPath,
  });

  @override
  Future<List<StorageSurveyVersion>> listSurveyVersions() async => versions;

  @override
  Future<SurveyDocument> loadSurvey(String objectPath) async {
    if (objectPath == failingPath) {
      throw const FormatException('Broken survey JSON.');
    }
    return survey.clone();
  }

  @override
  Future<void> deleteSurvey(String objectPath) async {}

  @override
  Future<StorageSurveyVersion> saveNewVersion({
    required SurveyDocument survey,
    required String currentObjectPath,
  }) {
    throw UnimplementedError();
  }
}

class _FakeMetadataRepository implements SurveyMetadataDataSource {
  final Set<String> indexedPaths;
  final List<SurveyVersionMetadata> registered = [];

  _FakeMetadataRepository({required this.indexedPaths});

  @override
  Future<List<StoreRecord>> loadStoreIndex() async => const [];

  @override
  Future<Set<String>> loadIndexedObjectPaths() async => {...indexedPaths};

  @override
  Future<List<SurveyVersionMetadata>> loadVersionsForStore(
    String storeNumber,
  ) async =>
      const [];

  @override
  Future<void> registerVersion(SurveyVersionMetadata version) async {
    registered.add(version);
    indexedPaths.add(version.objectPath);
  }

  @override
  Future<void> deleteVersion(String objectPath) async {
    indexedPaths.remove(objectPath);
  }
}
