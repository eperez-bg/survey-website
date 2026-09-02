// json_helpers.dart
// Defensive JSON helpers. The admin keeps the original JSON as the source of
// truth so model/calculation changes can evolve without dropping unknown fields.

class JsonHelpers {
  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static List<dynamic> list(dynamic value) => value is List ? value : const [];

  static String string(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static int integer(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double decimal(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static dynamic first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) return map[key];
    }
    return null;
  }
}
