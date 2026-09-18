// survey_version_path_builder.dart
//
// Responsibility:
// Builds a safe, immutable Storage object path for an edited survey version.
// Keeping this pure makes the no-overwrite naming rule independently testable.

class SurveyVersionPathBuilder {
  const SurveyVersionPathBuilder._();

  static String build({
    required String currentObjectPath,
    required String storeNumber,
    required String surveyId,
    required DateTime updatedAt,
  }) {
    final folder = _parentFolder(currentObjectPath);
    final timestamp = updatedAt.toUtc().toIso8601String().replaceAll(':', '-');
    final safeStore = _safeFilePart(storeNumber);
    final safeSurveyId = _safeFilePart(
      surveyId.trim().isEmpty ? 'edited' : surveyId,
    );
    final baseName = '$safeStore-$timestamp-$safeSurveyId';
    final candidate = _join(folder, '$baseName.json');

    // A clock value copied from an existing document should never turn a
    // save-as-new action into an attempt against that same object path.
    return candidate == currentObjectPath
        ? _join(folder, '$baseName-new.json')
        : candidate;
  }

  static String _parentFolder(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  static String _join(String folder, String fileName) {
    return folder.isEmpty ? fileName : '$folder/$fileName';
  }

  static String _safeFilePart(String value) {
    final normalized = value.trim().isEmpty ? 'unknown' : value.trim();
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  }
}
