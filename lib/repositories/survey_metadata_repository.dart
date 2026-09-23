// survey_metadata_repository.dart
//
// Responsibility:
// Isolates all Postgres access for the lightweight survey metadata index. It
// never downloads or uploads the full JSON survey object.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_record.dart';
import '../models/survey_version_metadata.dart';

abstract interface class SurveyMetadataDataSource {
  Future<List<StoreRecord>> loadStoreIndex();

  Future<List<SurveyVersionMetadata>> loadVersionsForStore(
    String storeNumber,
  );

  Future<Set<String>> loadIndexedObjectPaths();

  Future<void> registerVersion(SurveyVersionMetadata version);
}

class SurveyMetadataRepository implements SurveyMetadataDataSource {
  static const String versionsTable = 'survey_versions';
  static const String storeIndexView = 'survey_store_index';

  final SupabaseClient client;
  final int pageSize;

  const SurveyMetadataRepository({
    required this.client,
    this.pageSize = 500,
  });

  /// Loads exactly one small row per store from the latest-version view.
  @override
  Future<List<StoreRecord>> loadStoreIndex() async {
    final stores = <StoreRecord>[];
    var offset = 0;

    while (true) {
      final response = await client
          .from(storeIndexView)
          .select()
          .order('store_number')
          .range(offset, offset + pageSize - 1);

      for (final rawRow in response) {
        final row = Map<String, dynamic>.from(rawRow);
        final metadata = SurveyVersionMetadata.fromDatabaseRow(row);
        stores.add(
          StoreRecord(
            storageFolder: metadata.storageFolder,
            storeNumber: metadata.storeNumber,
            stateCode: metadata.stateCode,
            city: metadata.city,
            versions: [metadata.toStorageVersion()],
            indexedVersionCount: _intValue(
              row['version_count'],
              fallback: 1,
            ),
          ),
        );
      }

      if (response.length < pageSize) {
        break;
      }
      offset += pageSize;
    }

    stores.sort(_compareStores);
    return List.unmodifiable(stores);
  }

  /// Loads history only when a user opens a store. This keeps dashboard startup
  /// independent from the total number of historical versions in the bucket.
  @override
  Future<List<SurveyVersionMetadata>> loadVersionsForStore(
    String storeNumber,
  ) async {
    final versions = <SurveyVersionMetadata>[];
    var offset = 0;

    while (true) {
      final response = await client
          .from(versionsTable)
          .select()
          .eq('store_number', storeNumber)
          .order('uploaded_at', ascending: false)
          .order('object_path', ascending: false)
          .range(offset, offset + pageSize - 1);

      versions.addAll(
        response.map(
          (row) => SurveyVersionMetadata.fromDatabaseRow(
            Map<String, dynamic>.from(row),
          ),
        ),
      );
      if (response.length < pageSize) {
        break;
      }
      offset += pageSize;
    }

    return List.unmodifiable(versions);
  }

  /// Paginates explicitly so index repair continues to work after the table
  /// grows beyond Supabase's default response limit.
  @override
  Future<Set<String>> loadIndexedObjectPaths() async {
    final paths = <String>{};
    var offset = 0;

    while (true) {
      final response = await client
          .from(versionsTable)
          .select('object_path')
          .order('object_path')
          .range(offset, offset + pageSize - 1);

      for (final row in response) {
        final path = row['object_path']?.toString();
        if (path != null && path.isNotEmpty) {
          paths.add(path);
        }
      }

      if (response.length < pageSize) {
        break;
      }
      offset += pageSize;
    }

    return paths;
  }

  /// Registration is idempotent. A repeated request for the same immutable
  /// object path becomes ON CONFLICT DO NOTHING and needs no UPDATE permission.
  @override
  Future<void> registerVersion(SurveyVersionMetadata version) async {
    await client.from(versionsTable).upsert(
          version.toDatabaseRow(),
          onConflict: 'object_path',
          ignoreDuplicates: true,
        );
  }

  int _compareStores(StoreRecord a, StoreRecord b) {
    final aNumber = int.tryParse(a.storeNumber);
    final bNumber = int.tryParse(b.storeNumber);
    if (aNumber != null && bNumber != null) {
      return aNumber.compareTo(bNumber);
    }
    return a.storeNumber.compareTo(b.storeNumber);
  }

  int _intValue(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
