import 'distance_endpoint.dart';

class Distance {
  static const String inchesUnit = 'inches';

  final String distanceId;

  /// The measured end-to-end distance, always stored in inches.
  final double measuredDistance;

  final DistanceEndpoint start;
  final DistanceEndpoint end;

  Distance({
    required this.distanceId,
    required this.measuredDistance,
    required this.start,
    required this.end,
  }) {
    if (distanceId.trim().isEmpty) {
      throw ArgumentError('distanceId cannot be empty.');
    }
    if (!measuredDistance.isFinite || measuredDistance <= 0) {
      throw ArgumentError(
        'measuredDistance must be finite and greater than zero.',
      );
    }
    if (start == end) {
      throw ArgumentError('A distance must have two different endpoints.');
    }
    if (start is! TableDistanceEndpoint && end is! TableDistanceEndpoint) {
      throw ArgumentError(
        'A distance must connect at least one table fixture.',
      );
    }
    if (start is TableDistanceEndpoint && end is TableDistanceEndpoint) {
      final startTable = start as TableDistanceEndpoint;
      final endTable = end as TableDistanceEndpoint;
      if (startTable.tableId == endTable.tableId) {
        throw ArgumentError('A distance cannot connect a table to itself.');
      }
    }
  }

  /// Retained in JSON so the stored number is self-describing.
  String get measurementUnit => inchesUnit;

  Map<String, dynamic> toJson() => {
    'distanceId': distanceId,
    'measuredDistance': measuredDistance,
    'measurementUnit': measurementUnit,
    'start': start.toJson(),
    'end': end.toJson(),
  };

  factory Distance.fromJson(Map<String, dynamic> json) {
    final rawDistance = (json['measuredDistance'] as num).toDouble();
    final rawUnit = (json['measurementUnit'] as String).trim().toLowerCase();
    final measuredDistanceInches = switch (rawUnit) {
      'inches' || 'inch' || 'in' => rawDistance,
      'feet' || 'foot' || 'ft' => rawDistance * 12,
      _ => throw FormatException(
        'Unknown distance measurement unit: $rawUnit',
      ),
    };

    return Distance(
      distanceId: json['distanceId'] as String,
      measuredDistance: measuredDistanceInches,
      start: DistanceEndpoint.fromJson(
        Map<String, dynamic>.from(json['start'] as Map),
      ),
      end: DistanceEndpoint.fromJson(
        Map<String, dynamic>.from(json['end'] as Map),
      ),
    );
  }
}
