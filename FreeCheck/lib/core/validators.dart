// Helpers shared by the controllers' `validate` methods.

final hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
final digitsPattern = RegExp(r'^[0-9]+$');

/// Thai or English letters (plus spaces between words).
final thaiOrEnglishPattern = RegExp(r'^[A-Za-z฀-๿]+( [A-Za-z฀-๿]+)*$');
final isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Trimmed string, or `null` when the value is missing or blank.
String? textOf(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

/// Parses an int from an int or a digit string; `null` otherwise.
int? intOf(Object? value) {
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  if (value is String && RegExp(r'^-?\d+$').hasMatch(value.trim())) {
    return int.parse(value.trim());
  }
  return null;
}

/// Parses a number from a num or a numeric string; `null` otherwise.
num? numOf(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

/// Parses a `YYYY-MM-DD` date that exists on the calendar; `null` otherwise.
DateTime? dateOf(Object? value) {
  final s = textOf(value);
  if (s == null || !isoDatePattern.hasMatch(s)) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  // Reject dates like 2026-02-31 that DateTime silently rolls over.
  return parsed.toIso8601String().substring(0, 10) == s ? parsed : null;
}
