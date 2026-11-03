import 'json_serializable.dart';
import 'json_utils.dart';

class Organizer implements JsonSerializable {
  const Organizer({
    required this.orgName,
    required this.contactName,
    required this.color,
    this.orgId = 0,
    this.phone,
    this.rate = 0,
  });

  factory Organizer.fromJson(Map<String, dynamic> json) => Organizer(
    orgId: asInt(json['org_id']),
    orgName: json['org_name'] as String,
    contactName: json['contact_name'] as String,
    phone: json['phone'] as String?,
    color: json['color'] as String,
    rate: asNum(json['rate'] ?? 0),
  );

  /// 0 until saved.
  final int orgId;
  final String orgName;
  final String contactName;
  final String? phone;
  final String color;
  final num rate;

  @override
  Map<String, dynamic> toJson() => {
    'org_id': orgId,
    'org_name': orgName,
    'contact_name': contactName,
    'phone': phone,
    'color': color,
    'rate': rate,
  };
}
