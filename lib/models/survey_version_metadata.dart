// survey_version_metadata.dart
//
// Responsibility:
// Represents the lightweight Postgres index row for one immutable survey JSON
// object. The full survey remains in Supabase Storage; this model only contains
// fields needed to list stores, find version history, and open an object later.

import 'store_record.dart';
import 'survey_document.dart';

class SurveyVersionMetadata {
  final String objectPath;
  final String surveyId;
  final String storeNumber;
  final String stateCode;
  final String city;
  final int schemaVersion;
  final DateTime uploadedAt;
  final DateTime? surveyUpdatedAt;
  final String source;

  const SurveyVersionMetadata({
    required this.objectPath,
    required this.surveyId,
    required this.storeNumber,
    required this.stateCode,
    required this.city,
    required this.schemaVersion,
    required this.uploadedAt,
    required this.surveyUpdatedAt,
    required this.source,
  });

  factory SurveyVersionMetadata.fromDatabaseRow(Map<String, dynamic> row) {
    return SurveyVersionMetadata(
      objectPath: _requiredString(row, 'object_path'),
      surveyId: _stringValue(row['survey_id']),
      storeNumber: _requiredString(row, 'store_number'),
      stateCode: _stringValue(row['state_code']),
      city: _stringValue(row['city']),
      schemaVersion: _intValue(row['schema_version']),
      uploadedAt: _requiredDateTime(row, 'uploaded_at'),
      surveyUpdatedAt: _dateTimeValue(row['survey_updated_at']),
      source: _stringValue(row['source'], fallback: 'backfill'),
    );
  }

  factory SurveyVersionMetadata.fromSurveyDocument({
    required SurveyDocument survey,
    required String objectPath,
    required DateTime uploadedAt,
    required String source,
  }) {
    return SurveyVersionMetadata(
      objectPath: objectPath,
      surveyId: survey.surveyId,
      storeNumber: survey.storeNumber,
      stateCode: survey.stateCode,
      city: survey.city,
      schemaVersion: survey.schemaVersion,
      uploadedAt: uploadedAt.toUtc(),
      surveyUpdatedAt: survey.updatedAt?.toUtc(),
      source: source,
    );
  }

  Map<String, dynamic> toDatabaseRow() {
    return {
      'object_path': objectPath,
      'survey_id': surveyId,
      'store_number': storeNumber,
      'state_code': stateCode,
      'city': city,
      'schema_version': schemaVersion,
      'uploaded_at': uploadedAt.toUtc().toIso8601String(),
      'survey_updated_at': surveyUpdatedAt?.toUtc().toIso8601String(),
      'source': source,
    };
  }

  StorageSurveyVersion toStorageVersion() {
    return StorageSurveyVersion(
      objectPath: objectPath,
      updatedAt: uploadedAt,
    );
  }

  String get storageFolder {
    final slash = objectPath.lastIndexOf('/');
    return slash < 0 ? '' : objectPath.substring(0, slash);
  }
}

String _requiredString(Map<String, dynamic> row, String key) {
  final value = _stringValue(row[key]);
  if (value.trim().isEmpty) {
    throw FormatException('Survey metadata field "$key" is missing.');
  }
  return value;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _requiredDateTime(Map<String, dynamic> row, String key) {
  final value = _dateTimeValue(row[key]);
  if (value == null) {
    throw FormatException('Survey metadata field "$key" is missing.');
  }
  return value;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}
