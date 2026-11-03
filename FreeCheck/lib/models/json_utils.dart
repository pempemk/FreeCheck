// Conversions used by the models' fromJson/toJson. Not exported.

int asInt(Object? value) => value is int ? value : int.parse('$value');

/// `true`/`false`, or SQLite's `1`/`0`.
bool asBool(Object? value) => value == true || value == 1;

num asNum(Object? value) => value is num ? value : num.parse('$value');

DateTime? asDateTime(Object? value) => switch (value) {
  null => null,
  DateTime() => value,
  _ => DateTime.parse('$value'),
};

/// `YYYY-MM-DD`, for DATE columns.
String? dateOnly(DateTime? value) {
  if (value == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}'
      '-${two(value.day)}';
}

/// Parses each element of a JSON list (missing list → empty).
List<T> listOf<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
  for (final item in value as List? ?? const [])
    parse(item as Map<String, dynamic>),
];

/// Parses a nested JSON object, or returns null when it is absent.
T? objectOf<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is Map<String, dynamic> ? parse(value) : null;
