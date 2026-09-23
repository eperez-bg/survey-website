// store_record.dart
//
// Responsibility:
// Represents one store in the Postgres metadata index plus the JSON versions
// that have been loaded for it. The initial store list contains only the latest
// version; complete history is loaded lazily when the store is opened.

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
  final int? indexedVersionCount;

  const StoreRecord({
    required this.storageFolder,
    required this.storeNumber,
    required this.stateCode,
    required this.city,
    required this.versions,
    this.indexedVersionCount,
  });

  StorageSurveyVersion get latestVersion => versions.first;

  // Store number is the stable business identifier even if a corrected city
  // causes a later mobile upload to use a different Storage folder.
  String get key => storeNumber;

  int get versionCount => indexedVersionCount ?? versions.length;

  StoreRecord copyWith({
    String? storageFolder,
    String? storeNumber,
    String? stateCode,
    String? city,
    List<StorageSurveyVersion>? versions,
    int? indexedVersionCount,
  }) {
    return StoreRecord(
      storageFolder: storageFolder ?? this.storageFolder,
      storeNumber: storeNumber ?? this.storeNumber,
      stateCode: stateCode ?? this.stateCode,
      city: city ?? this.city,
      versions: versions ?? this.versions,
      indexedVersionCount: indexedVersionCount ?? this.indexedVersionCount,
    );
  }

  String get locationLabel {
    final pieces = [
      if (city.trim().isNotEmpty) city.trim(),
      if (stateCode.trim().isNotEmpty) stateCode.trim(),
    ];
    return pieces.isEmpty ? storageFolder : pieces.join(', ');
  }
}
