import 'dart:ui';

/// Converts the persisted #RRGGBB zone value into a Flutter color.
Color zoneColorFromHex(String colorHex) {
  final normalized = colorHex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
