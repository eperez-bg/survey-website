// store_record.dart
//
// Responsibility:
// Represents one store in the admin index plus every JSON version discovered in
// its Supabase Storage folder.

class StorageSurveyVersion {
  final String objectPath;
  final DateTime? updatedAt;

  const StorageSurveyVersion({required this.objectPath, this.updatedAt});

  String get fileName => objectPath.split('/').last;
}

class StoreRecord {
  final String storageFolder;
  final String storeNumber;
  final String stateCode;
  final String city;
  final List<StorageSurveyVersion> versions;

  const StoreRecord({
    required this.storageFolder,
    required this.storeNumber,
    required this.stateCode,
    required this.city,
    required this.versions,
  });

  StorageSurveyVersion get latestVersion => versions.first;

  String get key => storageFolder;

  String get locationLabel {
    final pieces = [
      if (city.trim().isNotEmpty) city.trim(),
      if (stateCode.trim().isNotEmpty) stateCode.trim(),
    ];
    return pieces.isEmpty ? storageFolder : pieces.join(', ');
  }
}
