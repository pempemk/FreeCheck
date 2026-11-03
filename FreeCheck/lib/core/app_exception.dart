/// An error from a controller. [fields] holds one message per input that
/// failed validation, so the page can show it under that input.
class AppException implements Exception {
  const AppException(this.statusCode, this.message, {this.fields});

  /// 400 — input failed validation.
  factory AppException.validation(Map<String, String> fields) =>
      AppException(400, 'ข้อมูลไม่ถูกต้อง', fields: fields);

  /// 404 — the requested record does not exist.
  factory AppException.notFound(String message) => AppException(404, message);

  /// 409 — duplicate data or an invalid status transition.
  factory AppException.conflict(
    String message, {
    Map<String, String>? fields,
  }) => AppException(409, message, fields: fields);

  final int statusCode;
  final String message;
  final Map<String, String>? fields;

  Map<String, dynamic> toJson() => {
    'error': message,
    if (fields != null && fields!.isNotEmpty) 'fields': fields,
  };

  @override
  String toString() => 'AppException($statusCode, $message, $fields)';
}
