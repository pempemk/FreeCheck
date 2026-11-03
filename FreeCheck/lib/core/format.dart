import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy', 'th');
final _shortDate = DateFormat('d MMM', 'th');
final _month = DateFormat('MMMM', 'th');
final _dateTime = DateFormat('d MMM yyyy HH:mm', 'th');
final _money = NumberFormat('#,##0.##');

/// `18 ต.ค. 2026`
String formatDate(DateTime? value) =>
    value == null ? '-' : _date.format(value.toLocal());

/// `18 ต.ค.`
String formatShortDate(DateTime? value) =>
    value == null ? '-' : _shortDate.format(value.toLocal());

String formatDateTime(DateTime? value) =>
    value == null ? '-' : _dateTime.format(value.toLocal());

/// `12–18 ตุลาคม`, or `28 ก.ย. – 4 ต.ค. 2026` across months.
String formatDateRange(DateTime start, DateTime? end) {
  if (end == null) return 'เริ่ม ${formatDate(start)}';
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${_month.format(end)}';
  }
  return '${formatShortDate(start)} – ${formatDate(end)}';
}

/// `฿ 24,000`
String formatBaht(num value) => '฿ ${_money.format(value)}';

/// `081-234-5678` for 10 digits, `02-123-4567` for 9; otherwise as is.
String formatPhone(String? phone) {
  if (phone == null || phone.isEmpty) return '-';
  if (phone.length == 10) {
    return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-'
        '${phone.substring(6)}';
  }
  if (phone.length == 9) {
    return '${phone.substring(0, 2)}-${phone.substring(2, 5)}-'
        '${phone.substring(5)}';
  }
  return phone;
}

/// `YYYY-MM-DD`, the date format the controllers expect.
String toApiDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

/// Parses `#RRGGBB`; falls back to grey.
Color colorFromHex(String? hex) {
  final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  return value == null ? Colors.grey : Color(0xFF000000 | value);
}

String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
