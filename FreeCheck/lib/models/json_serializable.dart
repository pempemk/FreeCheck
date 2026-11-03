/// Implemented by every model.
///
/// Each model also has `factory X.fromJson(Map<String, dynamic> json)`
/// (Dart interfaces cannot declare constructors). JSON keys are the
/// snake_case database columns, e.g. `orgId <-> org_id`.
abstract interface class JsonSerializable {
  Map<String, dynamic> toJson();
}
