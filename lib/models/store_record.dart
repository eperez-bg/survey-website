// store_record.dart
// Lightweight store index item used by the store-list page.

class StoreRecord {
  const StoreRecord({
    required this.storeNumber,
    required this.folderPath,
    required this.latestObjectPath,
    required this.locationSlug,
    this.state = '',
    this.city = '',
    this.latestUploadedAt,
  });

  final String storeNumber;
  final String folderPath;
  final String latestObjectPath;
  final String locationSlug;
  final String state;
  final String city;
  final DateTime? latestUploadedAt;

  String get locationLabel {
    final parts = [city, state].where((e) => e.trim().isNotEmpty).toList();
    return parts.isEmpty ? locationSlug : parts.join(', ');
  }

  StoreRecord copyWith({
    String? state,
    String? city,
    String? latestObjectPath,
    DateTime? latestUploadedAt,
  }) {
    return StoreRecord(
      storeNumber: storeNumber,
      folderPath: folderPath,
      latestObjectPath: latestObjectPath ?? this.latestObjectPath,
      locationSlug: locationSlug,
      state: state ?? this.state,
      city: city ?? this.city,
      latestUploadedAt: latestUploadedAt ?? this.latestUploadedAt,
    );
  }
}
