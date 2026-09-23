import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/controllers/survey_admin_controller.dart';
import 'package:survey_admin_web/models/store_record.dart';
import 'package:survey_admin_web/models/survey_document.dart';
import 'package:survey_admin_web/models/survey_version_metadata.dart';
import 'package:survey_admin_web/repositories/survey_metadata_repository.dart';
import 'package:survey_admin_web/repositories/survey_storage_repository.dart';

void main() {
  late SurveyDocument sampleSurvey;

  setUp(() {
    sampleSurvey = SurveyDocument.fromJsonString(
      File('assets/sample_survey_v9.json').readAsStringSync(),
    );
  });

  test('wrong password cannot delete the selected survey', () async {
    final fixture = _DeletionFixture.single(sampleSurvey);
    await fixture.openLatest();

    final result = await fixture.controller.deleteCurrentSurvey(
      password: 'wrong',
    );

    expect(result.succeeded, isFalse);
    expect(fixture.storage.deletedPaths, isEmpty);
    expect(fixture.metadata.versions, hasLength(1));
  });

  test('deleting newest survey promotes next newest version', () async {
    final fixture = _DeletionFixture.twoVersions(sampleSurvey);
    await fixture.openLatest();

    final result = await fixture.controller.deleteCurrentSurvey(
      password: 'a74rFnb',
    );

    expect(result.succeeded, isTrue);
    expect(fixture.storage.deletedPaths, ['store/2255/new.json']);
    expect(fixture.metadata.versions.single.objectPath, 'store/2255/old.json');
    expect(fixture.controller.currentObjectPath, 'store/2255/old.json');
    expect(fixture.controller.currentStore?.versionCount, 1);
  });

  test('deleting older survey keeps latest version selected', () async {
    final fixture = _DeletionFixture.twoVersions(sampleSurvey);
    final store = (await fixture.metadata.loadStoreIndex()).single;
    await fixture.controller.openStore(
      store,
      objectPath: 'store/2255/old.json',
    );

    final result = await fixture.controller.deleteCurrentSurvey(
      password: 'a74rFnb',
    );

    expect(result.succeeded, isTrue);
    expect(fixture.storage.deletedPaths, ['store/2255/old.json']);
    expect(fixture.metadata.versions.single.objectPath, 'store/2255/new.json');
    expect(fixture.controller.currentObjectPath, 'store/2255/new.json');
  });

  test('deleting only survey also removes the store', () async {
    final fixture = _DeletionFixture.single(sampleSurvey);
    await fixture.openLatest();

    final result = await fixture.controller.deleteCurrentSurvey(
      password: 'a74rFnb',
    );

    expect(result.succeeded, isTrue);
    expect(fixture.controller.stores, isEmpty);
    expect(fixture.controller.currentStore, isNull);
    expect(fixture.controller.currentSurvey, isNull);
    expect(fixture.controller.currentObjectPath, isNull);
  });

  test('Delete Store removes every Storage object and metadata row', () async {
    final fixture = _DeletionFixture.twoVersions(sampleSurvey);
    await fixture.openLatest();

    final result = await fixture.controller.deleteCurrentStore(
      password: 'a74rFnb',
    );

    expect(result.succeeded, isTrue);
    expect(
      fixture.storage.deletedPaths.toSet(),
      {'store/2255/new.json', 'store/2255/old.json'},
    );
    expect(fixture.storage.surveys, isEmpty);
    expect(fixture.metadata.versions, isEmpty);
    expect(fixture.controller.stores, isEmpty);
    expect(fixture.controller.currentStore, isNull);
  });
}

class _DeletionFixture {
  final _FakeStorageRepository storage;
  final _FakeMetadataRepository metadata;
  final SurveyAdminController controller;

  _DeletionFixture._({required this.storage, required this.metadata})
      : controller = SurveyAdminController(
          storageRepository: storage,
          metadataRepository: metadata,
        );

  factory _DeletionFixture.single(SurveyDocument survey) {
    final version = _metadata(
      objectPath: 'store/2255/only.json',
      uploadedAt: DateTime.utc(2026, 9, 20),
    );
    return _DeletionFixture._(
      storage: _FakeStorageRepository({
        version.objectPath: survey.clone(),
      }),
      metadata: _FakeMetadataRepository([version]),
    );
  }

  factory _DeletionFixture.twoVersions(SurveyDocument survey) {
    final oldVersion = _metadata(
      objectPath: 'store/2255/old.json',
      uploadedAt: DateTime.utc(2026, 9, 19),
    );
    final newVersion = _metadata(
      objectPath: 'store/2255/new.json',
      uploadedAt: DateTime.utc(2026, 9, 20),
    );
    return _DeletionFixture._(
      storage: _FakeStorageRepository({
        oldVersion.objectPath: survey.clone(),
        newVersion.objectPath: survey.clone(),
      }),
      metadata: _FakeMetadataRepository([oldVersion, newVersion]),
    );
  }

  Future<void> openLatest() async {
    final store = (await metadata.loadStoreIndex()).single;
    await controller.openStore(store);
  }

  static SurveyVersionMetadata _metadata({
    required String objectPath,
    required DateTime uploadedAt,
  }) {
    return SurveyVersionMetadata(
      objectPath: objectPath,
      surveyId: 'survey-2255',
      storeNumber: '2255',
      stateCode: 'IL',
      city: 'West Jefferson',
      schemaVersion: 9,
      uploadedAt: uploadedAt,
      surveyUpdatedAt: uploadedAt,
      source: 'mobile',
    );
  }
}

class _FakeStorageRepository implements SurveyStorageDataSource {
  final Map<String, SurveyDocument> surveys;
  final List<String> deletedPaths = [];

  _FakeStorageRepository(Map<String, SurveyDocument> surveys)
      : surveys = {...surveys};

  @override
  Future<void> deleteSurvey(String objectPath) async {
    deletedPaths.add(objectPath);
    surveys.remove(objectPath);
  }

  @override
  Future<List<StorageSurveyVersion>> listSurveyVersions() async {
    return [
      for (final path in surveys.keys) StorageSurveyVersion(objectPath: path),
    ];
  }

  @override
  Future<SurveyDocument> loadSurvey(String objectPath) async {
    final survey = surveys[objectPath];
    if (survey == null) {
      throw StateError('Missing fake Storage object: $objectPath');
    }
    return survey.clone();
  }

  @override
  Future<StorageSurveyVersion> saveNewVersion({
    required SurveyDocument survey,
    required String currentObjectPath,
  }) {
    throw UnimplementedError();
  }
}

class _FakeMetadataRepository implements SurveyMetadataDataSource {
  final List<SurveyVersionMetadata> versions;

  _FakeMetadataRepository(List<SurveyVersionMetadata> versions)
      : versions = [...versions];

  @override
  Future<void> deleteVersion(String objectPath) async {
    versions.removeWhere((version) => version.objectPath == objectPath);
  }

  @override
  Future<Set<String>> loadIndexedObjectPaths() async {
    return {for (final version in versions) version.objectPath};
  }

  @override
  Future<List<StoreRecord>> loadStoreIndex() async {
    final byStore = <String, List<SurveyVersionMetadata>>{};
    for (final version in versions) {
      byStore.putIfAbsent(version.storeNumber, () => []).add(version);
    }

    final stores = <StoreRecord>[];
    for (final entry in byStore.entries) {
      final storeVersions = entry.value
        ..sort((a, b) {
          final dateOrder = b.uploadedAt.compareTo(a.uploadedAt);
          return dateOrder != 0
              ? dateOrder
              : b.objectPath.compareTo(a.objectPath);
        });
      final latest = storeVersions.first;
      stores.add(
        StoreRecord(
          storageFolder: latest.storageFolder,
          storeNumber: latest.storeNumber,
          stateCode: latest.stateCode,
          city: latest.city,
          versions: [latest.toStorageVersion()],
          indexedVersionCount: storeVersions.length,
        ),
      );
    }
    return stores;
  }

  @override
  Future<List<SurveyVersionMetadata>> loadVersionsForStore(
    String storeNumber,
  ) async {
    final matches = versions
        .where((version) => version.storeNumber == storeNumber)
        .toList()
      ..sort((a, b) {
        final dateOrder = b.uploadedAt.compareTo(a.uploadedAt);
        return dateOrder != 0
            ? dateOrder
            : b.objectPath.compareTo(a.objectPath);
      });
    return matches;
  }

  @override
  Future<void> registerVersion(SurveyVersionMetadata version) async {
    if (versions.every((item) => item.objectPath != version.objectPath)) {
      versions.add(version);
    }
  }
}
