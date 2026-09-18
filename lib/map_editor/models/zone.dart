class Zone {
  final String zoneId;
  final String label;
  final String colorHex;

  Zone({
    required this.zoneId,
    required this.label,
    required this.colorHex,
  }) {
    if (zoneId.trim().isEmpty) {
      throw ArgumentError('zoneId cannot be empty.');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError('Zone label cannot be empty.');
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorHex)) {
      throw ArgumentError('colorHex must use the format #RRGGBB.');
    }
  }

  Map<String, dynamic> toJson() => {
        'zoneId': zoneId,
        'label': label,
        'colorHex': colorHex,
      };

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        zoneId: json['zoneId'] as String,
        label: json['label'] as String,
        colorHex: json['colorHex'] as String,
      );
}

