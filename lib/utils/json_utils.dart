// json_utils.dart
//
// Responsibility:
// Small JSON helpers shared by export and display services. These functions
// deliberately operate on dynamic JSON so newer survey fields are preserved.

import 'dart:convert';

Map<String, dynamic> deepCopyJsonMap(Map<String, dynamic> source) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
}

Map<String, dynamic> mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> mapListValue(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }
  return value.map(mapValue).toList(growable: false);
}

String? nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? nullableDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

int? nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime? nullableDateTime(Object? value) {
  final text = nullableString(value);
  return text == null ? null : DateTime.tryParse(text);
}

/// Flattens arbitrary JSON into dotted paths for a lossless-ish Excel view.
/// Lists use numeric path components such as
/// `distanceList.0.measuredDistance`.
Map<String, String> flattenJson(Object? value, {String prefix = ''}) {
  final result = <String, String>{};

  void visit(Object? current, String path) {
    if (current is Map) {
      if (current.isEmpty) {
        result[path] = '{}';
      }
      for (final entry in current.entries) {
        final next = path.isEmpty ? entry.key.toString() : '$path.${entry.key}';
        visit(entry.value, next);
      }
      return;
    }

    if (current is List) {
      if (current.isEmpty) {
        result[path] = '[]';
      }
      for (var index = 0; index < current.length; index += 1) {
        final next = path.isEmpty ? '$index' : '$path.$index';
        visit(current[index], next);
      }
      return;
    }

    result[path] = current == null ? 'null' : current.toString();
  }

  visit(value, prefix);
  return result;
}
